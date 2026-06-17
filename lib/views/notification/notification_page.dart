import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🌟 Ditambahkan untuk RemoteMessage

final ValueNotifier<List<Map<String, dynamic>>> appNotificationsNotifier = ValueNotifier([]);
final ValueNotifier<bool> hasUnreadNotifNotifier = ValueNotifier(false);

String? activeUserIdentifier;

class NotificationManager {

  // 🌟 FUNGSI BARU: Khusus untuk menyimpan notifikasi dari Pusher (Websocket) atau sistem lokal
  static Future<void> saveLocalNotification(Map<String, dynamic> newNotif) async {
    if (activeUserIdentifier == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Wajib sinkronisasi Isolate

    String targetKey = 'notifs_$activeUserIdentifier';
    final String? rawData = prefs.getString(targetKey);
    List<dynamic> currentList = rawData != null ? jsonDecode(rawData) : [];

    // Langsung simpan di paling atas (Karena Pusher tidak pernah duplikat dari OS)
    currentList.insert(0, newNotif);

    await prefs.setString(targetKey, jsonEncode(currentList));

    // Update Layar Real-time
    appNotificationsNotifier.value = currentList.map((e) => Map<String, dynamic>.from(e)).toList();
    hasUnreadNotifNotifier.value = true;

    debugPrint("✅ SAVED: Pesan Pusher Panggilan Pemeriksaan berhasil disimpan ke kotak masuk.");
  }

  static Future<void> loadUserNotifications(String userIdentifier) async {
    activeUserIdentifier = userIdentifier;
    final prefs = await SharedPreferences.getInstance();

    // 🌟 BEST PRACTICE: Wajib reload agar memori Isolate sinkron dengan Background Disk!
    await prefs.reload();

    final String? data = prefs.getString('notifs_$userIdentifier');
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      appNotificationsNotifier.value = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      appNotificationsNotifier.value = [];
    }
  }

  // 🌟 BEST PRACTICE: Fungsi Tunggal Penyelamat Notifikasi (Dipanggil dari mana saja aman!)
  static Future<void> saveIncomingMessage(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Wajib sinkronisasi Isolate

    // 1. Dapatkan KTP Unik Notifikasi dari Firebase (Atau buat hash fallback jika null)
    String title = message.notification?.title ?? message.data['title'] ?? 'Notifikasi STMC';
    String body = message.notification?.body ?? message.data['body'] ?? '';
    String msgId = message.messageId ?? (title + body).hashCode.toString();

    // 2. Baca User Aktif di Disk
    final userDataJson = prefs.getString('userData');
    String? savedIdentifier;
    if (userDataJson != null) {
      final data = jsonDecode(userDataJson);
      savedIdentifier = data['no_sap'] ?? data['nik'];
    }

    // 3. Shield Guard (Blokir Notif Nyasar)
    String? recipientSap = message.data['recipient_sap'] ?? 'ALL';
    if (savedIdentifier != null && recipientSap != 'ALL' && recipientSap.toString().toLowerCase() != savedIdentifier.toString().toLowerCase()) {
      debugPrint("🛑 DIBLOKIR: Notifikasi milik $recipientSap nyasar ke perangkat ini.");
      return;
    }

    // 4. Ambil Data Brankas Saat Ini
    String targetKey = savedIdentifier != null ? 'notifs_$savedIdentifier' : 'notifs_unknown';
    final String? rawData = prefs.getString(targetKey);
    List<dynamic> currentList = rawData != null ? jsonDecode(rawData) : [];

    // 5. PENGECEKAN DUPLIKASI BERDASARKAN KTP UNIK (MESSAGE ID)
    int existingIndex = currentList.indexWhere((n) => n['messageId'] == msgId);
    String actionLink = message.data['action_link'] ?? message.data['link'] ?? '';

    if (existingIndex != -1) {
      // JIKA SUDAH ADA: Cek apakah Linknya kosong. Jika kosong, tambal dengan link baru!
      String oldLink = (currentList[existingIndex]['action_link'] ?? '').toString().trim();
      if (oldLink.isEmpty && actionLink.isNotEmpty) {
        currentList[existingIndex]['action_link'] = actionLink;
        await prefs.setString(targetKey, jsonEncode(currentList));
        debugPrint("🔄 UPDATE: Menambal Action Link yang hilang dari OS Android.");
      } else {
        debugPrint("⚠️ SKIP: Pesan dengan ID $msgId sudah ada. Abaikan duplikat.");
      }
    } else {
      // JIKA BARU: Simpan di paling atas
      currentList.insert(0, {
        'messageId': msgId,
        'title': title,
        'body': body,
        'action_link': actionLink,
        'recipient_sap': recipientSap,
        'time': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      });
      await prefs.setString(targetKey, jsonEncode(currentList));
      debugPrint("✅ SAVED: Pesan baru dengan ID $msgId berhasil disimpan.");
    }

    // 6. Update Layar Real-time jika user sedang membuka aplikasi
    if (activeUserIdentifier != null && activeUserIdentifier == savedIdentifier) {
      appNotificationsNotifier.value = currentList.map((e) => Map<String, dynamic>.from(e)).toList();
      hasUnreadNotifNotifier.value = true;
    }
  }

  static Future<void> clearSession() async {
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka link.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error membuka link: $e')));
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
            onPressed: () async {
              appNotificationsNotifier.value = [];
              if (activeUserIdentifier != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('notifs_$activeUserIdentifier', jsonEncode([]));
              }
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
                  Text("Belum ada notifikasi baru", style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
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

              String rawLink = (notif['action_link'] ?? '').toString().trim();
              String? link = rawLink.isNotEmpty ? rawLink : null;
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
                      if (link != null) ...[
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
                            onPressed: () {
                              if (link.startsWith('route:')) {
                                String routeName = link.replaceFirst('route:', '');
                                Navigator.pushNamed(context, routeName);
                              } else {
                                _launchURL(context, link);
                              }
                            },
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