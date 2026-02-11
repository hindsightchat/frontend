import 'package:flutter/material.dart';

typedef MobilePageBuilder = Widget Function(BuildContext context);

class MobileNavigationProvider extends ChangeNotifier {
  MobilePageBuilder? _pageBuilder;
  MobilePageBuilder? _lastPageBuilder; // Keep track of last page for swipe-to-open
  bool _isPageOpen = false;
  
  MobilePageBuilder? get pageBuilder => _pageBuilder;
  MobilePageBuilder? get lastPageBuilder => _lastPageBuilder;
  bool get isPageOpen => _isPageOpen;
  bool get hasLastPage => _lastPageBuilder != null;
  
  /// Open a page as a sliding sheet on mobile
  void openPage(MobilePageBuilder builder) {
    _pageBuilder = builder;
    _lastPageBuilder = builder; // Store as last page
    _isPageOpen = true;
    notifyListeners();
  }
  
  /// Re-open the last page (for swipe gesture)
  void reopenLastPage() {
    if (_lastPageBuilder != null) {
      _pageBuilder = _lastPageBuilder;
      _isPageOpen = true;
      notifyListeners();
    }
  }
  
  /// Close the current page
  void closePage() {
    _isPageOpen = false;
    notifyListeners();
  }
  
  /// Clear the page builder (called after animation completes)
  void clearPage() {
    _pageBuilder = null;
    // Don't clear _lastPageBuilder so we can reopen
    notifyListeners();
  }
}
