import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stmc_health_app/constants.dart';

class McuService {
  final String _submitUrl = KBaseUrl + KSubmitJadwalUrl;
  final String _riwayatUrl = KBaseUrl + KRiwayatJadwalUrl;
  // Gunakan konstanta jika ada, atau pastikan path-nya benar
  final String _paketUrl = KBaseUrl + KGetPaketMcuUrl;
  final String _checkInPoliUrl = KBaseUrl + '/api/jadwal-poli/checkin';

  // 1. Mengajukan Jadwal
  Future<Map<String, dynamic>> submitJadwal({
    required String tanggalMcu,
    required String paketMcu,
    required String accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_submitUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'tanggal_mcu': tanggalMcu, // Format YYYY-MM-DD
          'paket_mcu': paketMcu,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Gagal mengajukan jadwal.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan koneksi: Gagal terhubung ke server.'};
    }
  }

  // 2. Mengambil Riwayat Jadwal
  Future<Map<String, dynamic>> fetchRiwayatJadwal({
    required String accessToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(_riwayatUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // PERUBAHAN DISINI: Ambil dari responseBody['data'] karena server membungkusnya
        print("====== DATA DARI SERVER: ${response.body} ======");
        final List allData = responseBody['data'] ?? [];

        return {
          'success': true,
          'aktif': allData.where((item) =>
          item['status'] == 'Scheduled' || item['status'] == 'Present').toList(),
          'selesai': allData.where((item) =>
          item['status'] == 'Finished' || item['status'] == 'Canceled').toList(),
        };
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Gagal mengambil data.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan koneksi: Gagal terhubung ke server. (${e.toString()})'};
    }
  }

  Future<List<Map<String, String>>> fetchPaketMcu({required String accessToken}) async {
    try {
      // Sesuaikan URL ini dengan endpoint filter Anda (misal: KLingkunganFilterUrl atau endpoint khusus paket)
      final response = await http.get(
        Uri.parse(_paketUrl), // Ganti dengan endpoint yang benar
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Asumsi response format: {"data": [{"id": 1, "nama_paket": "Paket 1"}, ...]}
        List<dynamic> paketList = data['data'];

        return paketList.map<Map<String, String>>((item) => {
          'id': item['id'].toString(),
          'name': item['name'].toString(), // 'name' berasal dari alias di query SQL tadi
        }).toList();
      }
      return [];
    } catch (e) {
      print("Error Fetch Paket: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> checkInPoli({
    required int idJadwalPoli,
    required String accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_checkInPoliUrl),
        headers: {
          'Accept': 'application/json', // ⬅️ WAJIB TAMBAHKAN BARIS INI
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'id_jadwal_poli': idJadwalPoli,
        }),
      );

      // ⬇️ TAMBAHKAN PRINT INI UNTUK MELIHAT RESPON ASLI DARI SERVER DI TERMINAL VS CODE
      print("RESPON DARI SERVER SAAT TOMBOL DITEKAN: ${response.body}");

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Berhasil check-in ke Poli'};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Gagal check-in poli.'};
      }
    } catch (e) {
      // ⬇️ PRINT INI UNTUK MENGETAHUI JIKA ADA CRASH DI SISI FLUTTER
      print("ERROR CRASH DI FLUTTER: $e");
      return {'success': false, 'message': 'Kesalahan koneksi: Gagal terhubung ke server.'};
    }
  }
}