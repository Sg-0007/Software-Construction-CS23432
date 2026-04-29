from flask import Flask, request, jsonify
import os
import json
import logging
from typing import Dict, List
from dotenv import load_dotenv
from flask_cors import CORS
import traceback

load_dotenv()

from profile_agent import process_profile_chat
from scheme_search_agent import search_schemes
from scheme_display_agent import SchemeDisplayAgent, fetch_scheme_details

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Global session state (in memory for single-user backend prototype)
session = {
    'phase': 'PROFILING',  # PROFILING or SCHEME_INTERACTION
    'user_info': {
        "full_name": None, "state": None, "gender": None, "caste": None,
        "occupation": None, "category": None, "income": None, "additional_details": None
    },
    'profile_session': {}, 
    'agent': None,
    'schemes': []
}

def validate_schemes(schemes: List[Dict]) -> List[Dict]:
    return [s for s in schemes if s.get('metadata', {}).get('scheme_name')]

def format_for_frontend(schemes: List[Dict]) -> List[Dict]:
    formatted = []
    for s in schemes:
        metadata = s.get('metadata', {})
        formatted.append({
            'scheme_id': metadata.get('scheme_id', str(s.get('id', ''))),
            'title': metadata.get('scheme_name', ''),
            'category': metadata.get('category', ''),
            'description': metadata.get('brief_description', ''),
            'state': metadata.get('state', '')
        })
    return formatted

