import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stmc_health_app/constants.dart'; // Sesuaikan path
import '../models/user_profile.dart'; // Sesuaikan path
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  // URL lengkap untuk login
  final String loginUrl = '$KBaseUrl$KLoginUrl';
  final String logoutUrl = '$KBaseUrl$KLogoutUrl';

  // Menyimpan token secara sementara (untuk contoh)
  // Dalam aplikasi nyata, gunakan SharedPreferences/flutter_secure_storage
  static String? authToken;
  static UserProfile? currentUserProfile;
  // Kunci untuk menyimpan token di SharedPreferences
  static const String _kAccessTokenKey = 'accessToken';
  static const String _kUserDataKey = 'userData'; // Untuk menyimpan data profil JSON

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login Berhasil

        // 1. Ambil token dan data user mentah
        final String? token = responseBody['token'];
        final Map<String, dynamic>? userDataRaw = responseBody['user_profile']; // <--- Gunakan data user mentah

        // Periksa apakah token dan data user ada
        if (token == null || userDataRaw == null) {
          return {
            'success': false,
            'message': 'Format respons API tidak lengkap (missing token atau user data).'
          };
        }

        // Simpan token untuk kebutuhan AuthService
        authToken = token;
        await saveLoginData(token, userDataRaw);

        // Return struktur yang diharapkan oleh LoginPage
        return {
          'success': true,
          'message': responseBody['message'],
          // Kunci baru untuk perbaikan:
          'accessToken': token, // <--- KUNCI INI YANG HILANG SEBELUMNYA
          'userData': userDataRaw, // <--- KUNCI INI YANG HILANG SEBELUMNYA
        };

      } else {
        // ... (Login Gagal tetap sama) ...
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Login gagal. Cek kredensial Anda.'
        };
      }
    } catch (e) {
      // ... (Kesalahan Koneksi/Server tetap sama) ...
      return {
        'success': false,
        'message': 'Gagal terhubung ke server. (${e.toString()})'
      };
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword, // Tambahkan konfirmasi password
    required String accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(changePasswordUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword, // <-- Kunci krusial untuk validasi Laravel
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Kata sandi berhasil diubah.'
        };
      } else if (response.statusCode == 401 || response.statusCode == 422) { // Tangani error validasi dari Laravel
        // 422 seringkali menandakan error validasi (password tidak cocok/password lama salah)
        final errorMsg = responseBody['message'] ?? (responseBody['errors'] != null ? responseBody['errors'].values.first[0] : 'Password lama salah atau validasi gagal.');
        return {
          'success': false,
          'message': errorMsg
        };
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Gagal mengubah kata sandi. Coba lagi nanti.'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kesalahan koneksi: Gagal terhubung ke server.'
      };
    }
  }

  // --- FUNGSI BARU UNTUK PERSISTENCY ---

  // 1. Menyimpan Token dan Data User setelah Login berhasil
  Future<void> saveLoginData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, token);

    // Simpan userData sebagai string JSON
    await prefs.setString(_kUserDataKey, jsonEncode(userData));

    // Simpan juga token di memori statis (opsional, tapi memudahkan akses cepat)
    authToken = token;
  }

  // 2. Mengambil Token dan Data User dari penyimpanan
  Future<Map<String, dynamic>?> getPersistedLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessTokenKey);
    final userDataJson = prefs.getString(_kUserDataKey);

    if (token != null && userDataJson != null) {
      // Jika ada data, kembalikan dalam bentuk Map
      return {
        'accessToken': token,
        'userData': jsonDecode(userDataJson) as Map<String, dynamic>,
      };
    }
    return null;
  }

  // 3. Menghapus Data Login saat Logout
  Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();

    // 2. Bersihkan total semua data SharedPreferences
    await prefs.clear();

    // 3. Reset variabel statis di memori
    authToken = null;
  }

  Future<bool> logout() async {
    // Ambil token dari SharedPreferences jika variabel statis kosong
    if (authToken == null) {
      final data = await getPersistedLoginData();
      authToken = data?['accessToken'];
    }

    // Jika setelah dicek ke storage tetap null, berarti memang sudah logout
    if (authToken == null) {
      await clearLoginData(); // Pastikan storage tetap bersih
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse(logoutUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      // Apapun status codenya (200, 401, 500), kita HARUS hapus data lokal
      await clearLoginData();
      return response.statusCode == 200;

    } catch (e) {
      // Jika koneksi error, tetap hapus data lokal agar user keluar
      await clearLoginData();
      return false;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String accessToken,
    String? nik,
    String? nama,
    String? email,
    String? noHp,
    String? tinggi,
    String? berat,
    String? alamat,
    String? provinsi,
    String? kabupaten,
    String? kecamatan,
    String? imagePath, // Path file gambar dari galeri/kamera
  }) async {
    try {
      // 1. Definisikan URL API Update Profil
      final uri = Uri.parse('$KBaseUrl$KUpdateProfileUrl');

      // 2. Gunakan MultipartRequest karena kita akan mengirim file gambar
      var request = http.MultipartRequest('POST', uri);

      // 3. Tambahkan Header Authorization
      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      });

      // 4. Tambahkan data teks ke dalam fields
      // Field ini harus sesuai dengan yang diharapkan oleh Backend (Laravel)
      if (nik != null) request.fields['nik'] = nik;
      if (nama != null) request.fields['nama'] = nama;
      if (email != null) request.fields['email'] = email;
      if (noHp != null) request.fields['no_hp'] = noHp;
      if (tinggi != null) request.fields['tinggi_badan'] = tinggi;
      if (berat != null) request.fields['berat_badan'] = berat;
      if (alamat != null) request.fields['alamat'] = alamat;
      if (provinsi != null) request.fields['provinsi'] = provinsi;
      if (kabupaten != null) request.fields['kabupaten'] = kabupaten;
      if (kecamatan != null) request.fields['kecamatan'] = kecamatan;

      // 5. Tambahkan File Gambar jika user memilih foto baru
      if (imagePath != null && imagePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_profil', // Nama field di Laravel
          imagePath,
        ));
      }

      // 6. Kirim Request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Cek apakah response kosong atau bukan JSON
      if (response.body.isEmpty) {
        throw Exception("Server memberikan respon kosong");
      }

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Jika berhasil, update data lokal (SharedPreferences)
        if (responseBody['user_profile'] != null) {
          await saveLoginData(accessToken, responseBody['user_profile']);
        }

        return {
          'success': true,
          'message': responseBody['message'] ?? 'Profil berhasil diperbarui.',
          'userData': responseBody['user_profile'],
        };
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Gagal memperbarui profil.',
        };
      }
    } catch (e) {
    return {
    'success': false,
    'message': 'Kesalahan koneksi: Gagal memperbarui profil. (${e.toString()})',
    };
    }
  }
}