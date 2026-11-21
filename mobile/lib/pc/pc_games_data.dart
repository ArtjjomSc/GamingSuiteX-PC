// GamingSuite X – Spiele-Messungen vom PC (/api/games), nur lesen.

double? _d(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
int? _i(dynamic v) =>
    v is num ? v.round() : (v is String ? int.tryParse(v) : null);
String _s(dynamic v, [String fallback = '']) =>
    (v == null || v.toString().isEmpty) ? fallback : v.toString();

class GameMeasurement {
  final String key;
  final String name;

  /// GUT, GELEGENTLICH, RUCKLER, MITTEL, AUFWAERMEN
  final String rating;
  final DateTime? date;
  final int? target;
  final int? avg;
  final int? low;
  final int? low01;
  final int? lowRatio;
  final double? hitchesPerMin;
  final int? gpu;
  final int? core;
  final int? vram;
  final bool fgActive;
  final String fg;
  final int? baseAvg;
  final int? baseLow;
  final int runs;
  final List<String> tips;

  GameMeasurement.fromJson(Map<String, dynamic> j)
      : key = _s(j['key']),
        name = _s(j['name'], 'Spiel'),
        rating = _s(j['rating'], '-'),
        date = DateTime.tryParse(_s(j['date'])),
        target = _i(j['target']),
        avg = _i(j['avg']),
        low = _i(j['low']),
        low01 = _i(j['low01']),
        lowRatio = _i(j['lowRatio']),
        hitchesPerMin = _d(j['hitchesPerMin']),
        gpu = _i(j['gpu']),
        core = _i(j['core']),
        vram = _i(j['vram']),
        fgActive = j['fgActive'] == true,
        fg = _s(j['fg']),
        baseAvg = _i(j['baseAvg']),
        baseLow = _i(j['baseLow']),
        runs = _i(j['runs']) ?? 1,
        tips = j['tips'] is List
            ? (j['tips'] as List).map((e) => e.toString()).toList()
            : <String>[];
}

class TuningGame {
  final String id;
  final String name;
  final int level;
  final String levelName;
  final int? pending;
  final int? recommended;
  final String status;

  TuningGame.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name'], 'Spiel'),
        level = _i(j['level']) ?? 0,
        levelName = _s(j['levelName']),
        pending = _i(j['pending']),
        recommended = _i(j['recommended']),
        status = _s(j['status']);
}

class GamesData {
  final int? target;
  final int? monitorHz;
  final List<GameMeasurement> games;
  final List<TuningGame> tuning;

  GamesData.fromJson(Map<String, dynamic> j)
      : target = _i(j['target']),
        monitorHz = _i(j['monitorHz']),
        games = _list(j['games'], GameMeasurement.fromJson),
        tuning = _list(j['tuning'], TuningGame.fromJson);

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) {
    // PowerShell liefert bei genau einem Eintrag manchmal ein Objekt statt einer Liste.
    if (v is Map) return [f(Map<String, dynamic>.from(v))];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <T>[];
  }
}
