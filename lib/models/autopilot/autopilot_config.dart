class AutoPilotConfig {
  final int checkIntervalSeconds;
  final int connectionTimeoutSeconds;
  final int maxFailCount;
  final int airplaneModeDelaySeconds;
  final int recoveryWaitSeconds;
  final int maxConsecutiveResets;
  final String pingDestination;
  final bool restartVpnAfterRecovery;

  const AutoPilotConfig({
    this.checkIntervalSeconds = 15,
    this.connectionTimeoutSeconds = 5,
    this.maxFailCount = 3,
    this.airplaneModeDelaySeconds = 3,
    this.recoveryWaitSeconds = 10,
    this.maxConsecutiveResets = 5,
    this.pingDestination = 'http://connectivitycheck.gstatic.com/generate_204',
    this.restartVpnAfterRecovery = true,
  });

  AutoPilotConfig copyWith({
    int? checkIntervalSeconds,
    int? connectionTimeoutSeconds,
    int? maxFailCount,
    int? airplaneModeDelaySeconds,
    int? recoveryWaitSeconds,
    int? maxConsecutiveResets,
    String? pingDestination,
    bool? restartVpnAfterRecovery,
  }) {
    return AutoPilotConfig(
      checkIntervalSeconds: checkIntervalSeconds ?? this.checkIntervalSeconds,
      connectionTimeoutSeconds:
          connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
      maxFailCount: maxFailCount ?? this.maxFailCount,
      airplaneModeDelaySeconds:
          airplaneModeDelaySeconds ?? this.airplaneModeDelaySeconds,
      recoveryWaitSeconds: recoveryWaitSeconds ?? this.recoveryWaitSeconds,
      maxConsecutiveResets: maxConsecutiveResets ?? this.maxConsecutiveResets,
      pingDestination: pingDestination ?? this.pingDestination,
      restartVpnAfterRecovery:
          restartVpnAfterRecovery ?? this.restartVpnAfterRecovery,
    );
  }
}
