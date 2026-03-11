import 'package:flutter/material.dart';

class PatientDetailsStep extends StatefulWidget {
  final Function(Map<String, String>) onCompleted;

  const PatientDetailsStep({super.key, required this.onCompleted});

  @override
  State<PatientDetailsStep> createState() => _PatientDetailsStepState();
}

class _PatientDetailsStepState extends State<PatientDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _genderCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onCompleted({
        "patient_name": _nameCtrl.text.trim(),
        "patient_age": _ageCtrl.text.trim(),
        "patient_gender": _genderCtrl.text.trim(),
        "patient_mobile": _mobileCtrl.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Patient Details", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? "Name is required" : null,
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _genderCtrl,
                    decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? "Required" : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _mobileCtrl,
              decoration: const InputDecoration(
                labelText: "Mobile (with Country Code)", 
                hintText: "e.g., 919876543210",
                border: OutlineInputBorder()
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return "Mobile is required";
                if (v.length < 10) return "Invalid number";
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text("Next: Urine Analysis"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
