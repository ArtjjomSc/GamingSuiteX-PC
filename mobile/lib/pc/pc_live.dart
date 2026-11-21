// GamingSuite X – Hilfs-Widget, um die Kacheln im Dashboard live zu füllen.
//
// Beispiel – statt  Text('-- %')  in der CPU-Kachel:
//
//   PcLive(builder: (context, s, pc) =>
//       Text(s == null ? '-- %' : '${s.cpu.usage.toStringAsFixed(0)} %'))
//
// Und statt  Text('Waiting for data'):
//
//   PcLive(builder: (context, s, pc) =>
//       Text(s == null ? 'Waiting for data' : s.cpu.name))

import 'package:flutter/widgets.dart';

import 'pc_connection.dart';
import 'pc_stats.dart';

class PcLive extends StatelessWidget {
  final Widget Function(BuildContext context, PcStats? stats, PcConnection pc)
      builder;
  const PcLive({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final pc = PcConnection.instance;
    return AnimatedBuilder(
      animation: pc,
      builder: (context, _) => builder(context, pc.stats, pc),
    );
  }
}
