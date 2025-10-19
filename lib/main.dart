// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Sayfalar
import 'main_layout.dart';
import 'screens/sign_in_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/splash_screen.dart'; // <-- splash

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapMap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B5E3)),
        useMaterial3: true,
      ),
      // Rotalar
      routes: {
        SignInPage.route: (_) => const SignInPage(),
        SignUpPage.route: (_) => const SignUpPage(),
      },
      // Başlangıç: Splash (logo ortada, sonra yukarı kayıp Auth durumuna göre yönlendirir)
      home: const SplashScreen(),
    );
  }
}
