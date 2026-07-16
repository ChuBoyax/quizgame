import 'package:shared_preferences/shared_preferences.dart';

// Nagtatala kung kailan mo huling natapos ang Daily Challenge, at kung ilang
// sunod-sunod na araw ka nang bumabalik.
class Daily {
  Daily._();
  static final Daily instance = Daily._();

  SharedPreferences? _prefs;

  static const _lastKey = 'daily_last'; // petsa ng huling tapos, "2026-07-15"
  static const _streakKey = 'daily_streak'; // sunod-sunod na araw
  static const _scoreKey = 'daily_score'; // puntos sa huling tapos

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
  }

  // Petsa lang, walang oras — ito ang nagpapasya kung "bagong araw" na.
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? get _last => _prefs?.getString(_lastKey);

  bool get doneToday => _last == dateKey(DateTime.now());

  int get dayStreak => _prefs?.getInt(_streakKey) ?? 0;

  int get lastScore => _prefs?.getInt(_scoreKey) ?? 0;

  /// Tawagin kapag natapos ang daily quiz. Walang epekto kung tapos na ngayong
  /// araw — kaya hindi mapepeke ang streak sa pamamagitan ng paulit-ulit na laro.
  ///
  /// Hindi ito `async` sa parehong dahilan ng HighScores.save: kailangang
  /// makita agad ng `dayStreak` ang bagong halaga kapag kinuwenta ang badges.
  void complete(int points) {
    if (doneToday) return;

    final now = DateTime.now();
    final yesterday = dateKey(now.subtract(const Duration(days: 1)));

    // Kinukuwenta bago pa isulat ang bagong petsa — kapag naunang naisulat,
    // "ngayon" na ang mababasa ng _last at masisira ang bilang.
    // Tuloy ang streak kung kahapon ang huli; kung may nalaktawang araw,
    // balik sa 1 — hindi 0, dahil natapos mo naman ang ngayong araw.
    final streak = _last == yesterday ? dayStreak + 1 : 1;

    try {
      _prefs?.setString(_lastKey, dateKey(now));
      _prefs?.setInt(_streakKey, streak);
      _prefs?.setInt(_scoreKey, points);
    } catch (_) {
      // Kung pumalya ang storage, hindi naitala — pero tuloy ang laro.
    }
  }
}
