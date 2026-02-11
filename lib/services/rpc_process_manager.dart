import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class RpcProcessManager {
  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  String get _executableName {
    if (Platform.isWindows) return 'rpc.exe';
    return 'rpc';
  }

  String? _getExecutablePath() {
    final candidates = <String>[];

    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      candidates.addAll([
        p.join(exeDir, _executableName),
        p.join(exeDir, 'data', 'flutter_assets', 'assets', _executableName),
        p.join(exeDir, 'bin', _executableName),
      ]);
    } else if (Platform.isMacOS) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final resourcesDir = p.join(exeDir, '..', 'Resources');
      candidates.addAll([
        p.join(resourcesDir, _executableName),
        p.join(exeDir, _executableName),
        '/Applications/HindsightChat.app/Contents/Resources/$_executableName',
      ]);
    } else if (Platform.isLinux) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      candidates.addAll([
        p.join(exeDir, _executableName),
        p.join(exeDir, 'lib', _executableName),
        p.join(exeDir, 'data', _executableName),
        '/usr/lib/hindsightchat/$_executableName',
        '/opt/hindsightchat/$_executableName',
      ]);
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return null;
  }

  Future<bool> start() async {
    if (_isRunning || kIsWeb) return false;

    final execPath = _getExecutablePath();
    if (execPath == null) {
      debugPrint('[rpc] executable not found');
      return false;
    }

    try {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', execPath]);
      }

      debugPrint('[rpc] starting: $execPath');
      _process = await Process.start(
        execPath,
        [],
        mode: ProcessStartMode.detachedWithStdio,
      );

      _isRunning = true;

      _process!.stdout.listen((data) {
        debugPrint('[rpc:out] ${String.fromCharCodes(data).trim()}');
      });

      _process!.stderr.listen((data) {
        debugPrint('[rpc:err] ${String.fromCharCodes(data).trim()}');
      });

      _process!.exitCode.then((code) {
        debugPrint('[rpc] exited with code: $code');
        _isRunning = false;
        _process = null;
      });

      return true;
    } catch (e) {
      debugPrint('[rpc] failed to start: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (_process == null) return;

    debugPrint('[rpc] stopping');
    _process!.kill(ProcessSignal.sigterm);

    await Future.delayed(const Duration(milliseconds: 500));

    if (_isRunning) {
      _process!.kill(ProcessSignal.sigkill);
    }

    _process = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
  }
}
