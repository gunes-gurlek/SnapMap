// lib/screens/sign_in_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sign_up_page.dart';
import '../main_layout.dart';


class SignInPage extends StatefulWidget {
  static const route = '/sign-in';
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  InputDecoration _underline(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
          color: Color(0xFF008DB1), fontWeight: FontWeight.w600, fontSize: 14),
      hintStyle: const TextStyle(
          color: Color(0xFFD1D6DB), fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFEBEBEB), width: 2),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF00B5E3), width: 2),
      ),
      suffixIcon: suffix,
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      // ✅ Başarılı giriş: AuthGate'i beklemeden ana sayfaya geç
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } on FirebaseAuthException catch (e) {
      _showErr(_friendly(e));   // sadece hata göster
      _pass.clear();            // isteğe bağlı: şifreyi temizle
      if (mounted) setState(() => _loading = false);
      return;
    } catch (_) {
      _showErr('Bir şeyler ters gitti.');
      _pass.clear();
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resetPassword() async {
    final mail = _email.text.trim();
    if (mail.isEmpty) {
      _showErr('Şifre sıfırlamak için e-posta gir.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      _snack('Sıfırlama maili gönderildi.');
    } on FirebaseAuthException catch (e) {
      _showErr(_friendly(e));
    }
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential': // ⬅️ Android’de sık gelir
        return 'E-posta veya şifre hatalı.';
      case 'invalid-email':
        return 'E-posta geçersiz.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.';
      default:
        return 'Giriş hatası: ${e.code}';
    }
  }


  void _showErr(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 386),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // ÜST HEADER (logo + SNAPMAP yazısı PNG)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Dairesel arka planlı ikon
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF7FB),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'images/ust_bar_logo.png', // dünya + tablet ikonun
                              width: 56,
                              height: 56,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // SNAPMAP yazısı PNG (wordmark)
                          // Boyutu buradan ayarlarsın (yüksekliği 26–30 arası iyi)
                          Image.asset(
                            'images/snapmap_yazi.png',
                            height: 56,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Sign In',
                        style: TextStyle(
                            color: Color(0xFF35424A),
                            fontWeight: FontWeight.w700,
                            fontSize: 26)),
                    const SizedBox(height: 6),
                    const Text('Hi there! Nice to see you again.',
                        style:
                        TextStyle(color: Color(0xFF989EB1), fontSize: 16)),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _underline('Email',
                                hint: 'example@email.com'),
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              final emailRx = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (t.isEmpty) return 'E-posta gerekli';
                              if (!emailRx.hasMatch(t)) return 'E-posta geçersiz';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: _underline(
                              'Password',
                              hint: '••••••••',
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFD1D6DB),
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'En az 6 karakter'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF00B5E3), Color(0xFF086075)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : const Text('Sign In',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: _loading ? null : () {/* Google auth sonra bağlanacak */},
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Image.asset('images/google_png.png', width: 36, height: 36),
                          ),
                        ),
                        const SizedBox(width: 24),
                        InkWell(
                          onTap: _loading ? null : () {/* Apple auth sonra */},
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Image.asset('images/apple_logo.png', width: 36, height: 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text('Forgot Password?',
                            style: TextStyle(color: Color(0xFF989EB1))),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pushNamed(
                          context,
                          SignUpPage.route,
                        ),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: Color(0xFF008DB1),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        height: 6,
                        width: 140,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
