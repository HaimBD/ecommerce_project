from flask import Blueprint, render_template
from flask_login import login_required, current_user
from .models import Order

bp = Blueprint('admin', __name__, url_prefix='/admin')

@bp.before_request
def restrict_to_admin():
    if not current_user.is_authenticated or not current_user.is_admin:
        from flask import abort
        abort(403)

@bp.route('/orders')
@login_required
def orders():
    orders = Order.query.order_by(Order.created_at.desc()).all()
    return render_template('admin_orders.html', orders=orders)
