import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:stmc_health_app/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

const Color primaryRed = Color(0xFFC00000);
const Color bgGrey = Color(0xFFF8F9FA);

class DataPribadiPage extends StatefulWidget {
  final UserState userState;
  const DataPribadiPage({super.key, required this.userState});
  @override State<DataPribadiPage> createState() => _DataPribadiPageState();
}

class _DataPribadiPageState extends State<DataPribadiPage> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _nikController, _namaController, _emailController, _noHpController, _tinggiController, _beratController, _alamatController, _provinsiController, _kabupatenController, _kecamatanController;
  File? _selectedImage;
  bool _isLoading = false;

  // 🌟 VARIABEL BARU UNTUK DROPDOWN PROVINSI
  String? _selectedProvinsi;
  final List<String> _listProvinsi = [
    'ACEH', 'SUMATERA UTARA', 'SUMATERA BARAT', 'RIAU', 'JAMBI', 'SUMATERA SELATAN', 'BENGKULU', 'LAMPUNG', 'KEPULAUAN BANGKA BELITUNG', 'KEPULAUAN RIAU',
    'DKI JAKARTA', 'JAWA BARAT', 'JAWA TENGAH', 'DI YOGYAKARTA', 'JAWA TIMUR', 'BANTEN', 'BALI', 'NUSA TENGGARA BARAT', 'NUSA TENGGARA TIMUR',
    'KALIMANTAN BARAT', 'KALIMANTAN TENGAH', 'KALIMANTAN SELATAN', 'KALIMANTAN TIMUR', 'KALIMANTAN UTARA',
    'SULAWESI UTARA', 'SULAWESI TENGAH', 'SULAWESI SELATAN', 'SULAWESI TENGGARA', 'GORONTALO', 'SULAWESI BARAT',
    'MALUKU', 'MALUKU UTARA', 'PAPUA BARAT', 'PAPUA', 'PAPUA SELATAN', 'PAPUA TENGAH', 'PAPUA PEGUNUNGAN', 'PAPUA BARAT DAYA'
  ];

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> rawData = widget.userState.userData ?? {};

    _nikController = TextEditingController(text: rawData['nik'] ?? widget.userState.nik ?? '');
    _namaController = TextEditingController(text: rawData['nama'] ?? widget.userState.name ?? '');
    _emailController = TextEditingController(text: rawData['email'] ?? widget.userState.email ?? '');
    _noHpController = TextEditingController(text: rawData['no_hp'] ?? widget.userState.no_hp ?? '');
    _tinggiController = TextEditingController(text: rawData['tinggi_badan']?.toString() ?? widget.userState.tinggi_badan ?? '');
    _beratController = TextEditingController(text: rawData['berat_badan']?.toString() ?? widget.userState.berat_badan ?? '');
    _alamatController = TextEditingController(text: rawData['alamat'] ?? widget.userState.alamat ?? '');
    _kabupatenController = TextEditingController(text: rawData['kabupaten'] ?? widget.userState.kabupaten ?? '');
    _kecamatanController = TextEditingController(text: rawData['kecamatan'] ?? widget.userState.kecamatan ?? '');

    // 🌟 LOGIKA UNTUK MENCOCOKKAN DATA PROVINSI DARI SERVER DENGAN DROPDOWN
    String initProvinsi = rawData['provinsi'] ?? widget.userState.provinsi ?? '';
    _provinsiController = TextEditingController(text: initProvinsi);

    if (initProvinsi.isNotEmpty) {
      String upperProvinsi = initProvinsi.toUpperCase();
      // Jika provinsi dari server belum ada di list kita, tambahkan sementara agar tidak error
      if (!_listProvinsi.contains(upperProvinsi)) {
        _listProvinsi.add(upperProvinsi);
      }
      _selectedProvinsi = upperProvinsi;
    }
  }

  @override
  void dispose() {
    _nikController.dispose(); _namaController.dispose(); _emailController.dispose(); _noHpController.dispose(); _tinggiController.dispose(); _beratController.dispose(); _alamatController.dispose(); _provinsiController.dispose(); _kabupatenController.dispose(); _kecamatanController.dispose(); super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _handleSaveProfile() async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$KBaseUrl/update-profile'));
      request.headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer ${widget.userState.accessToken}'});

      // _provinsiController akan selalu sinkron dengan dropdown karena kita update di onChanged
      request.fields.addAll({'nik': _nikController.text, 'nama': _namaController.text, 'email': _emailController.text, 'no_hp': _noHpController.text, 'tinggi_badan': _tinggiController.text, 'berat_badan': _beratController.text, 'alamat': _alamatController.text, 'provinsi': _provinsiController.text, 'kabupaten': _kabupatenController.text, 'kecamatan': _kecamatanController.text});

      if (_selectedImage != null) request.files.add(await http.MultipartFile.fromPath('foto_profil', _selectedImage!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final result = jsonDecode(response.body);
      setState(() => _isLoading = false);

      if (response.statusCode == 200 && result['status'] == 'success') {
        if (!mounted) return;
        final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;
        final Map<String, dynamic> newUserData = result['user_profile'];
        dynamic isEmployeeRaw = newUserData['is_employee'] ?? newUserData['isEmployee'];
        bool isEmployee = isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString() == 'true';

        userStateNotifier.value = UserState(
            isLoggedIn: true, accessToken: widget.userState.accessToken, userData: newUserData,
            name: newUserData['nama'], sap: newUserData['no_sap'] ?? newUserData['nik'],
            displayText: '${newUserData['no_sap'] ?? newUserData['nik']} - ${newUserData['nama']}',
            role: isEmployee ? 'KARYAWAN' : 'NON_PTST', jobTitle: newUserData['jabatan'],
            email: newUserData['email'], nik: newUserData['nik'], no_hp: newUserData['no_hp'],
            tinggi_badan: newUserData['tinggi_badan']?.toString(), berat_badan: newUserData['berat_badan']?.toString(),
            alamat: newUserData['alamat'], provinsi: newUserData['provinsi'],
            kabupaten: newUserData['kabupaten'], kecamatan: newUserData['kecamatan']
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(newUserData));
        setState(() => _selectedImage = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Gagal.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgGrey,
        appBar: AppBar(
          title: const Text('Data Pribadi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5)),
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3.5,
              labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [
                Tab(text: 'Info Dasar'),
                Tab(text: 'Alamat')
              ]
          ),
        ),
        body: Stack(
          children: [
            ValueListenableBuilder<UserState>(
                valueListenable: userStateNotifier,
                builder: (context, userState, child) {
                  return TabBarView(
                      children: [
                        _buildInformasiDasarTab(userState, context),
                        _buildAlamatTab()
                      ]
                  );
                }
            ),
            if (_isLoading) Container(color: Colors.white.withOpacity(0.8), child: const Center(child: CircularProgressIndicator(color: primaryRed))),
          ],
        ),
      ),
    );
  }

  Widget _buildInformasiDasarTab(UserState userState, BuildContext context) {
    return RefreshIndicator(
      color: primaryRed,
      backgroundColor: Colors.white,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          final Map<String, dynamic> rawData = userState.userData ?? {};
          _nikController.text = rawData['nik'] ?? userState.nik ?? '';
          _namaController.text = rawData['nama'] ?? userState.name ?? '';
          _emailController.text = rawData['email'] ?? userState.email ?? '';
          _noHpController.text = rawData['no_hp'] ?? userState.no_hp ?? '';
          _tinggiController.text = rawData['tinggi_badan']?.toString() ?? userState.tinggi_badan ?? '';
          _beratController.text = rawData['berat_badan']?.toString() ?? userState.berat_badan ?? '';
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))], border: Border.all(color: primaryRed.withOpacity(0.1), width: 4)),
                        child: ClipOval(
                          child: _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : (userState.userData?['foto'] != null && userState.userData!['foto'].toString().isNotEmpty
                              ? Image.network("${userState.userData!['foto']}?t=${DateTime.now().millisecondsSinceEpoch}", fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person_rounded, color: primaryRed, size: 55))
                              : const Icon(Icons.person_rounded, color: primaryRed, size: 55)),
                        ),
                      ),
                      Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: primaryRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20)
                              )
                          )
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                      onPressed: _pickImage,
                      style: TextButton.styleFrom(backgroundColor: primaryRed.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text("Ubah Foto Profil", style: TextStyle(color: primaryRed, fontWeight: FontWeight.w800))
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadOnlyField('Nomor SAP', userState.sap ?? '-'),
                  _buildEditableFieldWithController('NIK (KTP)', _nikController, Icons.badge_rounded),
                  _buildEditableFieldWithController('Nama Lengkap', _namaController, Icons.person_rounded),
                  _buildEditableFieldWithController('Alamat Email', _emailController, Icons.email_rounded),
                  _buildEditableFieldWithController('Nomor Handphone', _noHpController, Icons.phone_rounded),
                  Row(children: [Expanded(child: _buildEditableFieldWithController('Tinggi (cm)', _tinggiController, Icons.height_rounded)), const SizedBox(width: 15), Expanded(child: _buildEditableFieldWithController('Berat (kg)', _beratController, Icons.monitor_weight_rounded))]),
                  _buildPasswordField(context),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlamatTab() {
    return RefreshIndicator(
      color: primaryRed,
      backgroundColor: Colors.white,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        final currentState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
        setState(() {
          final Map<String, dynamic> rawData = currentState.userData ?? {};
          _alamatController.text = rawData['alamat'] ?? currentState.alamat ?? '';
          _kabupatenController.text = rawData['kabupaten'] ?? currentState.kabupaten ?? '';
          _kecamatanController.text = rawData['kecamatan'] ?? currentState.kecamatan ?? '';

          // Refresh sinkronisasi Dropdown
          String initProvinsi = rawData['provinsi'] ?? currentState.provinsi ?? '';
          _provinsiController.text = initProvinsi;
          if (initProvinsi.isNotEmpty) {
            String upperProvinsi = initProvinsi.toUpperCase();
            if (!_listProvinsi.contains(upperProvinsi)) _listProvinsi.add(upperProvinsi);
            _selectedProvinsi = upperProvinsi;
          } else {
            _selectedProvinsi = null;
          }
        });
      },
      child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
                child: Column(
                  children: [
                    _buildEditableFieldWithController('Alamat Lengkap Domisili', _alamatController, Icons.home_rounded),
                    // 🌟 MENGGANTI TEXT FIELD MENJADI DROPDOWN
                    _buildDropdownProvinsi(),
                    _buildEditableFieldWithController('Kabupaten / Kota', _kabupatenController, Icons.location_city_rounded),
                    _buildEditableFieldWithController('Kecamatan', _kecamatanController, Icons.holiday_village_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
          )
      ),
    );
  }

  // 🌟 WIDGET KHUSUS UNTUK DROPDOWN PROVINSI
  Widget _buildDropdownProvinsi() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Provinsi', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedProvinsi,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryRed.withOpacity(0.6), size: 28),
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.map_rounded, color: primaryRed.withOpacity(0.6), size: 22),
              filled: true,
              fillColor: bgGrey,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
            hint: const Text("Pilih Provinsi", style: TextStyle(fontSize: 15, color: Colors.black45, fontWeight: FontWeight.w500)),
            items: _listProvinsi.map((String val) {
              return DropdownMenuItem(
                value: val,
                child: Text(val),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedProvinsi = val;
                _provinsiController.text = val ?? ''; // Menjaga controller tetap sinkron untuk dikirim
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFieldWithController(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
                prefixIcon: Icon(icon, color: primaryRed.withOpacity(0.6), size: 22),
                filled: true,
                fillColor: bgGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 18)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSaveProfile,
        style: ElevatedButton.styleFrom(backgroundColor: primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: _isLoading
            ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w700))
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kata Sandi Akun', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '••••••••••', readOnly: true, obscureText: true, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_rounded, color: primaryRed.withOpacity(0.6), size: 22),
                filled: true, fillColor: bgGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                suffixIcon: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: primaryRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: IconButton(icon: const Icon(Icons.edit_rounded, color: primaryRed, size: 20), onPressed: () => _showChangePasswordDialog(context))
                )
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>(); final oldPassController = TextEditingController(); final newPassController = TextEditingController(); final confirmPassController = TextEditingController(); bool isPasswordVisible = false;
    showDialog(
      context: context, builder: (BuildContext dialogContext) {
      bool isSaving = false;
      return StatefulBuilder(builder: (BuildContext innerContext, StateSetter innerSetState) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24), contentPadding: const EdgeInsets.all(24),
          title: const Text('Ubah Kata Sandi', style: TextStyle(color: primaryRed, fontWeight: FontWeight.w900, fontSize: 18)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPasswordInput(controller: oldPassController, label: "Sandi Saat Ini", isVisible: isPasswordVisible, validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null, onToggle: () => innerSetState(() => isPasswordVisible = !isPasswordVisible)), const SizedBox(height: 16),
                  _buildPasswordInput(controller: newPassController, label: "Sandi Baru (Min. 6)", isVisible: isPasswordVisible, validator: (val) => val == null || val.length < 6 ? 'Minimal 6 karakter' : null, onToggle: () => innerSetState(() => isPasswordVisible = !isPasswordVisible)), const SizedBox(height: 16),
                  _buildPasswordInput(controller: confirmPassController, label: "Ulangi Sandi Baru", isVisible: isPasswordVisible, validator: (val) => val != newPassController.text ? 'Sandi tidak cocok' : null, onToggle: () => innerSetState(() => isPasswordVisible = !isPasswordVisible)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.of(innerContext).pop(), child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return; innerSetState(() => isSaving = true);
                final String? accessToken = widget.userState.accessToken; if (accessToken == null) return;
                final result = await _authService.changePassword(currentPassword: oldPassController.text, newPassword: newPassController.text, confirmPassword: confirmPassController.text, accessToken: accessToken);
                innerSetState(() => isSaving = false);
                if (result['success'] == true) { Navigator.of(innerContext).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kata sandi berhasil diubah!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
                else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Gagal.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      });
    },
    );
  }

  Widget _buildPasswordInput({required TextEditingController controller, required String label, required bool isVisible, required String? Function(String?) validator, required VoidCallback onToggle}) {
    return TextFormField(
      controller: controller, obscureText: !isVisible, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          suffixIcon: IconButton(icon: Icon(isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: Colors.grey), onPressed: onToggle),
          filled: true, fillColor: bgGrey,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: primaryRed, width: 1.5))
      ),
      validator: validator,
    );
  }
}