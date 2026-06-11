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

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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

        // Susun daftar halaman yang terlihat
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

        // --- FIX LAYAR MERAH: PENGAMAN INDEKS ---
        int safeIndex = _selectedIndex;
        if (safeIndex >= visibleItems.length) {
          safeIndex = visibleItems.length - 1;
        }
        if (safeIndex < 0) safeIndex = 0;

        return Scaffold(
          // extendBody di-set true agar konten bisa 'menyelusup' di bawah navigasi yang melayang
          extendBody: true,
          body: IndexedStack(
            index: safeIndex,
            children: visiblePages,
          ),
          // Navigasi bawah dibungkus dengan Container agar bisa dimodifikasi ala 'Floating'
          bottomNavigationBar: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20), // Memberi jarak agar melayang
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30), // Ujung melengkung modern
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
                  elevation: 0, // Matikan elevasi bawaan karena sudah pakai shadow di Container
                  selectedItemColor: primaryRed,
                  unselectedItemColor: Colors.grey.shade400,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, height: 1.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                  currentIndex: safeIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
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
      // Tampilan saat item sedang dipilih (aktif)
      activeIcon: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: primaryRed.withOpacity(0.1), // Efek background transparan
          borderRadius: BorderRadius.circular(20), // Pill shape
        ),
        child: Icon(activeIcon, size: 26, color: primaryRed),
      ),
      label: label,
    );
  }
}