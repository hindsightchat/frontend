import 'package:flutter/material.dart';

typedef MobilePageBuilder = Widget Function(BuildContext context);

class MobileNavigationProvider extends ChangeNotifier {
  MobilePageBuilder? _pageBuilder;
  MobilePageBuilder? _lastPageBuilder; 
  bool _isPageOpen = false;
  
  MobilePageBuilder? get pageBuilder => _pageBuilder;
  MobilePageBuilder? get lastPageBuilder => _lastPageBuilder;
  bool get isPageOpen => _isPageOpen;
  bool get hasLastPage => _lastPageBuilder != null;
  
  void openPage(MobilePageBuilder builder) {
    _pageBuilder = builder;
    _lastPageBuilder = builder; 
    _isPageOpen = true;
    notifyListeners();
  }
  
  void reopenLastPage() {
    if (_lastPageBuilder != null) {
      _pageBuilder = _lastPageBuilder;
      _isPageOpen = true;
      notifyListeners();
    }
  }
  
  void closePage() {
    _isPageOpen = false;
    notifyListeners();
  }
  
  void clearPage() {
    _pageBuilder = null;
    notifyListeners();
  }
}
