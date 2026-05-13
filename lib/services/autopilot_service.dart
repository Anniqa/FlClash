import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/autopilot/autopilot_config.dart';
import 'package:fl_clash/models/autopilot/autopilot_state.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shizuku_api/shizuku_api.dart';

class AutoPilotService extends ChangeNotifier {
  static const _prefsPrefix = 'daus_autopilot_';
  static const _shizukuCommandTimeout = Duration(seconds: 4);
  static const _watchdogPriorityRefreshInterval = 5;
  static const _airplaneModeMethods = [
    ['cmd connectivity airplane-mode {action}'],
    [
      'settings put global airplane_mode_on {stateValue}',
      'am broadcast -a android.intent.action.AIRPLANE_MODE --ez state {stateBool}',
    ],
    ['svc data {svcAction}'],
  ];

  static final AutoPilotService _instance = AutoPilotService._internal();

  factory AutoPilotService() => _instance;

  AutoPilotService._internal();

  final ShizukuApi _shizuku = ShizukuApi();
  final StreamController<AutoPilotState> _stateController =
      StreamController<AutoPilotState>.broadcast();

  AutoPilotConfig _config = const AutoPilotConfig();
  AutoPilotState _currentState = const AutoPilotState();
  final List<String> _logs = [];

  Timer? _timer;
  bool _isInitialized = false;
  bool _isChecking = false;
  bool _hasShizukuAccess = false;
  bool isRunning = false;
  int _consecutiveResets = 0;
  int _watchdogRefreshCounter = 0;

  Stream<AutoPilotState> get stateStream => _stateController.stream;
  AutoPilotConfig get config => _config;
  AutoPilotState get currentState => _currentState;
  List<String> get logs => List.unmodifiable(_logs);

  static String _normalizePingDestination(String? destination) {
    final trimmed = destination?.trim() ?? '';
    if (trimmed.isEmpty) return defaultTestUrl;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return defaultTestUrl;
    if (parsed.hasScheme) {
      if ((parsed.scheme == 'http' || parsed.scheme == 'https') &&
          parsed.host.isNotEmpty) {
        return parsed.toString();
      }
      return defaultTestUrl;
    }
    final withHttps = Uri.tryParse('https://$trimmed');
    if (withHttps == null || withHttps.host.isEmpty) return defaultTestUrl;
    return withHttps.toString();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadConfig();
    _isInitialized = true;
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _config = AutoPilotConfig(
      checkIntervalSeconds:
          prefs.getInt('${_prefsPrefix}checkIntervalSeconds') ?? 15,
      connectionTimeoutSeconds:
          prefs.getInt('${_prefsPrefix}connectionTimeoutSeconds') ?? 5,
      maxFailCount: prefs.getInt('${_prefsPrefix}maxFailCount') ?? 3,
      airplaneModeDelaySeconds:
          prefs.getInt('${_prefsPrefix}airplaneModeDelaySeconds') ?? 3,
      recoveryWaitSeconds:
          prefs.getInt('${_prefsPrefix}recoveryWaitSeconds') ?? 10,
      maxConsecutiveResets:
          prefs.getInt('${_prefsPrefix}maxConsecutiveResets') ?? 5,
      pingDestination: _normalizePingDestination(
        prefs.getString('${_prefsPrefix}pingDestination'),
      ),
      restartVpnAfterRecovery:
          prefs.getBool('${_prefsPrefix}restartVpnAfterRecovery') ?? true,
    );
  }

  Future<void> updateConfig(AutoPilotConfig newConfig) async {
    final wasRunning = isRunning;
    if (wasRunning) stop();
    _config = newConfig.copyWith(
      pingDestination: _normalizePingDestination(newConfig.pingDestination),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${_prefsPrefix}checkIntervalSeconds',
      _config.checkIntervalSeconds,
    );
    await prefs.setInt(
      '${_prefsPrefix}connectionTimeoutSeconds',
      _config.connectionTimeoutSeconds,
    );
    await prefs.setInt('${_prefsPrefix}maxFailCount', _config.maxFailCount);
    await prefs.setInt(
      '${_prefsPrefix}airplaneModeDelaySeconds',
      _config.airplaneModeDelaySeconds,
    );
    await prefs.setInt(
      '${_prefsPrefix}recoveryWaitSeconds',
      _config.recoveryWaitSeconds,
    );
    await prefs.setInt(
      '${_prefsPrefix}maxConsecutiveResets',
      _config.maxConsecutiveResets,
    );
    await prefs.setString(
      '${_prefsPrefix}pingDestination',
      _config.pingDestination,
    );
    await prefs.setBool(
      '${_prefsPrefix}restartVpnAfterRecovery',
      _config.restartVpnAfterRecovery,
    );
    if (wasRunning) await start();
    notifyListeners();
  }

