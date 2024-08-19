import 'package:flutter/material.dart';
import 'dart:io';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MyScanner(),
    );
  }
}

class MyScanner extends StatefulWidget {
  const MyScanner({super.key});

  @override
  State<MyScanner> createState() => _MyScannerState();
}

class _MyScannerState extends State<MyScanner> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: "QR");
  Barcode? barcodeResult;
  QRViewController? controller;
  bool _cameraPermissionGranted = false;
  bool _cameraPermissionRequestInProgress = false;
  bool isScanningForStationId = true; // State variable for scanning mode
  String? stationId;
  String scanPrompt =
      "Please scan the Station ID"; // State variable for the prompt message
  int scanInterval = 2000; // Time interval between scans in milliseconds
  DateTime lastScanTime = DateTime.now(); // Store the last scan time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _getCameraPermission(); // Retrieve camera permission during initialization
  }

  // In order to get the hot reload to work we need to pause the camera if the platform is Android,
  // or resume it if the platform is iOS
  @override
  void reassemble() {
    super.reassemble();

    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _getCameraPermission();
    }
  }

  Future<void> _getCameraPermission() async {
    PermissionStatus? status; // Make status nullable

    if (_cameraPermissionRequestInProgress) {
      return;
    }
    _cameraPermissionRequestInProgress = true;

    try {
      // Request camera permission if not granted or if status is null
      if (!await Permission.camera.isGranted || status == null) {
        print("NOT granted\n\n\n");

        status = await Permission.camera.request();
      }

      setState(() {
        _cameraPermissionGranted = status!.isGranted;
      });

      if (status.isGranted) {
        print('Granted\n\n\n');
      }

      // If permission is denied, but not permanently denied, show a message to request permission again
      if (status.isDenied) {
        print("isDenied\n\n\n");

        status = await Permission.camera.request();
      }

      // If permission is permanently denied, handle the denied scenario
      if (status.isPermanentlyDenied) {
        print("isPermanentlyDenied\n\n\n");
        await _showCameraPermissionDialog(); // Use await when calling _showCameraPermissionDialog
      }
    } finally {
      _cameraPermissionRequestInProgress = false; // Reset flag
    }
  }

  Future<void> _showCameraPermissionDialog() async {
    // Show dialog prompting user to go to app settings
    await showDialog(
      // You can use either 'return showDialog' or 'await showDialog'
      context: context,
      barrierDismissible: false, // Make the dialog undismissable
      builder: (BuildContext context) {
        return WillPopScope(
          // Intercept the back button press
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'Please grant camera permission from app settings to continue using the app.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraPermissionGranted) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(
                  height:
                      60), // Add space between the CircularProgressIndicator and the message
              Text(
                'Please grant camera permission!',
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 17, 0),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        body: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            buildQrView(context),
            Positioned(top: 28, left: 15, child: buildBackButton()),
            Positioned(top: 28, right: 15, child: buildResetButton()),
            Positioned(top: 35, child: buildControlButtons()),
            Positioned(bottom: 10, child: buildResult()),
          ],
        ),
      );
    }
  }

  Widget buildBackButton() {
    return SizedBox(
      height: 65, // Adjust the height
      width: 65, // Keep the width equal to height
      child: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context); // Navigate back
          print('BACK   !!!!!!!!!!!!!!!!\n\n\n\n');
        },
        backgroundColor: const Color.fromARGB(50, 162, 162, 162),
        shape: const CircleBorder(),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  Widget buildResetButton() {
    return SizedBox(
      height: 65,
      width: 65,
      child: FloatingActionButton(
        onPressed: resetScanner,
        backgroundColor: const Color.fromARGB(50, 162, 162, 162),
        shape: const CircleBorder(),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  void resetScanner() {
    // Update state variables to their initial values
    setState(() {
      isScanningForStationId = true; // Reset to scanning for Station ID
      stationId = null; // Clear the stored Station ID
      scanPrompt = "Please scan the Station ID"; // Reset the prompt message
      lastScanTime = DateTime.now(); // Reset the scan timer
      barcodeResult = null; // Clear the previous barcode result
    });

    // Resume the camera to ensure it is active and ready to scan
    controller?.resumeCamera();
  }

  Widget buildControlButtons() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color.fromARGB(255, 162, 162, 162),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: FutureBuilder<bool?>(
                future: controller?.getFlashStatus(),
                builder: (context, snapshot) {
                  if (snapshot.data != null) {
                    return ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        snapshot.data! ? Colors.yellow : Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Icon(
                        snapshot.data! ? Icons.flash_on : Icons.flash_off,
                      ),
                    );
                  } else {
                    return const ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Icon(Icons.flash_off),
                    );
                  }
                },
              ),
              onPressed: () async {
                await controller?.toggleFlash();
                setState(() {});
              },
            ),
            IconButton(
              icon: FutureBuilder(
                future: controller?.getCameraInfo(),
                builder: (context, snapshot) {
                  return const ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Icon(Icons.flip_camera_ios),
                  );
                },
              ),
              onPressed: () async {
                await controller?.flipCamera();
                setState(() {});
              },
            ),
          ],
        ));
  }

  Widget buildResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color.fromARGB(255, 162, 162, 162),
      ),
      constraints: BoxConstraints(
        maxHeight: 120,
        // Set maximum screen width
        maxWidth: MediaQuery.of(context).size.width * 0.95,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            Text(
              scanPrompt,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
              ),
            ),
            if (isScanningForStationId && stationId != null)
              ElevatedButton(
                onPressed: confirmStationId,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Color.fromARGB(255, 155, 183, 176),
                ),
                child: const Text("Confirm"),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderWidth: 10,
        borderLength: 30,
        borderRadius: 10,
        borderColor: const Color.fromARGB(255, 255, 255, 255),
        cutOutSize: MediaQuery.of(context).size.width * 0.8,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) {
      final now = DateTime.now();
      if (isScanningForStationId) {
        processStationIdScan(scanData);
      } else {
        if (now.difference(lastScanTime).inMilliseconds >= scanInterval) {
          lastScanTime = now;
          processBarcodeScan(scanData);
        }
      }
    });
  }

  void processStationIdScan(Barcode scanData) {
    barcodeResult = scanData;

    // Check if barcodeResult is not null (whether a station ID has been scanned)
    if (barcodeResult != null && barcodeResult!.code != null) {
      setState(() {
        stationId = barcodeResult!.code!;
        if (stationId != null) {
          // Update the prompt message and add a button for manual confirmation
          scanPrompt =
              "Station ID: $stationId\nPlease confirm to scan the barcode";
        } else {
          scanPrompt = "Invalid Station ID. Please scan again.";
        }
      });
    } else {
      setState(() {
        scanPrompt = "Invalid scan. Please scan the station ID again.";
      });
    }
  }

  void confirmStationId() {
    setState(() {
      if (stationId != null) {
        scanPrompt = "Station ID: $stationId\nPlease scan the barcode";
        isScanningForStationId = false;
      }
    });
  }

  void processBarcodeScan(Barcode scanData) async {
    barcodeResult = scanData;

    // Ensure stationId is not null before proceeding
    if (stationId == null) {
      setState(() {
        scanPrompt = "Station ID is missing. Please scan the Station ID first.";
      });
      return;
    }

    // Check if barcodeResult is not null (whether a barcode has been scanned) and send the data to the backend
    if (barcodeResult != null) {
      setState(() {
        scanPrompt =
            "Barcode Type: ${barcodeResult!.format.name}\nData: ${barcodeResult!.code}";
      });

      // Show a SnackBar with success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('İşlem Başarılı'),
          backgroundColor: Colors.green, // Set background color to green
          duration: const Duration(seconds: 2),
        ),
      );

      // Send the barcode data and stationId to the API
      await sendDataToBackend(barcodeResult, stationId!);

      print('Station ID: $stationId ?????   !!!!!!!!!!!!!!!!\n\n\n\n');
      print('${barcodeResult?.code} will be sent !!!!!!!!!!!!!!!!\n\n\n\n');
    } else {
      setState(() {
        scanPrompt = "Invalid scan. Please scan the barcode again.";
      });
    }
  }

  Future<void> sendDataToBackend(Barcode? barcode, String stationId) async {
    // Ensure that the barcode data is not empty or null before sending it to the backend.
    // This is important because even if barcodeResult is not null, its code property could be null or empty.
    // This check helps prevent sending invalid or empty data to the backend.
    if (barcode?.code?.isNotEmpty ?? false) {
      final apiUrl =
          'http://arcay179v:7575/api/embedded/insertTraceabilityData/$stationId';

      final data = {
        'scanBarcodeResult': barcode?.code,
        'isTherePallet': 1,
      };

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );

        if (response.statusCode == 200) {
          print('Data sent successfully to the backend.');
        } else {
          print('Error sending data. Status code: ${response.statusCode}');
          print('Failed to send data: ${response.reasonPhrase}');
        }
      } catch (e) {
        print('Error sending data: $e');
      }
    } else {
      print('Barcode data is empty or null. Not sent to the backend.');
    }
  }

  // Dispose of the controller and WidgetsBindingObserver when you are done with it
  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }
}
