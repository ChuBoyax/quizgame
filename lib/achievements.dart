import 'package:shared_preferences/shared_preferences.dart';

// Mga bilang na hindi makukuha sa ibang storage — ito ang pinagbabatayan ng
// achievements. Ang mga nakabatay sa level, daily streak, o ✅ ay hindi na
// inuulit dito; may sarili na silang tala.
class Achievements {
  Achievements._();
  static final Achievements instance = Achievements._();

  static const _gamesKey = 'ach_games';
  static const _perfectKey = 'ach_perfect';
  static const _fastKey = 'ach_fast';
  static const _streakKey = 'ach_best_streak';

  SharedPreferences? _prefs;

  // Kopya sa memory para sync ang pagbasa sa loob ng build(), at para agad na
  // makita ang bagong halaga pagkatapos ng recordGame().
  int _games = 0;
  int _perfect = 0;
  int _fast = 0;
  int _bestStreak = 0;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _games = _prefs?.getInt(_gamesKey) ?? 0;
      _perfect = _prefs?.getInt(_perfectKey) ?? 0;
      _fast = _prefs?.getInt(_fastKey) ?? 0;
      _bestStreak = _prefs?.getInt(_streakKey) ?? 0;
    } catch (_) {
      _prefs = null;
    }
  }

  int get gamesPlayed => _games;
  int get perfectGames => _perfect;
  int get fastAnswers => _fast;
  int get bestStreakEver => _bestStreak;

  /// Tawagin isang beses kada tapos na laro.
  void recordGame({
    required bool perfect,
    required int fastAnswers,
    required int bestStreak,
  }) {
    _games++;
    if (perfect) _perfect++;
    _fast += fastAnswers;
    if (bestStreak > _bestStreak) _bestStreak = bestStreak;

    _prefs?.setInt(_gamesKey, _games);
    _prefs?.setInt(_perfectKey, _perfect);
    _prefs?.setInt(_fastKey, _fast);
    _prefs?.setInt(_streakKey, _bestStreak);
  }
}
