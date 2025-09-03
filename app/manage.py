import os
from app import create_app, socketio
from app.extensions import db
from app.models import User, Product
from flask.cli import with_appcontext
import click

app = create_app()

@app.shell_context_processor
def shell():
    return {"db": db, "User": User, "Product": Product}

@click.group()
def cli():
    pass

@cli.command('seed')
@with_appcontext
def seed():
    """Seed the database with a few products."""
    if Product.query.count() == 0:
        sample = [
            Product(name="Wireless Mouse", description="Ergonomic 2.4G mouse", price=29.99, category="Peripherals", stock=50),
            Product(name="Mechanical Keyboard", description="RGB, Blue switches", price=89.99, category="Peripherals", stock=20),
            Product(name="USB-C Charger 65W", description="GaN fast charger", price=39.99, category="Power", stock=100),
        ]
        db.session.add_all(sample)
        db.session.commit()
        # Index to Elasticsearch
        from app.search import index_product
        for p in sample:
            index_product(p)
        print("Seeded sample products.")
    else:
        print("Products already present; skipping.")

@cli.command('run')
def run():
    """Run the Socket.IO dev server."""
    socketio.run(app, host="127.0.0.1", port=5000, allow_unsafe_werkzeug=True)

if __name__ == '__main__':
    cli()
