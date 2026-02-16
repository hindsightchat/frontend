import 'package:flutter/material.dart';

typedef SidebarBuilder = Widget? Function(BuildContext context);

class SidebarProvider extends ChangeNotifier {
  SidebarBuilder? _sidebarBuilder;
  bool _isDisposed = false;

  SidebarBuilder? get sidebarBuilder => _sidebarBuilder;

  void setSidebar(SidebarBuilder? builder) {
    if (_isDisposed) return;

    if (builder == null) {
      _sidebarBuilder = null;
    } else {
      _sidebarBuilder = builder;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  void clearSidebar() {
    if (_isDisposed) return;

    _sidebarBuilder = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
