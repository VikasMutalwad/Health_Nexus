import os
import jwt
import requests
import uuid
from datetime import datetime, timedelta, timezone

HMS_ACCESS_KEY = os.environ.get("HMS_ACCESS_KEY")
HMS_SECRET_KEY = os.environ.get("HMS_SECRET_KEY")

def get_management_token():
    """Generates a management token for 100ms API calls."""
    expires = datetime.now(timezone.utc) + timedelta(hours=24)
    payload = {
        "access_key": HMS_ACCESS_KEY,
        "type": "management",
        "version": 2,
        "iat": datetime.now(timezone.utc),
        "nbf": datetime.now(timezone.utc),
        "exp": expires
    }
    return jwt.encode(payload, HMS_SECRET_KEY, algorithm="HS256")

def get_app_token(room_id, user_id, role):
    """Generates a client auth token for the frontend SDK."""
    expires = datetime.now(timezone.utc) + timedelta(hours=24)
    payload = {
        "access_key": HMS_ACCESS_KEY,
        "room_id": room_id,
        "user_id": user_id,
        "role": role,
        "type": "app",
        "version": 2,
        "iat": datetime.now(timezone.utc),
        "nbf": datetime.now(timezone.utc),
        "exp": expires
    }
    return jwt.encode(payload, HMS_SECRET_KEY, algorithm="HS256")

def create_hms_room(room_name):
    """Creates a room via 100ms API or returns existing one."""
    token = get_management_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    # 100ms allows duplicate names but returns unique IDs. 
    # We use the unique room_name to ensure we get the specific room if it exists.
    response = requests.post(
        "https://api.100ms.live/v2/rooms",
        json={"name": room_name, "description": "Health Nexus Consultation"},
        headers=headers
    )
    if response.status_code in [200, 201]:
        return response.json()['id']
    raise Exception(f"Failed to create 100ms room: {response.text}")