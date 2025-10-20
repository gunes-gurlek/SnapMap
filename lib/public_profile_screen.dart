// lib/public_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PublicProfileArgs {
  final String userId;
  const PublicProfileArgs({required this.userId});
}

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key});
  static const routeName = '/publicProfile';

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _me = FirebaseAuth.instance.currentUser!;
  late final String _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as PublicProfileArgs;
    _userId = args.userId;
  }

  Future<Map<String, dynamic>?> _fetchUser() async {
    final s = await _db.child('users/$_userId').get();
    if (!s.exists) return null;
    return Map<String, dynamic>.from(s.value as Map);
  }

  Stream<bool> _isFriendStream() {
    return _db.child('friends/${_me.uid}/$_userId').onValue.map((e) => e.snapshot.exists);
  }

  Future<void> _toggleFriend(bool isFriend) async {
    final me = _me.uid;
    final updates = <String, dynamic>{};
    if (isFriend) {
      updates['friends/$me/$_userId'] = null;
      updates['friends/$_userId/$me'] = null;
    } else {
      updates['friends/$me/$_userId'] = true;
      updates['friends/$_userId/$me'] = true;
    }
    await _db.update(updates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(), title: const Text('Profil')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUser(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final u = snap.data;
          if (u == null) return const Center(child: Text('Kullanıcı bulunamadı.'));
          final fullName = (u['fullName'] ?? '') as String;
          final username = (u['username'] ?? '') as String;
          final avatar = (u['avatarUrl'] ?? '') as String;
          final followers = (u['followersCount'] ?? 0) as int;
          final follows = (u['followsCount'] ?? 0) as int;
          final posts = (u['postsCount'] ?? 0) as int;

          return Column(
            children: [
              const SizedBox(height: 16),
              CircleAvatar(radius: 40, backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null),
              const SizedBox(height: 8),
              Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('@$username', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              StreamBuilder<bool>(
                stream: _isFriendStream(),
                builder: (ctx, frSnap) {
                  final isFriend = frSnap.data ?? false;
                  return ElevatedButton(
                    onPressed: () => _toggleFriend(isFriend),
                    child: Text(isFriend ? 'Arkadaşsın' : 'Takip et / Arkadaş ekle'),
                  );
                },
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _stat('$followers followers'),
                    _stat('$follows follows'),
                    _stat('$posts posts'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: posts, // örnek
                  itemBuilder: (_, __) => Container(color: Colors.grey.shade300),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w500));
}
