from flask import current_app
from .extensions import socketio
from flask_socketio import join_room, leave_room, emit

@socketio.on('join_order')
def on_join_order(data):
    order_id = data.get('order_id')
    room = f"order-{order_id}"
    join_room(room)
    emit('joined', {'room': room})

def emit_order_update(order_id: int, data: dict):
    room = f"order-{order_id}"
    socketio.emit('order_update', {'order_id': order_id, **data}, to=room)
