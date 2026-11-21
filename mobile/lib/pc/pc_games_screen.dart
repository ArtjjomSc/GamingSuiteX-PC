// GamingSuite X – Seite "Spiele-Messungen": FPS, 1%-Low, Hänger pro Minute,
// Frame Generation und Empfehlungen aller gemessenen Spiele (nur lesen).

import 'dart:async';

import 'package:flutter/material.dart';

import 'pc_connection.dart';
import 'pc_diagnostics_screen.dart'
    show showPcConnectSheet, kAccent, kBg, kBar, kBorder, kCard, kCrit, kDim, kInfo, kText, kWarn;
import 'pc_games_data.dart';

Color ratingColor(String rating) {
  switch (rating) {
    case 'GUT':
      return kAccent;
    case 'GELEGENTLICH':
    case 'MITTEL':
      return kWarn;
    case 'RUCKLER':
      return kCrit;
    case 'AUFWAERMEN':
      return kInfo;
    default:
      return kDim;
  }
}

String ratingText(String rating) {
  switch (rating) {
    case 'AUFWAERMEN':
      return 'AUFWÄRMEN';
    default:
      return rating;
  }
}

class PcGamesScreen extends StatefulWidget {
  const PcGamesScreen({super.key});

  @override
  State<PcGamesScreen> createState() => _PcGamesScreenState();
}

