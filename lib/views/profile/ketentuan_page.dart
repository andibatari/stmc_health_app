import 'package:flutter/material.dart';

const Color primaryRed = Color(0xFFC00000);

const String termsOfServiceContent = """
## KETENTUAN PENGGUNAAN (Terms of Service)

**1. Penerimaan Ketentuan:**
Dengan mengakses atau menggunakan aplikasi STMC Health, Anda setuju untuk terikat oleh Ketentuan Penggunaan ini. Jika Anda tidak setuju dengan ketentuan ini, mohon untuk tidak menggunakan Aplikasi.

**2. Penggunaan Aplikasi:**
Aplikasi ini ditujukan hanya untuk karyawan PT Semen Tonasa dan staf yang berwenang untuk mengakses data kesehatan pribadi (MCU) dan data pemantauan lingkungan kerja. Dilarang menyalahgunakan, memodifikasi, atau mendistribusikan konten Aplikasi.

**3. Data Kesehatan Pribadi (MCU):**
Data yang diakses melalui Aplikasi (jadwal, status, dan hasil MCU) adalah data rahasia medis. Pengguna bertanggung jawab penuh atas keamanan kredensial akunnya. STMC Medical Centre menjaga kerahasiaan data sesuai standar medis dan hukum yang berlaku.
""";

const String privacyPolicyContent = """
## KEBIJAKAN PRIVASI (Privacy Policy)

**1. Pengumpulan Informasi:**
Kami mengumpulkan informasi yang Anda berikan saat login (Nomor SAP, NIK, Nama) dan data medis yang dihasilkan dari prosedur MCU. Kami juga mengumpulkan data lingkungan (misalnya, lokasi, suhu, kebisingan).

**2. Penggunaan Informasi:**
Informasi digunakan secara eksklusif untuk:
- Memfasilitasi pendaftaran dan penjadwalan MCU.
- Menyediakan hasil dan resume medis yang akurat.
- Memantau dan melaporkan kondisi lingkungan kerja.

**3. Perlindungan Data:**
Data kesehatan Anda disimpan di server internal yang aman. Data medis tidak akan dibagikan kepada pihak ketiga tanpa persetujuan tertulis dari Anda, kecuali diwajibkan oleh hukum.

""";

List<TextSpan> _parseBoldText(String text) {
  final List<TextSpan> spans = []; final RegExp exp = RegExp(r'(\*\*[^\*]+\*\*)'); int lastMatchEnd = 0;
  for (final match in exp.allMatches(text)) {
    if (match.start > lastMatchEnd) spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
    final String boldText = text.substring(match.start + 2, match.end - 2);
    spans.add(TextSpan(text: boldText, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)));
    lastMatchEnd = match.end;
  }
  if (lastMatchEnd < text.length) spans.add(TextSpan(text: text.substring(lastMatchEnd)));
  return spans;
}

class KetentuanPage extends StatelessWidget {
  const KetentuanPage({super.key});

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0.5, title: const Text("KETENTUAN PENGGUNAAN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(termsOfServiceContent),
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.black12)),
              _buildSection(privacyPolicyContent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String rawText) {
    final lines = rawText.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('##')) {
          return Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(trimmedLine.substring(2).trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryRed, letterSpacing: 0.5)));
        } else if (trimmedLine.isEmpty) {
          return const SizedBox(height: 12);
        } else {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.6, fontWeight: FontWeight.w500), children: _parseBoldText(trimmedLine))));
        }
      }).toList(),
    );
  }
}