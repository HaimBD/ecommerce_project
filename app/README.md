# Flask E‑Commerce (Kinesis + Elasticsearch + Socket.IO)

A minimal, production‑ready starter for a Flask‑based e‑commerce app featuring:
- User auth (Flask‑Login).
- Product catalog management (CRUD).
- Real‑time order tracking (Flask‑SocketIO).
- AWS Kinesis Streams ingestion for user activity + order events (boto3).
- Full‑text search across the product catalog (Elasticsearch 8.x).

> This is a starter template intended for local development and easy cloud deployment. You can extend it with payments, admin UI, and CI/CD.

---

## Requirements

- Python 3.10+
- (Optional) Node.js if you plan to add a modern frontend bundle.
- Elasticsearch 8.x accessible via HTTP(S) (or OpenSearch with minor changes).
- AWS credentials with access to 2 Streams (activity + orders).
- (Optional but recommended) Redis if you want WebSocket scaling.

## Quickstart

1. **Create a virtualenv & install deps**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Set environment variables**
   ```bash
   export FLASK_ENV=development
   export SECRET_KEY="dev-change-me"
   export DATABASE_URL="sqlite:///app.db"
   export ELASTICSEARCH_URL="http://localhost:9200"     # or https://user:pass@host:9200
   export ES_INDEX_PRODUCTS="products"
   export AWS_REGION="eu-west-1"
   export KINESIS_STREAM_ACTIVITY="ecom-activity"
   export KINESIS_STREAM_ORDERS="ecom-orders"
   # Optional Socket.IO message queue (for scaling beyond a single process)
   # export REDIS_URL="redis://localhost:6379/0"
   ```

3. **Initialize the DB & seed products**
   ```bash
   flask db init
   flask db migrate -m "init"
   flask db upgrade
   python manage.py seed
   ```

4. **Run the app (Socket.IO server)**
   ```bash
   python manage.py run
   ```
   Visit http://127.0.0.1:5000/

## Elasticsearch Notes

- Ensure the `ES_INDEX_PRODUCTS` index exists; the app will attempt to create it with a basic mapping. You may customize mappings/analysis.
- If using Elastic Cloud, set `ELASTICSEARCH_URL=https://<user>:<pass>@<host>:<port>`.

## Kinesis Notes

- The app will `put_record` user activity and order events into the streams defined by `KINESIS_STREAM_ACTIVITY` and `KINESIS_STREAM_ORDERS`.
- Ensure your AWS credentials are available to boto3 (env vars, shared credentials file, or IAM role).

## Real‑time Order Tracking

- When an order status changes (e.g., from "PLACED" → "PROCESSING" → "SHIPPED" → "DELIVERED"), the server emits a Socket.IO event to clients subscribed to that order room (`order-{order_id}`).
- See `templates/order_status.html` for a minimal client‑side example.

## Admin

- To mark a user as admin:
  ```sql
  UPDATE user SET is_admin = 1 WHERE email = 'you@example.com';
  ```
- Then visit `/admin/products` to add/edit products and `/admin/orders` to update order statuses.

## Migrations

This project uses Flask‑Migrate (Alembic). After changing models:
```bash
flask db migrate -m "your message"
flask db upgrade
```

## Tests

Add tests under `tests/` and run with `pytest` (not included by default).

## Deploying

- Use `gunicorn` with `eventlet` or `gevent` worker for Socket.IO:
  ```bash
  gunicorn -k eventlet -w 1 manage:app --bind 0.0.0.0:5000
  ```
- Configure environment variables in your platform (Heroku, AWS Elastic Beanstalk, ECS, etc.).
