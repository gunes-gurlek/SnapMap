// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

// DİKKAT: Artık MapFeedScreen'i değil, MainLayout'u import ediyoruz.
import 'main_layout.dart';


// Aşağıda yazacağımız ekranlar
import 'screens/sign_in_page.dart';
import 'screens/sign_up_page.dart';

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

      // Rotalar (Sign In/Up arasında rahat geçiş için)
      routes: {
        SignInPage.route: (_) => const SignInPage(),
        SignUpPage.route: (_) => const SignUpPage(),
      },
      // 🔒 Kimlik durumuna göre yöneten kapı
      home: const AuthGate(),
    );
  }
}
/// Kullanıcı girişliyse MainLayout'a; değilse SignIn'e götürür.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData && snap.data != null) {
          return const MainLayout(); // Arkadaşının ana ekran yapısı
        }
        return const SignInPage();
      },
    );
  }
}