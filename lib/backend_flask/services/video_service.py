from firebase_admin import firestore

def create_call_request(doctor_id, patient_id):
    """
    Creates a new video call request in Firestore.
    """
    db = firestore.client()
    
    doc_ref = db.collection('video_calls').document()
    call_data = {
        'doctor_id': doctor_id,
        'patient_id': patient_id,
        'status': 'pending',
        'created_at': firestore.SERVER_TIMESTAMP
    }
    doc_ref.set(call_data)
    return doc_ref.id, call_data