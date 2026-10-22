import os
from pathlib import Path
import sys
os.environ['GHarvest_DB'] = str(Path(__file__).parent / 'inventory_GHarvest.db')
os.environ['OPENAI_API_KEY']=''; os.environ['GHANANLP_API_KEY']=''; os.environ['LOCAL_ASR_URL']=''; os.environ['LOCAL_TTS_URL']=''; os.environ['LOCAL_LLM_URL']=''
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import main
from fastapi.testclient import TestClient

def test_order_reserves_inventory():
    with TestClient(main.app) as client:
        listing = client.post('/api/v1/produce/listings', headers={'X-Client-ID':'farmer-xx'}, json={
            'farmer_name':'Inventory Farm','crop':'Tomato','quantity':5,'unit':'crates','asking_price':100,'market':'Kumasi'
        }).json()['listing_id']
        first = client.post('/api/v1/orders', headers={'X-Client-ID':'buyer-xxx'}, json={
            'buyer_name':'Buyer','listing_id':listing,'quantity':4,'delivery_location':'Kumasi'
        })
        assert first.status_code == 200
        second = client.post('/api/v1/orders', headers={'X-Client-ID':'buyer-yyy'}, json={
            'buyer_name':'Buyer 2','listing_id':listing,'quantity':2,'delivery_location':'Kumasi'
        })
        assert second.status_code == 400
