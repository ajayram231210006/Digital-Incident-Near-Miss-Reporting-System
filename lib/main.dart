import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    // For Web, we try to initialize but don't block the app if it fails
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyB-MqyU-whPzUnIuADMnWu1xtaWA-Zb9ok',
          appId: '1:748983652775:web:f257a6e42000c55e97a682',
          messagingSenderId: '748983652775',
          projectId: 'users-3f3bd',
          storageBucket: 'users-3f3bd.firebasestorage.app',
        ),
      );
    } catch (e) {
      debugPrint('Firebase Web Init Error: $e');
    }
  } else {
    // Mobile initialization
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase Mobile Init Error: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InciTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const Wrapper(),
    );
  }
}
