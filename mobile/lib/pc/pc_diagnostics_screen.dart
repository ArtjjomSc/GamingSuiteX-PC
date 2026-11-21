// GamingSuite X – Bildschirm "PC-Diagnose".
// Öffnen mit:  Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const PcDiagnosticsScreen()));

import 'package:flutter/material.dart';

import 'pc_connection.dart';
import 'pc_stats.dart';

// Farben passend zum GamingSuite-X-Design.
const kBg = Color(0xFF0B0D12);
const kBar = Color(0xFF131720);
const kCard = Color(0xFF151A23);
const kBorder = Color(0xFF262D3A);
const kAccent = Color(0xFF4ADE80);
const kWarn = Color(0xFFFBBF24);
const kCrit = Color(0xFFF87171);
const kInfo = Color(0xFF60A5FA);
const kText = Color(0xFFE5E7EB);
const kDim = Color(0xFF9CA3AF);

Color loadColor(double? v, {double warn = 75, double crit = 90}) {
  if (v == null) return kDim;
  if (v >= crit) return kCrit;
  if (v >= warn) return kWarn;
  return kAccent;
}

Color tempColor(double? v) => loadColor(v, warn: 75, crit: 88);

class PcDiagnosticsScreen extends StatefulWidget {
  const PcDiagnosticsScreen({super.key});

  @override
  State<PcDiagnosticsScreen> createState() => _PcDiagnosticsScreenState();
}

class _PcDiagnosticsScreenState extends State<PcDiagnosticsScreen> {
  final pc = PcConnection.instance;

  @override
  void initState() {
    super.initState();
    if (pc.state == PcState.offline) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pc.autoConnect());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBar,
        foregroundColor: kText,
        elevation: 0,
        title: const Text('PC-DIAGNOSE',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'Verbindung',
            icon: const Icon(Icons.link),
            onPressed: () => showPcConnectSheet(context),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: pc,
        builder: (context, _) {
          final s = pc.stats;
          if (s == null) return _EmptyState(pc: pc);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _StatusBar(pc: pc, stats: s),
              if (s.warnings.isNotEmpty) _WarningsCard(s.warnings),
              _OverviewGrid(s),
              _CpuCard(s.cpu, pc.cpuHistory),
              for (final g in s.gpus) _GpuCard(g, g == s.mainGpu ? pc.gpuHistory : const <double>[]),
              _RamCard(s, pc.ramHistory),
              if (s.temps.isNotEmpty || s.fans.isNotEmpty) _SensorsCard(s),
              if (s.disks.isNotEmpty) _DisksCard(s),
              _NetworkCard(s),
              if (s.processes.isNotEmpty) _ProcessCard(s.processes),
              _SystemCard(s),
            ],
          );
        },
      ),
    );
  }
}

// ======================================================================= Teile

class _EmptyState extends StatelessWidget {
  final PcConnection pc;
  const _EmptyState({required this.pc});

