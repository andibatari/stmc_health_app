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

class DataPribadiPage extends StatefulWidget {
  final UserState userState;
  const DataPribadiPage({super.key, required this.userState});
  @override
  State<DataPribadiPage> createState() => _DataPribadiPageState();
}

class _DataPribadiPageState extends State<DataPribadiPage> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nikController;
  late TextEditingController _namaController;
  late TextEditingController _emailController;
  late TextEditingController _noHpController;
  late TextEditingController _tinggiController;
  late TextEditingController _beratController;
  late TextEditingController _alamatController;
  late TextEditingController _provinsiController;
  late TextEditingController _kabupatenController;
  late TextEditingController _kecamatanController;

  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nikController = TextEditingController(text: widget.userState.nik);
    _namaController = TextEditingController(text: widget.userState.name);
    _emailController = TextEditingController(text: widget.userState.email);
    _noHpController = TextEditingController(text: widget.userState.no_hp);
    _tinggiController = TextEditingController(text: widget.userState.tinggi_badan);
    _beratController = TextEditingController(text: widget.userState.berat_badan);
    _alamatController = TextEditingController(text: widget.userState.alamat);
    _provinsiController = TextEditingController(text: widget.userState.provinsi);
    _kabupatenController = TextEditingController(text: widget.userState.kabupaten);
    _kecamatanController = TextEditingController(text: widget.userState.kecamatan);
  }

  @override
  void dispose() {
    _nikController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _noHpController.dispose();
    _tinggiController.dispose();
    _beratController.dispose();
    _alamatController.dispose();
    _provinsiController.dispose();
    _kabupatenController.dispose();
    _kecamatanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // MENGGUNAKAN MULTIPART REQUEST LANGSUNG AGAR FOTO DIJAMIN TERKIRIM
  Future<void> _handleSaveProfile() async {
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$KBaseUrl/update-profile'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${widget.userState.accessToken}';

      request.fields['nik'] = _nikController.text;
      request.fields['nama'] = _namaController.text;
      request.fields['email'] = _emailController.text;
      request.fields['no_hp'] = _noHpController.text;
      request.fields['tinggi_badan'] = _tinggiController.text;
      request.fields['berat_badan'] = _beratController.text;
      request.fields['alamat'] = _alamatController.text;
      request.fields['provinsi'] = _provinsiController.text;
      request.fields['kabupaten'] = _kabupatenController.text;
      request.fields['kecamatan'] = _kecamatanController.text;

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('foto_profil', _selectedImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final result = jsonDecode(response.body);

      setState(() => _isLoading = false);

      if (response.statusCode == 200 && result['status'] == 'success') {
        if (!mounted) return;

        final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;
        // FIX BUG: API mereturn 'user_profile' BUKAN 'userData'
        final Map<String, dynamic> newUserData = result['user_profile'];

        dynamic isEmployeeRaw = newUserData['is_employee'] ?? newUserData['isEmployee'];
        bool isEmployee = isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString() == 'true';
        String updatedRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';
        String? updatedName = newUserData['nama'];
        String? updatedSap = newUserData['no_sap'] ?? newUserData['nik'];

        userStateNotifier.value = UserState(
          isLoggedIn: true,
          accessToken: widget.userState.accessToken,
          userData: newUserData,
          name: updatedName,
          sap: newUserData['no_sap'] ?? newUserData['nik'],
          displayText: '$updatedSap - $updatedName',
          role: updatedRole,
          jobTitle: newUserData['jabatan'],
          email: newUserData['email'],
          nik: newUserData['nik'],
          no_hp: newUserData['no_hp'],
          tinggi_badan: newUserData['tinggi_badan']?.toString(),
          berat_badan: newUserData['berat_badan']?.toString(),
          alamat: newUserData['alamat'],
          provinsi: newUserData['provinsi'],
          kabupaten: newUserData['kabupaten'],
          kecamatan: newUserData['kecamatan'],
        );

        // FIX: Simpan session terbaru ke HP
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(newUserData));

        setState(() => _selectedImage = null);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal memperbarui profil.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DATA PRIBADI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: primaryRed,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Informasi Dasar'),
              Tab(text: 'Alamat'),
            ],
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
                    _buildAlamatTab(),
                  ],
                );
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator(color: primaryRed)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformasiDasarTab(UserState userState, BuildContext context) {
    return RefreshIndicator(
      color: primaryRed,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _nikController.text = userState.nik ?? '';
          _namaController.text = userState.name ?? '';
          _emailController.text = userState.email ?? '';
          _noHpController.text = userState.no_hp ?? '';
          _tinggiController.text = userState.tinggi_badan ?? '';
          _beratController.text = userState.berat_badan ?? '';
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: primaryRed.withOpacity(0.1),
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (userState.userData?['foto'] != null &&
                            userState.userData!['foto'].toString().isNotEmpty
                            ? NetworkImage("${userState.userData!['foto']}?t=${DateTime.now().millisecondsSinceEpoch}")
                            : null),
                        child: (_selectedImage == null && userState.userData?['foto'] == null)
                            ? const Icon(Icons.person, color: primaryRed, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: primaryRed, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _pickImage,
                    child: const Text("Ubah Foto Profil", style: TextStyle(color: primaryRed)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildReadOnlyField('No. SAP', userState.sap ?? '-'),
            _buildEditableFieldWithController('NIK', _nikController, Icons.badge),
            _buildEditableFieldWithController('Nama Lengkap', _namaController, Icons.person),
            _buildEditableFieldWithController('Email', _emailController, Icons.email),
            _buildEditableFieldWithController('No. HP', _noHpController, Icons.phone),
            _buildEditableFieldWithController('Tinggi Badan (cm)', _tinggiController, Icons.height),
            _buildEditableFieldWithController('Berat Badan (kg)', _beratController, Icons.monitor_weight),
            _buildPasswordField(context),
            const SizedBox(height: 20),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlamatTab() {
    return RefreshIndicator(
      color: primaryRed,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        final currentState = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier.value;
        setState(() {
          _alamatController.text = currentState.alamat ?? '';
          _provinsiController.text = currentState.provinsi ?? '';
          _kabupatenController.text = currentState.kabupaten ?? '';
          _kecamatanController.text = currentState.kecamatan ?? '';
        });
      },
      child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEditableFieldWithController('Alamat Domisili', _alamatController, Icons.home),
              _buildEditableFieldWithController('Provinsi', _provinsiController, Icons.location_city),
              _buildEditableFieldWithController('Kabupaten', _kabupatenController, Icons.location_city),
              _buildEditableFieldWithController('Kecamatan', _kecamatanController, Icons.holiday_village_rounded),
              const SizedBox(height: 25),
              _buildSaveButton(),
            ],
          )
      ),
    );
  }

  Widget _buildEditableFieldWithController(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: primaryRed, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSaveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kata Sandi', style: TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 5),
          TextFormField(
            initialValue: '**********',
            readOnly: true,
            obscureText: true,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryRed, width: 2),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_note, color: primaryRed),
                onPressed: () {
                  _showChangePasswordDialog(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isPasswordVisible = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter innerSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Ubah Kata Sandi', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPasswordInput(
                        controller: oldPassController,
                        label: "Password Lama",
                        isVisible: isPasswordVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password lama harus diisi';
                          return null;
                        },
                        onToggle: () => innerSetState(() => isPasswordVisible = !isPasswordVisible),
                      ),
                      const SizedBox(height: 15),
                      _buildPasswordInput(
                        controller: newPassController,
                        label: "Password Baru",
                        isVisible: isPasswordVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password baru harus diisi';
                          if (value.length < 6) return 'Minimal 6 karakter';
                          return null;
                        },
                        onToggle: () => innerSetState(() => isPasswordVisible = !isPasswordVisible),
                      ),
                      const SizedBox(height: 15),
                      _buildPasswordInput(
                        controller: confirmPassController,
                        label: "Konfirmasi Password Baru",
                        isVisible: isPasswordVisible,
                        validator: (value) {
                          if (value != newPassController.text) return 'Konfirmasi password tidak cocok';
                          return null;
                        },
                        onToggle: () => innerSetState(() => isPasswordVisible = !isPasswordVisible),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(innerContext).pop(),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    innerSetState(() { isSaving = true; });

                    final String? accessToken = widget.userState.accessToken;
                    if (accessToken == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Anda belum login.'), backgroundColor: Colors.red),
                      );
                      Navigator.of(innerContext).pop();
                      return;
                    }

                    final result = await _authService.changePassword(
                      currentPassword: oldPassController.text,
                      newPassword: newPassController.text,
                      confirmPassword: confirmPassController.text,
                      accessToken: accessToken,
                    );

                    innerSetState(() { isSaving = false; });

                    if (result['success'] == true) {
                      Navigator.of(innerContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Kata sandi berhasil diubah.'), backgroundColor: primaryRed),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Gagal mengubah kata sandi.'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required String? Function(String?) validator,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}