import os
from pathlib import Path
import sys
os.environ['GHarvest_DB'] = str(Path(__file__).parent / 'matrix_GHarvest.db')
os.environ['OPENAI_API_KEY']=''
os.environ['GHANANLP_API_KEY']=''
os.environ['LOCAL_ASR_URL']=''
os.environ['LOCAL_TTS_URL']=''
os.environ['LOCAL_LLM_URL']=''
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import main


def test_intent_matrix():
    cases = {
        'What is the market price of tomatoes?': 'check_price',
        'Find me a buyer for my maize.': 'find_buyer',
        'I need a truck for 20 bags of maize.': 'find_transport',
        'Will it rain in Kumasi today?': 'check_weather',
        'Track my order number 123': 'track_order',
        'Help me list my produce': 'list_produce',
        'Akwaaba Kofi': 'greeting',
    }
    for text, expected in cases.items():
        assert main.intent_for(text) == expected


def test_quantity_and_location_extractors():
    assert main.extract_quantity('move 25 bags of maize') == 25
    assert main.extract_location('weather in Kumasi') == 'Kumasi'
    assert main.extract_locations('move maize from Kumasi to Accra') == ['Kumasi', 'Accra']


def test_twi_and_code_switch_routing():
    assert main.intent_for('Mepɛ sɛ mete ase, what is the price of tomato?') == 'check_price'
    assert main.intent_for('Mepɛ buyer ma me maize') == 'find_buyer'


def test_language_detection_heuristics():
    assert main.guess_language_from_transcript('Me pɛ sɛ me tɔn me tomato.', 'en-GH') == 'tw'
    assert main.guess_language_from_transcript('Hello, what is the market price?', 'en-GH') == 'en-GH'

