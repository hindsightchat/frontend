import 'package:flutter/material.dart';

typedef SidebarBuilder = Widget? Function(BuildContext context);

class SidebarProvider extends ChangeNotifier {
  SidebarBuilder? _sidebarBuilder;
  
  SidebarBuilder? get sidebarBuilder => _sidebarBuilder;
  
  /// Set a builder function for the sidebar content.
  /// The builder will be called on every rebuild, so it can react to provider changes.
  void setSidebar(SidebarBuilder? builder) {
    _sidebarBuilder = builder;
    notifyListeners();
  }
  
  /// Clear the sidebar (reverts to default)
  void clearSidebar() {
    _sidebarBuilder = null;
    notifyListeners();
  }
}
