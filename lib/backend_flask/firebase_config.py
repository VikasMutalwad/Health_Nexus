import firebase_admin
from firebase_admin import credentials, firestore
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def initialize_firebase():
    if not firebase_admin._apps:
        cred_path = os.path.join(BASE_DIR, "serviceAccountKey.json")

        if not os.path.exists(cred_path):
            raise FileNotFoundError(
                f"Firebase credentials file not found at {cred_path}"
            )

        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    return firestore.client()

db = initialize_firebase()