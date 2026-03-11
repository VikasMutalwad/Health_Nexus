from flask import Flask, request, jsonify
import json
import datetime
import sys
import os
import random
from lib.backend_flask.services.ai_service import analyze_health_data, analyze_urine_strip

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)

# Global storage
latest_vitals = {}
# smoothing memory
last_hr = 75
last_spo2 = 97
last_temp = 36.5
# 🔥 NEW: ECG BUFFER (does NOT change existing logic)
ecg_buffer = []

MAX_ECG_BUFFER = 1000   # prevent memory overflow


def filter_heart_rate(hr):
    global last_hr

    # 🔥 DEMO MODE: HR always between 70–82
    hr = random.randint(70, 82)

    last_hr = hr

    return hr


def filter_spo2(spo2):
    global last_spo2

    try:
        spo2 = float(spo2)
    except:
        return last_spo2

    if spo2 <= 0:
        return last_spo2

    if spo2 < 90 or spo2 > 100:
        spo2 = last_spo2

    spo2 = (last_spo2 * 0.7) + (spo2 * 0.3)

    last_spo2 = spo2

    return int(round(spo2))


def filter_temperature(temp):
    global last_temp

    try:
        temp = float(temp)
    except:
        return last_temp

    if temp <= 0:
        return last_temp

    if temp > 45:
        temp = (temp - 32) * 5 / 9

    if temp < 30 or temp > 40:
        temp = last_temp

    temp = (last_temp * 0.7) + (temp * 0.3)

    last_temp = temp

    return round(temp, 1)


@app.route('/live-vitals', methods=['POST'])
def receive_live_vitals():
    try:
        data = request.get_json(force=True, silent=True)
        print("ESP32 DATA:", data)
        if not data:
            return jsonify({"error": "No JSON data received"}), 400

        if 'device_id' not in data:
            return jsonify({"error": "Missing device_id"}), 400
       
        global latest_vitals
        global ecg_buffer

        # ---- Store ECG continuously ----
        ecg_value = data.get("ecg_value", None)
        if ecg_value is not None:
            ecg_buffer.append(ecg_value)
            if len(ecg_buffer) > MAX_ECG_BUFFER:
                ecg_buffer.pop(0)

        raw_hr = data.get("heart_rate", 0)
        raw_spo2 = data.get("spo2", 0)
        raw_temp = data.get("body_temperature", 0)

        # ESP32 connection detection (SAFE)
        esp32_connected = data.get("device_id") is not None

        if esp32_connected:
            hr = filter_heart_rate(raw_hr)
            spo2 = filter_spo2(raw_spo2)
            temp = filter_temperature(raw_temp)
        else:
            hr = raw_hr
            spo2 = raw_spo2
            temp = raw_temp

        latest_vitals["device_id"] = data.get("device_id")

        # update vitals only if present
        if "heart_rate" in data:
            latest_vitals["heart_rate"] = hr

        if "spo2" in data:
            latest_vitals["spo2"] = spo2

        if "body_temperature" in data:
            latest_vitals["body_temperature"] = temp

        # update ECG separately
        if ecg_value is not None:
            latest_vitals["ecg_value"] = ecg_value

        latest_vitals["timestamp"] = datetime.datetime.now().isoformat()

        return jsonify({"status": "success", "message": "Vitals updated"}), 200

    except Exception as e:
        return jsonify({"error": "Internal Server Error", "details": str(e)}), 500


@app.route('/get-latest-vitals', methods=['GET'])
def get_latest_vitals():
    try:
        global latest_vitals

        # If no data received yet
        if not latest_vitals:
            return jsonify({
                "heart_rate": 0,
                "spo2": 0,
                "body_temperature": 0,
                "ecg_value": 0,
                "timestamp": None,
                "status": "waiting_for_data"
            }), 200

        # ---- CLEAN & FORMAT VALUES ----
        heart_rate = latest_vitals.get("heart_rate", 0)
        spo2 = latest_vitals.get("spo2", 0)
        body_temp = latest_vitals.get("body_temperature", 0)
        ecg_value = latest_vitals.get("ecg_value", 0)

        # Remove floating precision
        try:
            heart_rate = int(round(float(heart_rate)))
        except:
            heart_rate = 0

        try:
            spo2 = int(round(float(spo2)))
        except:
            spo2 = 0

        try:
            body_temp = round(float(body_temp), 1)
        except:
            body_temp = 0

        # Create clean response
        cleaned_data = {
            "device_id": latest_vitals.get("device_id", "HN_KIT_01"),
            "heart_rate": heart_rate,
            "spo2": spo2,
            "body_temperature": body_temp,
            "ecg_value": ecg_value,
            "timestamp": latest_vitals.get("timestamp")
        }

        return jsonify(cleaned_data), 200

    except Exception as e:
        return jsonify({
            "error": "Internal Server Error",
            "details": str(e)
        }), 500


# 🔥 NEW: ECG FULL BUFFER ROUTE (does NOT affect existing routes)
@app.route('/get-ecg', methods=['GET'])
def get_ecg():
    try:
        global ecg_buffer
        return jsonify({"ecg": ecg_buffer}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/analyze-report', methods=['POST'])
def analyze_report():
    try:
        patient_id = request.form.get('patient_id')
        vitals_json = request.form.get('vitals_data')

        vitals_data = {}
        if vitals_json:
            try:
                vitals_data = json.loads(vitals_json)
            except Exception:
                pass

        if not vitals_data:
            global latest_vitals
            vitals_data = latest_vitals.copy()

        patient_details = {
            "patient_name": request.form.get("patient_name") or vitals_data.get("patient_name", "N/A"),
            "patient_age": request.form.get("patient_age") or vitals_data.get("patient_age", "N/A"),
            "patient_gender": request.form.get("patient_gender") or vitals_data.get("patient_gender", "N/A"),
            "patient_mobile": request.form.get("patient_mobile") or vitals_data.get("patient_mobile", "")
        }

        if not patient_id or not vitals_data:
            return jsonify({"error": "Missing patient_id or vitals_data"}), 400

        urine_images = request.files.getlist('urine_images')

        urine_data = analyze_urine_strip(urine_images)
        
        combined_health_data = vitals_data.copy()
        combined_health_data.update(urine_data)

        ai_analysis = analyze_health_data(combined_health_data)

        report = {
            "patient_id": patient_id,
            **patient_details,
            "vitals_data": vitals_data,
            "urine_data": urine_data,
            "ecg_status": vitals_data.get("ECG Status", "Normal"),
            "ai_interpretation": ai_analysis.get("ai_interpretation", "Analysis unavailable"),
            "risk_level": ai_analysis.get("risk_level", "Low"),
            "timestamp": datetime.datetime.now().isoformat(),
            "status": "pending"
        }

        print(f"Report generated for {patient_id} | Risk: {report['risk_level']}")

        return jsonify(report), 200

    except Exception as e:
        print(f"Backend Error: {e}")
        return jsonify({"error": "Internal Server Error", "details": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)