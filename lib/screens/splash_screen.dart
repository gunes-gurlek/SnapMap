import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main_layout.dart';
import 'sign_in_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _moveUpAnim;
  late Animation<double> _fadeTextAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 🔹 Logonun büyüklüğü (2 kat)
    _scaleAnim = Tween<double>(begin: 2.8, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 🔹 Yukarı kayma mesafesi azaltıldı (daha aşağıda kalır)
    _moveUpAnim = Tween<double>(begin: 0, end: -140).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeTextAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
    Timer(const Duration(seconds: 3), _navigateNext);
  }

  void _navigateNext() {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, _moveUpAnim.value),
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: Image.asset(
                      'images/ust_bar_logo.png',
                      width: 300,
                      height: 300,
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                Opacity(
                  opacity: _fadeTextAnim.value,
                  child: Image.asset(
                    'images/snapmap_yazi.png',
                    width: 380,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
