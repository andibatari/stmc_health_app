import 'package:flutter/material.dart';

import 'ketentuan_page.dart';

const Color primaryRed = Color(0xFFC00000);

class TentangAplikasiPage extends StatelessWidget {
  const TentangAplikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "TENTANG APLIKASI",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Logo dan Nama Aplikasi (DIPUSATKAN) ---
            Center( // <-- Bungkus Header dengan Center
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo-stmc.png',
                    height: 80,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "STMC",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryRed,
                    ),
                  ),
                  const Text(
                    "Semen Tonasa Medical Centre",
                    style: TextStyle(fontSize: 14, color: primaryRed),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "\"Together We Build a Better Future\"",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- Detail Aplikasi ---
            _buildDetailSection(
              title: "Deskripsi",
              content: "STMC Health adalah platform layanan kesehatan terintegrasi berbasis mobile yang dikembangkan untuk memfasilitasi manajemen Medical Check Up (MCU) dan pemantauan kondisi lingkungan kerja di lingkungan PT Semen Tonasa.",
            ),
            _buildDetailSection(
              title: "Versi",
              content: "1.0.0 (Build 20251205)",
            ),
            _buildDetailSection(
              title: "Pengembang",
              content: "Andi Batari Saudah Sajidah",
            ),
            _buildDetailSection(
              title: "Hak Cipta",
              content: "© 2025 Semen Tonasa Medical Centre. Semua hak dilindungi.",
            ),

            const SizedBox(height: 40),

            // Tombol untuk Legal atau Ketentuan
            Center(
              child: TextButton(
                onPressed: () {
                  // Navigasi ke halaman Ketentuan
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KetentuanPage()),
                  );
                },
                child: const Text(
                  'Ketentuan Penggunaan & Kebijakan Privasi',
                  style: TextStyle(
                      color: primaryRed,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600 // Tambahkan sedikit ketebalan
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper untuk membuat bagian detail yang rapi
  Widget _buildDetailSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryRed),
          ),
          const SizedBox(height: 5),
          Text(
            content,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