  Future<void> start() async {
    if (isRunning) return;
    await init();
    _hasShizukuAccess = await _ensureShizukuAccess();
    if (_hasShizukuAccess) {
      await _applyShizukuWatchdogPriority();
    }
    _timer = Timer.periodic(
      Duration(seconds: _config.checkIntervalSeconds),
      (_) => _checkAndRecover(),
    );
    isRunning = true;
    _updateState(
      _currentState.copyWith(
        status: AutoPilotStatus.running,
        failCount: 0,
        hasShizukuAccess: _hasShizukuAccess,
        message: _hasShizukuAccess
            ? 'AutoPilot aktif: Shizuku recovery siap'
            : 'AutoPilot aktif: monitor only, Shizuku belum aktif',
      ),
    );
    unawaited(_checkAndRecover());
  }

  void stop() {
    if (!isRunning) return;
    _timer?.cancel();
    _timer = null;
    isRunning = false;
    _watchdogRefreshCounter = 0;
    _updateState(
      _currentState.copyWith(
        status: AutoPilotStatus.stopped,
        message: 'AutoPilot berhenti',
      ),
    );
  }

  Future<bool> _ensureShizukuAccess() async {
    try {
      final isBinderAlive = await _shizuku.pingBinder() ?? false;
      if (!isBinderAlive) return false;
      if (await _shizuku.checkPermission() == true) return true;
      return await _shizuku.requestPermission() ?? false;
    } catch (e) {
      _addLog('Shizuku check gagal: $e');
      return false;
    }
  }

