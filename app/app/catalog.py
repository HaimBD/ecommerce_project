from flask import Blueprint, render_template, request, redirect, url_for, flash, abort
from flask_login import current_user, login_required
from .extensions import db
from .models import Product
from .kinesis import put_activity
from .search import index_product, delete_product_doc

bp = Blueprint('catalog', __name__, url_prefix='/catalog')

@bp.route('/')
def list_products():
    q = request.args.get('q')
    if q:
        # Redirect to search
        return redirect(url_for('search.search_products', q=q))
    products = Product.query.order_by(Product.created_at.desc()).all()
    return render_template('product_list.html', products=products)

@bp.route('/product/<int:product_id>')
def product_detail(product_id):
    product = Product.query.get_or_404(product_id)
    put_activity('view_product', {'product_id': product.id, 'name': product.name})
    return render_template('product_detail.html', product=product)

# Admin CRUD
def admin_required():
    if not (current_user.is_authenticated and current_user.is_admin):
        abort(403)

@bp.route('/admin/products')
@login_required
def admin_products():
    admin_required()
    products = Product.query.order_by(Product.id.desc()).all()
    return render_template('admin_products.html', products=products)

@bp.route('/admin/products/new', methods=['GET', 'POST'])
@login_required
def admin_new_product():
    admin_required()
    if request.method == 'POST':
        name = request.form.get('name')
        price = float(request.form.get('price', '0') or 0)
        stock = int(request.form.get('stock', '0') or 0)
        description = request.form.get('description')
        category = request.form.get('category')
        p = Product(name=name, price=price, stock=stock, description=description, category=category)
        db.session.add(p)
        db.session.commit()
        index_product(p)
        flash('Product created.', 'success')
        return redirect(url_for('catalog.admin_products'))
    return render_template('admin_product_form.html', product=None)

@bp.route('/admin/products/<int:pid>/edit', methods=['GET', 'POST'])
@login_required
def admin_edit_product(pid):
    admin_required()
    p = Product.query.get_or_404(pid)
    if request.method == 'POST':
        p.name = request.form.get('name')
        p.price = float(request.form.get('price', '0') or 0)
        p.stock = int(request.form.get('stock', '0') or 0)
        p.description = request.form.get('description')
        p.category = request.form.get('category')
        db.session.commit()
        index_product(p)
        flash('Product updated.', 'success')
        return redirect(url_for('catalog.admin_products'))
    return render_template('admin_product_form.html', product=p)

@bp.route('/admin/products/<int:pid>/delete', methods=['POST'])
@login_required
def admin_delete_product(pid):
    admin_required()
    p = Product.query.get_or_404(pid)
    db.session.delete(p)
    db.session.commit()
    delete_product_doc(pid)
    flash('Product deleted.', 'info')
    return redirect(url_for('catalog.admin_products'))