  @override
  Widget build(BuildContext context) {
    final busy = pc.state == PcState.searching || pc.state == PcState.connecting;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(color: kAccent))
            else
              const Icon(Icons.desktop_access_disabled, color: kCrit, size: 56),
            const SizedBox(height: 20),
            Text(
              busy ? pc.statusText : 'Kein PC verbunden',
              style: const TextStyle(
                  color: kText, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              pc.error ??
                  'Starte auf dem PC "GamingSuite X am PC" und verbinde das Handy '
                      'mit demselben WLAN.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kDim),
            ),
            const SizedBox(height: 24),
            if (!busy) ...[
              _PrimaryButton(
                icon: Icons.search,
                label: 'AUTOMATISCH SUCHEN',
                onTap: pc.autoConnect,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => showPcConnectSheet(context),
                child: const Text('IP manuell eingeben',
                    style: TextStyle(color: kAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final PcConnection pc;
  final PcStats stats;
  const _StatusBar({required this.pc, required this.stats});

  @override
  Widget build(BuildContext context) {
    final color = pc.isOnline ? kAccent : kWarn;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${stats.hostname}  ·  ${pc.host}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
          ),
          Text(pc.statusText,
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  final List<DiagnosticWarning> warnings;
  const _WarningsCard(this.warnings);

  @override
  Widget build(BuildContext context) {
    final ordered = [...warnings]..sort((a, b) => _rank(a).compareTo(_rank(b)));
    return _Section(
      title: 'DIAGNOSE',
      icon: Icons.health_and_safety,
      child: Column(
        children: [
          for (final w in ordered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(w), size: 18, color: _color(w)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(w.text,
                          style: const TextStyle(color: kText, height: 1.3))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static int _rank(DiagnosticWarning w) =>
      w.level == 'crit' ? 0 : (w.level == 'warn' ? 1 : 2);
  static Color _color(DiagnosticWarning w) =>
      w.level == 'crit' ? kCrit : (w.level == 'warn' ? kWarn : kInfo);
  static IconData _icon(DiagnosticWarning w) => w.level == 'crit'
      ? Icons.error
      : (w.level == 'warn' ? Icons.warning_amber : Icons.info_outline);
}

class _OverviewGrid extends StatelessWidget {
  final PcStats s;
  const _OverviewGrid(this.s);

  @override
  Widget build(BuildContext context) {
    final gpu = s.mainGpu;
    final tiles = [
      _Tile(Icons.memory, 'CPU', fmtNum(s.cpu.usage), '%', loadColor(s.cpu.usage)),
      _Tile(Icons.developer_board, 'GPU', fmtNum(gpu?.usage), '%', loadColor(gpu?.usage)),
      _Tile(Icons.storage, 'RAM', fmtNum(s.ram.percent), '%', loadColor(s.ram.percent, warn: 85, crit: 95)),
      _Tile(Icons.thermostat, 'TEMP', fmtNum(s.hottest), '°C', tempColor(s.hottest)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 12), Expanded(child: tiles[1])]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 12), Expanded(child: tiles[3])]),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final Color color;
  const _Tile(this.icon, this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccent, size: 26),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(color: kDim, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$value $unit',
              style: TextStyle(
                  color: color, fontSize: 28, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CpuCard extends StatelessWidget {
  final CpuInfo c;
  final List<double> history;
  const _CpuCard(this.c, this.history);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'CPU',
      icon: Icons.memory,
      trailing: _Big('${fmtNum(c.usage)} %', loadColor(c.usage)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _Sparkline(history, loadColor(c.usage)),
          const SizedBox(height: 12),
          _KV('Temperatur', c.temp == null ? 'n/v' : '${fmtNum(c.temp)} °C',
              tempColor(c.temp)),
          _KV('Takt', c.freqMhz == null ? 'n/v' : '${fmtNum(c.freqMhz)} MHz'
              '${c.freqMaxMhz != null ? '  (max ${fmtNum(c.freqMaxMhz)})' : ''}'),
          _KV('Kerne / Threads', '${c.coresPhysical} / ${c.coresLogical}'),
          if (c.powerW != null) _KV('Verbrauch', '${fmtNum(c.powerW)} W'),
          if (c.perCore.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Auslastung pro Thread',
                style: TextStyle(color: kDim, fontSize: 12)),
            const SizedBox(height: 8),
            _CoreBars(c.perCore),
          ],
        ],
      ),
    );
  }
}

class _GpuCard extends StatelessWidget {
  final GpuInfo g;
  final List<double> history;
  const _GpuCard(this.g, this.history);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'GPU',
      icon: Icons.developer_board,
      trailing: _Big(g.usage == null ? 'n/v' : '${fmtNum(g.usage)} %',
          loadColor(g.usage)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.name, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
          if (history.length > 1) ...[
            const SizedBox(height: 12),
            _Sparkline(history, loadColor(g.usage)),
          ],
          const SizedBox(height: 12),
          _KV('Temperatur', g.temp == null ? 'n/v' : '${fmtNum(g.temp)} °C',
              tempColor(g.temp)),
          if (g.memTotalMb != null) ...[
            _KV('VRAM',
                '${fmtBytes((g.memUsedMb ?? 0.0) * 1048576)} / ${fmtBytes(g.memTotalMb! * 1048576)}'),
            _Bar(g.memPercent),
            const SizedBox(height: 6),
          ] else if (g.memUsedMb != null)
            _KV('VRAM belegt', fmtBytes(g.memUsedMb! * 1048576)),
          if (g.powerW != null)
            _KV('Verbrauch', '${fmtNum(g.powerW)} W'
                '${g.powerLimitW != null ? ' / ${fmtNum(g.powerLimitW)} W' : ''}'),
          if (g.clockMhz != null) _KV('Kerntakt', '${fmtNum(g.clockMhz)} MHz'),
          if (g.memClockMhz != null) _KV('Speichertakt', '${fmtNum(g.memClockMhz)} MHz'),
          if (g.fan != null) _KV('Lüfter', '${fmtNum(g.fan)} %'),
        ],
      ),
    );
  }
}

class _RamCard extends StatelessWidget {
  final PcStats s;
  final List<double> history;
  const _RamCard(this.s, this.history);

  @override
  Widget build(BuildContext context) {
    final c = loadColor(s.ram.percent, warn: 85, crit: 95);
    return _Section(
      title: 'ARBEITSSPEICHER',
      icon: Icons.storage,
      trailing: _Big('${fmtNum(s.ram.percent)} %', c),
      child: Column(
        children: [
          _Sparkline(history, c),
          const SizedBox(height: 12),
          _KV('Belegt', '${fmtBytes(s.ram.used)} / ${fmtBytes(s.ram.total)}'),
          _KV('Frei', fmtBytes(s.ram.total - s.ram.used)),
          if (s.swap.total > 0) ...[
            _KV('Auslagerung',
                '${fmtBytes(s.swap.used)} / ${fmtBytes(s.swap.total)}'),
            _Bar(s.swap.percent),
          ],
        ],
      ),
    );
  }
}

class _SensorsCard extends StatelessWidget {
  final PcStats s;
  const _SensorsCard(this.s);

  @override
  Widget build(BuildContext context) {
    final temps = [...s.temps]..sort((a, b) => b.value.compareTo(a.value));
    return _Section(
      title: 'SENSOREN',
      icon: Icons.thermostat,
      trailing: Text(s.sensorSource,
          style: const TextStyle(color: kDim, fontSize: 11)),
      child: Column(
        children: [
          for (final t in temps.take(16))
            _KV('${t.name}  ·  ${t.hardware}', '${fmtNum(t.value)} °C',
                tempColor(t.value)),
          if (s.fans.isNotEmpty) const Divider(color: kBorder, height: 20),
          for (final f in s.fans) _KV(f.name, '${f.rpm} RPM'),
        ],
      ),
    );
  }
}

class _DisksCard extends StatelessWidget {
  final PcStats s;
  const _DisksCard(this.s);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'LAUFWERKE',
      icon: Icons.save,
      child: Column(
        children: [
          for (final d in s.disks) ...[
            _KV('${d.mount}  (${d.fs})',
                '${fmtBytes(d.used)} / ${fmtBytes(d.total)}',
                loadColor(d.percent, warn: 90, crit: 95)),
            _Bar(d.percent, warn: 90, crit: 95),
            const SizedBox(height: 10),
          ],
          _KV('Lesen', fmtRate(s.diskReadBps)),
          _KV('Schreiben', fmtRate(s.diskWriteBps)),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final PcStats s;
  const _NetworkCard(this.s);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'NETZWERK',
      icon: Icons.wifi,
      child: Column(
        children: [
          _KV('Download', fmtRate(s.netDownBps)),
          _KV('Upload', fmtRate(s.netUpBps)),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  final List<ProcInfo> procs;
  const _ProcessCard(this.procs);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'TOP-PROZESSE',
      icon: Icons.list_alt,
      child: Column(
        children: [
          for (final p in procs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kText))),
                  SizedBox(
                    width: 64,
                    child: Text('${fmtNum(p.cpu, 1)} %',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: loadColor(p.cpu, warn: 30, crit: 60))),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(fmtBytes(p.memMb * 1048576.0),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: kDim)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final PcStats s;
  const _SystemCard(this.s);

  @override
  Widget build(BuildContext context) {
    final b = s.battery;
    return _Section(
      title: 'SYSTEM',
      icon: Icons.computer,
      child: Column(
        children: [
          _KV('PC-Name', s.hostname),
          _KV('Betriebssystem', s.os),
          _KV('Laufzeit', fmtUptime(s.uptimeS)),
          if (b != null)
            _KV('Akku', '${b.percent} %${b.plugged ? '  (lädt)' : ''}'),
        ],
      ),
    );
  }
}

// ================================================================== Bausteine

final _cardDecoration = BoxDecoration(
  color: kCard,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: kBorder),
);

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _Section(
      {required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kAccent, size: 22),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  final String text;
  final Color color;
  const _Big(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800));
}

class _KV extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _KV(this.label, this.value, [this.color]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kDim))),
          const SizedBox(width: 12),
          Text(value,
              style: TextStyle(
                  color: color ?? kText, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double? value;
  final double warn, crit;
  const _Bar(this.value, {this.warn = 75, this.crit = 90});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: ((value ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
        minHeight: 8,
        backgroundColor: kBorder,
        valueColor: AlwaysStoppedAnimation(
            loadColor(value, warn: warn, crit: crit)),
      ),
    );
  }
}

class _CoreBars extends StatelessWidget {
  final List<double> cores;
  const _CoreBars(this.cores);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (var i = 0; i < cores.length; i++)
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: (cores[i] / 100).clamp(0.02, 1.0).toDouble(),
                    widthFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: loadColor(cores[i]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text('$i', style: const TextStyle(color: kDim, fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const _Sparkline(this.data, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(List.of(data), color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = kBorder
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);
    if (data.length < 2) return;
    final dx = size.width / (PcConnection.historyLength - 1);
    final x0 = size.width - (data.length - 1) * dx;
    double y(double v) => size.height - (v.clamp(0, 100) / 100) * size.height;

    final line = Path()..moveTo(x0, y(data.first));
    for (var i = 1; i < data.length; i++) {
      line.lineTo(x0 + i * dx, y(data[i]));
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(x0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ============================================================ Verbinden-Dialog

Future<void> showPcConnectSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _ConnectSheet(),
  );
}

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet();

  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  final pc = PcConnection.instance;
  late final TextEditingController _ip =
      TextEditingController(text: pc.host ?? '');
  bool _busy = false;
  List<DiscoveredPc> _found = [];
  String? _msg;

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final r = await pc.discover();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _found = r;
      _msg = r.isEmpty
          ? 'Kein PC gefunden. Server gestartet? Gleiches WLAN?'
          : null;
    });
  }

  Future<void> _connect(String host, [int? port]) async {
    if (host.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final ok = await pc.connect(host, port: port);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _msg = pc.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MIT PC VERBINDEN',
              style: TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
              'Auf dem PC "GamingSuite X am PC" starten. Handy und PC müssen im '
              'selben WLAN sein.',
              style: TextStyle(color: kDim)),
          const SizedBox(height: 16),
          _PrimaryButton(
            icon: Icons.search,
            label: _busy ? 'BITTE WARTEN ...' : 'AUTOMATISCH SUCHEN',
            onTap: _busy ? null : _search,
          ),
          for (final f in _found)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.computer, color: kAccent),
              title: Text(f.name, style: const TextStyle(color: kText)),
              subtitle: Text('${f.host}:${f.port}',
                  style: const TextStyle(color: kDim)),
              trailing: const Icon(Icons.chevron_right, color: kDim),
              onTap: _busy ? null : () => _connect(f.host, f.port),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _ip,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: kText),
            decoration: InputDecoration(
              labelText: 'IP-Adresse des PCs (z. B. 192.168.178.20)',
              labelStyle: const TextStyle(color: kDim),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kAccent)),
            ),
            onSubmitted: (v) => _connect(v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (pc.isOnline)
                TextButton(
                  onPressed: () {
                    pc.disconnect();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Trennen', style: TextStyle(color: kCrit)),
                ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => _connect(_ip.text),
                child: const Text('VERBINDEN',
                    style: TextStyle(
                        color: kAccent, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_msg!, style: const TextStyle(color: kWarn)),
            ),
        ],
      ),
    );
  }
}
