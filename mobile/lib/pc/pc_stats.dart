// GamingSuite X – Datenmodell für die PC-Diagnose.

double? _d(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
int? _i(dynamic v) => v is num ? v.toInt() : null;
String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) => v is List
    ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList()
    : <T>[];

class CpuInfo {
  final String name;
  final int coresPhysical;
  final int coresLogical;
  final double usage;
  final List<double> perCore;
  final double? freqMhz;
  final double? freqMaxMhz;
  final double? temp;
  final double? powerW;

  CpuInfo.fromJson(Map<String, dynamic> j)
      : name = _s(j['name'], 'CPU'),
        coresPhysical = _i(j['cores_physical']) ?? 0,
        coresLogical = _i(j['cores_logical']) ?? 0,
        usage = _d(j['usage']) ?? 0,
        perCore = (j['per_core'] is List)
            ? (j['per_core'] as List).map((e) => _d(e) ?? 0.0).toList()
            : <double>[],
        freqMhz = _d(j['freq_mhz']),
        freqMaxMhz = _d(j['freq_max_mhz']),
        temp = _d(j['temp']),
        powerW = _d(j['power_w']);
}

class GpuInfo {
  final String name;
  final String vendor;
  final double? usage;
  final double? memUsedMb;
  final double? memTotalMb;
  final double? temp;
  final double? powerW;
  final double? powerLimitW;
  final double? fan;
  final double? clockMhz;
  final double? memClockMhz;

  GpuInfo.fromJson(Map<String, dynamic> j)
      : name = _s(j['name'], 'GPU'),
        vendor = _s(j['vendor']),
        usage = _d(j['usage']),
        memUsedMb = _d(j['mem_used_mb']),
        memTotalMb = _d(j['mem_total_mb']),
        temp = _d(j['temp']),
        powerW = _d(j['power_w']),
        powerLimitW = _d(j['power_limit_w']),
        fan = _d(j['fan']),
        clockMhz = _d(j['clock_mhz']),
        memClockMhz = _d(j['mem_clock_mhz']);

  double? get memPercent => (memUsedMb != null && (memTotalMb ?? 0) > 0)
      ? memUsedMb! / memTotalMb! * 100
      : null;
}

class MemInfo {
  final double total;
  final double used;
  final double percent;

  MemInfo.fromJson(Map<String, dynamic> j)
      : total = _d(j['total']) ?? 0,
        used = _d(j['used']) ?? 0,
        percent = _d(j['percent']) ?? 0;
}

class DiskInfo {
  final String mount;
  final String fs;
  final double total;
  final double used;
  final double percent;

  DiskInfo.fromJson(Map<String, dynamic> j)
      : mount = _s(j['mount']),
        fs = _s(j['fs']),
        total = _d(j['total']) ?? 0,
        used = _d(j['used']) ?? 0,
        percent = _d(j['percent']) ?? 0;
}

class SensorReading {
  final String hardware;
  final String name;
  final double value;

  SensorReading.fromJson(Map<String, dynamic> j)
      : hardware = _s(j['hardware']),
        name = _s(j['name']),
        value = _d(j['value']) ?? 0;
}

class FanReading {
  final String name;
  final int rpm;

  FanReading.fromJson(Map<String, dynamic> j)
      : name = _s(j['name']),
        rpm = _i(j['rpm']) ?? 0;
}

class ProcInfo {
  final String name;
  final int pid;
  final double cpu;
  final int memMb;

  ProcInfo.fromJson(Map<String, dynamic> j)
      : name = _s(j['name'], '?'),
        pid = _i(j['pid']) ?? 0,
        cpu = _d(j['cpu']) ?? 0,
        memMb = _i(j['mem_mb']) ?? 0;
}

class DiagnosticWarning {
  /// 'crit', 'warn' oder 'info'
  final String level;
  final String text;

