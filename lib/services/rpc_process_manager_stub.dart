class RpcProcessManager {
  bool get isRunning => false;

  Future<bool> start() async => false;
  Future<void> stop() async {}
  void dispose() {}
}
