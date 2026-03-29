
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'wrapper_backup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Force Flutter errors to show in console
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  bool isFirebaseReady = false;
  String? errorMessage;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCV8WazDg4wmMHqNqVXIeM90Y56bjcUhm0",
          authDomain: "incitrack-61dde.firebaseapp.com",
          projectId: "incitrack-61dde",
          storageBucket: "incitrack-61dde.firebasestorage.app",
          messagingSenderId: "322746024984",
          appId: "1:322746024984:web:c7f9c139cfceee00cfef6d",
          measurementId: "G-8N32VM7R4D",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    isFirebaseReady = true;
    debugPrint("✅ Firebase initialized successfully");
  } catch (e) {
    errorMessage = e.toString();
    debugPrint('❌ Firebase Initialization Error: $e');
  }

  runApp(MyApp(
    isFirebaseReady: isFirebaseReady,
    error: errorMessage,
  ));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  final String? error;

  const MyApp({
    super.key,
    required this.isFirebaseReady,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InciTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // 🔥 DEBUG MODE SWITCH
      home: isFirebaseReady
          ? const DebugScreen() // 👈 TEMP: isolate issue
          : Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error ?? 'An unknown error occurred.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 TEMP DEBUG SCREEN
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "App is Running ✅",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

