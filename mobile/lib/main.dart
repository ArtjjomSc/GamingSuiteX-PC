import 'package:flutter/material.dart';

import 'device/device_stats.dart';
import 'gaming/gaming_mode_screen.dart';
import 'pc/pc_connection.dart';
import 'pc/pc_diagnostics_screen.dart';
import 'pc/pc_games_screen.dart';
import 'pc/pc_stats.dart';

void main() {
  runApp(const GamingSuiteXApp());
}

class GamingSuiteXApp extends StatelessWidget {
  const GamingSuiteXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GamingSuite X',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090B10),
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.cyanAccent,
        ),
      ),
      home: const GamingDashboard(),
    );
  }
}

// ======================================================
// DASHBOARD
// ======================================================

class GamingDashboard extends StatefulWidget {
  const GamingDashboard({super.key});

  @override
  State<GamingDashboard> createState() => _GamingDashboardState();
}

class _GamingDashboardState extends State<GamingDashboard> {
  final device = DeviceMonitor.instance;
  final pc = PcConnection.instance;

  @override
  void initState() {
    super.initState();
    device.start();
    // Einmal still nach einem PC im WLAN suchen. Findet er keinen,
    // bleibt "PC Connection" einfach OFFLINE.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pc.state == PcState.offline) pc.autoConnect();
    });
  }

  @override
  void dispose() {
    device.stop();
    super.dispose();
  }

  void _openPc() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PcDiagnosticsScreen()),
    );
  }

  void _openGames() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PcGamesScreen()),
    );
  }

  void _openGamingMode() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GamingModeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF10141C),
        elevation: 0,
        title: const Text(
          'GAMINGSUITE X',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'PC-Verbindung',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showPcConnectSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([device, pc]),
          builder: (context, _) {
            final cards = _buildCards(device.stats, pc.isOnline ? pc.stats : null);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'SYSTEM DASHBOARD',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      SourceChip(isPc: pc.isOnline),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Feste Kartenhöhe statt GridView mit childAspectRatio:
                  // verhindert "BOTTOM OVERFLOWED" bei jeder Bildschirmbreite
                  // und Schriftgröße.
                  Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[3]),
                    ],
                  ),

                  const SizedBox(height: 20),

                  StatusPanel(
                    deviceSensors: device.stats?.availableSensors ?? 0,
                    pc: pc,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'GAMING',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          icon: Icons.sports_esports,
                          label: 'GAMING MODE',
                          onPressed: _openGamingMode,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionButton(
                          icon: Icons.link,
                          label: 'PC CONNECT',
                          onPressed: _openPc,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      icon: Icons.insights,
                      label: 'SPIELE-MESSUNGEN',
                      onPressed: _openGames,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Baut die vier Karten. Ist ein PC verbunden, zeigen sie die PC-Werte,
  /// sonst die echten Werte des Smartphones. Nicht freigegebene Werte = "n/v".
  List<Widget> _buildCards(DeviceStats? d, PcStats? p) {
    if (p != null) {
      final gpu = p.mainGpu;
      return [
        SystemCard(
          icon: Icons.memory,
          title: 'CPU',
          value: '${fmtNum(p.cpu.usage)} %',
          subtitle: 'PC · ${p.cpu.name}',
          level: p.cpu.usage,
        ),
        SystemCard(
          icon: Icons.developer_board,
          title: 'GPU',
          value: gpu?.usage == null ? 'n/v' : '${fmtNum(gpu!.usage)} %',
          subtitle: gpu == null ? 'PC · keine GPU erkannt' : 'PC · ${gpu.name}',
          level: gpu?.usage,
        ),
        SystemCard(
          icon: Icons.storage,
          title: 'RAM',
          value: '${fmtNum(p.ram.percent)} %',
          subtitle: 'PC · ${fmtBytes(p.ram.used)} / ${fmtBytes(p.ram.total)}',
          level: p.ram.percent,
        ),
        SystemCard(
          icon: Icons.thermostat,
          title: 'TEMPERATURE',
          value: p.hottest == null ? 'n/v' : '${fmtNum(p.hottest)} °C',
          subtitle: p.hottest == null
              ? 'PC · Sensor nicht verfügbar'
              : 'PC · höchster Wert CPU/GPU',
          level: p.hottest,
          warnAt: 75,
          critAt: 88,
          showBar: false,
        ),
      ];
    }

    if (d == null) {
      return const [
        SystemCard(icon: Icons.memory, title: 'CPU', value: '-- %', subtitle: 'Lese Daten ...'),
        SystemCard(icon: Icons.developer_board, title: 'GPU', value: '-- %', subtitle: 'Lese Daten ...'),
        SystemCard(icon: Icons.storage, title: 'RAM', value: '-- %', subtitle: 'Lese Daten ...'),
        SystemCard(icon: Icons.thermostat, title: 'TEMPERATURE', value: '-- °C', subtitle: 'Lese Daten ...'),
      ];
    }

    final ghz = d.cpuFreqMhz == null ? null : d.cpuFreqMhz! / 1000;
    final maxGhz = d.cpuMaxMhz == null ? null : d.cpuMaxMhz! / 1000;

    return [
      // Android gibt Apps keine echte CPU-Auslastung frei (/proc/stat gesperrt).
      // Angezeigt wird deshalb ehrlich der aktuelle Takt.
      SystemCard(
        icon: Icons.memory,
        title: 'CPU-TAKT',
        value: ghz == null ? 'n/v' : '${ghz.toStringAsFixed(2)} GHz',
        subtitle: 'Handy · ${d.cores} Kerne'
            '${maxGhz != null ? ' · max ${maxGhz.toStringAsFixed(2)} GHz' : ''}',
        level: d.cpuFreqPercent,
      ),
      SystemCard(
        icon: Icons.developer_board,
        title: 'GPU',
        value: d.gpuLoad == null ? 'n/v' : '${fmtNum(d.gpuLoad)} %',
        subtitle: d.gpuLoad == null
            ? 'Handy · vom Gerät nicht freigegeben'
            : 'Handy · Adreno',
        level: d.gpuLoad,
      ),
      SystemCard(
        icon: Icons.storage,
        title: 'RAM',
        value: d.ramPercent == null ? 'n/v' : '${fmtNum(d.ramPercent)} %',
        subtitle: d.ramTotal == null
            ? 'Handy · nicht lesbar'
            : 'Handy · ${fmtBytes(d.ramUsed)} / ${fmtBytes(d.ramTotal)}',
        level: d.ramPercent,
        warnAt: 85,
        critAt: 95,
      ),
      SystemCard(
        icon: Icons.thermostat,
        title: 'TEMPERATURE',
        value: d.bestTemp == null ? 'n/v' : '${d.bestTemp!.toStringAsFixed(1)} °C',
        subtitle: d.bestTemp == null
            ? 'Handy · vom Gerät nicht freigegeben'
            : 'Handy · ${d.bestTempSource}'
                '${d.batteryLevel != null ? ' · Akku ${d.batteryLevel} %' : ''}',
        level: d.bestTemp,
        warnAt: 42,
        critAt: 48,
        showBar: false,
      ),
    ];
  }
}

// ======================================================
// DATENQUELLE (Handy / PC)
// ======================================================

class SourceChip extends StatelessWidget {
  final bool isPc;
  const SourceChip({super.key, required this.isPc});

  @override
  Widget build(BuildContext context) {
    final color = isPc ? Colors.cyanAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPc ? Icons.computer : Icons.smartphone, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            isPc ? 'PC' : 'HANDY',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// SYSTEM CARD
// ======================================================

class SystemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  /// Optionaler Wert (0–100 bzw. °C) für Farbe und Balken.
  final double? level;
  final double warnAt;
  final double critAt;

  /// Balken nur bei Prozentwerten, nicht bei Temperaturen.
  final bool showBar;

  const SystemCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.level,
    this.warnAt = 75,
    this.critAt = 90,
    this.showBar = true,
  });

  Color get _valueColor {
    final v = level;
    if (v == null) return Colors.white;
    if (v >= critAt) return Colors.redAccent;
    if (v >= warnAt) return Colors.amberAccent;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          if (level != null && showBar) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (level! / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                  _valueColor == Colors.white ? Colors.greenAccent : _valueColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================
// SYSTEM STATUS
// ======================================================

class StatusPanel extends StatelessWidget {
  final int deviceSensors;
  final PcConnection pc;

  const StatusPanel({
    super.key,
    required this.deviceSensors,
    required this.pc,
  });

  @override
  Widget build(BuildContext context) {
    final pcBusy = pc.state == PcState.searching || pc.state == PcState.connecting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEM STATUS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          const StatusRow(
            label: 'Flutter Engine',
            status: 'ONLINE',
            online: true,
          ),
          StatusRow(
            label: 'Handy-Sensoren',
            status: deviceSensors == 0 ? 'LESE ...' : '$deviceSensors/6 FREI',
            online: deviceSensors > 0,
          ),
          StatusRow(
            label: 'PC Connection',
            status: pc.statusText,
            online: pc.isOnline,
            busy: pcBusy,
          ),
          if (pc.isOnline && pc.stats?.game != null)
            StatusRow(
              label: pc.stats!.game!.name,
              status: pc.stats!.game!.measuring ? 'MESSUNG' : 'LÄUFT',
              online: true,
            ),
        ],
      ),
    );
  }
}

// ======================================================
// STATUS ROW
// ======================================================

class StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final bool online;
  final bool busy;

  const StatusRow({
    super.key,
    required this.label,
    required this.status,
    required this.online,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = online
        ? Colors.greenAccent
        : (busy ? Colors.amberAccent : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// ACTION BUTTON
// ======================================================

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111620),
          foregroundColor: Colors.greenAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
