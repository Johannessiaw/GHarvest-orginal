import os
from pathlib import Path
import sys

os.environ['GHarvest_DB'] = str(Path(__file__).parent / 'test_GHarvest.db')
os.environ['OPENAI_API_KEY'] = ''
os.environ['GHANANLP_API_KEY'] = ''
os.environ['LOCAL_ASR_URL'] = ''
os.environ['LOCAL_TTS_URL'] = ''
os.environ['LOCAL_LLM_URL'] = ''
os.environ['DEMO_MODE'] = 'true'
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import main
from fastapi.testclient import TestClient


def test_health():
    with TestClient(main.app) as client:
        r = client.get('/health')
        assert r.status_code == 200
        assert r.json()['status'] == 'ok'
        assert 'marketplace' in r.json()['capabilities']


def test_fresh_database_initializes_cleanly(tmp_path):
    original = main.DATABASE_PATH
    try:
        main.DATABASE_PATH = str(tmp_path / 'fresh.db')
        main.init_db()
        with main.db() as conn:
            assert conn.execute('SELECT COUNT(*) FROM listings').fetchone()[0] >= 1
            assert conn.execute('SELECT COUNT(*) FROM buyers').fetchone()[0] >= 1
            assert conn.execute('SELECT COUNT(*) FROM transporters').fetchone()[0] >= 1
    finally:
        main.DATABASE_PATH = original


def test_market_search():
    with TestClient(main.app) as client:
        r = client.get('/api/v1/market/search?crop=tomato')
        assert r.status_code == 200
        assert r.json()['results']
        assert all('Tomato' in item['crop'] for item in r.json()['results'])


def test_chat_uses_market_tool_and_persists():
    with TestClient(main.app) as client:
        headers = {'X-Client-ID': 'test-client-a'}
        r = client.post('/api/v1/ai/chat', headers=headers, json={'message': 'What is the price of tomatoes?', 'language': 'en-GH'})
        assert r.status_code == 200
        body = r.json()
        assert body['detected_intent'] == 'check_price'
        assert body['tool_result']['results']
        conversation_id = body['conversation_id']
        history = client.get(f'/api/v1/conversations/{conversation_id}', headers=headers)
        assert history.status_code == 200
        assert len(history.json()['messages']) == 2


def test_conversation_isolation():
    with TestClient(main.app) as client:
        r = client.post('/api/v1/ai/chat', headers={'X-Client-ID': 'client-a'}, json={'message': 'hello', 'language': 'en-GH'})
        conversation_id = r.json()['conversation_id']
        denied = client.get(f'/api/v1/conversations/{conversation_id}', headers={'X-Client-ID': 'client-b'})
        assert denied.status_code == 404


def test_listing_order_and_demo_payment_flow():
    with TestClient(main.app) as client:
        farmer_headers = {'X-Client-ID': 'farmer-a'}
        buyer_headers = {'X-Client-ID': 'buyer-aa'}
        farmer = client.post('/api/v1/produce/listings', headers=farmer_headers, json={
            'farmer_name': 'Test Farm', 'crop': 'Okra', 'quantity': 10, 'unit': 'bags',
            'asking_price': 250, 'market': 'Kumasi'
        })
        assert farmer.status_code == 200
        listing_id = farmer.json()['listing_id']
        order = client.post('/api/v1/orders', headers=buyer_headers, json={
            'buyer_name': 'Buyer A', 'listing_id': listing_id, 'quantity': 2,
            'delivery_location': 'Kumasi'
        })
        assert order.status_code == 200
        order_id = order.json()['order_id']
        visible = client.get('/api/v1/orders', headers=buyer_headers)
        assert any(item['id'] == order_id for item in visible.json()['orders'])
        assert next(item for item in visible.json()['orders'] if item['id'] == order_id)['can_pay'] is True
        hidden = client.get('/api/v1/orders', headers={'X-Client-ID': 'buyer-bb'})
        assert all(item['id'] != order_id for item in hidden.json()['orders'])
        paid = client.post(f'/api/v1/orders/{order_id}/pay', headers=buyer_headers)
        assert paid.status_code == 200
        assert paid.json()['payment_status'] == 'paid'


def test_profile_and_composite_kofi_tools():
    with TestClient(main.app) as client:
        headers = {'X-Client-ID': 'profile-test'}
        saved = client.put('/api/v1/profile', headers=headers, json={
            'name': 'Ama Farm', 'role': 'farmer', 'phone': '0550000000', 'email': 'ama@example.com', 'location': 'Kumasi'
        })
        assert saved.status_code == 200
        assert saved.json()['name'] == 'Ama Farm'
        read = client.get('/api/v1/profile', headers=headers)
        assert read.status_code == 200
        assert read.json()['location'] == 'Kumasi'

        chat = client.post('/api/v1/ai/chat', headers=headers, json={
            'message': 'I have 20 bags of maize. What is the price, find a buyer and a truck for me.',
            'language': 'en-GH', 'latitude': 6.6885, 'longitude': -1.6244,
        })
        assert chat.status_code == 200
        assert chat.json()['detected_intent'] == 'check_price'
        assert set(chat.json()['tool_used'].split(',')) >= {'check_price', 'find_buyer', 'find_transport'}