@app.route('/api/submit_profile', methods=['POST'])
def submit_profile():
    try:
        profile = request.json
        if not profile:
            return jsonify({'error': 'No profile data provided'}), 400
            
        with open('user_details.json', 'w', encoding='utf-8') as f:
            json.dump(profile, f, indent=4)
            
        logger.info("Direct Form Profile saved. Triggering Pinecone search...")
        
        schemes = search_schemes('user_details.json', 'recommended_schemes2.json')
        valid_schemes = validate_schemes(schemes)
        
        session['user_info'] = profile
        session['schemes'] = valid_schemes
        session['agent'] = SchemeDisplayAgent(valid_schemes, profile)
        session['phase'] = 'GENERAL_CHAT'
        
        return jsonify({
            'response': f"Thanks {profile.get('full_name', profile.get('name', 'User'))}! I found {len(valid_schemes)} recommended schemes for you! You can review them below, tap on one for details, or ask me any questions.",
            'action': 'complete',
            'data': format_for_frontend(valid_schemes)
        })
    except Exception as e:
        logger.error(f"Profile submission failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    try:
        user_input = request.json.get('message', '').strip()
        profile_data = request.json.get('profile') or {}
        
        # Debug Logging for Profile Data
        print("INCOMING PROFILE DATA:", profile_data)
        print("CURRENT SESSION PHASE:", session.get('phase'))
        print("FULL SESSION STATE:", {k: (v if k != 'agent' else '<Agent>') for k, v in session.items()})
        
        if not user_input and not profile_data:
            return jsonify({'response': 'Please provide a message.', 'action': 'none'})

        if profile_data and session['phase'] == 'PROFILING':
            session['user_info'].update(profile_data)
            session['phase'] = 'PROFILING_COMPLETE'
            with open('user_details.json', 'w', encoding='utf-8') as f:
                json.dump(session['user_info'], f, indent=4)
            logger.info("Supabase Profile loaded securely bypassing cold chat.")
            
            schemes = search_schemes('user_details.json', 'recommended_schemes2.json')
            valid_schemes = validate_schemes(schemes)
            session['schemes'] = valid_schemes
            session['agent'] = SchemeDisplayAgent(valid_schemes, session['user_info'])
            session['phase'] = 'GENERAL_CHAT'

        # Phase 1: Interactive Profiling Conversation
        if session['phase'] == 'PROFILING':
            # Boot response or first chat
            if user_input.lower() in ['hello', 'hi', 'start']:
                greeting = f"👋 Welcome to the Government Scheme Finder chatbot!\nLet's get to know you, {session['user_info'].get('full_name', 'User')}. You can say something like: 'I'm Priya from Tamil Nadu, my income is under 1 lakh.'"
                return jsonify({'response': greeting, 'action': 'profiling', 'data': session['user_info']})
            
            print(f"DEBUG: session['user_info'] content: {session.get('user_info')}")
            
            response, updated_info, is_complete, updated_profile_session = process_profile_chat(
                user_input, session.get('user_info', {}), session.get('profile_session', {})
            )
            
            session['user_info'] = updated_info
            session['profile_session'] = updated_profile_session
            
            # Transition to Searching Phase automatically
            if is_complete:
                session['phase'] = 'PROFILING_COMPLETE'
                
                # Safe conversion and field handling
                profile = dict(session['user_info'])
                profile['category'] = profile.get('caste', profile.get('category', ''))
                # Ensure full_name is present for downstream use if needed
                profile['full_name'] = profile.get('full_name', profile.get('name', 'User'))
                
                with open('user_details.json', 'w', encoding='utf-8') as f:
                    json.dump(profile, f, indent=4)
                    
                logger.info("User profile completed and saved. Triggering Pinecone search...")
                
                schemes = search_schemes('user_details.json', 'recommended_schemes2.json')
                valid_schemes = validate_schemes(schemes)
                
                if not valid_schemes:
                    return jsonify({
                        'response': response + "\n\nSorry, no schemes found matching your profile.",
                        'action': 'complete',
                        'data': []
                    })
                
                session['schemes'] = valid_schemes
                session['agent'] = SchemeDisplayAgent(valid_schemes)
                session['phase'] = 'GENERAL_CHAT'
                
                return jsonify({
                    'response': response + f"\n\nI found {len(valid_schemes)} recommended schemes for you! Ask me to 'show schemes' to view them.",
                    'action': 'complete',
                    'data': format_for_frontend(valid_schemes)
                })

            return jsonify({
                'response': response,
                'action': 'profiling',
                'data': session['user_info']
            })

        # Phase 2: Interacting with the Retrieved Schemes
        elif session['phase'] in ['SCHEME_INTERACTION', 'GENERAL_CHAT']:
            session['phase'] = 'GENERAL_CHAT'
            agent = session['agent']
            response = agent.handle_input(user_input)
            action = 'none'
            details = None
            data_payload = None

            clean_input = user_input.replace('🔍', '').replace('🔄', '').replace('❓', '').strip().lower()

            if clean_input in ['show schemes', 'show my schemes']:
                action = 'show_schemes'
                data_payload = {
                    'command': 'show_schemes',
                    'scheme_ids': [s.get('metadata', {}).get('scheme_id', '') for s in session['schemes']],
                    'schemes': format_for_frontend(session['schemes'])
                }
            elif clean_input.startswith('show scheme'):
                try:
                    scheme_num = int(clean_input.split()[-1]) - 1
                    if 0 <= scheme_num < len(session['schemes']):
                        scheme_id = session['schemes'][scheme_num]['metadata']['scheme_id']
                        details = fetch_scheme_details(scheme_id)
                        if details:
                            action = 'show_details'
                        else:
                            response = f"Sorry, no details found for scheme number {scheme_num + 1}."
                except (ValueError, IndexError):
                    response = "Please specify a valid scheme number (e.g., 'show scheme 3')."
            elif clean_input in ['quit', 'exit', 'restart']:
                action = 'restart'
                session['phase'] = 'PROFILING'
                # Safe reset of user info
                current_info = session.get('user_info', {})
                session['user_info'] = {k: None for k in current_info}
                session['profile_session'] = {}
                session['agent'] = None
                session['schemes'] = []

            return jsonify({
                'response': response,
                'action': action,
                'details': details,
                'data': data_payload
            })

    except Exception as e:
        logger.error(f"Chat failed: {str(e)}")
        traceback.print_exc() # Print full stack trace to terminal
        return jsonify({'response': f'Error: {str(e)}', 'action': 'error'}), 500

if __name__ == "__main__":
    app.run(port=5000, debug=True)