import 'dart:async';
import 'dart:convert';

import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Asumsi path file main.dart berada dua level di atas.
import '../../main.dart';
import '../../services/mcu_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stmc_health_app/global_notification.dart';

const Color primaryRed = Color(0xFFC00000);
const Color lightRed = Color(0xFFFBECEC);

// Definisikan data model untuk Jadwal MCU
class McuData {
  final int id;
  final String checkUpNumber;
  final String date;
  final String doctorName;
  final String status;
  final String category;
  final String noAntrean;
  final Map<String, dynamic>? resume;
  final String? downloadUrl;
  final String qrCodeId;
  final List<dynamic> checklistPoli;

  McuData({
    required this.id,
    required this.checkUpNumber,
    required this.date,
    required this.doctorName,
    required this.status,
    required this.category,
    required this.noAntrean,
    this.resume,
    this.downloadUrl,
    required this.qrCodeId,
    this.checklistPoli = const [],
  });
}

// ALAT BANTU UNTUK MENGAMBIL TAHUN DARI TEKS TANGGAL
String _extractYear(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return DateTime.now().year.toString();

  // Mencari 4 angka berurutan di dalam teks (contoh menemukan "2026" dari "22 Mei 2026")
  final match = RegExp(r'\d{4}').firstMatch(dateStr);
  return match != null ? match.group(0)! : DateTime.now().year.toString();
}

McuData _mcuDataFromApi(Map<String, dynamic> apiData) {
  // 🔥 1. FUNGSI PEMBONGKAR OBJEK DOKTER DARI LARAVEL
  String parseDoctorName(dynamic dokterData) {
    if (dokterData == null) return 'Dokter Piket (Menunggu)';
    // Jika bentuknya teks biasa
    if (dokterData is String) return dokterData;
    // Jika bentuknya Objek/Map dari relasi Laravel
    if (dokterData is Map<String, dynamic>) {
      return dokterData['nama_lengkap'] ?? dokterData['nama'] ?? 'Dokter Piket (Menunggu)';
    }
    return 'Dokter Piket (Menunggu)';
  }

  // 🔥 2. FUNGSI PEMBONGKAR OBJEK PAKET (Pencegahan error untuk kategori)
  String parsePaketName(dynamic paketData) {
    if (paketData == null) return 'Paket MCU';
    if (paketData is String) return paketData;
    if (paketData is Map<String, dynamic>) {
      return paketData['nama_paket'] ?? 'Paket MCU';
    }
    return 'Paket MCU';
  }

  return McuData(
    id: apiData['id'] ?? 0,
    checkUpNumber: _extractYear(apiData['tanggal_mcu']),
    noAntrean: apiData['no_antrean'] ?? '-',
    date: apiData['tanggal_mcu'] ?? 'N/A',

    // 👇 MENGGUNAKAN FUNGSI PEMBONGKAR DI SINI 👇
    doctorName: parseDoctorName(apiData['dokter']),
    category: parsePaketName(apiData['paket_mcu']),

    status: apiData['status'] ?? 'Scheduled',
    resume: apiData['resume'] is Map ? apiData['resume'] : null,
    downloadUrl: apiData['url_unduh_laporan'],
    qrCodeId: apiData['qr_code_id'] ?? '-',
    checklistPoli: apiData['checklist_poli'] ?? [],
  );
}

// Ikon dan warna status, sesuai dengan Gambar 5 (Admin Dashboard)
IconData _getStatusIcon(String status) {
  switch (status) {
    case 'Scheduled': return Icons.schedule_rounded;
    case 'Present': return Icons.how_to_reg_rounded;
    case 'Canceled': return Icons.cancel_rounded;
    case 'Finished': return Icons.task_alt_rounded;
    default: return Icons.help_outline_rounded;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'Scheduled': return Colors.amber.shade700;
    case 'Present':
    case 'Finished': return Colors.green.shade600;
    case 'Canceled': return Colors.red.shade600;
    default: return Colors.grey;
  }
}

