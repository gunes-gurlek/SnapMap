import 'dart:io';
import 'dart:typed_data'; // Uint8List için eklendi
import 'dart:ui' as ui; // Canvas işlemleri için eklendi
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ByteData için eklendi
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Network'ten resim çekmek için eklendi

// --- VERİ MODELİ (Değişiklik yok) ---
class Post {
  // ... (Mevcut kodunuzdaki gibi)
  final String id;
  final String imageUrl;
  final String userPhotoUrl;
  final double lat, lng;

  Post({required this.id, required this.imageUrl, required this.userPhotoUrl, required this.lat, required this.lng});

  factory Post.fromMap(String id, Map m) => Post(
    id: id,
    imageUrl: m['imageUrl'],
    userPhotoUrl: m['userPhotoUrl'] ?? '',
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
  );
}

// --- SAYFA WIDGET'I ---
class MapFeedScreen extends StatefulWidget {
  const MapFeedScreen({super.key});
  @override
  State<MapFeedScreen> createState() => _MapFeedScreenState();
}

class _MapFeedScreenState extends State<MapFeedScreen> {
  // --- STATE DEĞİŞKENLERİ ---
  GoogleMapController? _map;
  LatLng _my = const LatLng(41.0082, 28.9784);
  final _db = FirebaseDatabase.instance.ref();
  final _posts = <Post>[];
  final _overlayPositions = <String, Offset>{};
  bool _updatingPositions = false;

  // YENİ: Kendi konumumuzu gösterecek özel marker
  Marker? _myLocationMarker;

  final List<String> _friendAvatars = [
    'https:i.pravatar.cc/150?img=1', 'https:i.pravatar.cc/150?img=2',
    'https:i.pravatar.cc/150?img=3', 'https:i.pravatar.cc/150?img=4',
    'https:i.pravatar.cc/150?img=5', 'https:i.pravatar.cc/150?img=6',
    'https:i.pravatar.cc/150?img=7',
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenPosts();
  }

  // YENİ: Network'teki resmi dairesel bir marker ikonuna çeviren yardımcı fonksiyon
  Future<BitmapDescriptor> _createCustomMarkerBitmap(String imageUrl, {int size = 150}) async {
    final http.Response response = await http.get(Uri.parse(imageUrl));
    final Uint8List bytes = response.bodyBytes;
    final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: size);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint borderPaint = Paint()..color = Colors.white;
    final double borderRadius = size / 2;

    // Beyaz dış çerçeveyi çiz
    canvas.drawCircle(Offset(borderRadius, borderRadius), borderRadius, borderPaint);

    final Paint paint = Paint();
    final Path path = Path()
      ..addOval(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

    // Resmi dairesel olarak kırp
    canvas.clipPath(path);

    // Dairesel alana resmi çiz
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      image: image,
      fit: BoxFit.cover,
    );

