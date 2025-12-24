import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class LingkunganService {
  Future<List<dynamic>> fetchLingkungan(
      String token, {
        String? location,
        String? department,
        String? unitKerja,
        String? month
      }) async {
        // 1. Buat Map untuk query parameters
        final Map<String, String> queryParams = {};

        if (location != null && location != 'Semua') {
          queryParams['location'] = location;
        }
        if (department != null && department != 'Semua') {
          queryParams['department'] = department;
        }
        if (unitKerja != null && unitKerja != 'Semua') {
          queryParams['unit_kerja'] = unitKerja;
        }

        // 2. Gunakan Uri.parse dan replace untuk menggabungkan query parameters dengan aman
        // Pastikan KBaseUrl dan KLingkunganUrl digabung dengan benar
        final baseUri = Uri.parse('$KBaseUrl$KLingkunganUrl');
        final finalUri = baseUri.replace(queryParameters: queryParams);

        final response = await http.get(
          finalUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          return body['data'];
        } else {
          throw Exception('Gagal memuat data lingkungan');
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