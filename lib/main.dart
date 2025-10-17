// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// DİKKAT: Artık MapFeedScreen'i değil, MainLayout'u import ediyoruz.
import 'main_layout.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // DEĞİŞİKLİK: Uygulamanın ana ekranı artık tüm yapıyı içeren MainLayout.
      home: const MainLayout(),

      // 'routes' kısmını silebilirsiniz, çünkü sayfa geçişlerini
      // artık MainLayout kendi içinde yönetiyor.
    );
  }
}