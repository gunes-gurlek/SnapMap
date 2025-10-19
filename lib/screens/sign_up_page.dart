// lib/screens/sign_up_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SignUpPage extends StatefulWidget {
  static const String route = '/sign-up';
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  bool _loading = false;
  bool _obscurePw = true;
  bool _obscurePw2 = true;
  File? _pickedImage;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_pickedImage == null) return null;
    final ref = _storage.ref().child('user_profiles').child('$uid.jpg');
    final uploadTask = ref.putFile(_pickedImage!);
    final snapshot = await uploadTask.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  Future<bool> _isUsernameTaken(String username) async {
    final snap = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() => _loading = true);

    try {
      // 0) Check if username already exists
      final taken = await _isUsernameTaken(username);
      if (taken) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This username is already taken. Please try another.')),
        );
        return;
      }

      // 1) Create user in Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      // 2) Upload profile picture (if selected)
      final photoUrl = await _uploadProfileImage(uid);

      // 3) Save user profile in Firestore
      await _firestore.collection('users').doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4) Update Firebase Auth display name and photo
      await cred.user!.updateDisplayName('$firstName $lastName');
      if (photoUrl != null) {
        await cred.user!.updatePhotoURL(photoUrl);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful!')));
      Navigator.of(context).pop(); // or navigate to main screen
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'An error occurred during registration';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unexpected error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateNotEmpty(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field cannot be empty';
    return null;
  }

  String? _validateUsername(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Username cannot be empty';
    if (val.length < 3) return 'Username must be at least 3 characters';
    final re = RegExp(r'^[a-zA-Z0-9_\.]+$');
    if (!re.hasMatch(val)) return 'Only letters, numbers, dot and underscore are allowed';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email cannot be empty';
    final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!pattern.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password cannot be empty';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validatePasswordConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Password confirmation cannot be empty';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = 110.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/signup_header.png',
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: imageSize / 2,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _pickedImage != null ? FileImage(_pickedImage!) : null,
                              child: _pickedImage == null
                                  ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.camera_alt_outlined, size: 30),
                                  SizedBox(height: 6),
                                  Text('Select profile photo', style: TextStyle(fontSize: 12)),
                                ],
                              )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameCtrl,
                                  decoration: const InputDecoration(labelText: 'First Name'),
                                  validator: (v) => _validateNotEmpty(v, 'First name'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameCtrl,
                                  decoration: const InputDecoration(labelText: 'Last Name'),
                                  validator: (v) => _validateNotEmpty(v, 'Last name'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(labelText: 'Username'),
                            validator: _validateUsername,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePw = !_obscurePw),
                              ),
                            ),
                            obscureText: _obscurePw,
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _passwordConfirmCtrl,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePw2 ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePw2 = !_obscurePw2),
                              ),
                            ),
                            obscureText: _obscurePw2,
                            validator: _validatePasswordConfirm,
                          ),

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text('Sign Up'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loading ? null : () => Navigator.of(context).pop(),
                            child: const Text('Already have an account? Sign In'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
