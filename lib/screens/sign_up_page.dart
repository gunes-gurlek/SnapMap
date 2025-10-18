// lib/screens/sign_up_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sign_in_page.dart';

class SignUpPage extends StatefulWidget {
  static const route = '/sign-up';
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _agree = true;
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      _err('Devam etmek için şartları kabul et.');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      // ✅ Başarılı olursa AuthGate MainLayout'a geçirir.
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _err('Bu e-posta zaten kayıtlı.');
          break;
        case 'invalid-email':
          _err('E-posta geçersiz.');
          break;
        case 'weak-password':
          _err('Şifre zayıf (en az 6 karakter).');
          break;
        case 'operation-not-allowed':
          _err('Email/Password yöntemi kapalı. Firebase Console’dan aç.');
          break;
        case 'network-request-failed':
          _err('Ağ hatası. İnternet bağlantını kontrol et.');
          break;
        default:
          _err('Kayıt hatası: ${e.code}');
      }
      _pass.clear();                         // 🔒 opsiyonel: şifreyi temizle
      if (mounted) setState(() => _loading = false);
      return;                                // ⬅️ kritik: hiçbir yönlendirme yok
    } catch (_) {
      _err('Bir şeyler ters gitti.');
      _pass.clear();
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = false);
  }


  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: Colors.red),
  );

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
                    // Sağ üstteki logo (mockup gibi)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF7FB),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'images/ust_bar_logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Sign Up',
                        style: TextStyle(
                            color: Color(0xFF35424A),
                            fontWeight: FontWeight.w700,
                            fontSize: 26)),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _underline('Email',
                                hint: 'Your email address'),
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
                              hint: 'Your password',
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
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agree,
                          onChanged: (v) => setState(() => _agree = v ?? false),
                          activeColor: const Color(0xFF00A4D3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'I agree to the Terms of Services and Privacy Policy.',
                            style: TextStyle(
                                color: Color(0xFF606060), fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                          onPressed: _loading ? null : _signUp,
                          child: _loading
                              ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : const Text('Continue',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, SignInPage.route),
                        child: const Text('Have an Account?  Sign In',
                            style: TextStyle(
                                color: Color(0xFF989EB1),
                                fontWeight: FontWeight.w500)),
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
