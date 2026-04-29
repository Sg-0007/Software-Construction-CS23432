import json
import logging
import re
import os
from typing import Optional, Dict, Tuple

from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import Runnable
from langchain_groq import ChatGroq

# Logging setup
logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(__name__)

# Initialize the LLM
llm = ChatGroq(
    model="llama-3.3-70b-versatile",
    api_key=os.getenv("GROQ_API_KEY")
)

# Define prompt to extract user details
prompt = ChatPromptTemplate.from_template("""
You're a friendly chatbot helping collect user details for government scheme recommendations.

Instructions:
- Ask questions one by one conversationally to collect: name, state, gender, caste, occupation, category (like SC/ST/OBC), income.
- Be warm and friendly.
- At the end, respond with a JSON like:
{{
    "full_name": "...",
    "state": "...",
    "gender": "...",
    "caste": "...",
    "occupation": "...",
    "category": "...",
    "income": "...",
    "additional_details": "..."  # optional
}}

Conversation so far:
{chat_history}
User: {user_input}
Bot:
""")

chain: Runnable = prompt | llm | StrOutputParser()

def extract_json(text: str) -> Dict[str, Optional[str]]:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            return {}
    return {}

def process_profile_chat(user_input: str, user_info: Dict[str, Optional[str]], session_state: dict) -> Tuple[str, Dict[str, Optional[str]], bool, dict]:
    """
    Stateless function to process user input for profiling.
    """
    chat_history = session_state.get('chat_history', "")
    additional_info_phase = session_state.get('additional_info_phase', False)
    awaiting_additional_confirmation = session_state.get('awaiting_additional_confirmation', False)

    required_fields = ["full_name", "state", "gender", "caste", "occupation", "category", "income"]
    missing_fields = [field for field in required_fields if not user_info.get(field)]

    user_input_clean = user_input.strip().lower()
    
    # Handle additional info phase
    if additional_info_phase:
        if user_input_clean in ["no", "nah", "nope", "not", "dont want", "i dont want to"]:
            return "Got it! You’re a star! I’ve got all I need to find you awesome schemes!", user_info, True, session_state
        else:
            existing = user_info.get("additional_details", "")
            if existing and existing != "None":
                user_info["additional_details"] = f"{existing}, {user_input}".strip(", ")
            else:
                user_info["additional_details"] = user_input
            return "Got it! ✅ You can add more, or say 'no' to finish.", user_info, False, session_state

    # Handle additional info confirmation
    if awaiting_additional_confirmation:
        if user_input_clean in ["yes", "y", "sure", "yeah"]:
            session_state['additional_info_phase'] = True
            session_state['awaiting_additional_confirmation'] = False
            return "Great! Go ahead and tell me more. You can add as much as you want, and say 'no' when done.", user_info, False, session_state
        elif user_input_clean in ["no", "nah", "nope", "not", "dont want", "i dont want to"]:
            return "Got it! You’re a star! I’ve got all I need to find you awesome schemes!", user_info, True, session_state
        else:
            return "Please say 'yes' or 'no' to let me know if you want to add more details.", user_info, False, session_state

    # Normal LLM interaction to collect missing fields
    if missing_fields:
        response = chain.invoke({"user_input": user_input, "chat_history": chat_history})
        
        # update chat history
        session_state['chat_history'] = chat_history + f"\nUser: {user_input}\nBot: {response}"
        
        json_data = extract_json(response)
        if json_data:
            user_info.update({k: v for k, v in json_data.items() if v})
            
        # Check if all required fields are now collected
        new_missing_fields = [field for field in required_fields if not user_info.get(field)]
        if not new_missing_fields:
            session_state['awaiting_additional_confirmation'] = True
            return "Thanks! I’ve collected everything I need for the basic recommendation.\n\nWould you like to add any additional details (like education, land, family background, etc.)? (yes/no)", user_info, False, session_state
            
        return response.strip(), user_info, False, session_state

    # Failsafe if it reaches here with no missing fields
    return "You’re a star! I’ve got all I need to find you awesome schemes!", user_info, True, session_state