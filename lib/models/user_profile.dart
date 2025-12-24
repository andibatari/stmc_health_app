class UserProfile {
  final String type;
  final int id;
  final String nama;
  final String? noSap;
  final String nik;
  final String? departemen;
  final bool isEmployee;
  final String? email; // Hanya ada jika Pasien Non-Karyawan
  final String? tinggi_badan;
  final String? berat_badan;
  final String? no_hp;

  UserProfile({
    required this.type,
    required this.id,
    required this.nama,
    this.noSap,
    required this.nik,
    this.departemen,
    required this.isEmployee,
    this.email,
    this.tinggi_badan,
    this.berat_badan,
    this.no_hp,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      type: json['type'] as String,
      id: json['id'] as int,
      nama: json['nama'] as String,
      noSap: json['no_sap'] as String?,
      nik: json['nik'] as String,
      departemen: json['departemen'] as String?,
      isEmployee: json['is_employee'] as bool,
      email: json['email'] as String?,
      tinggi_badan: json['tinggi_badan'] as String?,
      berat_badan: json['berat_badan'] as String?,
      no_hp: json['no_hp'] as String?,
    );
  }
}