class _PcGamesScreenState extends State<PcGamesScreen> {
  final pc = PcConnection.instance;
  GamesData? _data;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await pc.fetchGames();
    if (!mounted) return;
    setState(() {
      if (d != null) _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBar,
        foregroundColor: kText,
        elevation: 0,
        title: const Text('SPIELE-MESSUNGEN',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'Verbindung',
            icon: const Icon(Icons.link),
            onPressed: () => showPcConnectSheet(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: pc,
        builder: (context, _) {
          if (!pc.isOnline && _data == null) return _buildOffline(context);
          if (_loading && _data == null) {
            return const Center(child: CircularProgressIndicator(color: kAccent));
          }
          final d = _data;
          if (d == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Keine Spieldaten vom PC.\nGamingSuite X am PC auf Version 10.8 aktualisieren.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kDim),
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: kAccent,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Header(data: d, pc: pc),
                if (d.tuning.isNotEmpty) ...[
                  const _SectionTitle('AUTO-TUNING'),
                  for (final t in d.tuning) _TuningTile(t),
                ],
                const _SectionTitle('MESSUNGEN'),
                if (d.games.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Noch keine Messung. Einfach am PC ein Spiel 3–4 Minuten spielen – '
                      'GamingSuite X misst automatisch.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kDim),
                    ),
                  ),
                for (final g in d.games)
                  _GameCard(game: g, onTap: () => _showDetails(context, g)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOffline(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.desktop_access_disabled, color: kCrit, size: 52),
            const SizedBox(height: 16),
            const Text('Kein PC verbunden',
                style: TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent, side: const BorderSide(color: kAccent)),
              onPressed: () => showPcConnectSheet(context),
              icon: const Icon(Icons.link),
              label: const Text('VERBINDEN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, GameMeasurement g) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(g.name,
                      style: const TextStyle(
                          color: kText, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                _RatingChip(g.rating),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${g.date != null ? _fmtDate(g.date!) : ''} · Ziel ${g.target ?? '-'} FPS · ${g.runs} Messung(en)',
              style: const TextStyle(color: kDim, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _MetricGrid(g),
            const SizedBox(height: 16),
            _KvRow('GPU-Auslastung', g.gpu == null ? 'n/v' : '${g.gpu} %'),
            _KvRow('Stärkster CPU-Kern', g.core == null ? 'n/v' : '${g.core} %'),
            _KvRow('VRAM belegt', g.vram == null ? 'n/v' : '${g.vram} %'),
            _KvRow('Frame Generation',
                g.fgActive ? 'an · echt Ø ${g.baseAvg ?? '-'} / 1% ${g.baseLow ?? '-'}' : (g.fg.isEmpty ? 'aus' : g.fg)),
            _KvRow('1%-Low / Durchschnitt', g.lowRatio == null ? 'n/v' : '${g.lowRatio} %'),
            const SizedBox(height: 16),
            const Text('EMPFEHLUNGEN',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            for (final t in g.tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.chevron_right, size: 16, color: kAccent),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(t, style: const TextStyle(color: kText, height: 1.35))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}. '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtSec(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

// ===================================================================== Teile

class _Header extends StatelessWidget {
  final GamesData data;
  final PcConnection pc;
  const _Header({required this.data, required this.pc});

  @override
  Widget build(BuildContext context) {
    final game = pc.stats?.game;
    String status;
    Color color;
    if (game == null) {
      status = 'Kein Spiel aktiv';
      color = kDim;
    } else if (game.measuring) {
      status = '${game.name} · Messung läuft${game.secondsLeft != null ? ' (${_fmtSec(game.secondsLeft!)})' : ''}';
      color = kAccent;
    } else if (game.waitSeconds != null && game.waitSeconds! > 0) {
      status = '${game.name} · Messung startet in ${_fmtSec(game.waitSeconds!)}';
      color = kWarn;
    } else {
      status = '${game.name} läuft';
      color = kText;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: kAccent, size: 20),
              const SizedBox(width: 8),
              Text('Ziel: ${data.target ?? '-'} FPS',
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              if (data.monitorHz != null)
                Text('Monitor ${data.monitorHz} Hz', style: const TextStyle(color: kDim)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(game?.measuring == true ? Icons.fiber_manual_record : Icons.sports_esports,
                  size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: kAccent, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      );
}

class _TuningTile extends StatelessWidget {
  final TuningGame t;
  const _TuningTile(this.t);

  @override
  Widget build(BuildContext context) {
    final level = t.level >= 1 ? 'Stufe ${t.level} · ${t.levelName}' : 'nicht optimiert';
    final pending = t.pending != null ? ' → ${t.pending} nach Spielende' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, color: t.level >= 1 ? kAccent : kDim, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
                Text('$level$pending',
                    style: TextStyle(color: t.pending != null ? kWarn : kDim, fontSize: 12)),
              ],
            ),
          ),
          if (t.recommended != null)
            Text('Start ${t.recommended}', style: const TextStyle(color: kDim, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameMeasurement game;
  final VoidCallback onTap;
  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = game;
    return Card(
      color: kCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ratingColor(g.rating).withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kText, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  _RatingChip(g.rating),
                ],
              ),
              const SizedBox(height: 12),
              _MetricGrid(g),
              const SizedBox(height: 10),
              Text(
                [
                  if (g.gpu != null) 'GPU ${g.gpu} %',
                  if (g.core != null) 'Kern ${g.core} %',
                  if (g.vram != null) 'VRAM ${g.vram} %',
                  if (g.fgActive) 'FG an (echt ${g.baseAvg ?? '-'})' else if (g.fg.isNotEmpty) 'FG ${g.fg}',
                  if (g.date != null) _fmtDate(g.date!),
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kDim, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final GameMeasurement g;
  const _MetricGrid(this.g);

  @override
  Widget build(BuildContext context) {
    final target = g.target ?? 0;
    Color fpsColor(int? v) {
      if (v == null || target == 0) return kText;
      if (v >= target * 0.93) return kAccent;
      if (v >= target * 0.7) return kWarn;
      return kCrit;
    }

    final hpm = g.hitchesPerMin;
    final hpmColor = hpm == null ? kText : (hpm < 2 ? kAccent : (hpm <= 10 ? kWarn : kCrit));
    return Row(
      children: [
        _Metric('Ø FPS', g.avg?.toString() ?? '-', fpsColor(g.avg)),
        _Metric('1%-Low', g.low?.toString() ?? '-', kText),
        _Metric('0,1%-Low', g.low01?.toString() ?? '-', kText),
        _Metric('Hänger/min', hpm == null ? '-' : hpm.toStringAsFixed(1), hpmColor),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Text(label, style: const TextStyle(color: kDim, fontSize: 11)),
          ],
        ),
      );
}

class _RatingChip extends StatelessWidget {
  final String rating;
  const _RatingChip(this.rating);

  @override
  Widget build(BuildContext context) {
    final c = ratingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.7)),
      ),
      child: Text(ratingText(rating),
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;
  const _KvRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: kDim))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
