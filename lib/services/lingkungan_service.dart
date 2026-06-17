import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class LingkunganService {
  Future<Map<String,dynamic>> fetchLingkungan(
      String token, {
        String? location,
        String? department,
        String? unitKerja,
        String? startDate,
        String? endDate,
        int page = 1,
        int perPage = 50
      }) async {

    final Map<String, String> queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (location != null && location != 'Semua') queryParams['location'] = location;
    if (department != null && department != 'Semua') queryParams['department'] = department;
    if (unitKerja != null && unitKerja != 'Semua') queryParams['unit_kerja'] = unitKerja;

    // Menambahkan filter tanggal jika dipilih
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final finalUri = Uri.parse('$KBaseUrl$KLingkunganUrl').replace(queryParameters: queryParams);

    final response = await http.get(
      finalUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // 🔥 PERBAIKAN: Sekarang kita return seluruh body agar Flutter bisa baca 'meta' (untuk paginasi)
      return body;
    } else {
      throw Exception('Gagal memuat data lingkungan: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchFilters(String token) async {
    final response = await http.get(
      Uri.parse('$KBaseUrl$KLingkunganFilterUrl'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Gagal memuat filter");
  }
}