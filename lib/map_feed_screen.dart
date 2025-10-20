import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class Post {
  final String id;
  final String imageUrl;
  final String userPhotoUrl;
  final double lat, lng;
  final String uid;
  final DateTime? createdAt;

  Post({
    required this.id,
    required this.imageUrl,
    required this.userPhotoUrl,
    required this.lat,
    required this.lng,
    required this.uid,
    this.createdAt,
  });

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Post(
      id: d.id,
      imageUrl: m['imageUrl'] ?? '',
      userPhotoUrl: (m['userPhotoUrl'] ?? '') as String,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      uid: (m['uid'] ?? '') as String,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

final _fs = FirebaseFirestore.instance;

class MapFeedScreen extends StatefulWidget {
  const MapFeedScreen({super.key});
  @override
  State<MapFeedScreen> createState() => _MapFeedScreenState();
}

class _MapFeedScreenState extends State<MapFeedScreen> {
  GoogleMapController? _map;
  LatLng _my = const LatLng(41.0082, 28.9784);

  final _posts = <Post>[];
  final _overlayPositions = <String, Offset>{};

  Marker? _myLocationMarker;
  StreamSubscription? _followSub;
  StreamSubscription? _postSub;
  Timer? _recomputeDebounce;

  final List<String> _friendAvatars = [
    'https://i.pravatar.cc/150?img=1',
    'https://i.pravatar.cc/150?img=2',
    'https://i.pravatar.cc/150?img=3',
    'https://i.pravatar.cc/150?img=4',
    'https://i.pravatar.cc/150?img=5',
    'https://i.pravatar.cc/150?img=6',
    'https://i.pravatar.cc/150?img=7',
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenPosts();
  }

  // 🔹 Dairesel marker resmi oluşturur
  Future<BitmapDescriptor> _createCustomMarkerBitmap(String imageUrl, {int size = 120}) async {
    final http.Response response = await http.get(Uri.parse(imageUrl));
    final Uint8List bytes = response.bodyBytes;
    final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: size);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = size / 2;

    // Dış beyaz çerçeve
    final Paint borderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    final Path path = Path()..addOval(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    canvas.clipPath(path);
    paintImage(canvas: canvas, rect: Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), image: image, fit: BoxFit.cover);

    final ui.Image markerImage = await recorder.endRecording().toImage(size, size);
    final ByteData? byteData = await markerImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // 🔹 Konum al ve marker oluştur
  Future<void> _initLocation() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return;

    final pos = await Geolocator.getCurrentPosition();
    _my = LatLng(pos.latitude, pos.longitude);

    _map?.animateCamera(CameraUpdate.newLatLngZoom(_my, 15));
    _updateMyLocationMarker();
  }

  Future<void> _updateMyLocationMarker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await _fs.collection('users').doc(user.uid).get();
    final data = doc.data();
    String? photoUrl = data?['photoUrl'] ?? user.photoURL;

    if (photoUrl == null || photoUrl.isEmpty) return;
    final icon = await _createCustomMarkerBitmap(photoUrl);

    setState(() {
      _myLocationMarker = Marker(
        markerId: const MarkerId('me'),
        position: _my,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
      );
    });
  }

  // 🔹 Firestore'dan postları dinle
  void _listenPosts() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final sinceMs = DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000;

    // Basit: sadece kendim + son 24 saat
    _postSub?.cancel();_postSub = _fs
        .collection('posts')
        .where('createdAtMs', isGreaterThanOrEqualTo: sinceMs)
        .orderBy('createdAtMs', descending: true)
        .snapshots()
        .listen((snap) {
      final all = snap.docs.map((d) => Post.fromDoc(d)).toList();

      // 🔹 her kullanıcının yalnızca en yeni post’unu göster
      final latestByUser = <String, Post>{};
      for (final p in all) {
        if (!latestByUser.containsKey(p.uid)) {
          latestByUser[p.uid] = p; // zaten sıralama descending
        }
      }

      _posts
        ..clear()
        ..addAll(latestByUser.values);

      print("📸 Haritada gösterilecek post sayısı: ${_posts.length}");
      if (!mounted) return;
      setState(() {});
      _recomputeOverlayPositions();
    });

  }

  // 🔹 Harita üzerindeki overlay konumlarını hesapla
  Future<void> _recomputeOverlayPositions() async {
    if (_map == null || !mounted) return;

    _recomputeDebounce?.cancel();
    _recomputeDebounce = Timer(const Duration(milliseconds: 80), () async {
      if (_map == null || !mounted) return;

      final dpr = MediaQuery.of(context).devicePixelRatio; // 👈 EKLE

      final newPos = <String, Offset>{};
      for (final p in _posts) {
        try {
          final sc = await _map!.getScreenCoordinate(LatLng(p.lat, p.lng));
          // 👇 ESKİ: Offset(sc.x.toDouble(), sc.y.toDouble())
          newPos[p.id] = Offset(sc.x / dpr, sc.y / dpr); // 👈 DÜZELTME
        } catch (e) {
          print("⚠️ Overlay pozisyon hatası: $e");
        }
      }

      setState(() {
        _overlayPositions
          ..clear()
          ..addAll(newPos);
      });

      print("🎯 Overlay hesaplanan adet: ${_overlayPositions.length}");
    });
  }


  void _onCameraMove(CameraPosition _) => _recomputeOverlayPositions();

  // 🔹 Fotoğraf çekme ve paylaşma
  Future<void> _onCameraButton() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.send),
            title: const Text('Paylaş'),
            onTap: () {
              Navigator.pop(context);
              _sharePhoto(x.path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tekrar Çek'),
            onTap: () {
              Navigator.pop(context);
              _onCameraButton();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _sharePhoto(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pos = await Geolocator.getCurrentPosition();
    final file = File(path);
    final ref = FirebaseStorage.instance.ref().child('posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final doc = await _fs.collection('users').doc(user.uid).get();
    final photoUrl = (doc.data()?['photoUrl'] as String?) ?? user.photoURL ?? '';

    await _fs.collection('posts').add({
      'uid': user.uid,
      'imageUrl': url,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'userPhotoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });

    // Yeni postu haritada göster
    _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15));
  }
  void _openStoryViewer(String uid, String currentPostId) async {
    final sinceMs = DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000;
    final snap = await _fs
        .collection('posts')
        .where('uid', isEqualTo: uid)
        .where('createdAtMs', isGreaterThanOrEqualTo: sinceMs)
        .orderBy('createdAtMs', descending: true)
        .get();

    final userPosts = snap.docs.map((d) => Post.fromDoc(d)).toList();
    if (userPosts.isEmpty) return;

    final initialIndex = userPosts.indexWhere((p) => p.id == currentPostId);
    final startIndex = (initialIndex < 0) ? 0 : initialIndex;

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 100)); // 🔹 küçük gecikme
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryViewerPage(posts: userPosts, initialIndex: startIndex),
      ),
    );
  }



  @override
  void dispose() {
    _followSub?.cancel();
    _postSub?.cancel();
    super.dispose();
  }

  // 🔹 Alt bar
  Widget _buildBottomBar() => Positioned(
    bottom: 24,
    left: 16,
    right: 16,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _onCameraButton,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 5)
            ]),
            child: const Icon(Icons.camera_alt, color: Colors.black),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _friendAvatars.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: CircleAvatar(radius: 25, backgroundImage: NetworkImage(_friendAvatars[i])),
              ),
            ),
          ),
        ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _my, zoom: 14),
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (c) async {
          _map = c;
          await Future.delayed(const Duration(milliseconds: 600));
          _recomputeOverlayPositions();
        },
        onCameraMove: _onCameraMove,
        onCameraIdle: _recomputeOverlayPositions,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: _myLocationMarker != null ? {_myLocationMarker!} : {},
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),   // haritayı sürükleme aktif
          Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()), // zoom aktif
          // TapGestureRecognizer bilerek eklenmiyor, çünkü tap'leri overlay'e geçmesini istiyoruz
        },

      ),
      ..._posts.map((p) {
        final pos = _overlayPositions[p.id];
        if (pos == null) return const SizedBox.shrink();

        const photoW = 110.0;
        const photoH = 160.0;
        const avatarR = 20.0;

        return Positioned(
          left: pos.dx - photoW / 2,
          top: pos.dy - photoH - avatarR * 2 - 6,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, // 🔹 Bunu ekliyorsun
            onTap: () => _openStoryViewer(p.uid, p.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: photoW,
                  height: photoH,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(blurRadius: 8, offset: Offset(0, 4), color: Colors.black26)
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(imageUrl: p.imageUrl, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: avatarR,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: avatarR - 2.5,
                    backgroundImage: p.userPhotoUrl.isNotEmpty
                        ? NetworkImage(p.userPhotoUrl)
                        : null,
                    child: p.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                  ),
                ),
              ],
            ),
          ),

        );
      }),

      _buildBottomBar(),
    ]);
  }
}
class StoryViewerPage extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;
  const StoryViewerPage({super.key, required this.posts, required this.initialIndex});

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: posts.length,
            itemBuilder: (_, i) {
              final p = posts[i];
              return Center(
                child: CachedNetworkImage(
                  imageUrl: p.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: posts.first.userPhotoUrl.isNotEmpty
                      ? NetworkImage(posts.first.userPhotoUrl)
                      : null,
                  child: posts.first.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

