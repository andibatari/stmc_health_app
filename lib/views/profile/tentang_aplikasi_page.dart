import 'package:flutter/material.dart';
import 'ketentuan_page.dart';

const Color primaryRed = Color(0xFFC00000);

class TentangAplikasiPage extends StatelessWidget {
  const TentangAplikasiPage({super.key});

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0.5, title: const Text("TENTANG APLIKASI", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]), child: Image.asset('assets/images/logo-stmc.png', height: 80)),
                  const SizedBox(height: 20),
                  const Text("STMC HEALTH", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryRed, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  const Text("Semen Tonasa Medical Centre", style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: const Text("Version 1.0.0 (Build 20251224)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(title: "Deskripsi", content: "STMC Health adalah platform layanan kesehatan terintegrasi berbasis mobile yang dikembangkan untuk memfasilitasi manajemen Medical Check Up (MCU) dan pemantauan kondisi lingkungan kerja di PT Semen Tonasa."),
                  const Divider(color: Colors.black12, height: 30),
                  _buildDetailSection(title: "Pengembang", content: "Andi Batari Saudah Sajidah"),
                  const Divider(color: Colors.black12, height: 30),
                  _buildDetailSection(title: "Hak Cipta", content: "© 2025 Semen Tonasa Medical Centre.\nSemua hak dilindungi."),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KetentuanPage())),
              child: const Text('Ketentuan Penggunaan & Kebijakan Privasi', style: TextStyle(color: primaryRed, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.5)),
      ],
    );
  }
}