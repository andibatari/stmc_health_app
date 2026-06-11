import 'package:flutter/material.dart';
import '../../global_notification.dart';
import '../../main.dart';
import '../../services/lingkungan_service.dart';

const Color primaryRed = Color(0xFFC00000);
const Color secondaryGreen = Color(0xFF2E7D32);

class LingkunganData {
  final String location, subArea, department, unitKerja, tanggal, kesimpulan;
  final double cahayaLux, debuMgNm3; final int bisingDb;
  final String suhuBasah, suhuKering, suhuRadiasi, suhuIndoor, suhuOutdoor, rh;

  LingkunganData({required this.location, required this.subArea, required this.department, required this.unitKerja, required this.tanggal, required this.kesimpulan, this.cahayaLux = 0, this.bisingDb = 0, this.debuMgNm3 = 0, this.suhuBasah = 'N/A', this.suhuKering = 'N/A', this.suhuRadiasi = 'N/A', this.suhuIndoor = 'N/A', this.suhuOutdoor = 'N/A', this.rh = 'N/A'});
}

class LingkunganPage extends StatefulWidget {
  const LingkunganPage({super.key});
  @override State<LingkunganPage> createState() => _LingkunganPageState();
}

class _LingkunganPageState extends State<LingkunganPage> {
  final LingkunganService _service = LingkunganService();
  List<LingkunganData> _lingkunganList = []; bool _isLoading = true;
  String _selectedLocation = 'Semua', _selectedDepartemen = 'Semua', _selectedUnitKerja = 'Semua';
  List<String> _locationOptions = ['Semua'], _deptOptions = ['Semua'], _unitOptions = ['Semua'];
  bool _showCahaya = true, _showBising = true, _showDebu = true, _showIklimKerja = true;

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { _initializeData(); }); globalRefreshTrigger.addListener(_loadData); }
  @override void dispose() { globalRefreshTrigger.removeListener(_loadData); super.dispose(); }

  Future<void> _initializeData() async { await _loadFilters(); await _loadData(); }

  Future<void> _loadFilters() async {
    try {
      final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
      final filters = await _service.fetchFilters(userState.accessToken!);
      if (mounted) setState(() { _locationOptions = List<String>.from(filters['areas'] ?? ['Semua']); _deptOptions = List<String>.from(filters['departments'] ?? ['Semua']); _unitOptions = List<String>.from(filters['units'] ?? ['Semua']); });
    } catch (e) { debugPrint("Gagal filter: $e"); }
  }

  Future<void> _loadData() async {
    if (!mounted) return; setState(() => _isLoading = true);
    try {
      final userState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
      final dataRaw = await _service.fetchLingkungan(userState.accessToken!, location: _selectedLocation, department: _selectedDepartemen, unitKerja: _selectedUnitKerja);
      if (mounted) setState(() {
        _lingkunganList = dataRaw.map((json) => LingkunganData(location: json['location']?.toString() ?? '', subArea: json['sub_area']?.toString() ?? '', department: json['department']?.toString() ?? '', unitKerja: json['unit_kerja']?.toString() ?? '', tanggal: json['tanggal']?.toString() ?? '', kesimpulan: json['kesimpulan']?.toString() ?? '', cahayaLux: double.tryParse(json['cahaya_lux'].toString()) ?? 0, bisingDb: int.tryParse(json['bising_db'].toString()) ?? 0, debuMgNm3: double.tryParse(json['debu_mg_nm3'].toString()) ?? 0, suhuBasah: json['suhu_basah']?.toString() ?? 'N/A', suhuKering: json['suhu_kering']?.toString() ?? 'N/A', suhuRadiasi: json['suhu_radiasi']?.toString() ?? 'N/A', suhuIndoor: json['suhu_indoor']?.toString() ?? 'N/A', suhuOutdoor: json['suhu_outdoor']?.toString() ?? 'N/A', rh: json['rh']?.toString() ?? 'N/A')).toList();
        _isLoading = false;
      });
    } catch (e) { if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); } }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Pemantauan Lingkungan", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), backgroundColor: primaryRed, foregroundColor: Colors.white, centerTitle: true, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: primaryRed)) : RefreshIndicator(
        color: primaryRed, onRefresh: _initializeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(_lingkunganList),
              const SizedBox(height: 24),
              _buildFilterSection(),
              const SizedBox(height: 30),
              _buildDataTable(_lingkunganList),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(List<LingkunganData> data) {
    final problemCount = data.where((d) => d.debuMgNm3 > 10 || d.bisingDb > 85 || d.cahayaLux > 100).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Area Melebihi NAB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54)), SizedBox(height: 4), Text("Nilai Ambang Batas", style: TextStyle(fontSize: 10, color: Colors.grey))]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: problemCount > 0 ? primaryRed.withOpacity(0.1) : secondaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(problemCount.toString(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: problemCount > 0 ? primaryRed : secondaryGreen))),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("FILTER DATA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          _buildFilterLabel("Area"), const SizedBox(height: 6),
          _buildDropdown(_locationOptions, _selectedLocation, (val) { setState(() => _selectedLocation = val!); _loadData(); }, 'Pilih Area'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFilterLabel("Departemen"), const SizedBox(height: 6), _buildDropdown(_deptOptions, _selectedDepartemen, (val) { setState(() => _selectedDepartemen = val!); _loadData(); }, 'Departemen')])),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFilterLabel("Unit Kerja"), const SizedBox(height: 6), _buildDropdown(_unitOptions, _selectedUnitKerja, (val) { setState(() => _selectedUnitKerja = val!); _loadData(); }, 'Unit Kerja')])),
          ]),
          const SizedBox(height: 20),
          _buildFilterLabel("Parameter Tampil"),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _buildCustomChip('Cahaya', _showCahaya, (val) => setState(() => _showCahaya = val)),
            _buildCustomChip('Bising', _showBising, (val) => setState(() => _showBising = val)),
            _buildCustomChip('Debu', _showDebu, (val) => setState(() => _showDebu = val)),
            _buildCustomChip('Iklim Kerja', _showIklimKerja, (val) => setState(() => _showIklimKerja = val)),
          ]),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String label) => Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey));

  Widget _buildDropdown(List<String> options, String selectedValue, ValueChanged<String?> onChanged, String hint) {
    String? effectiveValue = options.contains(selectedValue) ? selectedValue : (options.isNotEmpty ? options.first : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: effectiveValue, isExpanded: true, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87), icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryRed), items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: onChanged)),
    );
  }

  Widget _buildCustomChip(String label, bool isSelected, Function(bool) onToggle) {
    return InkWell(
      onTap: () => onToggle(!isSelected), borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? primaryRed : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? primaryRed : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildDataTable(List<LingkunganData> data) {
    if (data.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Tidak ada data ditemukan", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0), child: Text('TABEL PENGUKURAN', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 14, letterSpacing: 1.0))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100), columnSpacing: 25, horizontalMargin: 20, dataRowMaxHeight: 65,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black54, fontSize: 11), dataTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13),
                columns: [
                  const DataColumn(label: Text('NO')), const DataColumn(label: Text('AREA')), const DataColumn(label: Text('SUB-AREA')), const DataColumn(label: Text('DEPARTEMEN')), const DataColumn(label: Text('UNIT KERJA')), const DataColumn(label: Text('TANGGAL')),
                  if (_showCahaya) const DataColumn(label: Text('CAHAYA')), if (_showBising) const DataColumn(label: Text('BISING')), if (_showDebu) const DataColumn(label: Text('DEBU')),
                  if (_showIklimKerja) ...[const DataColumn(label: Text('S. BASAH')), const DataColumn(label: Text('S. KERING')), const DataColumn(label: Text('S. RADIASI')), const DataColumn(label: Text('ISBB INDOOR')), const DataColumn(label: Text('ISBB OUTDOOR')), const DataColumn(label: Text('RH')), const DataColumn(label: Text('KESIMPULAN'))],
                ],
                rows: data.asMap().entries.map((entry) {
                  LingkunganData d = entry.value; double parseSuhu(String val) => double.tryParse(val) ?? 0.0;
                  return DataRow(cells: [
                    DataCell(Text((entry.key + 1).toString())), DataCell(Text(d.location)), DataCell(Text(d.subArea)), DataCell(Text(d.department)), DataCell(Text(d.unitKerja)), DataCell(Text(d.tanggal)),
                    if (_showCahaya) DataCell(Text("${d.cahayaLux} Lux", style: TextStyle(color: d.cahayaLux > 100 ? Colors.red : Colors.black87, fontWeight: d.cahayaLux > 100 ? FontWeight.w900 : FontWeight.w600))),
                    if (_showBising) DataCell(Text("${d.bisingDb} dB", style: TextStyle(color: d.bisingDb > 85 ? Colors.red : Colors.black87, fontWeight: d.bisingDb > 85 ? FontWeight.w900 : FontWeight.w600))),
                    if (_showDebu) DataCell(Text("${d.debuMgNm3} mg", style: TextStyle(color: d.debuMgNm3 > 10 ? Colors.red : Colors.black87, fontWeight: d.debuMgNm3 > 10 ? FontWeight.w900 : FontWeight.w600))),
                    if (_showIklimKerja) ...[ DataCell(Text(d.suhuBasah)), DataCell(Text(d.suhuKering)), DataCell(Text(d.suhuRadiasi)), DataCell(Text(d.suhuIndoor, style: TextStyle(color: parseSuhu(d.suhuIndoor) > 27 ? Colors.red : Colors.black87, fontWeight: parseSuhu(d.suhuIndoor) > 27 ? FontWeight.w900 : FontWeight.w600))), DataCell(Text(d.suhuOutdoor)), DataCell(Text(d.rh)), DataCell(Text(d.kesimpulan)) ],
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}