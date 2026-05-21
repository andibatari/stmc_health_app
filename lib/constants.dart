const String KBaseUrl = "https://stmc-health.my.id/api";
const String KLoginUrl = "/login"; // Endpoint Login
const String KLogoutUrl = "/logout"; // Endpoint Logout

const String KChangePasswordUrl = "/change-password";
final String changePasswordUrl = '$KBaseUrl$KChangePasswordUrl';

const String KSubmitJadwalUrl = "/jadwal-mcu/ajukan";
const String KRiwayatJadwalUrl = "/jadwal-mcu/riwayat";
const String KUpdateProfileUrl = "/update-profile"; // Tambahkan ini

// --- ENDPOINT PEMANTAUAN LINGKUNGAN ---
const String KLingkunganUrl = "/lingkungan"; // Endpoint untuk data utama
const String KLingkunganFilterUrl = "/lingkungan/filters"; // Endpoint untuk filter dinamis

const String KGetPaketMcuUrl = "/jadwal-mcu/paket";