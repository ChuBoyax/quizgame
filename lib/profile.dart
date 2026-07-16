import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- XP CURVE ----
// Ang level 1→2 ay 100 XP, tapos may dagdag na 50 kada susunod na level
// (150, 200, 250...). Pahirap nang pahirap, kaya hindi agad nauubos ang laro.
const _xpBase = 100;
const _xpStep = 50;

int xpToAdvance(int level) => _xpBase + (level - 1) * _xpStep;

// Level + progress sa loob ng level, sabay-sabay na kinukuwenta — para isang
// beses lang tumakbo ang loop kahit tatlong bagay ang kailangan ng UI.
class LevelInfo {
  final int level;
  final int into; // XP na naipon sa loob ng kasalukuyang level
  final int need; // XP na kailangan para sa susunod na level
  const LevelInfo(this.level, this.into, this.need);

  double get progress => into / need;
}

LevelInfo levelInfoFor(int xp) {
  var level = 1;
  var need = xpToAdvance(1);
  var left = xp;

  while (left >= need) {
    left -= need;
    level++;
    need = xpToAdvance(level);
  }
  return LevelInfo(level, left, need);
}

// ---- RANKS ----
enum Rank { bronze, silver, gold, diamond }

extension RankInfo on Rank {
  // Ang pinakamababang level para maabot ang rank na ito.
  int get minLevel {
    switch (this) {
      case Rank.bronze:
        return 1;
      case Rank.silver:
        return 5;
      case Rank.gold:
        return 10;
      case Rank.diamond:
        return 20;
    }
  }

  String get label {
    switch (this) {
      case Rank.bronze:
        return 'Bronze';
      case Rank.silver:
        return 'Silver';
      case Rank.gold:
        return 'Gold';
      case Rank.diamond:
        return 'Diamond';
    }
  }

  String get emoji {
    switch (this) {
      case Rank.bronze:
        return '🥉';
      case Rank.silver:
        return '🥈';
      case Rank.gold:
        return '🥇';
      case Rank.diamond:
        return '💎';
    }
  }

  Color get color {
    switch (this) {
      case Rank.bronze:
        return const Color(0xFFCD7F32);
      case Rank.silver:
        return const Color(0xFFB8C4D0);
      case Rank.gold:
        return const Color(0xFFFFC53D);
      case Rank.diamond:
        return const Color(0xFF4AE0FF);
    }
  }
}

// Pinakamataas na rank na naabot ng level na ito.
Rank rankFor(int level) => Rank.values.lastWhere((r) => level >= r.minLevel);

// ---- STORAGE ----
class Profile {
  Profile._();
  static final Profile instance = Profile._();

  static const _xpKey = 'total_xp';

  SharedPreferences? _prefs;
  int _xp = 0; // ito ang totoong pinagbabatayan; ang prefs ay kopya sa disk

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _xp = _prefs?.getInt(_xpKey) ?? 0;
    } catch (_) {
      _prefs = null;
    }
  }

  int get xp => _xp;
  LevelInfo get levelInfo => levelInfoFor(_xp);
  int get level => levelInfo.level;
  Rank get rank => rankFor(level);

  /// Agad na tumataas ang XP sa memory; ang pagsulat sa disk ay hinahayaang
  /// matapos mag-isa — kaya sync ang pagbasa at hindi nagha-hang ang UI.
  void addXp(int amount) {
    _xp += amount;
    _prefs?.setInt(_xpKey, _xp);
  }
}
