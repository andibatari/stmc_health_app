import 'package:flutter/material.dart';
import 'package:stmc_health_app/views/profile/profile_page.dart';

import '../main.dart';
import 'home/home_page.dart';
import 'home/lingkungan_page.dart';
import 'home/mcu_page.dart';

// Definisikan tipe callback
typedef TabChangeCallback = void Function(int index);

// Warna utama
const Color primaryRed = Color(0xFFC00000);

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => MainWrapperState();
}

class MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  // 🌟 FUNGSI BARU: Mengingat tab mana saja yang sudah pernah dibuka
  final Set<int> _initializedIndices = {0}; // Beranda (0) otomatis diizinkan

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _initializedIndices.add(index); // Catat bahwa tab ini sudah pernah diklik
    });
  }

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    return ValueListenableBuilder<UserState>(
      valueListenable: userStateNotifier,
      builder: (context, userState, child) {
        // 1. Logika penentuan menu
        final bool showLingkunganTab = userState.role == 'KARYAWAN';

        // Susun daftar halaman yang tersedia
        List<Widget> visiblePages = [
          HomePage(onTabChange: onItemTapped),
          const McuPage(),
        ];

        // Susun daftar item navigasi bawah
        List<BottomNavigationBarItem> visibleItems = [
          _buildNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Beranda'
          ),
          _buildNavItem(
              icon: Icons.monitor_heart_rounded,
              activeIcon: Icons.favorite_rounded,
              label: 'MCU'
          ),
        ];

        if (showLingkunganTab) {
          visiblePages.add(const LingkunganPage());
          visibleItems.add(_buildNavItem(
              icon: Icons.eco_outlined,
              activeIcon: Icons.eco_rounded,
              label: 'Lingkungan'
          ));
        }

        visiblePages.add(const ProfilePage());
        visibleItems.add(_buildNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profil'
        ));

        // --- PENGAMAN INDEKS ---
        int safeIndex = _selectedIndex;
        if (safeIndex >= visibleItems.length) {
          safeIndex = visibleItems.length - 1;
        }
        if (safeIndex < 0) safeIndex = 0;

        // 🌟 FUNGSI BARU: LAZY LOAD
        // Hanya render halaman jika indeksnya ada di dalam _initializedIndices
        _initializedIndices.add(safeIndex);
        List<Widget> lazyPages = [];
        for (int i = 0; i < visiblePages.length; i++) {
          if (_initializedIndices.contains(i)) {
            lazyPages.add(visiblePages[i]);
          } else {
            // Jika tab belum pernah diklik, biarkan kosong agar tidak memanggil API
            lazyPages.add(const SizedBox.shrink());
          }
        }

        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: safeIndex,
            children: lazyPages, // Gunakan halaman yang sudah dilindungi
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  selectedItemColor: primaryRed,
                  unselectedItemColor: Colors.grey.shade400,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, height: 1.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                  currentIndex: safeIndex,
                  onTap: onItemTapped, // Gunakan fungsi onItemTapped yang baru
                  items: visibleItems,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper untuk membuat item navigasi dengan gaya "Active Pill"
  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(icon, size: 26),
      ),
      activeIcon: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: primaryRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(activeIcon, size: 26, color: primaryRed),
      ),
      label: label,
    );
  }
}