  DiagnosticWarning.fromJson(Map<String, dynamic> j)
      : level = _s(j['level'], 'info'),
        text = _s(j['text']);
}

class BatteryInfo {
  final int percent;
  final bool plugged;
  final int? secsLeft;

  BatteryInfo.fromJson(Map<String, dynamic> j)
      : percent = _i(j['percent']) ?? 0,
        plugged = j['plugged'] == true,
        secsLeft = _i(j['secs_left']);
}

/// Laufendes Spiel am PC und Status der FPS-Messung.
class RunningGame {
  final String name;
  final bool measuring;
  final int? secondsLeft;
  final int? waitSeconds;

  RunningGame.fromJson(Map<String, dynamic> j)
      : name = _s(j['name'], 'Spiel'),
        measuring = j['measuring'] == true,
        secondsLeft = _i(j['secondsLeft']),
        waitSeconds = _i(j['waitSeconds']);
}

class PcStats {
  final RunningGame? game;
  final String hostname;
  final String os;
  final int uptimeS;
  final CpuInfo cpu;
  final List<GpuInfo> gpus;
  final MemInfo ram;
  final MemInfo swap;
  final List<DiskInfo> disks;
  final double? diskReadBps;
  final double? diskWriteBps;
  final double netUpBps;
  final double netDownBps;
  final BatteryInfo? battery;
  final List<SensorReading> temps;
  final List<FanReading> fans;
  final List<ProcInfo> processes;
  final List<DiagnosticWarning> warnings;
  final String sensorSource;

  PcStats.fromJson(Map<String, dynamic> j)
      : game = j['game'] is Map ? RunningGame.fromJson(_m(j['game'])) : null,
        hostname = _s(j['hostname'], 'PC'),
        os = _s(j['os']),
        uptimeS = _i(j['uptime_s']) ?? 0,
        cpu = CpuInfo.fromJson(_m(j['cpu'])),
        gpus = _list(j['gpus'], GpuInfo.fromJson),
        ram = MemInfo.fromJson(_m(j['ram'])),
        swap = MemInfo.fromJson(_m(j['swap'])),
        disks = _list(j['disks'], DiskInfo.fromJson),
        diskReadBps = _d(_m(j['disk_io'])['read_bps']),
        diskWriteBps = _d(_m(j['disk_io'])['write_bps']),
        netUpBps = _d(_m(j['net'])['up_bps']) ?? 0,
        netDownBps = _d(_m(j['net'])['down_bps']) ?? 0,
        battery = j['battery'] is Map
            ? BatteryInfo.fromJson(_m(j['battery']))
            : null,
        temps = _list(j['temps'], SensorReading.fromJson),
        fans = _list(j['fans'], FanReading.fromJson),
        processes = _list(j['processes'], ProcInfo.fromJson),
        warnings = _list(j['warnings'], DiagnosticWarning.fromJson),
        sensorSource = _s(j['sensor_source']);

  GpuInfo? get mainGpu {
    if (gpus.isEmpty) return null;
    // Bevorzugt die dedizierte Karte (mit Auslastung bzw. NVIDIA/AMD).
    for (final g in gpus) {
      if (g.usage != null && g.vendor != 'Intel') return g;
    }
    return gpus.first;
  }

  /// Höchste bekannte Temperatur (CPU oder GPU) – für die Dashboard-Kachel.
  double? get hottest {
    final vals = <double>[
      if (cpu.temp != null) cpu.temp!,
      for (final g in gpus)
        if (g.temp != null) g.temp!,
    ];
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a > b ? a : b);
  }
}

// ---------------------------------------------------------------- Formatierung

String fmtBytes(double? b) {
  if (b == null) return '--';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String fmtRate(double? bps) => bps == null ? '--' : '${fmtBytes(bps)}/s';

String fmtUptime(int s) {
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h ${m}m';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String fmtNum(double? v, [int digits = 0]) =>
    v == null ? '--' : v.toStringAsFixed(digits);
