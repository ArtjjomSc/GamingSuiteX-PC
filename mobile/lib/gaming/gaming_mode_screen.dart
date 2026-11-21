// GamingSuite X Mobile – Gaming Mode: Vollbild-Monitor für den PC.
//
// - Vollbild ohne Status-/Navigationsleiste
// - Bildschirm bleibt an (über MainActivity, Kanal "gsx/screen")
// - Große Anzeigen für CPU, GPU, Temperatur, RAM + Verlauf + Infoleiste
// - Hoch- und Querformat
// - Einmal tippen: Schließen-Knopf einblenden

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pc/pc_connection.dart';
import '../pc/pc_diagnostics_screen.dart'
    show showPcConnectSheet, kAccent, kCrit, kWarn, loadColor, tempColor;
import '../pc/pc_stats.dart';

const _kCyan = Color(0xFF22D3EE);
const _kPanel = Color(0xFF0E1218);
const _kDim = Color(0xFF8B95A5);

class GamingModeScreen extends StatefulWidget {
  const GamingModeScreen({super.key});

  @override
  State<GamingModeScreen> createState() => _GamingModeScreenState();
}

class _GamingModeScreenState extends State<GamingModeScreen> {
  static const _screen = MethodChannel('gsx/screen');

  final pc = PcConnection.instance;
  Timer? _clockTimer;
  Timer? _hideTimer;
  DateTime _now = DateTime.now();
  bool _controlsVisible = false;

