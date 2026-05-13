class AutoPilotConfig {
  final int checkIntervalSeconds;
  final int connectionTimeoutSeconds;
  final int maxFailCount;
  final int airplaneModeDelaySeconds;
  final int recoveryWaitSeconds;
  final int recoveryCooldownSeconds;
  final int vpnGracePeriodSeconds;
  final int maxConsecutiveResets;
  final String pingDestination;
  final bool restartVpnAfterRecovery;
  final bool simpleMode;

  const AutoPilotConfig({
    this.checkIntervalSeconds = 15,
    this.connectionTimeoutSeconds = 5,
    this.maxFailCount = 3,
    this.airplaneModeDelaySeconds = 3,
    this.recoveryWaitSeconds = 10,
    this.recoveryCooldownSeconds = 180,
    this.vpnGracePeriodSeconds = 20,
    this.maxConsecutiveResets = 5,
    this.pingDestination = 'http://connectivitycheck.gstatic.com/generate_204',
    this.restartVpnAfterRecovery = true,
    this.simpleMode = true,
  });

  AutoPilotConfig copyWith({
    int? checkIntervalSeconds,
    int? connectionTimeoutSeconds,
    int? maxFailCount,
    int? airplaneModeDelaySeconds,
    int? recoveryWaitSeconds,
    int? recoveryCooldownSeconds,
    int? vpnGracePeriodSeconds,
    int? maxConsecutiveResets,
    String? pingDestination,
    bool? restartVpnAfterRecovery,
    bool? simpleMode,
  }) {
    return AutoPilotConfig(
      checkIntervalSeconds: checkIntervalSeconds ?? this.checkIntervalSeconds,
      connectionTimeoutSeconds:
          connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
      maxFailCount: maxFailCount ?? this.maxFailCount,
      airplaneModeDelaySeconds:
          airplaneModeDelaySeconds ?? this.airplaneModeDelaySeconds,
      recoveryWaitSeconds: recoveryWaitSeconds ?? this.recoveryWaitSeconds,
      recoveryCooldownSeconds:
          recoveryCooldownSeconds ?? this.recoveryCooldownSeconds,
      vpnGracePeriodSeconds:
          vpnGracePeriodSeconds ?? this.vpnGracePeriodSeconds,
      maxConsecutiveResets: maxConsecutiveResets ?? this.maxConsecutiveResets,
      pingDestination: pingDestination ?? this.pingDestination,
      restartVpnAfterRecovery:
          restartVpnAfterRecovery ?? this.restartVpnAfterRecovery,
      simpleMode: simpleMode ?? this.simpleMode,
    );
  }
}
