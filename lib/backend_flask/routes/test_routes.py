from flask import Blueprint, request, jsonify
from backend_flask.firebase_config import db
from backend_flask.services.ai_service import analyze_health_data, analyze_urine_strip
import datetime
import uuid

api = Blueprint('api', __name__)

@api.route('/start-test', methods=['POST'])
def start_test():
    try:
        data = request.json
        patient_id = data.get('patient_id')
        test_type = data.get('test_type', 'general')

        if not patient_id:
            return jsonify({'error': 'patient_id is required'}), 400

        test_id = str(uuid.uuid4())

        test_doc = {
            'test_id': test_id,
            'patient_id': patient_id,
            'test_type': test_type,
            'start_time': datetime.datetime.utcnow().isoformat(),
            'status': 'started',
            'vitals': {},
            'report': None
        }

        db.collection('tests').document(test_id).set(test_doc)

        return jsonify({
            'test_id': test_id,
            'status': 'started',
            'message': 'Test session initialized'
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api.route('/upload-data', methods=['POST'])
def upload_data():
    try:
        data = request.json
        test_id = data.get('test_id')
        vitals = data.get('vitals', {})

        # Remove deprecated blood strip fields
        for key in ['hemoglobin', 'random_glucose']:
            vitals.pop(key, None)

        if not test_id:
            return jsonify({'error': 'test_id is required'}), 400

        doc_ref = db.collection('tests').document(test_id)
        doc = doc_ref.get()

        if not doc.exists:
            return jsonify({'error': 'Invalid test_id'}), 404

        analysis = analyze_health_data(vitals)

        # Separate urine data for structured storage
        urine_keys = [
            'urine_glucose', 'urine_protein', 'urine_ketones', 'urine_ph',
            'urine_blood', 'urine_leukocytes', 'urine_nitrite', 
            'urine_bilirubin', 'urine_urobilinogen', 'urine_specific_gravity'
        ]
        urine_data = {k: vitals[k] for k in urine_keys if k in vitals}
        vitals_data = {k: v for k, v in vitals.items() if k not in urine_keys}

        update_data = {
            'vitals': vitals,
            'urine_data': urine_data,
            'vitals_data': vitals_data,
            'status': 'completed',
            'end_time': datetime.datetime.utcnow().isoformat(),
            'report': analysis
        }

        doc_ref.update(update_data)

        return jsonify({
            'status': 'success',
            'message': 'Data processed and report generated',
            'test_id': test_id,
            'analysis': analysis
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@api.route('/report/<test_id>', methods=['GET'])
def get_report(test_id):
    try:
        doc = db.collection('tests').document(test_id).get()

        if not doc.exists:
            return jsonify({'error': 'Test not found'}), 404

        data = doc.to_dict()
        # Remove deprecated fields from response
        if 'vitals' in data:
            for key in ['hemoglobin', 'random_glucose']:
                data['vitals'].pop(key, None)

        return jsonify(data), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500 


@api.route('/analyze-urine-images', methods=['POST'])
def analyze_urine_images():
    try:
        test_id = request.form.get('test_id')
        if not test_id:
            return jsonify({'error': 'test_id is required'}), 400

        images = request.files.getlist('images')
        if not images:
            return jsonify({'error': 'No images uploaded'}), 400
            
        if len(images) > 4:
            return jsonify({'error': 'Maximum 4 images allowed'}), 400

        # Verify test exists before processing images to save AI resources
        doc_ref = db.collection('tests').document(test_id)
        doc = doc_ref.get()
        
        if not doc.exists:
            return jsonify({'error': 'Test not found'}), 404

        # Validate file types
        allowed_extensions = {'png', 'jpg', 'jpeg'}
        for img in images:
            if not ('.' in img.filename and img.filename.rsplit('.', 1)[1].lower() in allowed_extensions):
                return jsonify({'error': 'Invalid file type. Only JPG/PNG allowed'}), 400

        # 1. Analyze images
        urine_results = analyze_urine_strip(images)
        
        if not urine_results:
             return jsonify({'error': 'Failed to analyze images'}), 500

        current_data = doc.to_dict()
        current_vitals = current_data.get('vitals', {})
        
        # 3. Merge urine data
        current_vitals.update(urine_results)
        
        # 4. Re-run full health analysis
        full_report = analyze_health_data(current_vitals)
        
        # 5. Structure data
        urine_keys = [
            'urine_glucose', 'urine_protein', 'urine_ketones', 'urine_ph',
            'urine_blood', 'urine_leukocytes', 'urine_nitrite', 
            'urine_bilirubin', 'urine_urobilinogen', 'urine_specific_gravity'
        ]
        urine_data = {k: current_vitals[k] for k in urine_keys if k in current_vitals}
        vitals_data = {k: v for k, v in current_vitals.items() if k not in urine_keys}
        
        doc_ref.update({
            'vitals': current_vitals,
            'urine_data': urine_data,
            'vitals_data': vitals_data,
            'report': full_report,
            'last_updated': datetime.datetime.utcnow().isoformat()
        })
        
        return jsonify({
            'status': 'success',
            'urine_data': urine_data,
            'report': full_report
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
 