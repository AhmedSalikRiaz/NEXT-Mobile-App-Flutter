import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:next_mobile_app/scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXT Mobile App',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'NEXT Mobile App Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  String _wifiName = 'Unknown';
  bool _locationPermissionRequestInProgress = false;
  static const url = 'http://next';
  final uri = Uri.parse(url);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    getWifiName(); // Retrieve wifi name during initialization
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      getWifiName();
    }
  }

  Future<void> getWifiName() async {
    final info = NetworkInfo();
    PermissionStatus? permissionStatus; // Make permissionStatus nullable

    // Check if the location permission is permanently denied
    final isPermanentlyDenied = await Permission.location.isPermanentlyDenied;

    // If the location permission is permanently denied, show the app settings dialog
    if (isPermanentlyDenied) {
      setState(() {
        _wifiName = 'Location permission permanently denied';
        print('Status 1111: $permissionStatus\n\n\n');
      });
      await showLocationPermissionDialog();
      return;
    }

    // Ensure that a permission request is not already in progress
    if (_locationPermissionRequestInProgress) {
      return;
    }
    _locationPermissionRequestInProgress = true;

    try {
      // Request location permission if not granted or if permissionStatus is null
      if (!await Permission.location.isGranted || permissionStatus == null) {
        permissionStatus = await Permission.location.request();

        print('Status 1: $permissionStatus\n\n\n');
      }

      // If permission is granted, retrieve the Wi-Fi name
      if (permissionStatus.isGranted) {
        final wifiName = await info.getWifiName();
        print('Wi-Fi SSID: $wifiName'); // Debug print
        print('Status 2: $permissionStatus\n\n\n');

        setState(() {
          _wifiName =
              wifiName ?? 'Not connected to Wi-Fi or location service is off';
          print('Status 3: $permissionStatus\n\n\n');
        });
      }

      // If permission is denied, but not permanently denied, show a message to request permission again
      else if (permissionStatus.isDenied) {
        // Check if the permission has been requested previously
        final isPreviouslyRequested =
            await Permission.location.isPermanentlyDenied;
        print('Status 4: $permissionStatus\n\n\n');

        // If permission has been previously requested, show a message to request permission again
        if (!isPreviouslyRequested) {
          setState(() {
            _wifiName = 'Please allow location permission';
            print('Status 5: $permissionStatus\n\n\n');
          });
        }
      }

      // If permission is permanently denied, handle the denied scenario
      else if (permissionStatus.isPermanentlyDenied) {
        setState(() {
          _wifiName = 'Location permission permanently denied';
          print('Status 6: $permissionStatus\n\n\n');
        });
      }
    } finally {
      _locationPermissionRequestInProgress = false;
    }
  }

  Future<void> showLocationPermissionDialog() async {
    // Show dialog prompting user to go to app settings
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Make the dialog undismissable
      builder: (BuildContext context) {
        return WillPopScope(
          // Intercept the back button press
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Please grant location permission from app settings to continue using the app.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openAppSettings(); // Open app settings
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to open URL in browser
  void _launchURL() async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NEXT',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true, // Center the app bar title
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue[100]!], // Set gradient colors
          ),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.start, // Align welcome message to the top
          children: [
            SizedBox(
              height: screenHeight * 0.13, // Set height of the welcome message
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(
                      top:
                          50.0), // Add margin to the top of the welcome message
                  child: const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment
                      .center, // Center the SSID text and button vertically
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0), // Adjust padding
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width *
                            0.75, // Set max width of the text box
                        child: Text(
                          'Wi-Fi SSID: $_wifiName',
                          textAlign: TextAlign.center, // Center align the text
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        getWifiName(); // Refresh Wi-Fi SSID
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                            255, 252, 248, 255), // Set button background color
                        shadowColor: const Color.fromARGB(255, 97, 97, 97),
                        elevation: 4, // Add elevation
                      ),
                      child: const Text(
                        'Refresh',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      // Button for barcode scanning
                      onPressed: () {
                        // Navigate to scanner screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ScannerScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 252, 248, 255),
                        shadowColor: const Color.fromARGB(255, 97, 97, 97),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Start Scanning',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.all(10.0), // Add padding
              margin: const EdgeInsets.all(15.0), // Add margin
              child: TextButton(
                onPressed:
                    null, // The button is disabled and won’t respond to taps as we only want the hyperlink to be tappable
                child: RichText(
                  textAlign:
                      TextAlign.center, // This will center align the text
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'NEXT Management Platform:\n',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: url,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer:
                            TapGestureRecognizer() // Makes the hyperlink tappable
                              ..onTap = () async {
                                _launchURL();
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dispose of the WidgetsBindingObserver when you are done with it
  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }
}