// ========================================================
// MCU PAGE - Halaman Utama Menu
// ========================================================

class McuPage extends StatelessWidget {
  const McuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Background elegan
      appBar: AppBar(
        title: const Text("Medical Check Up", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMcuButton(
              context,
              icon: Icons.edit_document,
              label: "Pendaftaran MCU",
              targetPage: const McuPendaftaranPage(),
            ),
            const SizedBox(height: 16),
            _buildMcuButton(
              context,
              icon: Icons.lightbulb_rounded,
              label: "Informasi Persiapan MCU",
              targetPage: const McuInformasiPage(),
            ),
            const SizedBox(height: 16),
            _buildMcuButton(
              context,
              icon: Icons.history_rounded,
              label: "Riwayat Jadwal MCU",
              targetPage: const McuJadwalPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMcuButton(BuildContext context, {required IconData icon, required String label, required Widget targetPage}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => targetPage));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: const BoxDecoration(color: lightRed, shape: BoxShape.circle),
                  child: Icon(icon, color: primaryRed, size: 26),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.2)),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================
// MCU DETAIL PAGE
// ========================================================

class McuDetailPage extends StatefulWidget {
  final McuData mcu;
  const McuDetailPage({super.key, required this.mcu});

  @override
  State<McuDetailPage> createState() => _McuDetailPageState();
}

class _McuDetailPageState extends State<McuDetailPage> {
  // Tambahkan state isLoading untuk proses tombol check-in
  bool _isCheckingIn = false;
  late McuData currentMcu; // Menyimpan data MCU yang bisa berubah nilainya

  // TAMBAHKAN FUNGSI INITSTATE
  @override
  void initState() {
    super.initState();

    // Inisialisasi data awal dari halaman sebelumnya
    currentMcu = widget.mcu;
    globalActiveJadwalId = currentMcu.id;

    // ✅ PASANG TELINGA KE REMOTE CONTROL GLOBAL
    globalRefreshTrigger.addListener(_refreshMcuDataFromServer);
  }

  @override
  void dispose() {
    // ✅ CABUT TELINGA SAAT KELUAR HALAMAN
    globalRefreshTrigger.removeListener(_refreshMcuDataFromServer);
    super.dispose();
  }

