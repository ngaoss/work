import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:updat/updat.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class UpdateHelper {
  static const String versionUrl =
      "https://raw.githubusercontent.com/ngaoss/work/main/version.json";

  static const _channel = MethodChannel('com.deepcode.flutter_app/apk_installer');
  static File? _downloadedFile;

  static Future<void> _installApkAndroid() async {
    if (_downloadedFile == null) {
      debugPrint("UpdateHelper: _downloadedFile is null!");
      return;
    }
    try {
      final success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': _downloadedFile!.path,
      });
      debugPrint("UpdateHelper: APK installation triggered: $success");
    } catch (e) {
      debugPrint("UpdateHelper: Error launching APK installer: $e");
    }
  }

  // Cache response to avoid multiple requests
  static Map<String, dynamic>? _cachedUpdateData;

  static Future<Map<String, dynamic>?> _fetchUpdateData() async {
    if (_cachedUpdateData != null) return _cachedUpdateData;
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        if (response.body.contains("<!DOCTYPE html>")) return null;
        _cachedUpdateData = json.decode(response.body);
        return _cachedUpdateData;
      }
    } catch (e) {
      debugPrint("UpdateHelper error: $e");
    }
    return null;
  }

  static Future<bool> isUpdateAvailable() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final data = await _fetchUpdateData();
    if (data == null) return false;
    final latestVersion = data['version']?.toString();
    if (latestVersion == null) return false;

    // Simple semantic version comparison logic (can be improved)
    try {
      final cleanCurrent = currentVersion.split('+')[0];
      final cleanLatest = latestVersion.split('+')[0];

      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final latestParts = cleanLatest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      return latestVersion != currentVersion;
    }
    return false;
  }

  static Future<void> openDownloadLink(BuildContext context) async {
    final data = await _fetchUpdateData();
    String? url;
    if (Platform.isAndroid) {
      url = (data?['androidUrl'] ?? data?['downloadUrl'])?.toString();
    } else if (Platform.isMacOS) {
      url = (data?['macosUrl'] ?? data?['downloadUrl'])?.toString();
    } else {
      url = (data?['windowsUrl'] ?? data?['downloadUrl'])?.toString();
    }

    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết tải về')),
          );
        }
      }
    }
  }

  static void checkUpdate(BuildContext context) async {
    if (!Platform.isWindows &&
        !Platform.isLinux &&
        !Platform.isMacOS &&
        !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng cập nhật chưa hỗ trợ nền tảng này'),
        ),
      );
      return;
    }

    _cachedUpdateData = null; // Reset cache on manual check

    // Hiện loading nhẹ trong khi check
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang kiểm tra bản cập nhật...'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }

    final hasUpdate = await isUpdateAvailable();
    if (!hasUpdate && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "Thông báo",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Bạn đang sử dụng phiên bản mới nhất."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: 420,
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              children: [
                // Header với Gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_alt_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "PHIÊN BẢN MỚI",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Material(
                      color: Colors.transparent,
                      child: UpdatWidget(
                        currentVersion: currentVersion,
                        appName: 'DeepCode Work',
                        openOnDownload: !Platform.isAndroid,
                        getLatestVersion: () async {
                          final data = await _fetchUpdateData();
                          return data?['version']?.toString() ?? currentVersion;
                        },
                        getBinaryUrl: (latestVersion) async {
                          final data = await _fetchUpdateData();
                          if (Platform.isAndroid) {
                            return (data?['androidUrl'] ?? data?['downloadUrl'])
                                    ?.toString() ??
                                '';
                          } else if (Platform.isMacOS) {
                            return (data?['macosUrl'] ?? data?['downloadUrl'])
                                    ?.toString() ??
                                '';
                          }
                          return (data?['windowsUrl'] ?? data?['downloadUrl'])
                                  ?.toString() ??
                              '';
                        },
                        getDownloadFileLocation: (latestVersion) async {
                          final downloadDir = await getDownloadsDirectory();
                          if (downloadDir == null) {
                            throw Exception('Unable to get downloads directory');
                          }
                          final ext = Platform.isAndroid ? 'apk' : 'exe';
                          final file = File('${downloadDir.path}/DeepCode Work-$latestVersion.$ext');
                          _downloadedFile = file;
                          return file;
                        },
                        callback: (status) {
                          if (status == UpdatStatus.readyToInstall && Platform.isAndroid) {
                            _installApkAndroid();
                          }
                        },
                        updateChipBuilder: ({
                          required BuildContext context,
                          required String? latestVersion,
                          required String appVersion,
                          required UpdatStatus status,
                          required void Function() checkForUpdate,
                          required void Function() openDialog,
                          required void Function() startUpdate,
                          required Future<void> Function() launchInstaller,
                          required void Function() dismissUpdate,
                        }) {
                          switch (status) {
                            case UpdatStatus.checking:
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF3B82F6)),
                                    SizedBox(height: 12),
                                    Text(
                                      "Đang kiểm tra bản cập nhật...",
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            case UpdatStatus.available:
                            case UpdatStatus.availableWithChangelog:
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Bản cập nhật $latestVersion đã sẵn sàng!",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: startUpdate,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: const Icon(Icons.download_rounded),
                                      label: const Text("Tải và Cập nhật"),
                                    ),
                                  ],
                                ),
                              );
                            case UpdatStatus.downloading:
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF3B82F6)),
                                    SizedBox(height: 12),
                                    Text(
                                      "Đang tải bản cập nhật...",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            case UpdatStatus.readyToInstall:
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Đã tải xong bản cập nhật!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (Platform.isAndroid) {
                                          _installApkAndroid();
                                        } else {
                                          launchInstaller();
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text("Cài đặt ngay"),
                                    ),
                                  ],
                                ),
                              );
                            case UpdatStatus.error:
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Có lỗi xảy ra khi tải bản cập nhật.",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: startUpdate,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text("Thử lại"),
                                    ),
                                  ],
                                ),
                              );
                            case UpdatStatus.upToDate:
                              return const Center(
                                child: Text(
                                  "Ứng dụng đã ở phiên bản mới nhất.",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            default:
                              return const SizedBox.shrink();
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "ĐÓNG",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
