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

// Update helper konversi data API
McuData _mcuDataFromApi(Map<String, dynamic> apiData) {
  return McuData(
    id: apiData['id'] ?? 0,
    checkUpNumber: _extractYear(apiData['tanggal_mcu']),
    noAntrean: apiData['no_antrean'] ?? '-', // Gunakan no_antrean
    date: apiData['tanggal_mcu'] ?? 'N/A',      // Gunakan tanggal_mcu
    doctorName: apiData['dokter'] ?? 'Menunggu',
    status: apiData['status'] ?? 'Scheduled',
    category: apiData['paket_mcu'] ?? 'Paket MCU', // Atau sesuaikan dengan field paket jika ada
    resume: apiData['resume'] is Map ? apiData['resume'] : null,
    downloadUrl: apiData['url_unduh_laporan'], // Mengambil URL merger PDF
    qrCodeId: apiData['qr_code_id'] ?? '-',
    checklistPoli: apiData['checklist_poli'] ?? [], // MAP DATA POLI DARI LARAVEL
  );
}

// Di dalam file mcu_page.dart
// Ikon dan warna status, sesuai dengan Gambar 5 (Admin Dashboard)
IconData _getStatusIcon(String status) {
  switch (status) {
    case 'Scheduled':
      return Icons.access_time;
    case 'Present':
      return Icons.check_circle_outline;
    case 'Canceled':
      return Icons.cancel_outlined;
    case 'Finished':
      return Icons.check_circle;
    default:
      return Icons.help_outline;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'Scheduled':
      return Colors.amber.shade700;
    case 'Present':
    case 'Finished':
      return Colors.green.shade600;
    case 'Canceled':
      return Colors.red.shade600;
    default:
      return Colors.grey;
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
      appBar: AppBar(
        title: const Text("Medical Check Up"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMcuButton(
              context,
              icon: Icons.assignment_outlined,
              label: "Pendaftaran MCU",
              // McuPendaftaranPage kini tidak lagi const
              targetPage: const McuPendaftaranPage(),
            ),
            const SizedBox(height: 14),
            _buildMcuButton(
              context,
              icon: Icons.info_outline,
              label: "Informasi Persiapan MCU",
              targetPage: const McuInformasiPage(),
            ),
            const SizedBox(height: 14),
            _buildMcuButton(
              context,
              icon: Icons.calendar_today_outlined,
              label: "Riwayat Jadwal MCU",
              targetPage: const McuJadwalPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMcuButton(BuildContext context,
      {required IconData icon,
        required String label,
        required Widget targetPage}) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetPage),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                const BoxDecoration(color: lightRed, shape: BoxShape.circle),
                child: Icon(icon, color: primaryRed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87))),
              const Icon(Icons.arrow_forward_ios, size: 16, color: primaryRed)
            ],
          ),
        ),
      ),
    );
  }
}


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
          const SnackBar(content: Text('Status Poli Anda Baru Saja Diperbarui! ✅'), backgroundColor: Colors.green),
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
      appBar: AppBar(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        title: Text(
          "Medical Check Up ${mcu.checkUpNumber}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- KARTU STATUS DAN DATA DASAR [KODE LAMA KAMU] ---
            Container(
              padding: const EdgeInsets.all(16),
              // ... [KODE UI KARTU STATUS & QR CODE TETAP SAMA] ...
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status MCU
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Status Jadwal:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Chip(
                        avatar: Icon(_getStatusIcon(mcu.status), size: 18, color: Colors.white),
                        label: Text(mcu.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: _getStatusColor(mcu.status),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // TAMPILKAN QR CODE DISINI (DITENGAHKAN)
                  if (mcu.qrCodeId.isNotEmpty && mcu.qrCodeId != '-')
                    Center( // Memastikan seluruh blok ini berada di tengah
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Memberikan dekorasi container putih dengan shadow halus agar QR lebih menonjol
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: mcu.qrCodeId,
                              version: QrVersions.auto,
                              size: 180.0,
                              gapless: true, // Menghilangkan garis putih antar modul QR agar lebih rapi
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Tunjukkan QR Code ini kepada petugas",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                  Text('Nomor Antrean: ${mcu.noAntrean}'), // Menampilkan C001
                  Text('Tanggal: ${mcu.date}'),
                  Text('Dokter: ${mcu.doctorName}'),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ==========================================================
            // FITUR BARU: DAFTAR POLI SAYA (REAL-TIME KEPADATAN)
            // ==========================================================
            if (isPresent) ...[
              const Text("Daftar Poli Saya", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 🌟 TEKS PERINGATAN BARU
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Mohon mengambil antrean HANYA saat Anda sudah berada di depan pintu Poli, agar panggilan Anda tidak bertabrakan dengan poli lain.",
                        style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              _buildChecklistPoli(mcu.checklistPoli),
              const SizedBox(height: 25),
            ],

            // --- TOMBOL UNDUH LAPORAN ---
            if (isFinished && mcu.downloadUrl != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleDownload(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Unduh Laporan PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

            if (isFinished) const SizedBox(height: 25),

            // --- RESUME DOKTER (Sesuai Gambar 6) ---
            if (isFinished)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Resume Dokter", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  // Detail Hasil Pemeriksaan di Kotak Merah
                  _buildResumeCard(resumeData),
                  const SizedBox(height: 15),
                  // Saran dan Kategori (Menggantikan Diagnosa/Rekomendasi)
                  const Text("Saran:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(saran),
                  const SizedBox(height: 10),
                  const Text("Kategori:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(kategori),
                ],
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text("Hasil MCU akan tersedia setelah status berubah menjadi Finished."),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- FUNGSI WIDGET CHECKLIST POLI ---
  Widget _buildChecklistPoli(List<dynamic> polis) {
    if (polis.isEmpty) {
      return const Text("Belum ada daftar poli yang ditetapkan.", style: TextStyle(color: Colors.grey));
    }

    return Column(
      children: polis.map((poli) {
        print("DEBUG DATA POLI: ${poli['nama_poli']} - Data: $poli");
        String namaPoli = poli['nama_poli'] ?? 'Poli';
        String statusPoli = poli['status'] ?? 'Pending'; // Pending, Waiting, Finished
        int totalAntreanPoli = poli['antrean_sekarang'] ?? 0; // Total orang yang antre
        int noAntreanAnda = int.tryParse(poli['no_antrean_poli']?.toString() ?? '0') ?? 0;
        int sisaAntrean = poli['sisa_antrean'] ?? 0;


        // 🌟 JIKA STATUSNYA WAITING, TAMPILKAN TIKET VIRTUAL
        if (statusPoli == 'Waiting' || statusPoli == 'Calling') {
          String noAntreanPoli = poli['no_antrean_poli']?.toString() ?? '-';

          // ✅ TAMBAHKAN PRINT INI UNTUK MELIHAT APA YANG DIKIRIM KE TIKET
          print("Kirim ke Tiket: Nama=$namaPoli, No=$noAntreanPoli, Sisa=${poli['sisa_antrean']}");

          return _buildVirtualTicket(namaPoli, sisaAntrean, noAntreanPoli,statusPoli);
        }

        // Logika Indikator Kepadatan 🔴🟡🟢
        Color indicatorColor = Colors.green;
        String statusText = '🟢 Kosong (Langsung Masuk)';
        IconData statusIcon = Icons.check_circle;

        if (statusPoli == 'Finished') {
          indicatorColor = Colors.green.shade600;
          statusText = '✅ Selesai Diperiksa';
          statusIcon = Icons.task_alt;
        } else if (totalAntreanPoli == 1) {
          indicatorColor = Colors.orange;
          statusText = '🟡 Antrean 1 Orang';
          statusIcon = Icons.people_alt;
        } else if (totalAntreanPoli > 1) {
          indicatorColor = Colors.red;
          statusText = '🔴 Antrean $totalAntreanPoli Orang';
          statusIcon = Icons.warning_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: indicatorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.medical_services_rounded, color: indicatorColor, size: 24),
            ),
            title: Text(
                namaPoli,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(statusIcon, size: 14, color: indicatorColor),
                  const SizedBox(width: 4),
                  Text(
                      statusText,
                      style: TextStyle(fontSize: 12, color: indicatorColor, fontWeight: FontWeight.w600)
                  ),
                ],
              ),
            ),
            trailing: _buildTrailingAction(poli['id_jadwal_poli'], statusPoli),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVirtualTicket(String namaPoli, int sisaAntrean, String noAntreanAnda,String statusPoli) {

    // Ubah String menjadi angka (int) terlebih dahulu agar bisa dibandingkan
    int noAntreanInt = int.tryParse(noAntreanAnda) ?? 0;

    // Jika database memberikan "0" tapi statusnya "Waiting", paksa tampilkan 1
    String displayAntrean = (noAntreanAnda == "0" || noAntreanAnda == "-") ? "1" : noAntreanAnda;

    // Jika sisa antrean negatif atau 0, tampilkan "0"
    String displaySisa = (sisaAntrean < 0) ? "0" : sisaAntrean.toString();

    // ✅ 2. LOGIKA STATUS BARU UNTUK BAGIAN BAWAH TIKET
    Color statusColor = (statusPoli == 'Calling') ? Colors.green.shade700 : Colors.grey;
    Color statusBgColor = (statusPoli == 'Calling') ? Colors.green.shade50 : Colors.grey.shade100;
    IconData statusIcon = (statusPoli == 'Calling') ? Icons.volume_up_rounded : Icons.access_time;
    String statusText = (statusPoli == 'Calling') ? "Status: GILIRAN ANDA! Silakan Masuk..." : "Status: Menunggu Panggilan...";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryRed.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header Tiket
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: primaryRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Center(
              child: Text("TIKET ANTREAN",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ),

          // Body Tiket
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text("ANDA BERADA DI ANTREAN", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(namaPoli.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),

                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text("No. Antrean Anda", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(displayAntrean, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryRed)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.grey.shade300),
                    Column(
                      children: [
                        const Text("Sisa Antrean Depan", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(displaySisa, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Text(statusText, style: TextStyle(fontWeight: FontWeight.w600, color: statusColor)),
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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          const SizedBox(height: 4),
          const Text("Selesai", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return ElevatedButton(
      onPressed: _isCheckingIn ? null : () => _handleAmbilAntrean(idJadwalPoli),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Ambil\nAntrean', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil mengambil antrean poli!')));
      _refreshMcuDataFromServer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  // Fungsi untuk handle download PDF
  void _handleDownload(BuildContext context) async {
    final Uri url = Uri.parse(currentMcu.downloadUrl!);

    try {
      // Menampilkan pesan loading
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menyiapkan dokumen...')));

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // Helper untuk membuat kartu detail (KOTAK MERAH)
  Widget _buildResumeCard(Map<String, dynamic> data) {
    if (data.isEmpty) return const Text("Data pemeriksaan belum diinput.");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: data.entries.map((e) => _buildResumeItem(e.key, e.value.toString())).toList(),
      ),
    );
  }

  // Helper untuk format baris Resume Item
  Widget _buildResumeItem(String label, String value) {
    // Karena ini adalah item daftar pemeriksaan, indikator warna diabaikan
    // agar tampilan lebih menyerupai daftar poin dari template PDF (Gambar 2)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text('$label:', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          Expanded(
            flex: 5,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
        ? 'Pilih Tanggal Ajukan Jadwal'
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
        _assignedDoctor = "Gagal memuat jadwal dokter";
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
        const SnackBar(content: Text('Pilih tanggal dan paket terlebih dahulu.'), backgroundColor: Colors.red),
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
        SnackBar(content: Text(result['message'] ?? 'Berhasil mengajukan jadwal'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Pengajuan gagal.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    // Logika Kunci Tombol: Tombol tidak bisa diklik jika submit berjalan, sedang cek data, kuota 0, atau tanggal belum dipilih
    bool isButtonDisabled = _isSubmitting || _isCheckingDate || _sisaKuota <= 0 || _selectedDate == null || _selectedPaketId == null;

    return ValueListenableBuilder<UserState>(
      valueListenable: userStateNotifier,
      builder: (context, userState, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: primaryRed,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text("PENDAFTARAN MCU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Identitas Pasien
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: userState.displayText ?? 'Data Pengguna Tidak Ditemukan',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(color: Colors.grey)),
                      disabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(color: Colors.grey)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),

                // Pilih Paket
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _isLoadingPaket
                      ? const Center(child: LinearProgressIndicator(color: primaryRed))
                      : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Pilih Paket MCU',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    ),
                    value: _selectedPaketId,
                    items: _paketOptions.map((Map<String, String> paket) {
                      return DropdownMenuItem<String>(value: paket['id'], child: Text(paket['name']!));
                    }).toList(),
                    onChanged: (String? newValue) => setState(() => _selectedPaketId = newValue),
                  ),
                ),

                // Pilih Tanggal
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10.0)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_dateText, style: TextStyle(fontSize: 16, color: _selectedDate == null ? Colors.grey[700] : Colors.black87)),
                        const Icon(Icons.calendar_today, color: primaryRed),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Informasi Dokter & Sisa Kuota
                Padding(
                  padding: const EdgeInsets.only(bottom: 25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Dokter Piket',
                          hintText: _assignedDoctor ?? 'Dokter ditentukan setelah tanggal dipilih',
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(color: Colors.grey)),
                          disabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10.0)), borderSide: BorderSide(color: Colors.grey)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                      ),

                      // INFORMASI KUOTA MERAH / HIJAU
                      if (_selectedDate != null && !_isCheckingDate)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            _sisaKuota > 0
                                ? '✅ Sisa Kuota Hari Ini: $_sisaKuota Orang'
                                : '❌ Kuota Hari Ini Penuh! Silakan pilih tanggal lain.',
                            style: TextStyle(
                              color: _sisaKuota > 0 ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Tombol Kirim (Warnanya jadi abu-abu jika Kuota 0)
                Container(
                  decoration: BoxDecoration(
                      color: isButtonDisabled ? Colors.grey.shade400 : primaryRed,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isButtonDisabled ? null : () => _submitPendaftaran(context, userState),
                      borderRadius: BorderRadius.circular(10.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isSubmitting || _isCheckingDate
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Kirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (!_isSubmitting && !_isCheckingDate) const SizedBox(width: 8),
                            if (!_isSubmitting && !_isCheckingDate) const Icon(Icons.send, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========================================================
// HALAMAN LAINNYA
// ========================================================

class McuInformasiPage extends StatelessWidget {
  const McuInformasiPage({super.key});

  List<TextSpan> _parseBoldText(String text) {
    final List<TextSpan> spans = [];
    // Regex untuk mencari teks yang dikelilingi oleh **
    final RegExp exp = RegExp(r'(\*\*[^\*]+\*\*)');

    int lastMatchEnd = 0;

    for (final match in exp.allMatches(text)) {
      // 1. Tambahkan teks non-bold (normal) sebelum match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(text: text.substring(lastMatchEnd, match.start)),
        );
      }

      // 2. Tambahkan teks bold
      // Hapus ** di awal dan akhir string bold
      final String boldText = text.substring(match.start + 2, match.end - 2);
      spans.add(
        TextSpan(
          text: boldText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

      lastMatchEnd = match.end;
    }

    // 3. Tambahkan teks non-bold sisa string
    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(text: text.substring(lastMatchEnd)),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar kustom sesuai desain informasi
      appBar: AppBar(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "INFORMASI",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Panduan Persiapan MCU",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryRed),
            ),
            const SizedBox(height: 15),

            // Teks panduan disusun menggunakan RichText atau string yang diformat
            _buildPanduanItem(
                '1. Puasa (Wajib untuk Tes Darah):',
                'Umumnya, Anda diwajibkan puasa **8 - 12 jam** sebelum pengambilan sampel darah. Yang tidak diperbolehkan saat puasa: Makan, minum selain air putih, merokok, mengunyah permen karet.',
                subPoin: [
                  '**Waktu Puasa:** Umumnya, Anda diwajibkan puasa **8 - 12 jam** sebelum pengambilan sampel darah.',
                  '**Yang tidak diperbolehkan saat puasa:** Makan, minum selain air putih, merokok, mengunyah permen karet.',
                  '**Yang diperbolehkan saat puasa:** Minum air putih tawar.'
                ]
            ),
            _buildPanduanItem(
              '2. Istirahat Cukup:',
              'Pastikan tidur nyenyak min **7 - 8 jam** pada malam sebelum hari pemeriksaan.',
            ),
            _buildPanduanItem(
              '3. Hindari Aktivitas Fisik Berat:',
              'Hindari olahraga berat atau aktivitas fisik yang intens minimal 24 jam sebelum pemeriksaan.',
            ),
            _buildPanduanItem(
              '4. Hindari Konsumsi Alkohol dan Merokok:',
              'Hindari konsumsi alkohol minimal 24-48 jam sebelum MCU, karena dapat memengaruhi fungsi hati dan kadar gula darah.',
                subPoin: [
                  'Usahakan tidak merokok minimal beberapa jam sebelum pemeriksaan, terutama sebelum tes fungsi paru-paru.',
                ]
            ),
            _buildPanduanItem(
              '5. Penggunaan Obat-obatan dan Suplemen:',
              'Informasikan kepada dokter atau staf medis mengenai semua obat-obatan resep, obat bebas, vitamin, dan suplemen herbal yang sedang Anda konsumsi. Beberapa obat dapat memengaruhi hasil tes.',
            ),
            _buildPanduanItem(
              '6. Pakaian yang Nyaman:',
              'Gunakan pakaian yang mudah dilepas dan tidak ketat.',
            ),
            _buildPanduanItem(
              '7. Untuk Wanita:',
              'Jika Anda akan menjalani tes urine atau papsmear, disarankan untuk tidak melakukan pemeriksaan saat sedang menstruasi. Umumnya, tes urine sebaiknya dilakukan 3 hari setelah menstruasi berakhir.',
            ),
            _buildPanduanItem(
              '8. Datang Tepat Waktu:',
              'Usahakan datang 15-30 menit lebih awal dari jadwal yang ditentukan untuk proses administrasi dan persiapan awal.',
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi pembantu untuk memformat poin-poin panduan
  Widget _buildPanduanItem(String title, String content, {List<String>? subPoin}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selalu tampilkan Judul
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          // 2. Tampilkan Content (Teks Utama/Pendahuluan) dengan RichText
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: RichText( // <-- Gunakan RichText untuk memproses bold pada content
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black, // Pastikan warna teks normal tetap hitam
                  fontSize: 14.0,
                  height: 1.5,
                ),
                children: _parseBoldText(content), // Gunakan fungsi parsing bold
              ),
            ),
          ),

          // 3. Tampilkan Sub Poin jika ada (dengan RichText)
          if (subPoin != null)
            ...subPoin.map((text) => Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(height: 1.5)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14.0,
                            height: 1.5
                        ),
                        children: _parseBoldText(text), // Parsing bold di subPoin
                      ),
                    ),
                  ),
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
    // DefaultTabController digunakan untuk mengelola TabBar dan TabBarView
    return DefaultTabController(
      length: 2, // Jumlah tab: Aktif dan Selesai
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            "JADWAL MCU",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.white, // Garis bawah tab berwarna putih
            labelColor: Colors.white, // Warna teks tab aktif
            unselectedLabelColor: Colors.white70, // Warna teks tab tidak aktif
            tabs: const [
              Tab(text: "Aktif"),
              Tab(text: "Selesai"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Konten untuk Tab "Aktif"
            JadwalAktifList(),
            // Konten untuk Tab "Selesai"
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

  const JadwalCard({
    super.key,
    required this.data, // Menerima objek data
    this.borderColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell( // Tambahkan InkWell di sini
      onTap: () {
        // Navigasi ke halaman detail dengan membawa data
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) {
            globalActiveJadwalId = data.id; //
            return McuDetailPage(mcu: data);
          }),
        );
      },
      child: Card(
        // [Kode Card tetap sama, gunakan data.checkUpNumber, data.date, dll.]
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medical Check Up ${data.checkUpNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: primaryRed),
                  const SizedBox(width: 5),
                  Text(data.date, style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Dokter : ${data.doctorName}',
                style: const TextStyle(color: Colors.black87),
              ),
            ],
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

    if (!userState.isLoggedIn || userState.accessToken == null) {
      return const Center(child: Text("Silakan login untuk melihat jadwal."));
    }

    // ✅ BUNGKUS DENGAN PENERIMA REMOTE CONTROL
    return ValueListenableBuilder<int>(
      valueListenable: globalRefreshTrigger,
      builder: (context, triggerValue, child) {

        return FutureBuilder<Map<String, dynamic>>(
          future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
          builder: (context, snapshot) {
            // ... (Isi kode di bawah ini biarkan sama persis seperti aslinya) ...
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryRed));
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: Gagal koneksi (Network/Timeout). ${snapshot.error.toString()}"));
            }
            if (snapshot.data == null || snapshot.data!['success'] == false) {
              return Center(child: Text("Gagal memuat jadwal: ${snapshot.data?['message'] ?? 'Error otorisasi/API.'}"));
            }

            final List activeJadwalsApi = snapshot.data!['aktif'] ?? [];
            final List<McuData> activeJadwals = activeJadwalsApi.map((data) => _mcuDataFromApi(data)).toList();

            if (activeJadwals.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Tidak ada jadwal MCU aktif saat ini.", style: TextStyle(color: Colors.black54)),
              ));
            }

            return ListView(
              padding: const EdgeInsets.only(top: 8.0),
              children: activeJadwals.map((data) => JadwalCard(
                data: data,
                borderColor: primaryRed,
              )).toList(),
            );
          },
        );
      },
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

    if (!userState.isLoggedIn || userState.accessToken == null) {
      return Container(); // Tidak menampilkan apa-apa jika belum login
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryRed));
        }
        // Penanganan error sama dengan di atas
        if (snapshot.hasError) {
          return Center(child: Text("Error: Gagal koneksi (Network/Timeout). ${snapshot.error.toString()}"));
        }
        if (snapshot.data == null || snapshot.data!['success'] == false) {
          return Center(child: Text("Gagal memuat riwayat: ${snapshot.data?['message'] ?? 'Error otorisasi/API.'}"));
        }

        final List finishedJadwalsApi = snapshot.data!['selesai'] ?? [];
        final List<McuData> finishedJadwals = finishedJadwalsApi.map((data) => _mcuDataFromApi(data)).toList();

        if (finishedJadwals.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Tidak ada riwayat jadwal MCU yang selesai.", style: TextStyle(color: Colors.black54)),
          ));
        }

        return ListView(
          padding: const EdgeInsets.only(top: 8.0),
          children: finishedJadwals.map((data) => JadwalCard(
            data: data,
            borderColor: Colors.grey.shade300,
          )).toList(),
        );
      },
    );
  }
}

// Widget baru untuk fetching data MCU Aktif di Beranda
class JadwalMedicalCheckUpAPI extends StatelessWidget {
  const JadwalMedicalCheckUpAPI({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
    final McuService mcuService = McuService();

    if (!userState.isLoggedIn || userState.accessToken == null) {
      return const SizedBox.shrink();
    }

    // ✅ BUNGKUS DENGAN PENERIMA REMOTE CONTROL
    return ValueListenableBuilder<int>(
      valueListenable: globalRefreshTrigger,
      builder: (context, triggerValue, child) {

        // 🔄 SETIAP KALI SINYAL DITERIMA, FUTUREBUILDER INI AKAN DI-RELOAD
        return FutureBuilder<Map<String, dynamic>>(
          future: mcuService.fetchRiwayatJadwal(accessToken: userState.accessToken!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: CircularProgressIndicator(color: primaryRed, strokeWidth: 2),
              ));
            }

            if (snapshot.hasError || snapshot.data == null || snapshot.data!['success'] == false) {
              return const SizedBox.shrink();
            }

            final List activeJadwalsApi = snapshot.data!['aktif'] ?? [];

            if (activeJadwalsApi.isEmpty) {
              return const SizedBox.shrink();
            }

            final activeMcu = _mcuDataFromApi(activeJadwalsApi.first);
            globalActiveJadwalId = activeMcu.id;

            return JadwalMedicalCheckUp(activeMcu: activeMcu);
          },
        );
      },
    );
  }
}

// Widget untuk menampilkan Jadwal MCU Aktif di Beranda
class JadwalMedicalCheckUp extends StatelessWidget {
  final McuData activeMcu; // Menerima satu objek jadwal aktif

  // Constructor menerima data jadwal aktif
  const JadwalMedicalCheckUp({super.key, required this.activeMcu});

  @override
  Widget build(BuildContext context) {
    // Gunakan activeMcu secara langsung
    final activeSchedule = activeMcu;

    // Karena widget ini hanya dipanggil jika ada jadwal aktif,
    // kita bisa mengasumsikan hasActiveSchedule true
    final hasActiveSchedule = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Jadwal Medical Check Up',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            InkWell(
              onTap: () {
                // TODO: Navigasi ke halaman utama Jadwal MCU (McuJadwalPage)
                // Ini harus memicu Bottom Nav ke tab MCU
              },
              child: const Icon(Icons.arrow_forward_ios, size: 16.0, color: primaryRed),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Widget Jadwal Aktif
        InkWell(
          onTap: () {
            // Navigasi ke halaman detail saat kartu di Beranda diklik
            if (hasActiveSchedule) {
              Navigator.push(
                context,
                // Navigasi ke detail dengan data MCU aktif
                MaterialPageRoute(builder: (_) {
                  globalActiveJadwalId = activeSchedule.id; //
                  return McuDetailPage(mcu: activeSchedule);
                }),
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              // Gunakan warna border berdasarkan status Scheduled
              border: Border.all(color: primaryRed, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5.0, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Check Up ${activeSchedule.checkUpNumber}',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Divider(height: 15, color: Colors.transparent),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: primaryRed),
                    SizedBox(width: 8),
                    Text(activeSchedule.date, style: TextStyle(fontSize: 14.0)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text('Dokter: ', style: TextStyle(fontSize: 14.0, color: Colors.black54)),
                    Text(activeSchedule.doctorName, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
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

