import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'offline_report_queue_service.dart';
import 'wrapper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBqZml7mim57mnAINgNgwfQHtX1yuy3JwM",
        authDomain: "users-3f3bd.firebaseapp.com",
        databaseURL: "https://users-3f3bd-default-rtdb.firebaseio.com",
        projectId: "users-3f3bd",
        storageBucket: "users-3f3bd.firebasestorage.app",
        messagingSenderId: "748983652775",
        appId: "1:748983652775:web:3f3e023e596fd70897a682",
        measurementId: "G-42B01W22VJ",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  final hasSystemNotification = message.notification != null;
  final hasDataTitleOrBody =
      message.data['title'] != null || message.data['body'] != null;

  if (!hasSystemNotification && hasDataTitleOrBody) {
    final notificationService = NotificationService();
    await notificationService.ensureLocalNotificationsInitialized();
    await notificationService.showNotificationFromRemoteMessage(message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseReady = false;
  String? errorMessage;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBqZml7mim57mnAINgNgwfQHtX1yuy3JwM",
          authDomain: "users-3f3bd.firebaseapp.com",
          databaseURL: "https://users-3f3bd-default-rtdb.firebaseio.com",
          projectId: "users-3f3bd",
          storageBucket: "users-3f3bd.firebasestorage.app",
          messagingSenderId: "748983652775",
          appId: "1:748983652775:web:3f3e023e596fd70897a682",
          measurementId: "G-42B01W22VJ",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await OfflineReportQueueService().init();
    isFirebaseReady = true;
  } catch (e) {
    errorMessage = e.toString();
    debugPrint('Firebase Initialization Error: $e');
  }

  runApp(MyApp(isFirebaseReady: isFirebaseReady, error: errorMessage));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseReady;
  final String? error;

  const MyApp({super.key, required this.isFirebaseReady, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InciTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 3,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.indigo.shade600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: isFirebaseReady
          ? const Wrapper()
          : Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Initialization Error',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error ?? 'An unknown error occurred during startup.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () => main(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
