enum AutoPilotStatus { idle, running, checking, recovering, error, stopped }

class AutoPilotState {
  final AutoPilotStatus status;
  final int failCount;
  final String? message;
  final DateTime? lastCheck;
  final bool hasInternet;
  final bool hasShizukuAccess;

  const AutoPilotState({
    this.status = AutoPilotStatus.idle,
    this.failCount = 0,
    this.message,
    this.lastCheck,
    this.hasInternet = false,
    this.hasShizukuAccess = false,
  });

  AutoPilotState copyWith({
    AutoPilotStatus? status,
    int? failCount,
    String? message,
    DateTime? lastCheck,
    bool? hasInternet,
    bool? hasShizukuAccess,
  }) {
    return AutoPilotState(
      status: status ?? this.status,
      failCount: failCount ?? this.failCount,
      message: message ?? this.message,
      lastCheck: lastCheck ?? this.lastCheck,
      hasInternet: hasInternet ?? this.hasInternet,
      hasShizukuAccess: hasShizukuAccess ?? this.hasShizukuAccess,
    );
  }
}
