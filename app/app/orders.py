from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort
from flask_login import login_required, current_user
from .extensions import db
from .models import Product, Order, OrderItem
from .kinesis import put_order_event
from .sockets import emit_order_update

bp = Blueprint('orders', __name__, url_prefix='/orders')

def _cart():
    return session.setdefault('cart', {})

@bp.route('/cart')
def cart():
    cart = _cart()
    items = []
    total = 0.0
    for pid, qty in cart.items():
        product = Product.query.get(int(pid))
        if product:
            line_total = product.price * qty
            items.append({'product': product, 'qty': qty, 'line_total': line_total})
            total += line_total
    return render_template('cart.html', items=items, total=total)

@bp.route('/cart/add/<int:pid>', methods=['POST'])
def add_to_cart(pid):
    product = Product.query.get_or_404(pid)
    qty = int(request.form.get('qty', '1') or 1)
    cart = _cart()
    cart[str(pid)] = cart.get(str(pid), 0) + qty
    session.modified = True
    flash(f'Added {qty} × {product.name} to cart.', 'success')
    return redirect(url_for('catalog.list_products'))

@bp.route('/cart/clear', methods=['POST'])
def clear_cart():
    session['cart'] = {}
    flash('Cart cleared.', 'info')
    return redirect(url_for('orders.cart'))

@bp.route('/checkout', methods=['POST'])
@login_required
def checkout():
    cart = _cart()
    if not cart:
        flash('Your cart is empty.', 'warning')
        return redirect(url_for('orders.cart'))
    order = Order(user_id=current_user.id, status='PLACED', total_amount=0.0)
    db.session.add(order)
    total = 0.0
    for pid, qty in cart.items():
        product = Product.query.get(int(pid))
        if not product:
            continue
        qty = int(qty)
        item = OrderItem(order=order, product_id=product.id, quantity=qty, price_each=product.price)
        total += product.price * qty
        db.session.add(item)
    order.total_amount = total
    db.session.commit()
    session['cart'] = {}
    put_order_event('order_placed', order)
    emit_order_update(order.id, {'status': order.status})
    flash(f'Order #{order.id} placed! Track it in real time.', 'success')
    return redirect(url_for('orders.track', order_id=order.id))

@bp.route('/track/<int:order_id>')
@login_required
def track(order_id):
    order = Order.query.get_or_404(order_id)
    if order.user_id != current_user.id and not current_user.is_admin:
        abort(403)
    return render_template('order_status.html', order=order)

# Admin: update order status
@bp.route('/admin/orders')
@login_required
def admin_orders():
    if not current_user.is_admin:
        abort(403)
    from .models import Order
    orders = Order.query.order_by(Order.created_at.desc()).all()
    return render_template('admin_orders.html', orders=orders)

@bp.route('/admin/orders/<int:oid>/status', methods=['POST'])
@login_required
def admin_update_status(oid):
    if not current_user.is_admin:
        abort(403)
    order = Order.query.get_or_404(oid)
    new_status = request.form.get('status', 'PROCESSING').upper()
    order.status = new_status
    db.session.commit()
    put_order_event('order_status_changed', order)
    emit_order_update(order.id, {'status': order.status})
    flash(f'Order #{order.id} updated to {order.status}.', 'success')
    return redirect(url_for('orders.admin_orders'))