    final ui.Image CROP_IMAGE_ = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? byteData = await CROP_IMAGE_.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List CROP_BYTES_ = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(CROP_BYTES_);
  }

  // YENİ: Kullanıcının konumunu ve profil resmini alıp marker'ı güncelleyen fonksiyon
  Future<void> _updateMyLocationMarker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnap = await _db.child('users/${user.uid}').get();
    String? photoUrl;
    if (userSnap.value is Map) {
      photoUrl = (userSnap.value as Map)['photoUrl'] as String?;
    }
    photoUrl ??= user.photoURL; // Eğer DB'de yoksa Auth'daki URL'i kullan

    if (photoUrl == null || photoUrl.isEmpty || !mounted) return;

    final BitmapDescriptor customIcon = await _createCustomMarkerBitmap(photoUrl);

    if (mounted) {
      setState(() {
        _myLocationMarker = Marker(
          markerId: const MarkerId('myLocation'),
          position: _my,
          icon: customIcon,
          anchor: const Offset(0.5, 0.5), // Ortala
        );
      });
    }
  }


  Future<void> _initLocation() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return;

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _my = LatLng(pos.latitude, pos.longitude);
        _map?.animateCamera(CameraUpdate.newLatLng(_my)); // Haritayı konuma odakla
      });
      // Konum alındıktan sonra marker'ı oluştur/güncelle
      _updateMyLocationMarker();
    }
  }

  // --- Diğer metodlarınız (Değişiklik yok) ---
  void _listenPosts() {
    // ...
    _db.child('posts').limitToLast(200).onValue.listen((e) {
      final val = e.snapshot.value as Map<Object?, Object?>?;
      _posts.clear();
      if (val != null) {
        val.forEach((key, value) {
          final m = Map<String, dynamic>.from(value as Map);
          _posts.add(Post.fromMap(key as String, m));
        });
      }
      if (mounted) {
        setState(() {});
        _recomputeOverlayPositions();
      }
    });
  }

  Future<void> _recomputeOverlayPositions() async {
    // ...
    if (_map == null || !mounted || _updatingPositions) return;
    _updatingPositions = true;

    final newPositions = <String, Offset>{};
    for (final p in _posts) {
      try {
        final sc = await _map!.getScreenCoordinate(LatLng(p.lat, p.lng));
        newPositions[p.id] = Offset(sc.x.toDouble(), sc.y.toDouble());
      } catch (e) {
        // Harita hazır değilse veya başka bir hata olursa yakala
      }
    }

    if (mounted) {
      setState(() {
        _overlayPositions.clear();
        _overlayPositions.addAll(newPositions);
      });
    }
    _updatingPositions = false;
  }

  void _onCameraMove(CameraPosition _) => _recomputeOverlayPositions();

  Future<void> _onCameraButton() async {
    // ...
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );
  }

  Future<void> _sharePhoto(String localPath) async {
    // ...
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giriş yapmalısın')));
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('posts/${user.uid}/$fileName');
    await ref.putFile(File(localPath));
    final url = await ref.getDownloadURL();

    final userSnap = await _db.child('users/${user.uid}').get();
    final userPhotoUrl = (userSnap.value is Map && (userSnap.value as Map).containsKey('photoUrl'))
        ? ((userSnap.value as Map)['photoUrl'] as String)
        : (user.photoURL ?? '');

    final postId = _db.child('posts').push().key!;
    await _db.child('posts/$postId').set({
      'uid': user.uid,
      'imageUrl': url,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'userPhotoUrl': userPhotoUrl,
      'createdAt': ServerValue.timestamp,
    });
  }

  Widget _buildBottomBar() {
    // ...
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _onCameraButton,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
                    ),
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
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundImage: NetworkImage(_friendAvatars[index]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _my, zoom: 14),
          // DEĞİŞİKLİK: Standart mavi noktayı kapatıyoruz
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          onMapCreated: (c) {
            _map = c;
            _recomputeOverlayPositions();
          },
          onCameraMove: _onCameraMove,
          onCameraIdle: _recomputeOverlayPositions,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          // YENİ: Oluşturduğumuz özel marker'ı haritaya ekliyoruz
          markers: _myLocationMarker != null ? {_myLocationMarker!} : {},
        ),

        // Fotoğraf overlay'leri (Değişiklik yok)
        ..._posts.map((p) {
          final pos = _overlayPositions[p.id];
          if (pos == null) return const SizedBox.shrink();
          const photoW = 110.0;
          const photoH = 160.0;
          const avatarR = 20.0;

          return Positioned(
            left: pos.dx - photoW / 2,
            top: pos.dy - photoH - (avatarR * 2) - 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: photoW,
                  height: photoH,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 4), color: Colors.black26)],
                      border: Border.all(color: Colors.white, width: 2.5)
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: p.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: avatarR,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: avatarR - 2.5,
                    backgroundImage: p.userPhotoUrl.isNotEmpty ? NetworkImage(p.userPhotoUrl) : null,
                    child: p.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                  ),
                ),
              ],
            ),
          );
        }),
        _buildBottomBar(),
      ],
    );
  }
}