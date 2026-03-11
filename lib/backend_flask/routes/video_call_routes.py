from flask import Blueprint, request, jsonify
from backend_flask.services.video_service import create_call_request
from backend_flask.services.hms_service import create_hms_room, get_app_token

video_bp = Blueprint('video_call', __name__, url_prefix='/api/video-call')

@video_bp.route('/request', methods=['POST'])
def request_video_call():
    data = request.get_json()
    
    doctor_id = data.get('doctor_id')
    patient_id = data.get('patient_id')
    
    if not doctor_id or not patient_id:
        return jsonify({"error": "Missing doctor_id or patient_id"}), 400
        
    try:
        call_id, call_data = create_call_request(doctor_id, patient_id)
        return jsonify({
            "message": "Video call requested successfully",
            "call_id": call_id
        }), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@video_bp.route('/create-room', methods=['POST'])
def create_video_room():
    data = request.get_json()
    doctor_id = data.get('doctor_id')
    patient_id = data.get('patient_id')

    if not doctor_id or not patient_id:
        return jsonify({"error": "Missing identifiers"}), 400

    try:
        # Create unique room name based on IDs
        room_name = f"consult-{doctor_id}-{patient_id}"
        room_id = create_hms_room(room_name)
        
        doctor_token = get_app_token(room_id, doctor_id, "doctor")
        phc_token = get_app_token(room_id, patient_id, "phc") # PHC acts on behalf of patient
        
        return jsonify({
            "room_id": room_id,
            "doctor_token": doctor_token,
            "phc_token": phc_token
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500