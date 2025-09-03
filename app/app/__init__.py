import os
from flask import Flask
from .extensions import db, migrate, login_manager, socketio
from .config import Config
from .models import User

def create_app():
    app = Flask(__name__, static_folder='static', template_folder='templates')
    app.config.from_object(Config())

    # Init extensions
    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)

    # Socket.IO (message queue optional via REDIS_URL env)
    message_queue = os.getenv("REDIS_URL")
    if message_queue:
        socketio.init_app(app, message_queue=message_queue, cors_allowed_origins="*")
    else:
        socketio.init_app(app, cors_allowed_origins="*")

    # Blueprints
    from .auth import bp as auth_bp
    from .catalog import bp as catalog_bp
    from .orders import bp as orders_bp
    from .search import bp as search_bp
    from .admin import bp as admin_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(catalog_bp)
    app.register_blueprint(orders_bp)
    app.register_blueprint(search_bp)
    app.register_blueprint(admin_bp)

    # Home route
    @app.route('/')
    def home():
        from flask import render_template
        return render_template('index.html')

    # User loader
    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    return app

# Expose socketio for manage.py
socketio = socketio
