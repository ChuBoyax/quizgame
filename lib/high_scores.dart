import 'package:shared_preferences/shared_preferences.dart';

// Nagtatago ng pinakamataas na puntos kada category+difficulty. Nananatili ito
// kahit isara ang app: localStorage sa web, SharedPreferences sa Android, at
// NSUserDefaults sa iOS/macOS — pero pare-pareho ang gamit natin.
class HighScores {
  HighScores._();
  static final HighScores instance = HighScores._();

  SharedPreferences? _prefs;

  /// Tawagin sa main() bago ang runApp. Kapag tapos na ito, sync na lahat ng
  /// pagbasa — kaya puwede nating tawagin ang best() diretso sa build().
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // 0 lahat ng high score, pero tumatakbo pa rin ang laro
    }
  }

  String _pointsKey(String category, String difficulty) =>
      'hs_${category}_$difficulty';

  String _correctKey(String category, String difficulty) =>
      'bc_${category}_$difficulty';

  /// Pinakamataas na puntos na naitala. 0 kung wala pang laro.
  int best(String category, String difficulty) =>
      _prefs?.getInt(_pointsKey(category, difficulty)) ?? 0;

  /// Pinakamaraming tamang sagot na naitala. Hiwalay ito sa puntos dahil dito
  /// nakabatay ang "perfect" — hindi mahuhulaan iyon sa puntos lang.
  int bestCorrect(String category, String difficulty) =>
      _prefs?.getInt(_correctKey(category, difficulty)) ?? 0;

  /// Itinatala ang dalawa, pero ang bawat isa ay kung mas mataas lang sa dati.
  ///
  /// Sinasadyang hindi ito `async`: agad na na-a-update ang in-memory cache ng
  /// SharedPreferences, kaya ang susunod na `bestCorrect()` ay makikita agad
  /// ang bagong halaga. Kapag inawait pa ang bawat sulat, hindi pa tapos ang
  /// pangalawa kapag kinuwenta na ang bagong badges sa katapusan ng laro.
  void save(String category, String difficulty,
      {required int points, required int correct}) {
    try {
      if (points > best(category, difficulty)) {
        _prefs?.setInt(_pointsKey(category, difficulty), points);
      }
      if (correct > bestCorrect(category, difficulty)) {
        _prefs?.setInt(_correctKey(category, difficulty), correct);
      }
    } catch (_) {
      // Kung pumalya ang storage, hindi na-save — pero tuloy ang laro.
    }
  }
}
