import 'package:fl_clash/models/autopilot/autopilot_config.dart';
import 'package:fl_clash/models/autopilot/autopilot_state.dart';
import 'package:fl_clash/services/autopilot_service.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AutoPilotView extends StatefulWidget {
  const AutoPilotView({super.key});

  @override
  State<AutoPilotView> createState() => _AutoPilotViewState();
}

class _AutoPilotViewState extends State<AutoPilotView> {
  final _service = AutoPilotService();
  bool _busy = false;
  late final TextEditingController _destinationController;

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(
      text: _service.config.pingDestination,
    );
    _service.init().then((_) {
      if (!mounted) return;
      _destinationController.text = _service.config.pingDestination;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Color _statusColor(AutoPilotStatus status) {
    return switch (status) {
      AutoPilotStatus.running => Colors.green,
      AutoPilotStatus.checking => Colors.blue,
      AutoPilotStatus.recovering => Colors.orange,
      AutoPilotStatus.error => Colors.red,
      AutoPilotStatus.idle || AutoPilotStatus.stopped => Colors.grey,
    };
  }

  IconData _statusIcon(AutoPilotStatus status) {
    return switch (status) {
      AutoPilotStatus.running => Icons.radar,
      AutoPilotStatus.checking => Icons.sync,
      AutoPilotStatus.recovering => Icons.flight_takeoff,
      AutoPilotStatus.error => Icons.error_outline,
      AutoPilotStatus.idle || AutoPilotStatus.stopped => Icons.stop_circle,
    };
  }

  bool _isRunning(AutoPilotStatus status) {
    return status != AutoPilotStatus.idle && status != AutoPilotStatus.stopped;
  }

  Future<void> _toggle(AutoPilotStatus status) async {
    setState(() => _busy = true);
    try {
      if (_isRunning(status)) {
        _service.stop();
      } else {
        await _service.start();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update(AutoPilotConfig config) async {
    await _service.updateConfig(config);
    if (mounted) setState(() {});
  }

  Future<void> _openShizuku() async {
    await launchUrl(
      Uri.parse('https://shizuku.rikka.app/download/'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _numberSlider({
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle),
          trailing: Text('$value$unit'),
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value$unit',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }

  Widget _buildStatus(AutoPilotState state) {
    final color = _statusColor(state.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(_statusIcon(state.status), color: color, size: 48),
            const SizedBox(height: 8),
            Text(
              state.status.name.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (state.message != null) ...[
              const SizedBox(height: 8),
              Text(state.message!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    state.hasShizukuAccess ? Icons.verified : Icons.warning,
                    size: 18,
                  ),
                  label: Text(
                    state.hasShizukuAccess ? 'Shizuku ready' : 'Monitor only',
                  ),
                ),
                Chip(
                  avatar: Icon(
                    state.hasInternet ? Icons.wifi : Icons.wifi_off,
                    size: 18,
                  ),
                  label: Text(state.hasInternet ? 'Online' : 'Offline'),
                ),
                Chip(
                  label: Text(
                    'Fail ${state.failCount}/${_service.config.maxFailCount}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(AutoPilotState state) {
    final running = _isRunning(state.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _toggle(state.status),
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              label: Text(running ? 'Stop AutoPilot' : 'Start AutoPilot'),
            ),
            TextButton.icon(
              onPressed: _openShizuku,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Install / buka panduan Shizuku'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    final cfg = _service.config;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monitoring',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            _numberSlider(
              title: 'Check interval',
              subtitle: 'Jeda antar health-check internet',
              value: cfg.checkIntervalSeconds,
              min: 5,
              max: 60,
              unit: 's',
              onChanged: (v) => _update(cfg.copyWith(checkIntervalSeconds: v)),
            ),
            _numberSlider(
              title: 'Ping timeout',
              subtitle: 'Batas tunggu tiap health-check',
              value: cfg.connectionTimeoutSeconds,
              min: 2,
              max: 15,
              unit: 's',
              onChanged: (v) =>
                  _update(cfg.copyWith(connectionTimeoutSeconds: v)),
            ),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Ping destination',
                hintText: 'http://connectivitycheck.gstatic.com/generate_204',
              ),
              onSubmitted: (v) => _update(cfg.copyWith(pingDestination: v)),
            ),
            const Divider(height: 32),
            const Text(
              'Recovery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            _numberSlider(
              title: 'Max fail count',
              subtitle: 'Jumlah gagal sebelum mode pesawat dipicu',
              value: cfg.maxFailCount,
              min: 1,
              max: 10,
              unit: 'x',
              onChanged: (v) => _update(cfg.copyWith(maxFailCount: v)),
            ),
            _numberSlider(
              title: 'Airplane duration',
              subtitle: 'Lama mode pesawat ON sebelum dimatikan lagi',
              value: cfg.airplaneModeDelaySeconds,
              min: 1,
              max: 10,
              unit: 's',
              onChanged: (v) =>
                  _update(cfg.copyWith(airplaneModeDelaySeconds: v)),
            ),
            _numberSlider(
              title: 'Recovery wait',
              subtitle: 'Waktu tunggu setelah tiap level recovery',
              value: cfg.recoveryWaitSeconds,
              min: 5,
              max: 30,
              unit: 's',
              onChanged: (v) => _update(cfg.copyWith(recoveryWaitSeconds: v)),
            ),
            _numberSlider(
              title: 'Recovery cooldown',
              subtitle: 'Jeda aman sebelum recovery berat berikutnya',
              value: cfg.recoveryCooldownSeconds,
              min: 30,
              max: 300,
              unit: 's',
              onChanged: (v) =>
                  _update(cfg.copyWith(recoveryCooldownSeconds: v)),
            ),
            _numberSlider(
              title: 'VPN grace period',
              subtitle: 'Abaikan fail setelah start/restart VPN',
              value: cfg.vpnGracePeriodSeconds,
              min: 5,
              max: 60,
              unit: 's',
              onChanged: (v) => _update(cfg.copyWith(vpnGracePeriodSeconds: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Restart VPN after recovery'),
              subtitle: const Text(
                'FlClash restart setelah jaringan hidup lagi',
              ),
              value: cfg.restartVpnAfterRecovery,
              onChanged: (v) =>
                  _update(cfg.copyWith(restartVpnAfterRecovery: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogs() {
    final logs = _service.logs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity log',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text('Belum ada log.')
            else
              for (final log in logs.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'AutoPilot',
      body: StreamBuilder<AutoPilotState>(
        stream: _service.stateStream,
        initialData: _service.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _service.currentState;
          return ListView(
            padding: const EdgeInsets.all(16).copyWith(bottom: 32),
            children: [
              _buildStatus(state),
              _buildControls(state),
              _buildSettings(),
              _buildLogs(),
              const SizedBox(height: 8),
              const Text(
                'AutoPilot v2: multi-target health check → restart VPN → reset mobile data → airplane cellular reset. Wi‑Fi/hotspot dijaga agar tidak ikut masuk airplane radios.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
