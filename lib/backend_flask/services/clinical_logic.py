def apply_clinical_overrides(vitals):
    """
    Applies hardcoded clinical safety checks.
    Returns (severity, notes_list).
    """
    override_severity = None
    override_notes = []

    try:
        spo2 = float(vitals.get('spo2', 100))
        # Support both 'body_temperature' (app) and 'temperature' (legacy/ESP32)
        temp = float(vitals.get('body_temperature', vitals.get('temperature', 37)))
        hr = float(vitals.get('heart_rate', 70))
    except (ValueError, TypeError):
        return "UNKNOWN", ["Invalid vital data format"]

    if spo2 < 90:
        override_severity = "CRITICAL"
        override_notes.append("Hypoxia detected (SpO2 < 90%). Immediate attention required.")
    
    if temp > 39.5:
        override_severity = "CRITICAL"
        override_notes.append("High fever detected.")

    if hr > 120 or hr < 40:
        override_severity = "CRITICAL"
        override_notes.append("Abnormal heart rate detected.")

    return override_severity, override_notes