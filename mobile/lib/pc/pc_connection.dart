// GamingSuite X – Verbindung zum PC-Server (findet den PC automatisch im WLAN).
// Benötigt keine zusätzlichen Pakete (nur dart:io).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'pc_games_data.dart';
import 'pc_stats.dart';

enum PcState { offline, searching, connecting, online, lost }

class DiscoveredPc {
  final String host;
  final int port;
  final String name;
  const DiscoveredPc(this.host, this.port, this.name);
}

class PcConnection extends ChangeNotifier {
  PcConnection._() {
    _loadPin();
  }
  static final PcConnection instance = PcConnection._();

  /// PIN aus den PC-Einstellungen ("Handy-/Browser-Zugriff"). Leer = keine PIN.
  String pin = '';
  int? _lastStatus;

  File get _pinFile =>
      File('${Directory.systemTemp.parent.path}/gsx_pin.txt');

  void _loadPin() {
    try {
      if (_pinFile.existsSync()) pin = _pinFile.readAsStringSync().trim();
    } catch (_) {}
  }

  void setPin(String value) {
    pin = value.trim();
    try {
      _pinFile.writeAsStringSync(pin);
    } catch (_) {}
  }

  String _failText(String h, int p) {
    if (_lastStatus == 401) {
      return pin.isEmpty
          ? 'Der PC verlangt eine PIN. Bitte unten die PIN aus den '
              'PC-Einstellungen eingeben.'
          : 'PIN falsch. Bitte die PIN aus den PC-Einstellungen prüfen.';
    }
    if (_lastStatus == 403) {
      return 'Handy-Zugriff ist am PC ausgeschaltet '
          '(Einstellungen -> Handy-/Browser-Zugriff).';
    }
    if (_lastStatus != null) {
      return 'PC antwortet mit Fehler HTTP $_lastStatus.';
    }
    return 'Keine Verbindung zu $h:$p. Server gestartet? Firewall erlaubt?';
  }

  static const int discoveryPort = 47800;
  static const int defaultPort = 47801;
  static const Duration pollInterval = Duration(seconds: 1);
  static const int historyLength = 60;

  PcState state = PcState.offline;
  String? host;
  int port = defaultPort;
  PcStats? stats;
  String? error;

