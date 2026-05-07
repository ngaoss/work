import 'package:flutter/material.dart';
import 'package:updat/updat.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateHelper {
  static const String versionUrl =
      "https://work.deepcode.vn/updates/version.json";

  static void checkUpdate(BuildContext context) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng cập nhật chưa hỗ trợ nền tảng này'),
        ),
      );
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 450,
          height: 350,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "Kiểm tra cập nhật",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Expanded(
                child: UpdatWidget(
                  currentVersion: currentVersion,
                  appName: 'DeepCode Work',
                  getLatestVersion: () async {
                    try {
                      final response = await http.get(Uri.parse(versionUrl));
                      if (response.statusCode == 200) {
                        final data = json.decode(response.body);
                        return data['version'];
                      }
                    } catch (e) {
                      debugPrint("Error fetching version: $e");
                    }
                    return currentVersion;
                  },
                  getBinaryUrl: (latestVersion) async {
                    try {
                      final response = await http.get(Uri.parse(versionUrl));
                      if (response.statusCode == 200) {
                        final data = json.decode(response.body);
                        return data['downloadUrl'];
                      }
                    } catch (e) {
                      debugPrint("Error fetching binary URL: $e");
                    }
                    return '';
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