  // FUNGSI RAHASIA JALAN SULTAN: Ambil data segar langsung dari database via API
  Future<void> _refreshMcuDataFromServer() async {
    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final mcuService = McuService();

    final result = await mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!);
    if (result['success'] == true) {
      final List activeListApi = result['aktif'] ?? [];
      // Cari data saya di dalam list terbaru
      final myFreshData = activeListApi.firstWhere(
            (item) => item['id'] == currentMcu.id,
        orElse: () => null,
      );

      if (myFreshData != null && mounted) {
        setState(() {
          // Ganti data lama dengan data baru yang segar dari server
          currentMcu = _mcuDataFromApi(myFreshData);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status Poli Anda Baru Saja Diperbarui! ✅', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mcu = currentMcu;
    //Lakukan proses konversi (casting) secara eksplisit untuk memberi tahu Dart bahwa itu memang Map
    final Map<String, dynamic> resumeData = (mcu.resume?['hasil'] as Map<String, dynamic>?) ?? {};
    final String saran = mcu.resume?['saran'] ?? '-';
    final String kategori = mcu.resume?['kategori'] ?? '-';
    final bool isFinished = mcu.status == 'Finished';

    // Asumsi: Checklist hanya muncul jika pasien sudah "Present" (Hadir di RS)
    final bool isPresent = mcu.status == 'Present';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: Text("MCU ${mcu.checkUpNumber}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        centerTitle: true,
      ),
      // 🌟 1. BUNGKUS BODY DENGAN RefreshIndicator
      body: RefreshIndicator(
        color: primaryRed,
        onRefresh: _refreshMcuDataFromServer, // Panggil fungsi refresh milikmu
        // 🌟 2. TAMBAHKAN physics AGAR BISA DITARIK MESKIPUN KONTENNYA SEDIKIT
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🌟 3. TAMBAHKAN BANNER INFORMASI REFRESH DI SINI
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.swipe_down_rounded, color: Colors.orange.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Tarik layar ke bawah (Refresh) sesekali untuk memperbarui status antrean Anda.",
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w700, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // --- KARTU STATUS DAN DATA DASAR ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status MCU
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: _getStatusColor(mcu.status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(mcu.status), size: 18, color: _getStatusColor(mcu.status)),
                          const SizedBox(width: 8),
                          Text(mcu.status.toUpperCase(), style: TextStyle(color: _getStatusColor(mcu.status), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // TAMPILKAN QR CODE DISINI (DITENGAHKAN)
                    if (mcu.qrCodeId.isNotEmpty && mcu.qrCodeId != '-')
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade200, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, spreadRadius: 2)],
                            ),
                            child: QrImageView(
                              data: mcu.qrCodeId,
                              version: QrVersions.auto,
                              size: 180.0,
                              gapless: true,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text("Tunjukkan QR Code ini kepada petugas", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 30),
                        ],
                      ),

                    const Divider(color: Colors.black12, height: 1),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('No. Antrean', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 13)), Text(mcu.noAntrean, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryRed))]),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tanggal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 13)), Text(mcu.date, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87))]),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Dokter', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 13)), Expanded(child: Text(mcu.doctorName, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87), overflow: TextOverflow.ellipsis))]),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // ==========================================================
              // FITUR BARU: DAFTAR POLI SAYA (REAL-TIME KEPADATAN)
              // ==========================================================
              if (isPresent) ...[
                const Text("DAFTAR POLI SAYA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1.0)),
                const SizedBox(height: 16),

                // 🌟 TEKS PERINGATAN BARU
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_rounded, color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Mohon mengambil antrean HANYA saat Anda sudah berada di depan pintu Poli, agar panggilan Anda tidak bertabrakan dengan poli lain.",
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade800, fontWeight: FontWeight.w700, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildChecklistPoli(mcu.checklistPoli),
                const SizedBox(height: 30),
              ],

              // --- TOMBOL UNDUH LAPORAN ---
              if (isFinished && mcu.downloadUrl != null)
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDownload(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 24),
                    label: const Text('UNDUH LAPORAN PDF', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                    ),
                  ),
                ),

              if (isFinished) const SizedBox(height: 35),

              // --- RESUME DOKTER ---
              if (isFinished)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("RESUME MEDIS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1.0)),
                    const SizedBox(height: 16),
                    // Detail Hasil Pemeriksaan di Kotak Merah
                    _buildResumeCard(resumeData),
                    const SizedBox(height: 20),

                    // Saran dan Kategori (Menggantikan Diagnosa/Rekomendasi)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("KATEGORI KESEHATAN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.0)),
                          const SizedBox(height: 4),
                          Text(kategori, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryRed)),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.black12, height: 1)),
                          const Text("SARAN MEDIS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.0)),
                          const SizedBox(height: 6),
                          Text(saran, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87, height: 1.5)),
                        ],
                      ),
                    )
                  ],
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 30.0, bottom: 30),
                    child: Text("Hasil MCU akan tersedia setelah status Finished.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FUNGSI WIDGET CHECKLIST POLI ---
  Widget _buildChecklistPoli(List<dynamic> polis) {
    if (polis.isEmpty) {
      return const Text("Belum ada daftar poli yang ditetapkan.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600));
    }

    return Column(
      // 🌟 PERBAIKAN: Menambahkan Type-Casting <Widget>
      children: polis.map<Widget>((poli) {
        String namaPoli = poli['nama_poli'] ?? 'Poli';
        String statusPoli = poli['status'] ?? 'Pending'; // Pending, Waiting, Finished
        int totalAntreanPoli = poli['antrean_sekarang'] ?? 0; // Total orang yang antre
        int sisaAntrean = poli['sisa_antrean'] ?? 0;

        // 🌟 JIKA STATUSNYA WAITING, TAMPILKAN TIKET VIRTUAL
        if (statusPoli == 'Waiting' || statusPoli == 'Calling') {
          String noAntreanPoli = poli['no_antrean_poli']?.toString() ?? '-';
          return _buildVirtualTicket(namaPoli, sisaAntrean, noAntreanPoli, statusPoli);
        }

        // Logika Indikator Kepadatan 🔴🟡🟢
        Color indicatorColor = Colors.green;
        String statusText = '🟢 Kosong (Langsung Masuk)';
        IconData statusIcon = Icons.check_circle_rounded;

        if (statusPoli == 'Finished') {
          indicatorColor = Colors.green.shade600;
          statusText = '✅ Selesai Diperiksa';
          statusIcon = Icons.task_alt_rounded;
        } else if (totalAntreanPoli == 1) {
          indicatorColor = Colors.orange.shade700;
          statusText = '🟡 Antrean 1 Orang';
          statusIcon = Icons.people_alt_rounded;
        } else if (totalAntreanPoli > 1) {
          indicatorColor = Colors.red.shade700;
          statusText = '🔴 Antrean $totalAntreanPoli Orang';
          statusIcon = Icons.warning_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: indicatorColor.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: indicatorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.medical_information_rounded, color: indicatorColor, size: 24),
            ),
            title: Text(namaPoli, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(statusIcon, size: 14, color: indicatorColor),
                  const SizedBox(width: 6),
                  Text(statusText, style: TextStyle(fontSize: 12, color: indicatorColor, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            trailing: _buildTrailingAction(poli['id_jadwal_poli'], statusPoli),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVirtualTicket(String namaPoli, int sisaAntrean, String noAntreanAnda, String statusPoli) {
    // Jika database memberikan "0" tapi statusnya "Waiting", paksa tampilkan 1
    String displayAntrean = (noAntreanAnda == "0" || noAntreanAnda == "-") ? "1" : noAntreanAnda;

    // Jika sisa antrean negatif atau 0, tampilkan "0"
    String displaySisa = (sisaAntrean < 0) ? "0" : sisaAntrean.toString();

    // ✅ LOGIKA STATUS
    Color statusColor = (statusPoli == 'Calling') ? Colors.green.shade700 : Colors.grey.shade700;
    Color statusBgColor = (statusPoli == 'Calling') ? Colors.green.shade50 : Colors.grey.shade100;
    IconData statusIcon = (statusPoli == 'Calling') ? Icons.campaign_rounded : Icons.hourglass_top_rounded;
    String statusText = (statusPoli == 'Calling') ? "GILIRAN ANDA! Silakan Masuk" : "Menunggu Panggilan...";

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Header Tiket
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            width: double.infinity,
            decoration: const BoxDecoration(color: primaryRed, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: const Center(
              child: Text("TIKET ANTREAN VIRTUAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 12)),
            ),
          ),
          // Body Tiket
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text("RUANGAN POLI", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(namaPoli.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text("ANTREAN ANDA", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.0)),
                        const SizedBox(height: 4),
                        Text(displayAntrean, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: primaryRed, height: 1.1)),
                      ],
                    ),
                    Container(height: 60, width: 2, color: Colors.grey.shade200),
                    Column(
                      children: [
                        const Text("SISA DEPAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.0)),
                        const SizedBox(height: 4),
                        Text(displaySisa, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.orange.shade600, height: 1.1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Status Bottom
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusIcon, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(statusText, style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 13), textAlign: TextAlign.center),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TOMBOL AKSI CARA A (Ambil Antrean) ---
  Widget _buildTrailingAction(int? idJadwalPoli, String statusPoli) {
    if (statusPoli == 'Finished') {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          SizedBox(height: 4),
          Text("Selesai", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      );
    }

    return ElevatedButton(
      onPressed: _isCheckingIn ? null : () => _handleAmbilAntrean(idJadwalPoli),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Ambil', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }

  // --- LOGIKA TOMBOL AMBIL ANTREAN ---
  Future<void> _handleAmbilAntrean(int? idJadwalPoli) async {
    if (idJadwalPoli == null) return;

    setState(() => _isCheckingIn = true);

    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final mcuService = McuService();

    // Panggil API untuk "Check-In" ke Poli
    final result = await mcuService.checkInPoli(idJadwalPoli: idJadwalPoli, accessToken: userState.accessToken!);
    if (!mounted) return;
    setState(() => _isCheckingIn = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil mengambil antrean poli!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      _refreshMcuDataFromServer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  // Fungsi untuk handle download PDF
  void _handleDownload(BuildContext context) async {
    final Uri url = Uri.parse(currentMcu.downloadUrl!);

    try {
      // Menampilkan pesan loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyiapkan dokumen...', style: TextStyle(fontWeight: FontWeight.bold)), behavior: SnackBarBehavior.floating));

      // Memeriksa apakah URL bisa dibuka
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Membuka di browser/PDF viewer eksternal
        );
      } else {
        throw 'Tidak dapat membuka laporan. Pastikan koneksi internet stabil.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  // Helper untuk membuat kartu detail (KOTAK MERAH)
  Widget _buildResumeCard(Map<String, dynamic> data) {
    if (data.isEmpty) return const Text("Data pemeriksaan belum diinput.", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryRed, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        // 🌟 PERBAIKAN: Menambahkan Type-Casting <Widget>
        children: data.entries.map<Widget>((e) => _buildResumeItem(e.key, e.value.toString())).toList(),
      ),
    );
  }

  // Helper untuk format baris Resume Item
  Widget _buildResumeItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 5,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ========================================================
// MCU PENDAFTARAN PAGE (Menggunakan User State)
// ========================================================

class McuPendaftaranPage extends StatefulWidget {
  const McuPendaftaranPage({super.key});

  @override
  State<McuPendaftaranPage> createState() => _McuPendaftaranPageState();
}

class _McuPendaftaranPageState extends State<McuPendaftaranPage> {
  DateTime? _selectedDate;
  String? _selectedPaketId;
  String? _assignedDoctor;

  List<Map<String, String>> _paketOptions = [];
  bool _isLoadingPaket = true;
  final McuService _mcuService = McuService();
  bool _isSubmitting = false;

  // --- STATE BARU UNTUK CEK KUOTA ---
  bool _isCheckingDate = false;
  int _sisaKuota = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPaketData();
    });
  }

  Future<void> _loadPaketData() async {
    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    if (userState.accessToken != null) {
      try {
        final pakets = await _mcuService.fetchPaketMcu(accessToken: userState.accessToken!);
        setState(() {
          _paketOptions = pakets;
          _isLoadingPaket = false;
        });
      } catch (e) {
        setState(() => _isLoadingPaket = false);
      }
    }
  }

  String get _dateText {
    return _selectedDate == null
        ? 'Pilih Tanggal Jadwal'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
  }

  // --- FUNGSI BARU MEMANGGIL API LARAVEL ---
  Future<void> _checkKetersediaanData(DateTime date) async {
    setState(() {
      _isCheckingDate = true;
      _assignedDoctor = "Mengecek sistem...";
    });

    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final String formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final result = await _mcuService.checkKetersediaan(tanggal: formattedDate, accessToken: userState.accessToken!);

    if (!mounted) return;

    setState(() {
      _isCheckingDate = false;
      if (result['success'] == true) {
        _assignedDoctor = result['dokter'];
        _sisaKuota = result['sisa_kuota'] ?? 0;
      } else {
        _assignedDoctor = "Gagal memuat jadwal";
        _sisaKuota = 0; // Jika error, kunci tombol dengan membuat kuota 0
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryRed,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Panggil API saat tanggal dipilih
      _checkKetersediaanData(picked);
    }
  }

  void _submitPendaftaran(BuildContext context, UserState userState) async {
    if (_selectedDate == null || _selectedPaketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi form!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final String formattedDate = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    final result = await _mcuService.submitJadwal(
      tanggalMcu: formattedDate,
      paketMcu: _selectedPaketId!,
      accessToken: userState.accessToken!,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Berhasil mengajukan jadwal', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Pengajuan gagal.', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey),
    prefixIcon: Icon(icon, color: primaryRed.withOpacity(0.7), size: 22),
    filled: true, fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    // Logika Kunci Tombol: Tombol tidak bisa diklik jika submit berjalan, sedang cek data, kuota 0, atau tanggal belum dipilih
    bool isDisabled = _isSubmitting || _isCheckingDate || _sisaKuota <= 0 || _selectedDate == null || _selectedPaketId == null;

    return ValueListenableBuilder<UserState>(
      valueListenable: userStateNotifier,
      builder: (context, userState, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
            title: const Text("PENDAFTARAN MCU", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identitas Pasien
                const Text("Identitas Pasien", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: userState.displayText ?? '-',
                  enabled: false,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 15),
                  decoration: _inputDec("Nama & Identitas", Icons.person_rounded),
                ),
                const SizedBox(height: 24),

                // Pilih Paket
                const Text("Paket Medical Check Up", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                _isLoadingPaket
                    ? const LinearProgressIndicator(color: primaryRed)
                    : DropdownButtonFormField<String>(
                  decoration: _inputDec("Pilih Paket MCU", Icons.medical_services_rounded),
                  value: _selectedPaketId,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryRed),
                  items: _paketOptions.map((Map<String, String> paket) {
                    return DropdownMenuItem<String>(value: paket['id'], child: Text(paket['name']!, style: const TextStyle(fontWeight: FontWeight.w800)));
                  }).toList(),
                  onChanged: (String? newValue) => setState(() => _selectedPaketId = newValue),
                ),
                const SizedBox(height: 24),

                // Pilih Tanggal
                const Text("Tanggal Pelaksanaan", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Icon(Icons.edit_calendar_rounded, color: primaryRed.withOpacity(0.7), size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_dateText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _selectedDate == null ? Colors.grey : Colors.black87))),
                        const Icon(Icons.arrow_drop_down_circle_rounded, color: primaryRed),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Informasi Dokter & Sisa Kuota
                const Text("Dokter & Ketersediaan Kuota", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey(_assignedDoctor), // ⬅️ KUNCI AJAIB: Memaksa Flutter merefresh form ini saat nama dokter berubah
                  initialValue: _assignedDoctor ?? 'Menunggu Tanggal...',
                  enabled: false,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 15),
                  decoration: _inputDec("Dokter Piket", Icons.medical_services_rounded),
                ),

                // INFORMASI KUOTA MERAH / HIJAU
                if (_selectedDate != null && !_isCheckingDate)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: _sisaKuota > 0 ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _sisaKuota > 0 ? Colors.green.shade200 : Colors.red.shade200)),
                    child: Row(
                      children: [
                        Icon(_sisaKuota > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: _sisaKuota > 0 ? Colors.green.shade700 : Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_sisaKuota > 0 ? 'Sisa Kuota: $_sisaKuota Pasien' : 'Kuota Penuh! Pilih tanggal lain.', style: TextStyle(color: _sisaKuota > 0 ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w900, fontSize: 13))),
                      ],
                    ),
                  ),
                const SizedBox(height: 45),

                // Tombol Kirim (Warnanya jadi abu-abu jika Kuota 0)
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isDisabled ? null : () => _submitPendaftaran(context, userState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSubmitting || _isCheckingDate
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text("KIRIM PENGAJUAN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========================================================
// MCU INFORMASI PAGE
// ========================================================

class McuInformasiPage extends StatelessWidget {
  const McuInformasiPage({super.key});

  List<TextSpan> _parseBoldText(String text) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'(\*\*[^\*]+\*\*)');
    int lastMatchEnd = 0;

    for (final match in exp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      final String boldText = text.substring(match.start + 2, match.end - 2);
      spans.add(TextSpan(text: boldText, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text("INFORMASI MCU", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Panduan Persiapan Medis", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryRed)),
            const SizedBox(height: 24),
            _buildPanduanItem('1. Aturan Puasa (Wajib):', 'Umumnya, Anda diwajibkan puasa **8 - 12 jam** sebelum pengambilan sampel darah.', subPoin: ['**Waktu Puasa:** 8 - 12 jam sebelum pemeriksaan.', '**Dilarang:** Makan, minum (kecuali air putih tawar), merokok, permen karet.']),
            _buildPanduanItem('2. Istirahat Cukup:', 'Pastikan tidur nyenyak min **7 - 8 jam** pada malam sebelum hari pemeriksaan.'),
            _buildPanduanItem('3. Hindari Aktivitas Berat:', 'Hindari olahraga berat atau aktivitas fisik intens minimal 24 jam sebelum pemeriksaan.'),
            _buildPanduanItem('4. Hindari Alkohol & Merokok:', 'Hindari konsumsi alkohol 24-48 jam. Usahakan tidak merokok minimal beberapa jam sebelum tes fungsi paru.'),
            _buildPanduanItem('5. Obat & Suplemen:', 'Informasikan kepada dokter mengenai semua obat resep, vitamin, dan suplemen herbal yang sedang dikonsumsi.'),
            _buildPanduanItem('6. Pakaian yang Nyaman:', 'Gunakan pakaian yang mudah dilepas dan tidak ketat untuk memudahkan proses lab.'),
            _buildPanduanItem('7. Khusus Wanita:', 'Jika akan menjalani tes urine/papsmear, disarankan tidak sedang menstruasi (minimal 3 hari setelahnya).'),
            _buildPanduanItem('8. Kehadiran:', 'Usahakan datang **15-30 menit lebih awal** dari jadwal yang ditentukan.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPanduanItem(String title, String content, {List<String>? subPoin}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
          const SizedBox(height: 10),
          RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14.0, height: 1.6, fontWeight: FontWeight.w600), children: _parseBoldText(content))),
          if (subPoin != null)
            ...subPoin.map((text) => Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(height: 1.6, color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13.0, height: 1.6, fontWeight: FontWeight.w600), children: _parseBoldText(text)),
                    ),
                  )
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }
}

// ========================================================
// MCU JADWAL PAGE (TAB VIEW)
// ========================================================

class McuJadwalPage extends StatelessWidget {
  const McuJadwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          title: const Text("RIWAYAT MCU", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: primaryRed,
            indicatorWeight: 4,
            labelColor: primaryRed,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.w900),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: "Aktif"),
              Tab(text: "Selesai"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            JadwalAktifList(),
            JadwalSelesaiList(),
          ],
        ),
      ),
    );
  }
}

// Helper Widget untuk kartu jadwal
class JadwalCard extends StatelessWidget {
  final McuData data;
  final Color borderColor;

  const JadwalCard({super.key, required this.data, this.borderColor = Colors.grey});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            globalActiveJadwalId = data.id;
            Navigator.push(context, MaterialPageRoute(builder: (_) => McuDetailPage(mcu: data)));
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('MCU ${data.checkUpNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87))),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey)
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: primaryRed),
                    const SizedBox(width: 10),
                    Text(data.date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87))
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.medical_services_rounded, size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(child: Text(data.doctorName, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget untuk daftar jadwal yang AKTIF
class JadwalAktifList extends StatelessWidget {
  const JadwalAktifList({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final McuService mcuService = McuService();

    if (!userState.isLoggedIn) return const Center();

    return ValueListenableBuilder<int>(
        valueListenable: globalRefreshTrigger,
        builder: (context, val, child) => FutureBuilder<Map<String, dynamic>>(
            future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryRed));
              if (snapshot.hasError || snapshot.data == null) return const Center();

              // 🌟 PERBAIKAN: Menambahkan Type-Casting <Widget>
              final list = (snapshot.data!['aktif'] ?? []).map<McuData>((d) => _mcuDataFromApi(d)).toList();

              if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Tidak ada jadwal aktif.", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey, fontSize: 16))]));

              // 🌟 PERBAIKAN: Menambahkan Type-Casting <Widget> pada children
              return ListView(padding: const EdgeInsets.only(top: 24, bottom: 24), children: list.map<Widget>((d) => JadwalCard(data: d, borderColor: primaryRed.withOpacity(0.5))).toList());
            }
        )
    );
  }
}

// Widget untuk daftar jadwal yang SELESAI
class JadwalSelesaiList extends StatelessWidget {
  const JadwalSelesaiList({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final McuService mcuService = McuService();

    if (!userState.isLoggedIn) return const Center();

    return FutureBuilder<Map<String, dynamic>>(
        future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryRed));
          if (snapshot.hasError || snapshot.data == null) return const Center();

          final list = (snapshot.data!['selesai'] ?? []).map<McuData>((d) => _mcuDataFromApi(d)).toList();

          if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Tidak ada riwayat.", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey, fontSize: 16))]));

          // 🌟 PERBAIKAN: Menambahkan Type-Casting <Widget> pada children
          return ListView(padding: const EdgeInsets.only(top: 24, bottom: 24), children: list.map<Widget>((d) => JadwalCard(data: d, borderColor: Colors.transparent)).toList());
        }
    );
  }
}

// ========================================================
// API JADWAL BERANDA
// ========================================================

class JadwalMedicalCheckUpAPI extends StatelessWidget {
  const JadwalMedicalCheckUpAPI({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final McuService mcuService = McuService();

    if (!userState.isLoggedIn || userState.accessToken == null) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: globalRefreshTrigger,
      builder: (context, triggerValue, child) {
        return FutureBuilder<Map<String, dynamic>>(
          future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(color: primaryRed, strokeWidth: 2)));
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!['success'] == false) return const SizedBox.shrink();

            final List activeJadwalsApi = snapshot.data!['aktif'] ?? [];
            if (activeJadwalsApi.isEmpty) return const SizedBox.shrink();

            final activeMcu = _mcuDataFromApi(activeJadwalsApi.first);
            globalActiveJadwalId = activeMcu.id;

            return JadwalMedicalCheckUp(activeMcu: activeMcu);
          },
        );
      },
    );
  }
}

class JadwalMedicalCheckUp extends StatelessWidget {
  final McuData activeMcu;

  const JadwalMedicalCheckUp({super.key, required this.activeMcu});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Jadwal MCU Aktif', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w900, color: Colors.black87)),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16.0, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 16),

        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            globalActiveJadwalId = activeMcu.id;
            Navigator.push(context, MaterialPageRoute(builder: (_) => McuDetailPage(mcu: activeMcu)));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: primaryRed.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.04), blurRadius: 15.0, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Medical Check Up ${activeMcu.checkUpNumber}', style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w900, color: Colors.black87))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)), child: Text(activeMcu.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800)))
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.black12, height: 1)),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_month_rounded, size: 20, color: primaryRed)),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Tanggal Pelaksanaan", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(activeMcu.date, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w800, color: Colors.black87)),
                    ])
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}