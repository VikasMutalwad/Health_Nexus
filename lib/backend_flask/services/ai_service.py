import os
import json
from PIL import Image 
import re
from google import genai
from dotenv import load_dotenv

from lib.backend_flask.services.clinical_logic import apply_clinical_overrides
load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
print("Loaded Gemini Key:", api_key)

client = genai.Client(api_key=api_key)


def rule_based_interpretation(vitals_data, urine_data=None):
    """
    Fallback logic to generate interpretation when AI is unavailable.
    """
    severity, notes = apply_clinical_overrides(vitals_data)
    
    risk_level = severity if severity else "Low"
    interpretation = "Vitals are within normal clinical ranges."
    
    if severity == "CRITICAL":
        interpretation = "Critical health indicators detected. Immediate attention required."

    return {
        "risk_level": risk_level,
        "ai_interpretation": interpretation,
        "recommendations": ["Consult a healthcare provider.", "Monitor vitals regularly."],
        "risk_factors": notes if notes else ["None detected"]
    }

def analyze_health_data(vitals):

    # Filter out deprecated fields for AI analysis
    ai_vitals = vitals.copy()
    for key in ['hemoglobin', 'random_glucose']:
        ai_vitals.pop(key, None)

    ai_result = {
        "risk_level": "Low",
        "ai_interpretation": "Pending analysis...",
        "recommendations": [],
        "risk_factors": []
    }

    ai_called = False

    try:
        prompt = f"""
        Analyze vitals. Return JSON only.
        Data: {json.dumps(ai_vitals)}
        Schema:
        {{
            "risk_level": "Low|Medium|High|Critical",
            "ai_interpretation": "Brief clinical summary",
            "recommendations": ["3 short tips"],
            "risk_factors": ["Key risks"]
        }}
        """

        if not ai_called:
            response = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=prompt
            )
            ai_called = True

        text_response = response.text.strip()

        # Extract JSON using regex to be more robust
        match = re.search(r'\{.*\}', text_response, re.DOTALL)
        if match:
            text_response = match.group(0)

        try:
            ai_result = json.loads(text_response)
        except Exception as parse_error:
            print("JSON Parse Error:", parse_error)
            raise parse_error

    except Exception as e:
        print("Gemini Error:", e)
        ai_result = rule_based_interpretation(vitals)

    override_severity, override_notes = apply_clinical_overrides(vitals)

    final_result = ai_result.copy()

    if override_severity:
        final_result["risk_level"] = override_severity

    if override_notes:
        alert_msg = "[CLINICAL ALERT] " + "; ".join(override_notes)
        final_result["ai_interpretation"] = alert_msg + " " + final_result.get("ai_interpretation", "")

    return final_result


def analyze_urine_strip(image_files):
    """
    Analyzes urine strip images using Gemini Vision.
    Returns a dictionary of urine parameters.
    """
    # Initialize with safe defaults to ensure frontend receives all parameters
    urine_result = {
        "urine_glucose": "Negative",
        "urine_protein": "Negative",
        "urine_ketones": "Negative",
        "urine_ph": "6.0",
        "urine_blood": "Negative",
        "urine_leukocytes": "Negative",
        "urine_nitrite": "Negative",
        "urine_bilirubin": "Negative",
        "urine_urobilinogen": "Normal",
        "urine_specific_gravity": "1.015"
    }

    try:
        prompt = """
        Analyze the provided urine dipstick images.
        Identify the color pads and determine the values for the following 10 parameters:
        urine_glucose, urine_protein, urine_ketones, urine_ph, urine_blood, 
        urine_leukocytes, urine_nitrite, urine_bilirubin, urine_urobilinogen, urine_specific_gravity.

        Return ONLY valid JSON.
        Do not use markdown code blocks.
        Format:
        {
            "urine_glucose": "value",
            "urine_protein": "value",
            ...
        }
        """

        contents = [prompt]
        for file in image_files:
            img = Image.open(file)
            contents.append(img)

        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=contents
        )

        text_response = response.text.strip()
        
        # Extract JSON using regex to be more robust
        match = re.search(r'\{.*\}', text_response, re.DOTALL)
        if match:
            text_response = match.group(0)

        parsed_result = json.loads(text_response)
        urine_result.update(parsed_result)

    except Exception as e:
        print("Gemini Vision Error:", e)

    return urine_result