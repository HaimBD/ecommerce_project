from flask import Blueprint, render_template, request, current_app
from elasticsearch import Elasticsearch
from .models import Product
from .extensions import db

bp = Blueprint('search', __name__, url_prefix='/search')

def get_es():
    url = current_app.config['ELASTICSEARCH_URL']
    return Elasticsearch(url, verify_certs=False)  # adjust verify_certs as needed

def ensure_index(es, index):
    if not es.indices.exists(index=index):
        es.indices.create(
            index=index,
            mappings={
                "properties": {
                    "name": {"type": "text"},
                    "description": {"type": "text"},
                    "category": {"type": "keyword"},
                    "price": {"type": "float"}
                }
            }
        )

def index_product(product: Product):
    es = get_es()
    index = current_app.config['ES_INDEX_PRODUCTS']
    ensure_index(es, index)
    doc = {
        "name": product.name,
        "description": product.description or "",
        "category": product.category or "",
        "price": product.price,
    }
    es.index(index=index, id=product.id, document=doc)

def delete_product_doc(product_id: int):
    es = get_es()
    index = current_app.config['ES_INDEX_PRODUCTS']
    try:
        es.delete(index=index, id=product_id)
    except Exception:
        pass

@bp.route('/')
def search_products():
    q = request.args.get('q', '').strip()
    results = []
    if q:
        es = get_es()
        index = current_app.config['ES_INDEX_PRODUCTS']
        try:
            res = es.search(
                index=index,
                query={
                    "multi_match": {
                        "query": q,
                        "fields": ["name^2", "description"]
                    }
                }
            )
            ids = [int(hit['_id']) for hit in res['hits']['hits']]
            if ids:
                results = Product.query.filter(Product.id.in_(ids)).all()
        except Exception:
            results = []
    return render_template('search_results.html', q=q, products=results)