  /// null = unbekannt, true = Bildschirm bleibt an, false = nicht möglich.
  bool? _keepOnActive;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setKeepScreenOn(true);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (pc.state == PcState.offline) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pc.autoConnect());
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _hideTimer?.cancel();
    _setKeepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _setKeepScreenOn(bool on) async {
    try {
      await _screen.invokeMethod<void>('keepOn', on);
      if (on && mounted) setState(() => _keepOnActive = true);
    } catch (_) {
      // MainActivity noch nicht erweitert -> Bildschirm geht nach Timeout aus.
      if (on && mounted) setState(() => _keepOnActive = false);
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _hideTimer?.cancel();
    if (_controlsVisible) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  String get _clock =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: pc,
                  builder: (context, _) {
                    final s = pc.stats;
                    if (s == null) return _buildOffline(context);
                    return _buildMonitor(s);
                  },
                ),
              ),
              if (_controlsVisible) _buildControls(context),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ohne PC

  Widget _buildOffline(BuildContext context) {
    final busy =
        pc.state == PcState.searching || pc.state == PcState.connecting;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(color: kAccent),
              )
            else
              const Icon(Icons.desktop_access_disabled, color: kCrit, size: 52),
            const SizedBox(height: 16),
            Text(
              busy ? pc.statusText : 'Kein PC verbunden',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              pc.error ??
                  'GamingSuite X am PC starten (selbes WLAN) und verbinden.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kDim),
            ),
            if (!busy) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        side: const BorderSide(color: kAccent)),
                    onPressed: pc.autoConnect,
                    icon: const Icon(Icons.search),
                    label: const Text('SUCHEN'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        side: const BorderSide(color: kAccent)),
                    onPressed: () => showPcConnectSheet(context),
                    icon: const Icon(Icons.link),
                    label: const Text('IP EINGEBEN'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Monitor

  Widget _buildMonitor(PcStats s) {
    final gpu = s.mainGpu;
    final temp = s.hottest;
    final tempLabel = (gpu?.temp != null && gpu!.temp == temp) ? 'GPU TEMP' : 'TEMP';

    final gauges = <Widget>[
      _Gauge(
        label: 'CPU',
        value: s.cpu.usage,
        unit: '%',
        color: loadColor(s.cpu.usage),
        sub: s.cpu.temp != null
            ? '${fmtNum(s.cpu.temp)} °C'
            : (s.cpu.freqMhz != null
                ? '${(s.cpu.freqMhz! / 1000).toStringAsFixed(2)} GHz'
                : ''),
      ),
      _Gauge(
        label: 'GPU',
        value: gpu?.usage,
        unit: '%',
        color: loadColor(gpu?.usage),
        sub: gpu?.powerW != null ? '${fmtNum(gpu!.powerW)} W' : '',
      ),
      _Gauge(
        label: tempLabel,
        value: temp,
        unit: '°C',
        color: tempColor(temp),
        sub: (s.cpu.temp != null && tempLabel == 'GPU TEMP')
            ? 'CPU ${fmtNum(s.cpu.temp)} °C'
            : '',
      ),
      _Gauge(
        label: 'RAM',
        value: s.ram.percent,
        unit: '%',
        color: loadColor(s.ram.percent, warn: 85, crit: 95),
        sub: '${fmtBytes(s.ram.used)} / ${fmtBytes(s.ram.total)}',
      ),
    ];

    final alerts =
        s.warnings.where((w) => w.level == 'crit' || w.level == 'warn').toList();

    return LayoutBuilder(
      builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              _TopBar(
                name: s.hostname,
                online: pc.isOnline,
                status: pc.statusText,
                clock: _clock,
                game: s.game,
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 6),
                _AlertBanner(
                  text: alerts.first.text,
                  critical: alerts.first.level == 'crit',
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                flex: landscape ? 6 : 5,
                child: landscape
                    ? Row(
                        children: [
                          for (final g in gauges) Expanded(child: g),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Row(children: [
                              Expanded(child: gauges[0]),
                              Expanded(child: gauges[1]),
                            ]),
                          ),
                          Expanded(
                            child: Row(children: [
                              Expanded(child: gauges[2]),
                              Expanded(child: gauges[3]),
                            ]),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: landscape ? 2 : 2,
                child: _HistoryChart(
                  cpu: List.of(pc.cpuHistory),
                  gpu: List.of(pc.gpuHistory),
                ),
              ),
              const SizedBox(height: 8),
              _InfoBar(stats: s),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kPanel.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_keepOnActive == false)
              const Padding(
                padding: EdgeInsets.only(left: 8, right: 4),
                child: Text('Bildschirm-An nicht aktiv',
                    style: TextStyle(color: kWarn, fontSize: 11)),
              ),
            IconButton(
              tooltip: 'Verbindung',
              icon: const Icon(Icons.link, color: Colors.white70),
              onPressed: () => showPcConnectSheet(context),
            ),
            IconButton(
              tooltip: 'Gaming Mode beenden',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================== Teile

class _TopBar extends StatelessWidget {
  final String name;
  final bool online;
  final String status;
  final String clock;
  final RunningGame? game;

  const _TopBar({
    required this.name,
    required this.online,
    required this.status,
    required this.clock,
    this.game,
  });

  @override
  Widget build(BuildContext context) {
    final color = online ? kAccent : kWarn;
    return Row(
      children: [
        Icon(Icons.sports_esports, color: kAccent.withValues(alpha: 0.9), size: 20),
        const SizedBox(width: 8),
        const Text('GAMING MODE',
            style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 13)),
        const SizedBox(width: 12),
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        if (game != null && game!.measuring) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: kCrit.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kCrit.withValues(alpha: 0.7)),
            ),
            child: Text(
              'MESSUNG ${game!.secondsLeft != null ? '${game!.secondsLeft! ~/ 60}:${(game!.secondsLeft! % 60).toString().padLeft(2, '0')}' : ''}',
              style: const TextStyle(color: kCrit, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            online ? (game != null ? '$name · ${game!.name}' : name) : '$name · $status',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Text(clock,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String text;
  final bool critical;
  const _AlertBanner({required this.text, required this.critical});

  @override
  Widget build(BuildContext context) {
    final color = critical ? kCrit : kWarn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(critical ? Icons.error : Icons.warning_amber, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final Color color;
  final String sub;

  const _Gauge({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.max(40.0, math.min(box.maxWidth, box.maxHeight) - 8);
        final fraction = ((value ?? 0) / 100).clamp(0.0, 1.0).toDouble();
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _GaugePainter(fraction: fraction, color: color),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: _kDim,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                fontSize: 14)),
                        Text(
                          value == null ? 'n/v' : '${value!.round()}$unit',
                          style: TextStyle(
                              color: value == null ? _kDim : color,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                        if (sub.isNotEmpty)
                          Text(sub,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  _GaugePainter({required this.fraction, required this.color});

  static const _start = math.pi * 0.75; // unten links
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final bg = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, bg);
    if (fraction <= 0) return;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * fraction, false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

class _HistoryChart extends StatelessWidget {
  final List<double> cpu;
  final List<double> gpu;
  const _HistoryChart({required this.cpu, required this.gpu});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _Legend(color: kAccent, text: 'CPU'),
              SizedBox(width: 14),
              _Legend(color: _kCyan, text: 'GPU'),
              Spacer(),
              Text('letzte 60 s',
                  style: TextStyle(color: _kDim, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _HistoryPainter(cpu: cpu, gpu: gpu),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: _kDim, fontSize: 10)),
      ],
    );
  }
}

class _HistoryPainter extends CustomPainter {
  final List<double> cpu;
  final List<double> gpu;
  _HistoryPainter({required this.cpu, required this.gpu});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _line(canvas, size, gpu, _kCyan);
    _line(canvas, size, cpu, kAccent);
  }

  void _line(Canvas canvas, Size size, List<double> data, Color color) {
    if (data.length < 2) return;
    final dx = size.width / (PcConnection.historyLength - 1);
    final x0 = size.width - (data.length - 1) * dx;
    double y(double v) =>
        size.height - (v.clamp(0, 100).toDouble() / 100) * size.height;
    final path = Path()..moveTo(x0, y(data.first));
    for (var i = 1; i < data.length; i++) {
      path.lineTo(x0 + i * dx, y(data[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter old) => true;
}

class _InfoBar extends StatelessWidget {
  final PcStats stats;
  const _InfoBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final gpu = stats.mainGpu;
    final top = stats.processes.isNotEmpty ? stats.processes.first : null;
    final items = <(IconData, String)>[
      if (gpu?.memTotalMb != null)
        (
          Icons.memory_outlined,
          'VRAM ${fmtBytes((gpu!.memUsedMb ?? 0.0) * 1048576)} / ${fmtBytes(gpu.memTotalMb! * 1048576)}'
        ),
      (Icons.arrow_downward, fmtRate(stats.netDownBps)),
      (Icons.arrow_upward, fmtRate(stats.netUpBps)),
      if (top != null) (Icons.bolt, '${top.name} ${fmtNum(top.cpu, 1)} %'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kPanel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, size: 14, color: kAccent),
                  const SizedBox(width: 6),
                  Text(item.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
