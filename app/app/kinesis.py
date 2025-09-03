import json
import boto3
from flask import current_app
from flask_login import current_user

def _client():
    region = current_app.config['AWS_REGION']
    return boto3.client('kinesis', region_name=region)

def put_activity(event_type: str, payload: dict):
    """Put a user activity event to Kinesis."""
    stream = current_app.config['KINESIS_STREAM_ACTIVITY']
    record = {
        "event_type": event_type,
        "user_id": getattr(current_user, 'id', None),
        "payload": payload,
    }
    try:
        _client().put_record(
            StreamName=stream,
            Data=json.dumps(record).encode('utf-8'),
            PartitionKey=str(record.get("user_id") or "anonymous")
        )
    except Exception as e:
        # For a starter app, we swallow exceptions; add logging in production.
        pass

def put_order_event(event_type: str, order):
    stream = current_app.config['KINESIS_STREAM_ORDERS']
    record = {
        "event_type": event_type,
        "order_id": order.id,
        "user_id": order.user_id,
        "status": order.status,
        "total_amount": order.total_amount,
    }
    try:
        _client().put_record(
            StreamName=stream,
            Data=json.dumps(record).encode('utf-8'),
            PartitionKey=str(order.id)
        )
    except Exception:
        pass