  Future<void> _checkAndRecover() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      await _refreshShizukuWatchdogPriorityIfNeeded();
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.checking,
          message: 'Mengecek koneksi...',
        ),
      );
      final hasInternet = await _hasInternetConnection();
      final lastCheck = DateTime.now();
      if (hasInternet) {
        _consecutiveResets = 0;
        _updateState(
          _currentState.copyWith(
            status: AutoPilotStatus.running,
            failCount: 0,
            lastCheck: lastCheck,
            hasInternet: true,
            message: 'Internet stabil',
          ),
        );
        return;
      }
      final newFailCount = _currentState.failCount + 1;
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.running,
          failCount: newFailCount,
          lastCheck: lastCheck,
          hasInternet: false,
          message: 'Internet putus ($newFailCount/${_config.maxFailCount})',
        ),
      );
      if (newFailCount >= _config.maxFailCount) {
        await _performRecovery();
      }
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.error,
          message: 'Check error: $e',
        ),
      );
    } finally {
      _isChecking = false;
    }
  }

  Future<bool> _hasInternetConnection() async {
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: _config.connectionTimeoutSeconds);
    try {
      final start = DateTime.now();
      final request = await client
          .getUrl(Uri.parse(_config.pingDestination))
          .timeout(Duration(seconds: _config.connectionTimeoutSeconds));
      final response = await request.close().timeout(
        Duration(seconds: _config.connectionTimeoutSeconds),
      );
      await response.drain<void>();
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final ok =
          response.statusCode == 204 ||
          (response.statusCode >= 200 && response.statusCode < 400);
      _addLog('PING ${response.statusCode} ${elapsed}ms');
      return ok;
    } catch (e) {
      _addLog('PING gagal: ${e.toString().split('\n').first}');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _performRecovery() async {
    if (_consecutiveResets >= _config.maxConsecutiveResets) {
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.error,
          message: 'Batas reset tercapai (${_config.maxConsecutiveResets})',
        ),
      );
      return;
    }
    if (!_hasShizukuAccess) {
      _hasShizukuAccess = await _ensureShizukuAccess();
    }
    if (!_hasShizukuAccess) {
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.error,
          hasShizukuAccess: false,
          message: 'Recovery dilewati: Shizuku belum aktif/izin belum ada',
        ),
      );
      return;
    }
    _consecutiveResets++;
    _updateState(
      _currentState.copyWith(
        status: AutoPilotStatus.recovering,
        message: 'Recovery mode pesawat #$_consecutiveResets...',
      ),
    );
    try {
      await _toggleAirplaneMode(true);
      await Future.delayed(Duration(seconds: _config.airplaneModeDelaySeconds));
      await _toggleAirplaneMode(false);
      await Future.delayed(Duration(seconds: _config.recoveryWaitSeconds));
      final recovered = await _hasInternetConnection();
      if (recovered && _config.restartVpnAfterRecovery) {
        await _restartVpn();
      }
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.running,
          failCount: recovered ? 0 : _currentState.failCount,
          hasInternet: recovered,
          hasShizukuAccess: true,
          message: recovered
              ? 'Recovery berhasil'
              : 'Recovery selesai, koneksi belum stabil',
        ),
      );
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: AutoPilotStatus.error,
          message: 'Recovery gagal: $e',
        ),
      );
    }
  }

  Future<void> _restartVpn() async {
    if (!appController.isAttach) return;
    if (!appController.isStart) return;
    _addLog('Restart VPN setelah recovery jaringan');
    await appController.updateStatus(false);
    await Future.delayed(const Duration(seconds: 1));
    await appController.updateStatus(true);
  }

  Future<void> _refreshShizukuWatchdogPriorityIfNeeded() async {
    if (!_hasShizukuAccess) return;
    _watchdogRefreshCounter++;
    if (_watchdogRefreshCounter % _watchdogPriorityRefreshInterval == 0) {
      await _applyShizukuWatchdogPriority();
    }
  }

  Future<void> _applyShizukuWatchdogPriority() async {
    const pkg = packageName;
    final commands = [
      'dumpsys deviceidle whitelist +$pkg',
      'cmd appops set $pkg RUN_IN_BACKGROUND allow',
      'cmd appops set $pkg RUN_ANY_IN_BACKGROUND allow',
      'cmd activity set-inactive $pkg false',
      'cmd activity set-standby-bucket $pkg active',
      'pidof $pkg | xargs -r -n 1 -I {} sh -c "renice -n -10 -p {} || true"',
      'pidof $pkg | xargs -r -n 1 -I {} sh -c "echo -900 > /proc/{}/oom_score_adj || true"',
    ];
    for (final command in commands) {
      await _runShizukuCommandSafe(command);
    }
  }

  Future<void> _runShizukuCommandSafe(String command) async {
    try {
      await _shizuku.runCommand(command).timeout(_shizukuCommandTimeout);
    } catch (_) {
      _addLog('Command ignored: $command');
    }
  }

  Future<void> _toggleAirplaneMode(bool enabled) async {
    final action = enabled ? 'enable' : 'disable';
    final stateValue = enabled ? 1 : 0;
    final stateBool = enabled.toString();
    final svcAction = enabled ? 'disable' : 'enable';
    if (enabled) {
      await _runShizukuCommandSafe(
        'settings put global airplane_mode_radios cell,nfc,wimax',
      );
    }
    Object? lastError;
    for (final method in _airplaneModeMethods) {
      try {
        for (final template in method) {
          final command = template
              .replaceAll('{action}', action)
              .replaceAll('{stateValue}', stateValue.toString())
              .replaceAll('{stateBool}', stateBool)
              .replaceAll('{svcAction}', svcAction);
          await _shizuku.runCommand(command).timeout(_shizukuCommandTimeout);
        }
        _addLog('Airplane mode ${enabled ? 'ON' : 'OFF'} via ${method.first}');
        return;
      } catch (e) {
        lastError = e;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    throw 'Unable to toggle airplane mode: $lastError';
  }

  void _updateState(AutoPilotState newState) {
    if (newState.message != null && newState.message != _currentState.message) {
      _addLog(newState.message!);
    }
    _currentState = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _logs.insert(0, '[$stamp] $message');
    if (_logs.length > 80) _logs.removeLast();
    commonPrint.log('[AutoPilot] $message');
  }

  @override
  void dispose() {
    stop();
    _stateController.close();
    super.dispose();
  }
}
