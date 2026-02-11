typedef IpcMessageCallback = void Function(Map<String, dynamic> data);

class IpcServer {
  bool get isRunning => false;

  Future<void> start({int port = 19542}) async {}
  void onMessage(IpcMessageCallback callback) {}
  void removeListener(IpcMessageCallback callback) {}
  void broadcast(Map<String, dynamic> data) {}
  Future<void> stop() async {}
  void dispose() {}
}
