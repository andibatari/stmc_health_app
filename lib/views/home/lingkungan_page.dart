import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/lingkungan_service.dart';

// --- DEKLARASI KONSTANTA DAN DATA MODEL ---
const Color primaryRed = Color(0xFFC00000);
const Color secondaryGreen = Color(0xFF388E3C); // Warna hijau untuk indikator aman

// Data Model untuk Pengukuran Lingkungan
class LingkunganData {
  final String location;
  final String subArea;
  final String department;
  final String unitKerja;
  final String tanggal;
  final String kesimpulan;
  final double cahayaLux;
  final int bisingDb;
  final double debuMgNm3;
  final String suhuBasah;
  final String suhuKering;
  final String suhuRadiasi;
  final String suhuIndoor;
  final String suhuOutdoor;
  final String rh; // Kelembaban Relatif (RH)

  LingkunganData({
    required this.location,
    required this.subArea,
    required this.department,
    required this.unitKerja,
    required this.tanggal,
    required this.kesimpulan,
    this.cahayaLux = 0,
    this.bisingDb = 0,
    this.debuMgNm3 = 0,
    this.suhuBasah = 'N/A',
    this.suhuKering = 'N/A',
    this.suhuRadiasi = 'N/A',
    this.suhuIndoor = 'N/A',
    this.suhuOutdoor = 'N/A',
    this.rh = 'N/A',
  });
}

// ========================================================
// LINGKUNGAN PAGE (Halaman Utama Pemantauan Lingkungan)
// ========================================================

class LingkunganPage extends StatefulWidget {
  const LingkunganPage({super.key});

  @override
  State<LingkunganPage> createState() => _LingkunganPageState();
}

class _LingkunganPageState extends State<LingkunganPage> {
  final LingkunganService _service = LingkunganService();
  List<LingkunganData> _lingkunganList = [];
  bool _isLoading = true;

  // --- VARIABEL STATE UNTUK FILTER (FIX ERROR) ---
  String _selectedLocation = 'Semua';
  String _selectedDepartemen = 'Semua';
  String _selectedUnitKerja = 'Semua';

  // Daftar pilihan dari database
  List<String> _locationOptions = ['Semua'];
  List<String> _deptOptions = ['Semua'];
  List<String> _unitOptions = ['Semua'];

  bool _showCahaya = true;
  bool _showBising = true;
  bool _showDebu = true;
  bool _showIklimKerja = true;

