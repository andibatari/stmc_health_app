import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:stmc_health_app/constants.dart'; // Sesuaikan path
import '../models/user_profile.dart'; // Sesuaikan path
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  // URL lengkap untuk kebutuhan API Auth & Profile
  final String loginUrl = '$KBaseUrl$KLoginUrl';
  final String logoutUrl = '$KBaseUrl$KLogoutUrl';
  final String changePasswordUrl = '$KBaseUrl/change-password'; // 🌟 PERBAIKAN: Definisikan URL Ganti Password
  final String updateProfileUrl = '$KBaseUrl/update-profile';   // 🌟 PERBAIKAN: Definisikan URL Update Profil secara eksplisit

  // Menyimpan token secara sementara
  static String? authToken;
  static UserProfile? currentUserProfile;

  // Kunci untuk menyimpan data di SharedPreferences
  static const String _kAccessTokenKey = 'accessToken';
  static const String _kUserDataKey = 'userData';

  // 🌟 PERBAIKAN: Menambahkan parameter opsional fcmToken
  Future<Map<String, dynamic>> login(String identifier, String password, {String? fcmToken}) async {
    try {
      // Siapkan data yang akan dikirim
      Map<String, dynamic> requestBody = {
        'identifier': identifier,
        'password': password,
      };

      // Jika token berhasil didapatkan dari HP, masukkan ke keranjang pengiriman
      if (fcmToken != null && fcmToken.isNotEmpty) {
        requestBody['fcm_token'] = fcmToken;
      }

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody), // Kirim data beserta tokennya
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login Berhasil
        final String? token = responseBody['token'];
        final Map<String, dynamic>? userDataRaw = responseBody['user_profile'];

        if (token == null || userDataRaw == null) {
          return {
            'success': false,
            'message': 'Format respons API tidak lengkap (missing token atau user data).'
          };
        }

        authToken = token;
        await saveLoginData(token, userDataRaw);

        return {
          'success': true,
          'message': responseBody['message'],
          'accessToken': token,
          'userData': userDataRaw,
        };

      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Login gagal. Cek kredensial Anda.'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke server. (${e.toString()})'
      };
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
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
          'new_password_confirmation': confirmPassword,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Kata sandi berhasil diubah.'
        };
      } else if (response.statusCode == 401 || response.statusCode == 422) {
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

  // --- PERSISTENCY HANDLERS ---

  // 1. Menyimpan Token dan Data User setelah Login/Update berhasil
  Future<void> saveLoginData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, token);
    await prefs.setString(_kUserDataKey, jsonEncode(userData));
    authToken = token;
  }

  // 2. Mengambil Token dan Data User dari penyimpanan lokal
  Future<Map<String, dynamic>?> getPersistedLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessTokenKey);
    final userDataJson = prefs.getString(_kUserDataKey);

    if (token != null && userDataJson != null) {
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
    await prefs.clear();
    authToken = null;
  }

  Future<bool> logout() async {
    if (authToken == null) {
      final data = await getPersistedLoginData();
      authToken = data?['accessToken'];
    }

    // 🌟 PERBAIKAN PENTING: Matikan antena notifikasi HP sebelum keluar!
    try {
      await FirebaseMessaging.instance.deleteToken();
      print("Antena FCM berhasil dimatikan saat logout.");
    } catch (e) {
      print("Gagal mematikan antena FCM: $e");
    }

    if (authToken == null) {
      await clearLoginData();
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

      await clearLoginData();
      return response.statusCode == 200;

    } catch (e) {
      await clearLoginData();
      return false;
    }
  }

  // --- UPDATE PROFILE METHOD WITH MULTIPART ---
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
    String? imagePath,
  }) async {
    try {
      // 1. Inisialisasi MultipartRequest menggunakan URL yang benar
      var request = http.MultipartRequest('POST', Uri.parse(updateProfileUrl));

      // 2. Tambahkan Header Keamanan & Response Format
      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      });

      // 3. Masukkan data teks ke field request sesuai dengan parameter Laravel controller
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

      // 4. Tambahkan file gambar jika ada foto baru yang dipilih oleh user
      if (imagePath != null && imagePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_profil', // Harus presisi sesuai nama field file yang divalidasi Laravel
          imagePath,
        ));
      }

      // 5. Kirim data aliran multipart ke server
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.body.isEmpty) {
        throw Exception("Server memberikan respon kosong");
      }

      final responseBody = jsonDecode(response.body);

      // 6. Evaluasi status code hasil pengiriman
      if (response.statusCode == 200 && responseBody['status'] == 'success') {

        // Simpan pembaruan profil ke memori SharedPreferences lokal HP agar persistensinya terjaga
        if (responseBody['user_profile'] != null) {
          await saveLoginData(accessToken, responseBody['user_profile']);
        }

        return {
          'success': true,
          'message': responseBody['message'] ?? 'Profil berhasil diperbarui.',
          'userData': responseBody['user_profile'], // Dikembalikan sebagai userData untuk ditangkap UI Page
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