  final List<double> cpuHistory = [];
  final List<double> gpuHistory = [];
  final List<double> ramHistory = [];

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);
  Timer? _timer;
  bool _busy = false;
  int _failures = 0;

  bool get isOnline => state == PcState.online;

  String get statusText {
    switch (state) {
      case PcState.online:
        return 'ONLINE';
      case PcState.searching:
        return 'SUCHE ...';
      case PcState.connecting:
        return 'VERBINDE ...';
      case PcState.lost:
        return 'GETRENNT';
      case PcState.offline:
        return 'OFFLINE';
    }
  }

  // ------------------------------------------------------------- Suche im WLAN

  Future<List<DiscoveredPc>> discover(
      {Duration timeout = const Duration(seconds: 3)}) async {
    final found = <String, DiscoveredPc>{};
    RawDatagramSocket? socket;
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket = s;
      s.broadcastEnabled = true;
      s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = s.receive();
        if (dg == null) return;
        try {
          final data = jsonDecode(utf8.decode(dg.data));
          if (data is Map && data['service'] == 'gamingsuite-x') {
            final h = dg.address.address;
            found[h] = DiscoveredPc(
              h,
              (data['port'] as num?)?.toInt() ?? defaultPort,
              (data['name'] ?? h).toString(),
            );
          }
        } catch (_) {}
      });

      final targets = await _broadcastTargets();
      final msg = utf8.encode('GSX_DISCOVER');
      final start = DateTime.now();
      while (DateTime.now().difference(start) < timeout) {
        for (final t in targets) {
          try {
            s.send(msg, t, discoveryPort);
          } catch (_) {}
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (found.isNotEmpty &&
            DateTime.now().difference(start) > const Duration(seconds: 1)) {
          break;
        }
      }
    } catch (e) {
      error = 'Suche fehlgeschlagen: $e';
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  Future<List<InternetAddress>> _broadcastTargets() async {
    final targets = <String>{'255.255.255.255'};
    try {
      final ifaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final i in ifaces) {
        for (final a in i.addresses) {
          final p = a.address.split('.');
          if (p.length == 4 && !a.isLoopback) {
            targets.add('${p[0]}.${p[1]}.${p[2]}.255');
          }
        }
      }
    } catch (_) {}
    return targets.map(InternetAddress.new).toList();
  }

  // ---------------------------------------------------------------- Verbinden

  /// Sucht den PC und verbindet sich mit dem ersten Treffer.
  Future<bool> autoConnect() async {
    error = null;
    _setState(PcState.searching);
    final pcs = await discover();
    if (pcs.isEmpty) {
      error = 'Kein PC gefunden. Läuft der Server und ist das Handy im '
          'selben WLAN? Sonst IP manuell eingeben.';
      _setState(PcState.offline);
      return false;
    }
    return connect(pcs.first.host, port: pcs.first.port);
  }

  /// Verbindet sich mit einer IP, z. B. "192.168.1.20" oder "192.168.1.20:47801".
  Future<bool> connect(String address, {int? port}) async {
    disconnect(notify: false);
    var h = address.trim();
    var p = port ?? defaultPort;
    if (h.contains(':')) {
      final parts = h.split(':');
      h = parts[0];
      p = int.tryParse(parts[1]) ?? p;
    }
    host = h;
    this.port = p;
    error = null;
    _setState(PcState.connecting);

    _lastStatus = null;
    final ok = await _poll();
    if (!ok) {
      error = _failText(h, p);
      _setState(PcState.offline);
      return false;
    }
    _timer = Timer.periodic(pollInterval, (_) => _poll());
    return true;
  }

  void disconnect({bool notify = true}) {
    _timer?.cancel();
    _timer = null;
    stats = null;
    _failures = 0;
    cpuHistory.clear();
    gpuHistory.clear();
    ramHistory.clear();
    state = PcState.offline;
    if (notify) notifyListeners();
  }

  // ---------------------------------------------------------------- Abfragen

  /// Spiele-Messungen vom PC (nur lesen). null = nicht verbunden / alter PC-Stand.
  Future<GamesData?> fetchGames() async {
    if (host == null) return null;
    try {
      return GamesData.fromJson(await _getJson('/api/games'));
    } catch (_) {
      return null;
    }
  }

  Future<bool> _poll() async {
    if (_busy || host == null) return false;
    _busy = true;
    try {
      final s = PcStats.fromJson(await _getJson('/api/stats'));
      stats = s;
      _push(cpuHistory, s.cpu.usage);
      _push(gpuHistory, s.mainGpu?.usage);
      _push(ramHistory, s.ram.percent);
      _failures = 0;
      error = null;
      state = PcState.online;
      notifyListeners();
      return true;
    } catch (e) {
      _failures++;
      if (state == PcState.online && _failures >= 3) {
        state = PcState.lost;
        error = (_lastStatus == 401 || _lastStatus == 403)
            ? _failText(host ?? '', port)
            : 'Verbindung zum PC unterbrochen ...';
        notifyListeners();
      }
      // Nach ca. 30 s ohne Antwort aufgeben.
      if (_failures >= 30 && _timer != null) {
        _timer?.cancel();
        _timer = null;
        state = PcState.offline;
        error = 'PC antwortet nicht mehr.';
        notifyListeners();
      }
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = Uri(scheme: 'http', host: host, port: port, path: path);
    final req = await _client.getUrl(uri).timeout(const Duration(seconds: 3));
    if (pin.isNotEmpty) req.headers.set('X-GSX-Pin', pin);
    final res = await req.close().timeout(const Duration(seconds: 3));
    if (path == '/api/stats') _lastStatus = res.statusCode;
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: uri);
    }
    final body = await res
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 3));
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  void _push(List<double> list, double? v) {
    if (v == null) return;
    list.add(v);
    if (list.length > historyLength) list.removeAt(0);
  }

  void _setState(PcState s) {
    state = s;
    notifyListeners();
  }
}
