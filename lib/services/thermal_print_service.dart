import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';

class ThermalPrintService {
  static final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  static BluetoothDevice? _selectedPrinter;

  /// Shows a modal bottom sheet to select a bonded Bluetooth printer.
  /// The selected printer is stored in [_selectedPrinter] for the session.
  static Future<void> selectPrinter(BuildContext context) async {
    // Get bonded devices and check current connection status beforehand.
    List<BluetoothDevice> devices = await _printer.getBondedDevices();
    bool? isConnected = await _printer.isConnected;

    final BluetoothDevice? result = await showModalBottomSheet<BluetoothDevice>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Select a Printer",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              if (devices.isEmpty)
                const ListTile(
                  leading: Icon(Icons.bluetooth_disabled),
                  title: Text("No Bonded Printers Found"),
                  subtitle: Text(
                      "Please pair a printer in your device's Bluetooth settings."),
                )
              else
                LimitedBox(
                  maxHeight: 250,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      // Check if this device is the one that is currently connected.
                      final bool isThisDeviceConnected =
                          isConnected == true && _selectedPrinter?.address == device.address;

                      return ListTile(
                        leading: Icon(
                          Icons.print_outlined,
                          color: isThisDeviceConnected ? Colors.green : Theme.of(context).iconTheme.color,
                        ),
                        title: Text(device.name ?? "Unknown Device"),
                        subtitle: Text(device.address ?? "No address"),
                        trailing: isThisDeviceConnected
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Connected", style: TextStyle(color: Colors.green)),
                                  SizedBox(width: 5),
                                  Icon(Icons.check_circle,
                                      color: Colors.green),
                                ],
                              )
                            : null,
                        onTap: () {
                          if (Navigator.canPop(ctx)) {
                            Navigator.of(ctx).pop(device);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      _selectedPrinter = result;
    }
  }

  static Future<void> printReport(
    BuildContext context,
    Map<String, dynamic> vitals,
    String patientName,
    String age,
    String sex,
    String riskLevel,
    String diagnosis,
  ) async {
    try {
      // If no printer is selected, prompt the user to select one.
      if (_selectedPrinter == null) {
        await selectPrinter(context);
        // If the user cancelled the selection, abort printing.
        if (_selectedPrinter == null) {
          debugPrint("Print cancelled: No printer selected.");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Print cancelled: No printer selected.")),
            );
          }
          return;
        }
      }

      bool? isConnected = await _printer.isConnected;

      if (isConnected != true) {
        debugPrint("Connecting to printer: ${_selectedPrinter!.name}");
        await _printer.connect(_selectedPrinter!);
        isConnected = await _printer.isConnected;

        // If connection fails, inform the user and reset the selection.
        if (isConnected != true) {
          debugPrint("Failed to connect to printer: ${_selectedPrinter!.name}");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Failed to connect to ${_selectedPrinter!.name}")),
            );
          }
          _selectedPrinter = null; // Reset to allow re-selection
          return;
        }
      }

      // HEADER
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("HEALTH NEXUS", 2, 1); // Medium Bold, Centered
      _printer.printCustom("AI Assisted Diagnostic Slip", 1, 1); // Normal, Centered
      _printer.printCustom("--------------------------------", 0, 1);

      // PATIENT DETAILS
      _printer.printCustom("Patient Details", 0, 0);
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("Name : $patientName", 0, 0);
      _printer.printCustom("Age  : $age   Sex : $sex", 0, 0);
      final now = DateTime.now();
      final dateStr =
          "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} "
          "${(now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} "
          "${now.hour >= 12 ? 'PM' : 'AM'}";
      _printer.printCustom("Date : $dateStr", 0, 0);

      // VITAL SIGNS
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("VITAL SIGNS", 0, 0);
      _printer.printCustom("--------------------------------", 0, 1);

      String getVitalValue(dynamic value) {
        if (value == null) return 'N/A';
        final String str = value.toString().trim();
        if (str.isEmpty || str == '--' || str.toLowerCase() == 'n/a') return 'N/A';

        // Extract numeric part to handle "98%", "72 bpm" correctly
        final Match? match = RegExp(r'^([0-9]+(\.[0-9]+)?)').firstMatch(str);
        if (match == null) return 'N/A';
        final String numStr = match.group(0)!;
        return (double.tryParse(numStr) == 0) ? 'N/A' : numStr;
      }

      final hr = getVitalValue(vitals['Heart Rate']);
      final spo2 = getVitalValue(vitals['SpO2']);
      final temp = getVitalValue(vitals['Body Temperature']);

      _printer.printCustom("${"Heart Rate".padRight(11)}: $hr bpm", 0, 0);
      _printer.printCustom("${"SpO2".padRight(11)}: $spo2 %", 0, 0);
      _printer.printCustom("${"Temp".padRight(11)}: $temp °C", 0, 0);

      // ECG SCREENING
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("ECG SCREENING", 0, 0);
      _printer.printCustom("--------------------------------", 0, 1);
      final bool isEcgPerformed = vitals['isEcgPerformed'] == true;
      if (isEcgPerformed) {
        final rhythm = vitals['Rhythm Pattern']?.toString() ?? 'N/A';
        final signal = vitals['Signal Quality']?.toString() ?? 'Good';
        _printer.printCustom("${"Status".padRight(11)}: Performed", 0, 0);
        _printer.printCustom("${"Rhythm".padRight(11)}: $rhythm", 0, 0);
        _printer.printCustom("${"Signal Qlty".padRight(11)}: $signal", 0, 0);
      } else {
        _printer.printCustom("${"Status".padRight(11)}: Not Performed", 0, 0);
      }

      // URINE TEST
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("URINE TEST", 0, 0);
      _printer.printCustom("--------------------------------", 0, 1);
      final bool urineDone = vitals['isUrinePerformed'] == true ||
          vitals['urinePerformed'] == true ||
          vitals['urine_status'] == "performed";
           vitals['urine_test'] == "Performed";

      if (urineDone) {
        _printer.printCustom("${"Status".padRight(11)}: Performed", 0, 0);
      } else {
        _printer.printCustom("${"Status".padRight(11)}: Performed", 0, 0);
      }

      // AI SUMMARY
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("AI SUMMARY", 0, 0);
      _printer.printCustom("--------------------------------", 0, 1);
      String summary = diagnosis;
      const int lineLength = 32;
      if (summary.length > lineLength * 2) {
        summary = "${summary.substring(0, lineLength * 2 - 4)}...";
      }
      if (summary.length > lineLength) {
        int splitPoint = summary.lastIndexOf(' ', lineLength);
        if (splitPoint == -1) splitPoint = lineLength;
        _printer.printCustom(summary.substring(0, splitPoint), 0, 0);
        _printer.printCustom(summary.substring(splitPoint).trim(), 0, 0);
      } else {
        _printer.printCustom(summary, 0, 0);
      }
      _printer.printCustom("Risk Level : $riskLevel", 0, 0);

      // FOOTER
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("Note:", 0, 0);
      _printer.printCustom("Screening-level analysis.", 0, 0);
      _printer.printCustom("Doctor validation required.", 0, 0);
      _printer.printCustom("--------------------------------", 0, 1);
      _printer.printCustom("System Generated", 0, 1);
      _printer.printCustom("--------------------------------", 0, 1);

      _printer.paperCut();

      debugPrint("Print successful");
    } catch (e) {
      debugPrint("Error printing: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Printing Error: ${e.toString()}")),
        );
      }
    }
  }

  /// Generates and prints a report by delegating to the static `printReport` method.
  ///
  /// This method is provided for compatibility with existing calls from the dashboard.
  /// The call site must be updated to provide all the required parameters.
  /// Ideally, the call site should be refactored to call `ThermalPrintService.printReport` directly.
  Future<void> printReceipt({
    required BuildContext context,
    required Map<String, dynamic> vitals,
    required String patientName,
    required String age,
    required String sex,
    required String diagnosis,
    required String severity, // Corresponds to 'riskLevel' in printReport
  }) async {
    // Delegate the call to the fully implemented static printReport method.
    await ThermalPrintService.printReport(
      context,
      vitals,
      patientName,
      age,
      sex,
      severity, // Pass severity as the riskLevel
      diagnosis,
    );
  }
}