  @override
  void initState() {
    super.initState();
    // Gunakan WidgetsBinding agar context tersedia saat pertama kali load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }
  Future<void> _initializeData() async {
    await _loadFilters(); // Ambil daftar pilihan filter dulu
    await _loadData();    // Baru ambil data tabel
  }

  Future<void> _loadFilters() async {
    try {
      final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
      final filters = await _service.fetchFilters(userState.accessToken!);

      if (mounted) {
        setState(() {
          // Hanya memuat filter Area, Departemen, dan Unit
          _locationOptions = List<String>.from(filters['areas'] ?? ['Semua']);
          _deptOptions = List<String>.from(filters['departments'] ?? ['Semua']);
          _unitOptions = List<String>.from(filters['units'] ?? ['Semua']);
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat filter: $e");
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;

      // Pemanggilan API tanpa parameter month
      final dataRaw = await _service.fetchLingkungan(
        userState.accessToken!,
        location: _selectedLocation,
        department: _selectedDepartemen,
        unitKerja: _selectedUnitKerja,
      );

      if (mounted) {
        setState(() {
          _lingkunganList = dataRaw.map((json) => LingkunganData(
            location: json['location']?.toString() ?? '',
            subArea: json['sub_area']?.toString() ?? '',
            department: json['department']?.toString() ?? '',
            unitKerja: json['unit_kerja']?.toString() ?? '',
            tanggal: json['tanggal']?.toString() ?? '',
            kesimpulan: json['kesimpulan']?.toString() ?? '',
            cahayaLux: double.tryParse(json['cahaya_lux'].toString()) ?? 0,
            bisingDb: int.tryParse(json['bising_db'].toString()) ?? 0,
            debuMgNm3: double.tryParse(json['debu_mg_nm3'].toString()) ?? 0,
            suhuBasah: json['suhu_basah']?.toString() ?? 'N/A',
            suhuKering: json['suhu_kering']?.toString() ?? 'N/A',
            suhuRadiasi: json['suhu_radiasi']?.toString() ?? 'N/A',
            suhuIndoor: json['suhu_indoor']?.toString() ?? 'N/A',
            suhuOutdoor: json['suhu_outdoor']?.toString() ?? 'N/A',
            rh: json['rh']?.toString() ?? 'N/A',
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pemantauan Lingkungan"),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryRed))
            : RefreshIndicator(
          onRefresh: _initializeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildStatusCard(_lingkunganList),
                const SizedBox(height: 16),
                _buildFilterSection(),
                const SizedBox(height: 20),
                _buildDataTable(_lingkunganList),
                const SizedBox(height: 40),// Gunakan list hasil API
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterLabel("Filter Berdasarkan Area"),
          const SizedBox(height: 4),
          _buildDropdown(_locationOptions, _selectedLocation, (val) {
            setState(() => _selectedLocation = val!);
            _loadData();
          }, 'Pilih Area'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel("Departemen"),
                    const SizedBox(height: 4),
                    _buildDropdown(_deptOptions, _selectedDepartemen, (val) {
                      setState(() => _selectedDepartemen = val!);
                      _loadData();
                    }, 'Pilih Departemen'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel("Unit Kerja"),
                    const SizedBox(height: 4),
                    _buildDropdown(_unitOptions, _selectedUnitKerja, (val) {
                      setState(() => _selectedUnitKerja = val!);
                      _loadData();
                    }, 'Pilih Unit Kerja'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterLabel("Tampilkan Parameter"),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _buildCheckbox('Cahaya', _showCahaya, (val) => setState(() => _showCahaya = val!)),
              _buildCheckbox('Bising', _showBising, (val) => setState(() => _showBising = val!)),
              _buildCheckbox('Debu', _showDebu, (val) => setState(() => _showDebu = val!)),
              _buildCheckbox('Iklim', _showIklimKerja, (val) => setState(() => _showIklimKerja = val!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  // --- Helper Widget: STATUS CARD (Total Area Bermasalah) ---
  Widget _buildStatusCard(List<LingkunganData> data) {
    // Logika NAB: Bising > 85, Debu > 10, Cahaya > 100
    final problemCount = data.where((d) => d.debuMgNm3 > 10 || d.bisingDb > 85 || d.cahayaLux > 100).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Area Melebihi NAB', style: TextStyle(fontSize: 14, color: Colors.black54)),
          Text(
            problemCount.toString(),
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: problemCount > 0 ? primaryRed : secondaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> options, String selectedValue, ValueChanged<String?> onChanged, String hint) {
    String? effectiveValue = options.contains(selectedValue) ? selectedValue : (options.isNotEmpty ? options.first : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?>? onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24, width: 24,
          child: Checkbox(value: value, onChanged: onChanged, activeColor: primaryRed),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDataTable(List<LingkunganData> data) {
    if (data.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Tidak ada data ditemukan")));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('DETAIL PENGUKURAN', style: TextStyle(fontWeight: FontWeight.bold, color: primaryRed, fontSize: 14)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columnSpacing: 20,
              horizontalMargin: 12,
              columns: [
                const DataColumn(label: Text('NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('AREA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('SUB-AREA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                // TAMBAHKAN KOLOM DEPARTEMEN DAN UNIT KERJA DI SINI
                const DataColumn(label: Text('DEPARTEMEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('UNIT KERJA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('TANGGAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),

                if (_showCahaya) const DataColumn(label: Text('CAHAYA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showBising) const DataColumn(label: Text('BISING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showDebu) const DataColumn(label: Text('DEBU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showIklimKerja) ...[
                  const DataColumn(label: Text('S. BASAH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const DataColumn(label: Text('S. KERING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const DataColumn(label: Text('S. RADIASI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const DataColumn(label: Text('ISBB. INDOOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const DataColumn(label: Text('ISBB. OUTDOOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const DataColumn(label: Text('RH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const DataColumn(label: Text('KESIMPULAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ],
              rows: data.asMap().entries.map((entry) {
                int idx = entry.key;
                LingkunganData d = entry.value;

                // Helper untuk konversi suhu ke double agar bisa dibandingkan
                double parseSuhu(String val) => double.tryParse(val) ?? 0.0;

                return DataRow(cells: [
                  DataCell(Text((idx + 1).toString())),
                  DataCell(Text(d.location)),
                  DataCell(Text(d.subArea)),
                  // TAMBAHKAN DATA CELL DEPARTEMEN DAN UNIT KERJA DI SINI
                  DataCell(Text(d.department)),
                  DataCell(Text(d.unitKerja)),
                  DataCell(Text(d.tanggal)),

                  if (_showCahaya)
                    DataCell(Text(
                      "${d.cahayaLux} Lux",
                      style: TextStyle(
                          color: d.cahayaLux > 100 ? Colors.red : Colors.black,
                          fontWeight: d.cahayaLux > 100 ? FontWeight.bold : FontWeight.normal
                      ),
                    )),
                  if (_showBising)
                    DataCell(Text(
                      "${d.bisingDb} dB",
                      style: TextStyle(
                          color: d.bisingDb > 85 ? Colors.red : Colors.black,
                          fontWeight: d.bisingDb > 85 ? FontWeight.bold : FontWeight.normal
                      ),
                    )),
                  if (_showDebu)
                    DataCell(Text(
                      "${d.debuMgNm3} mg",
                      style: TextStyle(
                          color: d.debuMgNm3 > 10 ? Colors.red : Colors.black,
                          fontWeight: d.debuMgNm3 > 10 ? FontWeight.bold : FontWeight.normal
                      ),
                    )),
                  if (_showIklimKerja) ...[
                    DataCell(Text(d.suhuBasah)),
                    DataCell(Text(d.suhuKering)),
                    DataCell(Text(d.suhuRadiasi)),
                    DataCell(Text(
                      d.suhuIndoor,
                      style: TextStyle(
                          color: parseSuhu(d.suhuIndoor) > 27 ? Colors.red : Colors.black,
                          fontWeight: parseSuhu(d.suhuIndoor) > 27 ? FontWeight.bold : FontWeight.normal
                      ),
                    )),
                    DataCell(Text(d.suhuOutdoor)),
                    DataCell(Text(d.rh)),
                    DataCell(Text(d.kesimpulan)),
                  ],
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}