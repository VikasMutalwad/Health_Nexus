from flask import Blueprint, request, jsonify
from backend_flask.services.ai_service import analyze_urine_strip

diagnostic_bp = Blueprint('diagnostic_bp', __name__)

@diagnostic_bp.route('/analyze-urine-images', methods=['POST'])
def analyze_urine_images_route():
    if 'images' not in request.files:
        return jsonify({"error": "No images uploaded"}), 400
    
    files = request.files.getlist('images')
    
    if len(files) < 1:
        return jsonify({"error": "At least 1 image required"}), 400
    
    if len(files) > 4:
        return jsonify({"error": "Maximum 4 images allowed"}), 400

    # Validate file types
    valid_extensions = {'jpg', 'jpeg', 'png'}
    for file in files:
        if not file.filename.lower().split('.')[-1] in valid_extensions:
             return jsonify({"error": f"Invalid file type: {file.filename}"}), 400

    try:
        # analyze_urine_strip expects file objects, which Flask provides
        urine_data = analyze_urine_strip(files)
        return jsonify(urine_data), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500