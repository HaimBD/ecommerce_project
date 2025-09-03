from flask import Blueprint, render_template, request, redirect, url_for, flash
from flask_login import login_user, logout_user, login_required, current_user
from .extensions import db
from .models import User
from .kinesis import put_activity

bp = Blueprint('auth', __name__, url_prefix='/auth')

@bp.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        email = request.form.get('email', '').strip().lower()
        password = request.form.get('password', '')
        if not email or not password:
            flash('Email and password are required.', 'danger')
            return redirect(url_for('auth.register'))
        if User.query.filter_by(email=email).first():
            flash('Email already registered.', 'warning')
            return redirect(url_for('auth.register'))
        user = User(email=email)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        flash('Registered! Please log in.', 'success')
        return redirect(url_for('auth.login'))
    return render_template('register.html')

@bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email', '').strip().lower()
        password = request.form.get('password', '')
        user = User.query.filter_by(email=email).first()
        if user and user.check_password(password):
            login_user(user)
            put_activity('login', {'email': email, 'user_id': user.id})
            return redirect(url_for('catalog.list_products'))
        flash('Invalid credentials.', 'danger')
        return redirect(url_for('auth.login'))
    return render_template('login.html')

@bp.route('/logout')
@login_required
def logout():
    put_activity('logout', {'user_id': current_user.id})
    logout_user()
    flash('Logged out.', 'info')
    return redirect(url_for('auth.login'))
