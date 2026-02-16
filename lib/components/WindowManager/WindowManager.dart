import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/services/rpc_process_manager.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowManager extends StatefulWidget {
  final Widget child;
  const WindowManager({super.key, required this.child});

  @override
  // ignore: no_logic_in_create_state
  State<WindowManager> createState() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return _WindowManagerState();
    } else {
      return _WindowManagerStubState();
    }
  }
}

class _WindowManagerStubState extends State<WindowManager> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _WindowManagerState extends State<WindowManager>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);
    trayManager.addListener(this);
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseDown() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  void onCloseApplication() async {
    DataProvider dataProvider = Provider.of<DataProvider>(
      context,
      listen: false,
    );

    AuthProvider authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    dataProvider.dispose(); // force cleanup of data provider
    authProvider.dispose(); // force cleanup of auth provider
    KillRPCProcess(); // ensure rpc process is killed on app exit

    // hide window immediately to prevent user from interacting with app while cleanup is happening
    await windowManager.hide();

    // then allow window to close
    await windowManager.destroy();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit') {
      onCloseApplication();
    }
  }

  @override
  void onWindowClose() async {
    // this is triggered when user clicks the close button on the window, we want to override this to hide the window instead of closing it, so that the app continues running in the background and can be accessed from the system tray
    await windowManager.hide();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
