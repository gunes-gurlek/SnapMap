import 'package:flutter/material.dart';

class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(int) onIconTap;
  final int currentIndex;

  const CustomTopBar({
    super.key,
    required this.onIconTap,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    // Önceki kodda titleSpacing: 0 eklemiştik, o kalmalı.
    // Eğer sildiyseniz tekrar ekleyin.
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0, // Bu satır taşma hatasını önlemek için çok önemli!
      title: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIcon(Icons.person_outline, 0),
            _buildIcon(Icons.menu_book_outlined, 1),

            // --- DEĞİŞİKLİKLER BURADA ---
            GestureDetector(
              onTap: () => onIconTap(2),
              child: Container(
                padding: const EdgeInsets.all(2), // Bu, mavi kenarlık için kalabilir
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: currentIndex == 2
                        ? Border.all(color: Colors.blue.shade300, width: 2.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                ),
                child: ClipOval(
                  child: Padding(
                    // 1. Değişiklik: İç boşluğu azaltarak logoya daha fazla yer açıyoruz.
                    padding: const EdgeInsets.all(2.0),
                    child: Image.asset(
                      'images/ust_bar_logo.png', // Logo dosyanın yolu
                      // 2. Değişiklik: Logonun daha belirgin olması için boyutunu artırıyoruz.
                      width: 40,
                      height: 40,
                      // 3. Değişiklik: Resmin daire şeklindeki alanı tam doldurmasını sağlıyoruz.
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            // --- DEĞİŞİKLİKLERİN SONU ---

            _buildIcon(Icons.people_alt_outlined, 3),
            _buildIcon(Icons.settings_outlined, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, int index) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => onIconTap(index),
      icon: Icon(
        icon,
        color: currentIndex == index ? Colors.blue : Colors.black54,
        size: 28,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}