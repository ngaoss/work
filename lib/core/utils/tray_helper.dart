import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayHelper with TrayListener {
  static final TrayHelper _instance = TrayHelper._internal();
  factory TrayHelper() => _instance;
  TrayHelper._internal();

  static VoidCallback? _onShowApp;

  static Future<void> initialize(VoidCallback onShowApp) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    _onShowApp = onShowApp;
    trayManager.removeListener(_instance);
    trayManager.addListener(_instance);

    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/work_icon.png',
    );

    List<MenuItem> items = [
      MenuItem(key: 'show_app', label: 'Hiện ứng dụng'),
      MenuItem.separator(),
      MenuItem(key: 'quit_app', label: 'Thoát'),
    ];
    await trayManager.setContextMenu(Menu(items: items));
    await trayManager.setToolTip('DeepCode Work');
  }

  @override
  void onTrayIconMouseDown() {
    _onShowApp?.call();
  }

  @override
  void onTrayIconMouseUp() {
    _onShowApp?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_app') {
      _onShowApp?.call();
    } else if (menuItem.key == 'quit_app') {
      exit(0);
    }
  }
}
