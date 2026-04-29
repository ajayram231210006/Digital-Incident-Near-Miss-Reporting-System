import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app_theme.dart';
import 'offline_reporter_home.dart';
import 'notification_service.dart';
import 'reporter_identity.dart';
import 'user_profile_service.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Connectivity _connectivity = Connectivity();
  final UserProfileService _userProfileService = UserProfileService();
  StreamSubscription<dynamic>? _connectivitySubscription;

  bool _isFirebaseReady = false;
  bool _isInitializing = true;
  bool _isOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      final isOnline = _hasConnection(result);
      if (!mounted) return;

      if (_isOffline != !isOnline) {
        setState(() {
          _isOffline = !isOnline;
        });
      }

      if (isOnline && !_isFirebaseReady && !_isInitializing) {
        _bootstrap();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    final isOnline = await _checkInternetAvailability();
    if (!mounted) return;

    setState(() {
      _isOffline = !isOnline;
    });

    try {
      await _initializeFirebase().timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = true;
        _isInitializing = false;
        _error = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = false;
        _isInitializing = false;
        _error = 'Startup timed out while preparing online services.';
      });
    } catch (e) {
      debugPrint('Firebase Initialization Error: $e');
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = false;
        _isInitializing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
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
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<bool> _checkInternetAvailability() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _hasConnection(result);
    } catch (_) {
      return false;
    }
  }

  bool _hasConnection(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InciTrack',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: _buildHome(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    if (_isFirebaseReady) {
      return const Wrapper();
    }

    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isOffline) {
      return FutureBuilder<ReporterIdentity?>(
        future: _userProfileService.getOfflineReporterSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final reporter = snapshot.data;
          if (reporter != null) {
            return OfflineReporterHome(reporter: reporter);
          }

          return _StartupFallbackScreen(
            isOffline: true,
            error: _error,
            onRetry: _bootstrap,
          );
        },
      );
    }

    return _StartupFallbackScreen(
      isOffline: _isOffline,
      error: _error,
      onRetry: _bootstrap,
    );
  }
}

class _StartupFallbackScreen extends StatelessWidget {
  final bool isOffline;
  final String? error;
  final Future<void> Function() onRetry;

  const _StartupFallbackScreen({
    required this.isOffline,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = isOffline ? 'Offline Mode' : 'Initialization Error';
    final message = isOffline
        ? 'The app opened, but online services are unavailable right now. Reconnect to continue with sign-in, sync, and live data.'
        : (error ?? 'An unknown error occurred during startup.');
    final icon = isOffline ? Icons.cloud_off : Icons.error_outline;
    final color = isOffline ? AppColors.textSecondary : AppColors.error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 80),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: onRetry,
                  child: Text(isOffline ? 'Retry Connection' : 'Retry Startup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
