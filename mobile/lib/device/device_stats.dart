// GamingSuite X Mobile – echte Systemdaten des Smartphones.
//
// Liest nur Werte, die Android Apps ohne Root freigibt (/proc, /sys).
// Was das Gerät nicht freigibt, bleibt null und wird als "n/v" angezeigt –
// es werden keine Werte geschätzt oder erfunden.
// Benötigt keine zusätzlichen Pakete.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class DeviceStats {
  /// Anzahl CPU-Kerne.
  final int cores;

  /// Durchschnittlicher aktueller CPU-Takt aller Kerne in MHz.
  final double? cpuFreqMhz;

  /// Höchster maximaler Takt aller Kerne in MHz.
  final double? cpuMaxMhz;

  /// Arbeitsspeicher in Bytes.
  final double? ramTotal;
  final double? ramAvailable;

  /// Akkutemperatur in °C.
  final double? batteryTemp;

  /// Akkustand in %.
  final int? batteryLevel;

  /// Höchste CPU/SoC-Temperatur in °C (falls freigegeben).
  final double? socTemp;

  /// GPU-Auslastung in % (nur Adreno/Qualcomm, falls freigegeben).
  final double? gpuLoad;

  const DeviceStats({
    required this.cores,
    this.cpuFreqMhz,
    this.cpuMaxMhz,
    this.ramTotal,
    this.ramAvailable,
    this.batteryTemp,
    this.batteryLevel,
    this.socTemp,
    this.gpuLoad,
  });

  double? get ramUsed => (ramTotal != null && ramAvailable != null)
      ? ramTotal! - ramAvailable!
      : null;

  double? get ramPercent => (ramUsed != null && (ramTotal ?? 0) > 0)
      ? ramUsed! / ramTotal! * 100
      : null;

  /// Aktueller Takt im Verhältnis zum Maximaltakt (keine echte Auslastung!).
  double? get cpuFreqPercent => (cpuFreqMhz != null && (cpuMaxMhz ?? 0) > 0)
      ? (cpuFreqMhz! / cpuMaxMhz! * 100).clamp(0, 100).toDouble()
      : null;

  /// Beste verfügbare Temperatur: SoC, sonst Akku.
  double? get bestTemp => socTemp ?? batteryTemp;
  String get bestTempSource =>
      socTemp != null ? 'SoC' : (batteryTemp != null ? 'Akku' : '');

  /// Wie viele der Messwerte das Gerät freigibt.
  int get availableSensors => [
        cpuFreqMhz,
        ramTotal,
        batteryTemp,
        batteryLevel,
        socTemp,
        gpuLoad,
      ].where((v) => v != null).length;
}

class DeviceMonitor extends ChangeNotifier {
  DeviceMonitor._();
  static final DeviceMonitor instance = DeviceMonitor._();

  static const Duration interval = Duration(seconds: 2);

  DeviceStats? stats;
  Timer? _timer;
  bool _busy = false;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _update();
    _timer = Timer.periodic(interval, (_) => _update());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _update() async {
    if (_busy) return;
    _busy = true;
    try {
      final cores = Platform.numberOfProcessors;
      final freqs = await _cpuFrequencies(cores);
      final mem = await _memInfo();
      final batTemp = await _readNum('/sys/class/power_supply/battery/temp');
      final batLevel =
          await _readNum('/sys/class/power_supply/battery/capacity');

      stats = DeviceStats(
        cores: cores,
        cpuFreqMhz: freqs.$1,
        cpuMaxMhz: freqs.$2,
        ramTotal: mem.$1,
        ramAvailable: mem.$2,
        batteryTemp: _plausibleTemp(batTemp == null ? null : batTemp / 10),
        batteryLevel: batLevel?.round(),
        socTemp: await _socTemperature(),
        gpuLoad: await _gpuLoad(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceMonitor: $e');
    } finally {
      _busy = false;
    }
  }

  // ------------------------------------------------------------------- Lesen

  static Future<String?> _read(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return (await f.readAsString()).trim();
    } catch (_) {
      return null; // von Android gesperrt
    }
  }

  static Future<double?> _readNum(String path) async {
    final s = await _read(path);
    if (s == null) return null;
    final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  static double? _plausibleTemp(double? t) =>
      (t != null && t > 0 && t < 130) ? t : null;

  /// (durchschnittlicher aktueller Takt, höchster Maximaltakt) in MHz.
  static Future<(double?, double?)> _cpuFrequencies(int cores) async {
    final current = <double>[];
    double? maxAll;
    for (var i = 0; i < cores; i++) {
      final base = '/sys/devices/system/cpu/cpu$i/cpufreq';
      final cur = await _readNum('$base/scaling_cur_freq');
      final max = await _readNum('$base/cpuinfo_max_freq');
      if (cur != null && cur > 0) current.add(cur / 1000);
      if (max != null && max > 0) {
        final mhz = max / 1000;
        if (maxAll == null || mhz > maxAll) maxAll = mhz;
      }
    }
    final avg = current.isEmpty
        ? null
        : current.reduce((a, b) => a + b) / current.length;
    return (avg, maxAll);
  }

  /// (MemTotal, MemAvailable) in Bytes.
  static Future<(double?, double?)> _memInfo() async {
    final s = await _read('/proc/meminfo');
    if (s == null) return (null, null);
    double? total, available;
    for (final line in s.split('\n')) {
      final m = RegExp(r'^(\w+):\s+(\d+)').firstMatch(line);
      if (m == null) continue;
      final kb = double.parse(m.group(2)!) * 1024;
      if (m.group(1) == 'MemTotal') total = kb;
      if (m.group(1) == 'MemAvailable') available = kb;
    }
    return (total, available);
  }

  /// Höchste Temperatur der CPU-/SoC-Thermalzonen.
  static Future<double?> _socTemperature() async {
    double? best;
    try {
      final dir = Directory('/sys/class/thermal');
      if (!await dir.exists()) return null;
      await for (final e in dir.list()) {
        if (!e.path.contains('thermal_zone')) continue;
        final type = (await _read('${e.path}/type'))?.toLowerCase() ?? '';
        if (!(type.contains('cpu') ||
            type.contains('soc') ||
            type.contains('tsens') ||
            type.contains('mtktscpu'))) {
          continue;
        }
        var t = await _readNum('${e.path}/temp');
        if (t == null) continue;
        if (t > 1000) t = t / 1000; // Milligrad
        final v = _plausibleTemp(t);
        if (v != null && (best == null || v > best)) best = v;
      }
    } catch (_) {
      return null;
    }
    return best;
  }

  /// GPU-Auslastung (Qualcomm Adreno), falls lesbar.
  static Future<double?> _gpuLoad() async {
    final pct =
        await _readNum('/sys/class/kgsl/kgsl-3d0/gpu_busy_percentage');
    if (pct != null && pct >= 0 && pct <= 100) return pct;

    final busy = await _read('/sys/class/kgsl/kgsl-3d0/gpubusy');
    if (busy != null) {
      final parts = busy.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final b = double.tryParse(parts[0]);
        final t = double.tryParse(parts[1]);
        if (b != null && t != null && t > 0) {
          return (b / t * 100).clamp(0, 100).toDouble();
        }
      }
    }
    return null;
  }
}
