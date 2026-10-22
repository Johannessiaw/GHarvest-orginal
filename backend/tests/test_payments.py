import hashlib
import hmac
import json
import os
from pathlib import Path
import sys

os.environ['GHarvest_DB'] = str(Path(__file__).parent / 'payments_GHarvest.db')
os.environ['OPENAI_API_KEY'] = ''
os.environ['GHANANLP_API_KEY'] = ''
os.environ['LOCAL_ASR_URL'] = ''
os.environ['LOCAL_TTS_URL'] = ''
os.environ['LOCAL_LLM_URL'] = ''
os.environ['PAYSTACK_WEBHOOK_SECRET'] = 'test-secret'
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import main
from fastapi.testclient import TestClient


def test_invalid_paystack_signature_is_rejected():
    payload = json.dumps({'event': 'charge.success', 'data': {'reference': 'ref-x'}}).encode()
    with TestClient(main.app) as client:
        response = client.post('/api/v1/payments/paystack/webhook', content=payload, headers={'x-paystack-signature': 'bad'})
        assert response.status_code == 401


def test_valid_paystack_signature_is_accepted():
    payload = json.dumps({'event': 'unknown', 'data': {'reference': 'ref-x'}}).encode()
    signature = hmac.new(b'test-secret', payload, hashlib.sha512).hexdigest()
    with TestClient(main.app) as client:
        response = client.post('/api/v1/payments/paystack/webhook', content=payload, headers={'x-paystack-signature': signature})
        assert response.status_code == 200
        assert response.json()['ok'] is True


def test_failed_payment_releases_reserved_inventory():
    with TestClient(main.app) as client:
        farmer = {'X-Client-ID': 'farmer-release'}
        buyer = {'X-Client-ID': 'buyer-release'}
        listing = client.post('/api/v1/produce/listings', headers=farmer, json={
            'farmer_name': 'Release Farm', 'crop': 'Tomato', 'quantity': 10, 'unit': 'bags',
            'asking_price': 100, 'market': 'Kumasi'
        }).json()['listing_id']
        order = client.post('/api/v1/orders', headers=buyer, json={
            'buyer_name': 'Buyer', 'listing_id': listing, 'quantity': 3, 'delivery_location': 'Kumasi'
        }).json()
        reference = 'release-ref-123'
        conn = main.db()
        try:
            conn.execute("UPDATE orders SET payment_provider='paystack', payment_reference=?, payment_status='pending', status='payment_processing' WHERE id=?", (reference, order['order_id']))
            conn.commit()
        finally:
            conn.close()
        assert main.apply_payment_failure(reference, {'event': 'charge.failed', 'data': {'reference': reference}}) is True
        rows = client.get('/api/v1/produce/listings?mine=true', headers=farmer).json()['results']
        assert next(x for x in rows if x['id'] == listing)['quantity'] == 10


def test_failed_payment_reference_targets_latest_order():
    with TestClient(main.app) as client:
        farmer = {'X-Client-ID': 'farmer-latest'}
        buyer = {'X-Client-ID': 'buyer-latest'}
        a = client.post('/api/v1/produce/listings', headers=farmer, json={'farmer_name':'Farm A','crop':'Tomato','quantity':5,'unit':'bags','asking_price':100,'market':'Kumasi'}).json()['listing_id']
        b = client.post('/api/v1/produce/listings', headers=farmer, json={'farmer_name':'Farm B','crop':'Tomato','quantity':8,'unit':'bags','asking_price':100,'market':'Kumasi'}).json()['listing_id']
        oa = client.post('/api/v1/orders', headers=buyer, json={'buyer_name':'Buyer','listing_id':a,'quantity':2,'delivery_location':'Kumasi'}).json()['order_id']
        ob = client.post('/api/v1/orders', headers=buyer, json={'buyer_name':'Buyer','listing_id':b,'quantity':3,'delivery_location':'Kumasi'}).json()['order_id']
        conn = main.db()
        try:
            for oid in (oa, ob):
                conn.execute("UPDATE orders SET payment_reference='reused-test-ref', payment_provider='paystack', payment_status='pending' WHERE id=?", (oid,))
            conn.commit()
        finally:
            conn.close()
        assert main.apply_payment_failure('reused-test-ref', {'event':'charge.failed','data':{'reference':'reused-test-ref'}}) is True
        rows = {x['id']: x['quantity'] for x in client.get('/api/v1/produce/listings?mine=true', headers=farmer).json()['results']}
        assert rows[a] == 3
        assert rows[b] == 8
