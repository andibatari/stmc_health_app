import 'package:flutter/material.dart';
import 'package:stmc_health_app/views/profile/profile_page.dart';

import '../main.dart';
import 'home/home_page.dart';
import 'home/lingkungan_page.dart';
import 'home/mcu_page.dart';// Import main.dart untuk UserState


// Definisikan tipe callback
typedef TabChangeCallback = void Function(int index);

// Warna utama
const Color primaryRed = Color(0xFFC00000);

class MainWrapper extends StatefulWidget {
  // Tambahkan property untuk mengakses UserState
  // Ambil userStateNotifier dari context (ValueNotifier di MyApp)
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

  // Definisikan _pages di sini agar dapat mengakses 'onItemTapped'
  late final List<Widget> _pages = [
    // Teruskan onItemTapped. Data User akan diakses melalui ValueListenableBuilder
    HomePage(onTabChange: onItemTapped),
    McuPage(),
    const LingkunganPage(),
    const ProfilePage()
  ];

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    return ValueListenableBuilder<UserState>(
      valueListenable: userStateNotifier,
      builder: (context, userState, child) {
        // 1. Logika penentuan menu
        final bool showLingkunganTab = userState.role == 'KARYAWAN';

        List<Widget> visiblePages = [
          HomePage(onTabChange: onItemTapped),
          const McuPage(),
        ];
        List<BottomNavigationBarItem> visibleItems = [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          const BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'MCU'),
        ];

        if (showLingkunganTab) {
          visiblePages.add(const LingkunganPage());
          visibleItems.add(const BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Lingkungan'));
        }

        visiblePages.add(const ProfilePage());
        visibleItems.add(const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'));

        // --- FIX LAYAR MERAH: PENGAMAN INDEKS ---
        // Jika _selectedIndex lebih besar atau sama dengan jumlah item yang tersedia,
        // kita paksa balik ke index terakhir (Profile) atau 0 (Beranda).
        int safeIndex = _selectedIndex;
        if (safeIndex >= visibleItems.length) {
          safeIndex = visibleItems.length - 1; // Pindah ke tab Profile (paling kanan)
        }
        if (safeIndex < 0) safeIndex = 0;

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: visiblePages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: primaryRed,
            unselectedItemColor: Colors.grey,
            currentIndex: safeIndex, // Gunakan safeIndex
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: visibleItems,
          ),
        );
      },
    );
  }
}

