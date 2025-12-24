import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:stmc_health_app/constants.dart';
import 'package:http/http.dart' as http; // Import HTTP
import 'dart:convert';
import '../../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';


// Definisikan ulang warna yang diperlukan
const Color primaryRed = Color(0xFFC00000);

class DataPribadiPage extends StatefulWidget {
  final UserState userState;
  const DataPribadiPage({super.key, required this.userState});
  @override
  State<DataPribadiPage> createState() => _DataPribadiPageState(); // Buat State baru
}

class _DataPribadiPageState extends State<DataPribadiPage> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  // Controller untuk menangani input teks yang bisa diubah
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

  File? _selectedImage; // Menyimpan file gambar yang baru dipilih
  bool _isLoading = false; // State loading saat proses simpan

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller dengan data dari UserState
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
    _noHpController.dispose();
    _alamatController.dispose();
    _provinsiController.dispose();
    _kabupatenController.dispose();
    _kecamatanController.dispose();
    super.dispose();
  }

  // --- Fungsi Pilih Gambar ---
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // --- Fungsi Simpan Profil ke API ---
  Future<void> _handleSaveProfile() async {
    setState(() => _isLoading = true);

    final result = await _authService.updateProfile(
      accessToken: widget.userState.accessToken!,
      nik: _nikController.text,
      nama: _namaController.text,
      email: _emailController.text,
      noHp: _noHpController.text,
      tinggi: _tinggiController.text,
      berat: _beratController.text,
      alamat: _alamatController.text,
      provinsi: _provinsiController.text,
      kabupaten: _kabupatenController.text,
      kecamatan: _kecamatanController.text,
      imagePath: _selectedImage?.path,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // PENGECEKAN MOUNTED: Memastikan widget masih ada di layar
      if (!mounted) return;

      // 1. Ambil Notifier dari root (MyApp)
      final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;
      final Map<String, dynamic> newUserData = result['userData'];

      // Tentukan role berdasarkan data terbaru dari server
      dynamic isEmployeeRaw = newUserData['is_employee'] ?? newUserData['isEmployee'];
      bool isEmployee = isEmployeeRaw == true || isEmployeeRaw == 1 || isEmployeeRaw.toString() == 'true';
      String updatedRole = isEmployee ? 'KARYAWAN' : 'NON_PTST';

      String? updatedName = newUserData['nama'];
      String? updatedSap = newUserData['no_sap'] ?? newUserData['nik'];

      // 3. Update UserStateNotifier agar seluruh UI yang memakai userState ter-refresh
      userStateNotifier.value = UserState(
        isLoggedIn: true,
        accessToken: widget.userState.accessToken,
        userData: newUserData,
        name: newUserData['nama'],
        sap: newUserData['no_sap'] ?? newUserData['nik'],
        displayText: '$updatedSap - $updatedName',
        role: updatedRole, // <--- SANGAT PENTING: Agar menu Lingkungan muncul kembali
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

      // 4. Bersihkan state foto sementara
      setState(() => _selectedImage = null);

      // 5. Tampilkan Pesan Sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui!'), backgroundColor: Colors.green),
      );

      // 6. REVISI UTAMA: Kembali ke halaman Profile sebelumnya
      // Ini akan menutup halaman edit dan memicu refresh otomatis pada halaman ProfilePage
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal memperbarui profil.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil notifier dari root (MyApp)
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
        body: Stack( // Gunakan Stack untuk overlay loading
          children: [
            ValueListenableBuilder<UserState>(
              valueListenable: userStateNotifier,
              builder: (context, userState, child) {
                return TabBarView(
                  children: [
                    _buildInformasiDasarTab(userState,context),
                    _buildAlamatTab(),
                  ],
                );
              },
            ),
            if (_isLoading) // Overlay Loading
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator(color: primaryRed)),
              ),
          ],
        ),
      ),
    );
  }

  // --- Widget untuk Tab Informasi Dasar ---
  Widget _buildInformasiDasarTab(UserState userState, BuildContext context) {
    return RefreshIndicator(
        color: primaryRed,
        onRefresh: () async {
          /// 1. Ambil Notifier dari root
          final userStateNotifier = (context.findAncestorWidgetOfExactType<MyApp>() as MyApp).userStateNotifier;

          // 2. Simulasi/Panggil API (Ganti dengan fungsi fetch profile yang sesungguhnya jika ada)
          await Future.delayed(const Duration(seconds: 1));

          // 3. Update Controller agar teks di input field berubah jika ada data baru dari server
          // Contoh jika data di userState.userData sudah terbaru:
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
          // PENTING: physics ini memastikan fitur tarik tetap aktif walau konten pendek
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SEKSI FOTO PROFIL
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: primaryRed.withOpacity(0.1),
                          // Logika tampilan gambar:
                          // 1. Gambar baru dipilih (Lokal)
                          // 2. Gambar dari server (URL)
                          // 3. Ikon Default
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (userState.userData?['foto'] != null
                                  ? NetworkImage(userState.userData!['foto'])
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

              // FIELD EDITABLE: NO HP
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

  // Widget Tab Alamat yang direvisi:
  Widget _buildAlamatTab() {
    return RefreshIndicator(
        color: primaryRed,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));

          // Update controller alamat dengan data terbaru dari state
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
              // Alamat Domisili (Bisa Diedit)
              _buildEditableFieldWithController(
                  'Alamat Domisili',
                  _alamatController,
                  Icons.home
              ),
              // Kota/Kabupaten (Tampilan dari API)
              _buildEditableFieldWithController('Provinsi', _provinsiController, Icons.location_city),

              // Kecamatan (Tampilan dari API)
              _buildEditableFieldWithController('Kabupaten', _kabupatenController, Icons.location_city),
              _buildEditableFieldWithController('Kecamatan', _kecamatanController, Icons.holiday_village_rounded),

              const SizedBox(height: 25),

              // Tombol Simpan
              _buildSaveButton(),
            ],
          )
        ),
    );
  }

  // --- Helper Baru: Field dengan Controller ---
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

  // --- Helper Widget untuk Field ReadOnly ---
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
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widget untuk Password Field ---
  // PENTING: _buildPasswordField harus diubah untuk memanggil dialog
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
            readOnly: true, // Tidak bisa diubah langsung di sini
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
                  _showChangePasswordDialog(context); // <--- FUNGSI UTAMA
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  // -------------------------------------------------------------------
  // --- FUNGSI UTAMA: MENAMPILKAN DIALOG UBAH PASSWORD ---
  // -------------------------------------------------------------------
  void _showChangePasswordDialog(BuildContext context) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isPasswordVisible = false;
    // bool isSaving = false;

    // Tambahkan StatefulBuilder di dalam showDialog untuk mengelola state lokal dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isSaving = false; // Tambahkan state lokal untuk indikator loading
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
                      // Field 1: Password Lama
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
                      // Field 2: Password Baru
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
                      // Field 3: Konfirmasi Password Baru
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
                  // LOGIKA SUBMIT SEKARANG ADA DI SINI:
                  onPressed: isSaving ? null : () async { // <-- Ubah menjadi async

                    // 1. Validasi
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    // 2. Set Loading
                    innerSetState(() {
                      // Mengubah variabel lokal isSaving di scope StatefulBuilder
                      isSaving = true;
                    });

                    // Ambil token dari userState (dari StatefulWidget utama)
                    final String? accessToken = widget.userState.accessToken;

                    if (accessToken == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Anda belum login atau sesi telah berakhir.'), backgroundColor: Colors.red),
                      );
                      Navigator.of(innerContext).pop();
                      return;
                    }

                    // 3. Panggil fungsi API (AuthService)
                    final result = await _authService.changePassword(
                      currentPassword: oldPassController.text,
                      newPassword: newPassController.text,
                      confirmPassword: confirmPassController.text, // Mengirim konfirmasi untuk validasi server
                      accessToken: accessToken,
                    );

                    // 4. Set Loading Selesai
                    innerSetState(() {
                      isSaving = false;
                    });

                    // 5. Feedback ke User
                    if (result['success'] == true) {
                      // Sukses: Tutup dialog dan tampilkan pesan sukses
                      Navigator.of(innerContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Kata sandi berhasil diubah.'), backgroundColor: primaryRed),
                      );
                    } else {
                      // Gagal: Tampilkan pesan error di SnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Gagal mengubah kata sandi.'), backgroundColor: Colors.red),
                      );
                    }
                  }, // END onPressed
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                  ),
                  child: isSaving
                      ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                      : const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper untuk input password di dialog
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