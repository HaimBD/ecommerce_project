import os

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-change-me')
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL', 'sqlite:///app.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    ELASTICSEARCH_URL = os.getenv('ELASTICSEARCH_URL', 'http://localhost:9200')
    ES_INDEX_PRODUCTS = os.getenv('ES_INDEX_PRODUCTS', 'products')

    AWS_REGION = os.getenv('AWS_REGION', 'eu-west-1')
    KINESIS_STREAM_ACTIVITY = os.getenv('KINESIS_STREAM_ACTIVITY', 'ecom-activity')
    KINESIS_STREAM_ORDERS = os.getenv('KINESIS_STREAM_ORDERS', 'ecom-orders')
