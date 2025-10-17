import 'package:flutter/material.dart';
import 'map_feed_screen.dart'; // Harita ekranınızın yolu
import 'widgets/custom_top_bar.dart'; // Az önce oluşturduğumuz widget

// Diğer sayfalarınızı buraya import edin (varsayımsal)
// import 'package:heytaksi/screens/profile_screen.dart';
// import 'package:heytaksi/screens/settings_screen.dart';


class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 2; // Başlangıçta harita sayfası (index 2) aktif olsun

  // İkonlara tıklandığında gösterilecek sayfaların listesi
  final List<Widget> _pages = [
    const Center(child: Text('Profil Sayfası')),   // Index 0
    const Center(child: Text('Menü Sayfası')),    // Index 1
    const MapFeedScreen(),                        // Index 2 (Harita)
    const Center(child: Text('Arkadaşlar Sayfası')), // Index 3
    const Center(child: Text('Ayarlar Sayfası')),  // Index 4
  ];

  void _onIconTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: true sayesinde body, appbar'ın arkasına uzanır.
      // Bu, haritanın tam ekran görünmesi için kritik.
      extendBodyBehindAppBar: true,
      appBar: CustomTopBar(
        currentIndex: _currentIndex,
        onIconTap: _onIconTapped,
      ),
      body: _pages[_currentIndex],
    );
  }
}