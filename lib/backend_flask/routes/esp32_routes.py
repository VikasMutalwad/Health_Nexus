from flask import Blueprint, request, jsonify
from firebase_config import db
import datetime

from backend_flask.services.ai_service import analyze_health_data

esp32_api = Blueprint('esp32_api', __name__)

@esp32_api.route('/upload-sensor-data', methods=['POST'])
def upload_sensor_data():
    """
    Receives sensor data from ESP32, runs diagnostics, and updates Firebase.
    """
    try:
        payload = request.json
        if not payload:
            return jsonify({"error": "No JSON payload received"}), 400

        test_id = payload.get('test_id')
        vitals = payload.get('vitals')

        if not test_id or not vitals:
            return jsonify({"error": "Missing test_id or vitals"}), 400

        # Remove deprecated blood strip fields
        for key in ['hemoglobin', 'random_glucose']:
            vitals.pop(key, None)

        # 1. Preprocessing (ESP32 handles raw acquisition, backend validates)
        # Ensure required fields exist
        required_fields = ['heart_rate', 'spo2', 'temperature', 'ecg_features']
        for field in required_fields:
            if field not in vitals:
                return jsonify({"error": f"Missing vital: {field}"}), 400

        # 2. Call AI Service for analysis
        # The analyze_health_data function handles AI call and clinical overrides.
        final_report = analyze_health_data(vitals)

        # Separate urine data
        urine_keys = [
            'urine_glucose', 'urine_protein', 'urine_ketones', 'urine_ph',
            'urine_blood', 'urine_leukocytes', 'urine_nitrite', 
            'urine_bilirubin', 'urine_urobilinogen', 'urine_specific_gravity'
        ]
        urine_data = {k: vitals[k] for k in urine_keys if k in vitals}
        vitals_data = {k: v for k, v in vitals.items() if k not in urine_keys}

        # 4. Store report in Firebase
        db.collection('tests').document(test_id).update({
            'report': final_report, 
            'vitals': vitals,
            'urine_data': urine_data,
            'vitals_data': vitals_data,
            'status': 'completed',
            'end_time': datetime.datetime.utcnow().isoformat()
        })

        return jsonify({"status": "success", "message": "Data processed successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500