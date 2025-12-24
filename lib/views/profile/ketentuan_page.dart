import 'package:flutter/material.dart';

const Color primaryRed = Color(0xFFC00000);

// --- KONTEN TEKS LENGKAP ---

const String termsOfServiceContent = """
## KETENTUAN PENGGUNAAN (Terms of Service)

**1. Penerimaan Ketentuan:**
Dengan mengakses atau menggunakan aplikasi STMC Health, Anda setuju untuk terikat oleh Ketentuan Penggunaan ini. Jika Anda tidak setuju dengan ketentuan ini, mohon untuk tidak menggunakan Aplikasi.

**2. Penggunaan Aplikasi:**
Aplikasi ini ditujukan hanya untuk karyawan PT Semen Tonasa dan staf yang berwenang untuk mengakses data kesehatan pribadi (MCU) dan data pemantauan lingkungan kerja (K3L). Dilarang menyalahgunakan, memodifikasi, atau mendistribusikan konten Aplikasi.

**3. Data Kesehatan Pribadi (MCU):**
Data yang diakses melalui Aplikasi (jadwal, status, dan hasil MCU) adalah data rahasia medis. Pengguna bertanggung jawab penuh atas keamanan kredensial akunnya. STMC Medical Centre menjaga kerahasiaan data sesuai standar medis dan hukum yang berlaku.
""";

const String privacyPolicyContent = """
## KEBIJAKAN PRIVASI (Privacy Policy)

**1. Pengumpulan Informasi:**
Kami mengumpulkan informasi yang Anda berikan saat login (Nomor SAP, NIK, Nama) dan data medis yang dihasilkan dari prosedur MCU. Kami juga mengumpulkan data lingkungan (misalnya, lokasi, suhu, kebisingan) untuk tujuan K3L.

**2. Penggunaan Informasi:**
Informasi digunakan secara eksklusif untuk:
* Memfasilitasi pendaftaran dan penjadwalan MCU.
* Menyediakan hasil dan resume medis yang akurat.
* Memantau dan melaporkan kondisi lingkungan kerja sesuai regulasi K3L.

**3. Perlindungan Data:**
Data kesehatan Anda disimpan di server internal yang aman. Data medis tidak akan dibagikan kepada pihak ketiga tanpa persetujuan tertulis dari Anda, kecuali diwajibkan oleh hukum.

**4. Data Lingkungan:**
Data pemantauan lingkungan dikumpulkan dan digunakan untuk analisis internal K3L dan peningkatan keselamatan kerja di PT Semen Tonasa. Data ini tidak terikat langsung dengan identitas pribadi pasien.
""";


// --- FUNGSI PARSING BOLD (DIPERLUKAN UNTUK KETENTUAN) ---
List<TextSpan> _parseBoldText(String text) {
  final List<TextSpan> spans = [];
  final RegExp exp = RegExp(r'(\*\*[^\*]+\*\*)');
  int lastMatchEnd = 0;

  for (final match in exp.allMatches(text)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
    }
    final String boldText = text.substring(match.start + 2, match.end - 2);
    spans.add(
      TextSpan(
        text: boldText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    lastMatchEnd = match.end;
  }
  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastMatchEnd)));
  }
  return spans;
}


// ========================================================
// KETENTUAN PAGE (Halaman Detail ToS/Privacy)
// ========================================================

class KetentuanPage extends StatelessWidget {
  const KetentuanPage({super.key});

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
          "KETENTUAN PENGGUNAAN",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Konten Ketentuan Penggunaan
            _buildSection(termsOfServiceContent),
            const SizedBox(height: 30),

            // Konten Kebijakan Privasi
            _buildSection(privacyPolicyContent),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Helper untuk memformat teks (memproses Markdown dan menggunakan RichText)
  Widget _buildSection(String rawText) {
    final lines = rawText.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('##')) {
          // Header (misalnya, "## KETENTUAN PENGGUNAAN")
          return Padding(
            padding: const EdgeInsets.only(top: 15.0, bottom: 8.0),
            child: Text(
              trimmedLine.substring(2).trim(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primaryRed
              ),
            ),
          );
        } else if (trimmedLine.isEmpty) {
          return const SizedBox(height: 10);
        } else {
          // Paragraf atau poin (Memproses sintaks **bold**)
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.5,
                ),
                // Menggunakan fungsi parsing bold
                children: _parseBoldText(trimmedLine),
              ),
            ),
          );
        }
      }).toList(),
    );
  }
}