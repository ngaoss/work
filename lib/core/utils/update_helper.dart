import 'package:flutter/material.dart';
import 'package:updat/updat.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateHelper {
  static const String versionUrl =
      "https://raw.githubusercontent.com/ngaoss/work/main/version.json";

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

  static void checkUpdate(BuildContext context) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng cập nhật chưa hỗ trợ nền tảng này'),
        ),
      );
      return;
    }

    _cachedUpdateData = null; // Reset cache on manual check
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          height: 380,
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                const Text(
                  "KIỂM TRA CẬP NHẬT",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.blueGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: UpdatWidget(
                    currentVersion: currentVersion,
                    appName: 'DeepCode Work',
                    getLatestVersion: () async {
                      final data = await _fetchUpdateData();
                      return data?['version']?.toString() ?? currentVersion;
                    },
                    getBinaryUrl: (latestVersion) async {
                      final data = await _fetchUpdateData();
                      return data?['downloadUrl']?.toString() ?? '';
                    },
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
