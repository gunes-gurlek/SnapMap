// lib/friends_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'public_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  static const routeName = '/friends';

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _me = FirebaseAuth.instance.currentUser!;
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(_onChanged);
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _q = _searchCtl.text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  /// Firestore: friends/{uid}/list/{friendUid} { createdAt }
  Stream<List<_UserLite>> _friendsStream() async* {
    final listRef = FirebaseFirestore.instance
        .collection('friends')
        .doc(_me.uid)
        .collection('list')
        .orderBy('createdAt', descending: true)
        .snapshots();

    await for (final qs in listRef) {
      final ids = qs.docs.map((d) => d.id).toList();
      if (ids.isEmpty) {
        yield [];
        continue;
      }

      // whereIn 10 sınırı -> parçala
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }

      final List<_UserLite> out = [];
      for (final c in chunks) {
        final res = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: c)
            .get();
        out.addAll(res.docs.map(_UserLite.fromDoc));
      }
      yield out;
    }
  }

  /// Arama: username + firstName/lastName (prefix), kayıt şemasını değiştirmeden
  Future<List<_UserLite>> _search(String raw) async {
    final q = raw.trim();
    if (q.length < 2) return [];

    final users = FirebaseFirestore.instance.collection('users');

    // Case-sensitive’i tolere etmek için birkaç varyant
    List<String> _variants(String s) {
      if (s.isEmpty) return [];
      String title = s[0].toUpperCase() + s.substring(1).toLowerCase();
      String tr(String x) => x
          .replaceAll('i', 'İ')
          .replaceAll('ı', 'I')
          .replaceAll('ğ', 'Ğ')
          .replaceAll('ş', 'Ş')
          .replaceAll('ç', 'Ç')
          .replaceAll('ö', 'Ö')
          .replaceAll('ü', 'Ü');
      final set = {
        s,
        s.toLowerCase(),
        s.toUpperCase(),
        title,
        tr(title),
        tr(s),
      };
      return set.where((e) => e.isNotEmpty).toList();
    }

    // “elif cöm” -> ["elif","cöm"]
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final v1 = _variants(tokens[0]);
    final v2 = tokens.length > 1 ? _variants(tokens[1]) : const <String>[];

    final Map<String, _UserLite> uniq = {};

    Future<void> _prefixFetch({
      required String field,
      required String p,
      int limit = 20,
    }) async {
      final qs = await users
          .orderBy(field)
          .startAt([p])
          .endAt(['$p\uf8ff'])
          .limit(limit)
          .get();
      for (final d in qs.docs) {
        if (d.id == _me.uid) continue; // kendimi çıkar
        uniq[d.id] = _UserLite.fromDoc(d);
      }
    }

    // 1) username
    for (final p in v1) {
      await _prefixFetch(field: 'username', p: p, limit: 25);
    }

    // 2) firstName & lastName
    for (final p in v1) {
      await _prefixFetch(field: 'firstName', p: p);
      await _prefixFetch(field: 'lastName', p: p);
    }
    for (final p in v2) {
      await _prefixFetch(field: 'firstName', p: p);
      await _prefixFetch(field: 'lastName', p: p);
    }

    // İstemci doğrulama: username prefix || fullName token containment
    bool _matches(_UserLite u) {
      final user = (u.username ?? '').toLowerCase();
      final full = ('${u.firstName ?? ''} ${u.lastName ?? ''}').trim().toLowerCase();
      if (user.startsWith(q.toLowerCase())) return true;
      return tokens.every((t) => full.contains(t.toLowerCase()));
    }

    final results = uniq.values.where(_matches).toList();

    // Sıralama: önce username prefix uyanlar
    results.sort((a, b) {
      final au = (a.username ?? '').toLowerCase();
      final bu = (b.username ?? '').toLowerCase();
      final ap = au.startsWith(q.toLowerCase()) ? 0 : 1;
      final bp = bu.startsWith(q.toLowerCase()) ? 0 : 1;
      if (ap != bp) return ap - bp;
      final af = ('${a.firstName ?? ''} ${a.lastName ?? ''}').toLowerCase();
      final bf = ('${b.firstName ?? ''} ${b.lastName ?? ''}').toLowerCase();
      return af.compareTo(bf);
    });

    return results;
  }

  Widget _tile(_UserLite u) {
    final fullName = ('${u.firstName ?? ''} ${u.lastName ?? ''}').trim();
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (u.photoUrl != null && u.photoUrl!.isNotEmpty)
            ? NetworkImage(u.photoUrl!)
            : null,
        child: (u.photoUrl == null || u.photoUrl!.isEmpty) ? Text(u.initials) : null,
      ),
      title: Text(fullName.isNotEmpty ? fullName : (u.username ?? 'Kullanıcı')),
      subtitle: Text(u.username != null ? '@${u.username}' : ''),
      onTap: () {
        Navigator.pushNamed(
          context,
          PublicProfileScreen.routeName,
          arguments: PublicProfileArgs(userId: u.uid),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _q.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşlar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
                hintText: 'İsim, soyisim veya @kullanıcı adı',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: searching
                ? FutureBuilder<List<_UserLite>>(
              future: _search(_q),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) return const Center(child: Text('Sonuç yok'));
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(items[i]),
                );
              },
            )
                : StreamBuilder<List<_UserLite>>(
              stream: _friendsStream(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz arkadaşın yok.\nArama çubuğundan ekleyebilirsin.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserLite {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;

  _UserLite({
    required this.uid,
    this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
  });

  factory _UserLite.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return _UserLite(
      uid: d.id,
      firstName: m['firstName'] as String?,
      lastName:  m['lastName']  as String?,
      username:  m['username']  as String?,
      photoUrl:  m['photoUrl']  as String?,
    );
  }

  String get initials {
    final f = (firstName ?? '').isNotEmpty ? firstName![0] : '';
    final l = (lastName ?? '').isNotEmpty ? lastName![0] : '';
    return (f + l).toUpperCase();
  }
}
