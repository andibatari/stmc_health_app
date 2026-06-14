import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =======================================================
// BRANKAS GLOBAL
// =======================================================
final ValueNotifier<List<Map<String, dynamic>>> appNotificationsNotifier = ValueNotifier([]);
final ValueNotifier<bool> hasUnreadNotifNotifier = ValueNotifier(false);

// Menyimpan identitas user yang sedang aktif
String? activeUserIdentifier;

// =======================================================
// MANAJER BRANKAS PRIBADI
// =======================================================
class NotificationManager {
  // Buka brankas khusus untuk user yang baru login
  static Future<void> loadUserNotifications(String userIdentifier) async {
    activeUserIdentifier = userIdentifier;
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('notifs_$userIdentifier');

    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      appNotificationsNotifier.value = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      appNotificationsNotifier.value = [];
    }
  }

  // Simpan notifikasi ke memori HP khusus untuk user ini
  static Future<void> saveUserNotifications() async {
    if (activeUserIdentifier == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notifs_$activeUserIdentifier', jsonEncode(appNotificationsNotifier.value));
  }

  // 🔥 FUNGSI BARU: FILTER ANTI-DUPLIKASI (PENCEGAH NOTIF DOUBLE)
  static void addNotification(Map<String, dynamic> newNotif) {
    if (activeUserIdentifier == null) return;

    final currentList = appNotificationsNotifier.value;

    // Filter Super Ketat: Cek apakah notifikasi yang baru masuk KEMBAR dengan notifikasi di urutan teratas
    if (currentList.isNotEmpty) {
      final topNotif = currentList.first;
      if (topNotif['title'] == newNotif['title'] && topNotif['body'] == newNotif['body']) {
        debugPrint("⚠️ Notifikasi kembar ditolak masuk ke halaman.");
        return; // Dibuang, jangan disimpan
      }
    }

    // Jika aman, masukkan ke list paling atas
    appNotificationsNotifier.value = [newNotif, ...currentList];
    hasUnreadNotifNotifier.value = true;
    saveUserNotifications();
  }

  // Bersihkan layar saat Logout
  static void clearSession() {
    activeUserIdentifier = null;
    appNotificationsNotifier.value = [];
    hasUnreadNotifNotifier.value = false;
  }
}

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka link tersebut.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error membuka link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFC00000);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Bersihkan Notifikasi",
            onPressed: () {
              appNotificationsNotifier.value = [];
              NotificationManager.saveUserNotifications();
            },
          )
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: appNotificationsNotifier,
        builder: (context, notifications, child) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada notifikasi baru",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final String title = notif['title'] ?? 'Tanpa Judul';
              final String body = notif['body'] ?? '';
              final String? link = notif['link'];
              final String time = notif['time'] ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.notifications_active, color: primaryRed, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(body, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                const SizedBox(height: 8),
                                Text(time, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (link != null && link.isNotEmpty) ...[
                        const Divider(height: 25),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text("Buka Tautan Lampiran"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _launchURL(context, link),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}