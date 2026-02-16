class Constants {
  static const DEV_API_URL = 'http://localhost:3000';
  static const PROD_API_URL = 'https://chat.robbiem.dev';

  static const DEV_WS_URL = 'ws://localhost:3000/ws';
  static const PROD_WS_URL = 'wss://chat.robbiem.dev/ws';

  String get API_URL {
    // means prod
    if (const bool.fromEnvironment('dart.vm.product')) {
      return PROD_API_URL;
    } else {
      return DEV_API_URL;
    }
  }

  String get WS_URL {
    // means prod
    if (const bool.fromEnvironment('dart.vm.product')) {
      return PROD_WS_URL;
    } else {
      return DEV_WS_URL;
    }
  }
}
