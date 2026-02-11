import 'package:flutter/material.dart';

typedef SidebarBuilder = Widget? Function(BuildContext context);

class SidebarProvider extends ChangeNotifier {
  SidebarBuilder? _sidebarBuilder;
  
  SidebarBuilder? get sidebarBuilder => _sidebarBuilder;
  
  void setSidebar(SidebarBuilder? builder) {
    _sidebarBuilder = builder;
    notifyListeners();
  }
  
  void clearSidebar() {
    _sidebarBuilder = null;
    notifyListeners();
  }
}
