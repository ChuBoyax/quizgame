import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'achievements.dart';
import 'daily.dart';
import 'high_scores.dart';
import 'profile.dart';
import 'sfx.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Basahin ang naka-save bago ipakita ang UI, para sync na ang lahat ng
  // pagbasa sa loob ng build().
  await HighScores.instance.init();
  await Daily.instance.init();
  await Profile.instance.init();
  await Achievements.instance.init();
  runApp(const QuizApp());
}

// ---- PALETTE ----
const _bgTop = Color(0xFF1E1440);
const _bgBottom = Color(0xFF0B0817);
const _accent = Color(0xFF7C5CFF);
const _accent2 = Color(0xFFC24BFF);
const _correct = Color(0xFF22D39A);
const _wrong = Color(0xFFFF5C7A);
const _card = Color(0xFF241B3D);
const _cardBorder = Color(0xFF3A2E5C);
const _gold = Color(0xFFFFC53D); // high score at perfect
const _fire = Color(0xFFFF8A3D); // streak

// ---- TIMER ----
const _secondsPerQuestion = 15.0;
const _tick = Duration(milliseconds: 50);

// ---- ADAPTIVE ----
const _adaptiveQuestions = 8; // mas mahaba kaysa sa 5 — may puwang mag-adjust
const _levelUpAfter = 2; // ilang sunod na tama bago umakyat ng level

// ---- PUNTOS ----
const _basePoints = 10; // bawat tamang sagot
const _streakNeeded = 3; // ilang sunod-sunod bago magsimula ang bonus

// Para sa Speed Demon: kailangang tama AT nasagot sa loob ng ganitong segundo.
// Hindi sapat na mabilis lang — kung hindi, kayang i-farm sa pagpindot agad ng
// kahit anong sagot.
const _fastAnswerSeconds = 3.0;

// Bonus kapag 3 pataas na sunod-sunod ang tama: +5, +10, +15...
// Kaya mas masakit ang pagkakamali habang mataas ang streak.
int _bonusFor(int streak) => streak >= _streakNeeded ? 5 * (streak - 2) : 0;

// ---- DATA MODELS ----
class Question {
  final String text;
  final List<String> answers;
  final int correct;
  const Question(this.text, this.answers, this.correct);
}

enum Difficulty { easy, medium, hard }

extension DifficultyInfo on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  Color get color {
    switch (this) {
      case Difficulty.easy:
        return const Color(0xFF22D39A);
      case Difficulty.medium:
        return const Color(0xFFFFB020);
      case Difficulty.hard:
        return const Color(0xFFFF5C7A);
    }
  }

  String get emoji {
    switch (this) {
      case Difficulty.easy:
        return '🟢';
      case Difficulty.medium:
        return '🟡';
      case Difficulty.hard:
        return '🔴';
    }
  }
}

class Category {
  final String name;
  final String emoji;
  final Color color;
  // Bawat difficulty may sariling listahan ng tanong
  final Map<Difficulty, List<Question>> questions;
  const Category(this.name, this.emoji, this.color, this.questions);
}

// ---- ALL CATEGORIES + QUESTIONS BY DIFFICULTY ----
final List<Category> categories = [
  Category('Animals', '🐾', const Color(0xFF22D39A), {
    Difficulty.easy: const [
      Question('Which animal is known as the "King of the Jungle"?',
          ['Tiger', 'Elephant', 'Lion', 'Bear'], 2),
      Question('How many legs does a spider have?',
          ['6', '8', '10', '4'], 1),
      Question('Which bird cannot fly?',
          ['Eagle', 'Penguin', 'Sparrow', 'Pigeon'], 1),
      Question('Which animal is famous for its long neck?',
          ['Horse', 'Camel', 'Giraffe', 'Zebra'], 2),
      Question('What sound does a dog make?',
          ['Meow', 'Moo', 'Bark', 'Quack'], 2),
    ],
    Difficulty.medium: const [
      Question('What is the largest animal in the world?',
          ['Elephant', 'Whale Shark', 'Blue Whale', 'Giraffe'], 2),
      Question('Which animal can sleep standing up?',
          ['Cat', 'Horse', 'Dog', 'Rabbit'], 1),
      Question('How many hearts does an octopus have?',
          ['1', '2', '3', '4'], 2),
      Question('Which mammal lays eggs?',
          ['Bat', 'Platypus', 'Whale', 'Kangaroo'], 1),
      Question('What is a group of lions called?',
          ['Pack', 'Herd', 'Pride', 'Flock'], 2),
    ],
    Difficulty.hard: const [
      Question('What is the fastest land animal?',
          ['Lion', 'Cheetah', 'Horse', 'Greyhound'], 1),
      Question('Which animal has the longest lifespan?',
          ['Elephant', 'Tortoise', 'Whale', 'Greenland Shark'], 3),
      Question('What is the only mammal capable of true flight?',
          ['Flying squirrel', 'Bat', 'Sugar glider', 'Colugo'], 1),
      Question('How many chambers does a cow\'s stomach have?',
          ['1', '2', '3', '4'], 3),
      Question('Which animal has blue blood?',
          ['Octopus', 'Frog', 'Snake', 'Shark'], 0),
    ],
  }),
  Category('Food', '🍔', const Color(0xFFFFB020), {
    Difficulty.easy: const [
      Question('What fruit is yellow and curved?',
          ['Apple', 'Banana', 'Grape', 'Cherry'], 1),
      Question('What is the main ingredient in bread?',
          ['Rice', 'Flour', 'Corn', 'Potato'], 1),
      Question('Which drink comes from cows?',
          ['Juice', 'Milk', 'Soda', 'Water'], 1),
      Question('What color is a ripe tomato?',
          ['Blue', 'Green', 'Red', 'Purple'], 2),
      Question('Which is a citrus fruit?',
          ['Banana', 'Orange', 'Apple', 'Grape'], 1),
    ],
    Difficulty.medium: const [
      Question('Which country did sushi originate from?',
          ['China', 'Korea', 'Japan', 'Thailand'], 2),
      Question('What spice is known as the most expensive?',
          ['Pepper', 'Saffron', 'Cinnamon', 'Vanilla'], 1),
      Question('What flavor is wasabi?',
          ['Sweet', 'Sour', 'Spicy', 'Bitter'], 2),
      Question('Cheese is made from what?',
          ['Water', 'Milk', 'Flour', 'Oil'], 1),
      Question('Which fruit is called the "king of fruits"?',
          ['Mango', 'Durian', 'Pineapple', 'Guava'], 1),
    ],
    Difficulty.hard: const [
      Question('What is the main ingredient in traditional hummus?',
          ['Lentils', 'Chickpeas', 'Beans', 'Peas'], 1),
      Question('Which vitamin is found abundantly in citrus fruits?',
          ['Vitamin A', 'Vitamin B', 'Vitamin C', 'Vitamin D'], 2),
      Question('What process gives bread its rise?',
          ['Boiling', 'Fermentation', 'Freezing', 'Drying'], 1),
      Question('Which nut is used to make marzipan?',
          ['Peanut', 'Almond', 'Cashew', 'Walnut'], 1),
      Question('What is tofu made from?',
          ['Rice', 'Soybeans', 'Wheat', 'Corn'], 1),
    ],
  }),
  Category('Science', '🔬', const Color(0xFF4AA8FF), {
    Difficulty.easy: const [
      Question('What is the chemical symbol for water?',
          ['CO2', 'H2O', 'O2', 'NaCl'], 1),
      Question('How many planets are in the Solar System?',
          ['7', '8', '9', '10'], 1),
      Question('What gas do we breathe to live?',
          ['Carbon Dioxide', 'Nitrogen', 'Oxygen', 'Helium'], 2),
      Question('What is the closest star to Earth?',
          ['Moon', 'Sun', 'Mars', 'Venus'], 1),
      Question('Which body part is used for thinking?',
          ['Heart', 'Lungs', 'Brain', 'Liver'], 2),
    ],
    Difficulty.medium: const [
      Question('What planet is known as the Red Planet?',
          ['Venus', 'Mars', 'Jupiter', 'Saturn'], 1),
      Question('What is the powerhouse of the cell?',
          ['Nucleus', 'Mitochondria', 'Ribosome', 'Membrane'], 1),
      Question('What force pulls objects toward Earth?',
          ['Magnetism', 'Gravity', 'Friction', 'Tension'], 1),
      Question('What is the hardest natural substance?',
          ['Gold', 'Iron', 'Diamond', 'Quartz'], 2),
      Question('At what temperature does water boil (°C)?',
          ['50', '90', '100', '120'], 2),
    ],
    Difficulty.hard: const [
      Question('What is the speed of light (approx)?',
          ['300,000 km/s', '150,000 km/s', '1,000 km/s', '3,000 km/s'], 0),
      Question('What element has the atomic number 1?',
          ['Helium', 'Oxygen', 'Hydrogen', 'Carbon'], 2),
      Question('What is the study of fungi called?',
          ['Botany', 'Mycology', 'Zoology', 'Ecology'], 1),
      Question('Which scientist proposed the theory of relativity?',
          ['Newton', 'Einstein', 'Darwin', 'Tesla'], 1),
      Question('What is the pH of pure water?',
          ['5', '7', '9', '14'], 1),
    ],
  }),
  Category('History', '📜', const Color(0xFFC24BFF), {
    Difficulty.easy: const [
      Question('Who is the national hero of the Philippines?',
          ['Bonifacio', 'Aguinaldo', 'Rizal', 'Mabini'], 2),
      Question('What is the capital of the Philippines?',
          ['Cebu', 'Manila', 'Davao', 'Baguio'], 1),
      Question('Which ocean is the largest?',
          ['Atlantic', 'Indian', 'Pacific', 'Arctic'], 2),
      Question('How many continents are there?',
          ['5', '6', '7', '8'], 2),
      Question('What shape is planet Earth?',
          ['Flat', 'Square', 'Round', 'Triangle'], 2),
    ],
    Difficulty.medium: const [
      Question('Who was the first president of the Philippines?',
          ['Quezon', 'Aguinaldo', 'Rizal', 'Marcos'], 1),
      Question('Which country colonized PH for 300+ years?',
          ['USA', 'Japan', 'Spain', 'China'], 2),
      Question('In what year did EDSA People Power happen?',
          ['1986', '1972', '1998', '2001'], 0),
      Question('Who discovered the Americas in 1492?',
          ['Magellan', 'Columbus', 'Cook', 'Drake'], 1),
      Question('Which war ended in 1945?',
          ['World War I', 'World War II', 'Cold War', 'Korean War'], 1),
    ],
    Difficulty.hard: const [
      Question('Who was the first person to walk on the moon?',
          ['Buzz Aldrin', 'Neil Armstrong', 'Yuri Gagarin', 'John Glenn'], 1),
      Question('The Great Wall is located in which country?',
          ['Japan', 'India', 'China', 'Korea'], 2),
      Question('Who wrote "Noli Me Tangere"?',
          ['Bonifacio', 'Rizal', 'Luna', 'Mabini'], 1),
      Question('Which ancient civilization built the pyramids of Giza?',
          ['Roman', 'Greek', 'Egyptian', 'Mayan'], 2),
      Question('In what year did the Philippines gain independence from Spain?',
          ['1898', '1900', '1946', '1521'], 0),
    ],
  }),
  Category('Sports', '⚽', const Color(0xFFFF5C7A), {
    Difficulty.easy: const [
      Question('How many players are on a basketball team on court?',
          ['4', '5', '6', '7'], 1),
      Question('What sport does Manny Pacquiao play?',
          ['Basketball', 'Boxing', 'Football', 'Tennis'], 1),
      Question('What sport uses a bat and a ball?',
          ['Soccer', 'Baseball', 'Swimming', 'Boxing'], 1),
      Question('In soccer, what do you call a score?',
          ['Point', 'Goal', 'Run', 'Basket'], 1),
      Question('Which sport is played at Wimbledon?',
          ['Golf', 'Tennis', 'Cricket', 'Rugby'], 1),
    ],
    Difficulty.medium: const [
      Question('How often are the Summer Olympics held?',
          ['Every 2 years', 'Every 3 years', 'Every 4 years', 'Every 5 years'],
          2),
      Question('How many players in a soccer team on the field?',
          ['9', '10', '11', '12'], 2),
      Question('Which sport uses "love" as a score?',
          ['Football', 'Tennis', 'Golf', 'Badminton'], 1),
      Question('How many rings are on the Olympic flag?',
          ['4', '5', '6', '7'], 1),
      Question('In which sport would you perform a slam dunk?',
          ['Volleyball', 'Basketball', 'Tennis', 'Hockey'], 1),
    ],
    Difficulty.hard: const [
      Question('How many points is a touchdown worth in American football?',
          ['3', '6', '7', '2'], 1),
      Question('Which country has won the most FIFA World Cups?',
          ['Germany', 'Italy', 'Brazil', 'Argentina'], 2),
      Question('In golf, what is one under par called?',
          ['Eagle', 'Birdie', 'Bogey', 'Par'], 1),
      Question('How long is a marathon (approx)?',
          ['26 miles', '42 miles', '13 miles', '50 miles'], 0),
      Question('Which country originated the sport of judo?',
          ['China', 'Korea', 'Japan', 'Thailand'], 2),
    ],
  }),
];

// Hinahalo ang sagot sa pamamagitan ng index para masundan kung saan napunta
// ang tama — gumagana kahit magkapareho ang teksto ng dalawang sagot.
// Kapag may ibinigay na [rng], mahuhulaan ang resulta — iyon ang kailangan ng
// Daily Challenge para pare-pareho ang laro sa buong araw.
Question shuffleAnswers(Question q, [Random? rng]) {
  final order = List.generate(q.answers.length, (i) => i)..shuffle(rng);
  return Question(
    q.text,
    [for (final i in order) q.answers[i]],
    order.indexOf(q.correct),
  );
}

// ---- DAILY CHALLENGE ----
const _dailyQuestions = 6;

// Hindi ito kasama sa `categories`, kaya walang epekto sa ✅ progress. Nandito
// lang ito para may maibigay na category ang QuizScreen at may sariling susi
// ang high score nito ("hs_Daily_daily").
const _dailyCategory = Category('Daily', '📅', _accent2, {});

// Ang petsa mismo ang seed, kaya pare-pareho ang tanong sa buong araw at
// awtomatikong nagpapalit sa hatinggabi — walang server na kailangan.
List<Question> dailyQuestionsFor(DateTime day) {
  final rng = Random(day.year * 10000 + day.month * 100 + day.day);
  final all = <Question>[
    for (final c in categories)
      for (final d in Difficulty.values) ...(c.questions[d] ?? const <Question>[]),
  ]..shuffle(rng);

  return all.take(_dailyQuestions).map((q) => shuffleAnswers(q, rng)).toList();
}

// ---- PROGRESS ----
// Perpekto = naabot mo na ang lahat ng tanong sa level na iyon nang tama.
bool isPerfect(Category category, Difficulty diff) {
  final total = category.questions[diff]?.length ?? 0;
  if (total == 0) return false;
  return HighScores.instance.bestCorrect(category.name, diff.name) >= total;
}

// Ilan sa tatlong difficulty ang na-perfect na sa category na ito.
int perfectCount(Category category) =>
    Difficulty.values.where((d) => isPerfect(category, d)).length;

// Lahat ng level sa lahat ng category (5 × 3).
int get totalLevels => categories.length * Difficulty.values.length;

int get perfectedLevels =>
    categories.fold<int>(0, (sum, c) => sum + perfectCount(c));

// ---- ACHIEVEMENTS ----
// Ang [current] ay bumabasa nang live sa tunay na tala, kaya walang hiwalay na
// listahan ng "unlocked" na puwedeng ma-out-of-sync — ang bilang mismo ang
// nagsasabi kung bukas na ito.
class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String hint;
  final int target;
  final int Function() current;

  const Achievement(
      this.id, this.emoji, this.title, this.hint, this.target, this.current);

  int get progress => min(current(), target);
  bool get unlocked => current() >= target;
}

final List<Achievement> achievements = [
  Achievement('first', '🎬', 'First Steps', 'Tapusin ang unang laro', 1,
      () => Achievements.instance.gamesPlayed),
  Achievement('games10', '🎮', 'Regular', 'Maglaro ng 10 beses', 10,
      () => Achievements.instance.gamesPlayed),
  Achievement('games50', '🏅', 'Veteran', 'Maglaro ng 50 beses', 50,
      () => Achievements.instance.gamesPlayed),
  Achievement('perfect1', '💯', 'Perfect Score', 'Isang laro na walang mali', 1,
      () => Achievements.instance.perfectGames),
  Achievement('perfect10', '👑', 'Perfectionist', '10 larong walang mali', 10,
      () => Achievements.instance.perfectGames),
  Achievement('streak5', '🔥', 'On Fire', '5 sunod-sunod na tama sa isang laro',
      5, () => Achievements.instance.bestStreakEver),
  Achievement('speed', '⚡', 'Speed Demon',
      '25 tamang sagot sa loob ng 3 segundo', 25,
      () => Achievements.instance.fastAnswers),
  Achievement('daily7', '📅', 'Week Warrior', '7 sunod-sunod na araw ng daily',
      7, () => Daily.instance.dayStreak),
  Achievement('gold', '🥇', 'Gold Rank', 'Abutin ang Level 10', 10,
      () => Profile.instance.level),
  Achievement('complete', '🏆', 'Completionist', 'I-perfect ang lahat ng level',
      totalLevels, () => perfectedLevels),
];

Set<String> unlockedBadgeIds() =>
    achievements.where((a) => a.unlocked).map((a) => a.id).toSet();

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: _bgBottom),
      home: const HomeScreen(),
    );
  }
}

Widget appBackground(Widget child) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bgTop, _bgBottom],
      ),
    ),
    child: SafeArea(child: child),
  );
}

// ============ HOME (CATEGORY PICKER) ============
// Stateful para ma-refresh ang progress pagbalik mula sa laro.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Ilan sa lahat ng level (5 category × 3 difficulty) ang na-perfect na.
    final done = categories.fold<int>(0, (sum, c) => sum + perfectCount(c));
    final total = categories.length * Difficulty.values.length;

    return Scaffold(
      body: appBackground(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text('🧠 Quiz Game',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _rankStrip(),
              const SizedBox(height: 14),
              Row(
                children: [
                  // Flexible + ellipsis: tatlong bagay ang nasa isang row, at
                  // sumisikip ito sa makikitid na screen.
                  const Flexible(
                    child: Text('Choose a category',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white60, fontSize: 16)),
                  ),
                  const Spacer(),
                  Text(
                    done == total ? '🏆 All' : '✅ $done/$total',
                    style: TextStyle(
                        color: done == total ? _gold : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  _badgesButton(),
                ],
              ),
              const SizedBox(height: 20),
              _dailyCard(),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) => _CategoryCard(
                    category: categories[index],
                    onReturn: () => setState(() {}), // i-refresh ang progress
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgesButton() {
    final unlocked = achievements.where((a) => a.unlocked).length;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BadgesScreen()));
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withValues(alpha: 0.5)),
        ),
        child: Text('🎖️ $unlocked/${achievements.length}',
            style: const TextStyle(
                color: _gold, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Rank, level, at XP bar — ang long-term goal, kaya nasa itaas mismo.
  Widget _rankStrip() {
    final info = Profile.instance.levelInfo;
    final rank = Profile.instance.rank;
    final next = _nextRank(rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: rank.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Text(rank.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${rank.label} • Level ${info.level}',
                        style: TextStyle(
                            color: rank.color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${info.into}/${info.need} XP',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: info.progress,
                    minHeight: 6,
                    backgroundColor: _card,
                    valueColor: AlwaysStoppedAnimation(rank.color),
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 5),
                  Text(
                      '${next.emoji} ${next.label} sa Level ${next.minLevel}',
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Susunod na rank, o null kung Diamond na (wala nang mas mataas).
  Rank? _nextRank(Rank current) {
    final i = Rank.values.indexOf(current);
    return i + 1 < Rank.values.length ? Rank.values[i + 1] : null;
  }

  // Isang laro kada araw. Kapag tapos na, hindi na ito matatapik — iyon mismo
  // ang dahilan para bumalik bukas.
  Widget _dailyCard() {
    final done = Daily.instance.doneToday;
    final streak = Daily.instance.dayStreak;
    final color = done ? _correct : _accent2;

    return GestureDetector(
      onTap: done
          ? null
          : () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuizScreen(
                  category: _dailyCategory,
                  difficulty: Difficulty.medium,
                  dailyQuestions: dailyQuestionsFor(DateTime.now()),
                ),
              ));
              if (mounted) setState(() {});
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: done ? 0.10 : 0.28),
            _accent.withValues(alpha: done ? 0.10 : 0.28),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: color.withValues(alpha: done ? 0.4 : 0.8), width: 1.5),
        ),
        child: Row(
          children: [
            Text(done ? '✅' : '📅', style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Challenge',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(
                    done
                        ? 'Tapos na! ⭐ ${Daily.instance.lastScore} • balik bukas'
                        : '$_dailyQuestions questions • bago kada araw',
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _fire.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _fire.withValues(alpha: 0.6)),
                ),
                child: Text('🔥 $streak',
                    style: const TextStyle(
                        color: _fire,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            if (!done) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: _accent2, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onReturn;
  const _CategoryCard({required this.category, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final done = perfectCount(category);
    final total = Difficulty.values.length;
    final allDone = done == total;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DifficultyScreen(category: category),
        ));
        onReturn();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          // Gintong border kapag kumpleto ang tatlong difficulty — makikita
          // agad sa grid kung alin ang tapos na.
          border: Border.all(
              color: allDone ? _gold : category.color.withValues(alpha: 0.5),
              width: allDone ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: (allDone ? _gold : category.color)
                    .withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 12),
            Text(category.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ProgressDots(done: done, total: total),
          ],
        ),
      ),
    );
  }
}

// Tatlong tuldok sa ilalim ng category card — isa kada difficulty. Ginto
// kapag na-perfect na, madilim kung hindi pa.
class _ProgressDots extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressDots({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final filled = i < done;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: filled ? _gold : Colors.white24,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ============ BADGES ============
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      body: appBackground(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios, color: Colors.white70, size: 16),
                      Text('Back',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('🎖️ Badges',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('$unlocked/${achievements.length} unlocked',
                  style: const TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: achievements.length,
                  itemBuilder: (_, i) => _BadgeTile(achievement: achievements[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  const _BadgeTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final open = achievement.unlocked;
    final color = open ? _gold : Colors.white24;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: open ? _gold.withValues(alpha: 0.10) : _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: open ? 0.6 : 0.4)),
      ),
      child: Row(
        children: [
          // Naka-lock: kupas ang emoji, pero hindi tinatago — para may makita
          // kang puntahan.
          Opacity(
            opacity: open ? 1 : 0.35,
            child: Text(achievement.emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title,
                    style: TextStyle(
                        color: open ? Colors.white : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(achievement.hint,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                if (!open) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: achievement.progress / achievement.target,
                      minHeight: 5,
                      backgroundColor: _bgBottom,
                      valueColor: const AlwaysStoppedAnimation(_accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${achievement.progress}/${achievement.target}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ],
            ),
          ),
          if (open)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle_rounded, color: _gold, size: 24),
            ),
        ],
      ),
    );
  }
}

// ============ DIFFICULTY PICKER ============
// Stateful ito dahil kailangang mag-refresh ang high score pagbalik mula sa
// laro — kung hindi, luma pa rin ang makikitang record.
class DifficultyScreen extends StatefulWidget {
  final Category category;
  const DifficultyScreen({super.key, required this.category});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    return Scaffold(
      body: appBackground(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios,
                          color: Colors.white70, size: 16),
                      Text('Back',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('${category.emoji} ${category.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Select difficulty',
                  style: TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 36),
              ...Difficulty.values.map((diff) {
                final count = category.questions[diff]?.length ?? 0;
                final best = HighScores.instance.best(category.name, diff.name);
                final perfect = isPerfect(category, diff);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          category: category,
                          difficulty: diff,
                        ),
                      ));
                      if (mounted) setState(() {}); // ipakita ang bagong record
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 22),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: diff.color.withValues(alpha: 0.6),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: diff.color.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(diff.emoji,
                              style: const TextStyle(fontSize: 30)),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(diff.label,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  if (perfect)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text('✅',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                                ],
                              ),
                              Text('$count questions',
                                  style: TextStyle(
                                      color: diff.color, fontSize: 13)),
                            ],
                          ),
                          const Spacer(),
                          // Walang trophy kung hindi pa nalalaro — walang
                          // kwentang magpakita ng "🏆 0".
                          if (best > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Text('🏆 $best',
                                  style: const TextStyle(
                                      color: _gold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            ),
                          Icon(Icons.arrow_forward_ios,
                              color: diff.color, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              _adaptiveCard(),
            ],
          ),
        ),
      ),
    );
  }

  // Pang-apat na mode, hiwalay sa tatlo. Hindi nito ginagalaw ang record o ang
  // ✅ ng Easy/Medium/Hard.
  Widget _adaptiveCard() {
    final category = widget.category;
    final best = HighScores.instance.best(category.name, 'adaptive');

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuizScreen(
            category: category,
            difficulty: Difficulty.medium, // panimula sa gitna
            adaptive: true,
          ),
        ));
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _accent.withValues(alpha: 0.25),
            _accent2.withValues(alpha: 0.25),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent2.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _accent2.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 18),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adaptive',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('$_adaptiveQuestions questions • sumusunod sa iyo',
                    style: TextStyle(color: _accent2, fontSize: 13)),
              ],
            ),
            const Spacer(),
            if (best > 0)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text('🏆 $best',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            const Icon(Icons.arrow_forward_ios, color: _accent2, size: 18),
          ],
        ),
      ),
    );
  }
}

// ============ QUIZ SCREEN ============
class QuizScreen extends StatefulWidget {
  final Category category;
  final Difficulty difficulty; // sa adaptive, ito ang panimulang level
  final bool adaptive;
  // Kapag may laman, Daily Challenge ito: handa na ang tanong, walang shuffle
  // at walang adaptive — pareho ang laro ng lahat sa buong araw.
  final List<Question>? dailyQuestions;
  const QuizScreen(
      {super.key,
      required this.category,
      required this.difficulty,
      this.adaptive = false,
      this.dailyQuestions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _current = 0;
  int _correctCount = 0; // bilang ng tama — ito ang basehan ng result ring
  int _points = 0; // puntos kasama ang streak bonus — ito ang ⭐ sa itaas
  int _streak = 0; // ilan nang sunod-sunod na tama ngayon
  int _bestStreak = 0;
  int _lastGain = 0; // puntos na nakuha sa huling sagot (pang-display lang)
  int _previousBest = 0; // record bago ang larong ito — pang-result screen
  bool _isNewRecord = false;
  int _xpGained = 0; // XP na nakuha sa larong ito — pang-result screen
  int _newLevel = 0;
  bool _leveledUp = false;
  int _fastAnswers = 0; // mabibilis na tamang sagot sa larong ito
  List<Achievement> _newBadges = const [];
  bool _answered = false;
  int? _selected;
  bool _finished = false;
  bool _timedOut = false;

  Timer? _ticker;
  double _timeLeft = _secondsPerQuestion;

  // ---- ADAPTIVE ----
  // Kada difficulty may sariling natitirang tanong. Hinuhugot isa-isa habang
  // naglalaro, kaya ang antas ng susunod ay base sa huling sagot mo.
  late Map<Difficulty, List<Question>> _pool = _buildPool();
  late int _levelIndex = widget.difficulty.index;
  int _atLevel = 0; // sunod-sunod na tama sa kasalukuyang level

  Difficulty get _level => Difficulty.values[_levelIndex];

  // Hindi puwedeng humingi ng mas maraming tanong kaysa sa meron ang category.
  // Binibilang ito sa mismong data at hindi sa _pool, dahil nauubos ang _pool
  // habang naglalaro — magiging mali ang bilang depende sa kung kailan mabasa.
  late final int _adaptiveTotal = min(
      _adaptiveQuestions,
      Difficulty.values.fold<int>(
          0, (n, d) => n + (widget.category.questions[d]?.length ?? 0)));

  int get _totalQuestions =>
      widget.adaptive ? _adaptiveTotal : _questions.length;

  Map<Difficulty, List<Question>> _buildPool() => {
        for (final d in Difficulty.values)
          d: (widget.category.questions[d] ?? const <Question>[])
              .map(shuffleAnswers)
              .toList()
            ..shuffle(),
      };

  // Dalawang sunod na tama = akyat. Isang mali = baba agad.
  // Mas mabilis bumaba kaysa umakyat, para hindi ka ma-stuck sa sobrang hirap.
  void _adapt(bool correct) {
    if (!widget.adaptive) return;
    if (correct) {
      _atLevel++;
      if (_atLevel >= _levelUpAfter && _levelIndex < Difficulty.values.length - 1) {
        _levelIndex++;
        _atLevel = 0;
      }
    } else {
      if (_levelIndex > 0) _levelIndex--;
      _atLevel = 0;
    }
  }

  // Kumukuha sa kasalukuyang level; kung ubos na iyon, sa pinakamalapit na
  // level na may natitira pa — kaya hindi nauubusan sa gitna ng laro.
  Question? _draw() {
    final byNearest = Difficulty.values.toList()
      ..sort((a, b) => (a.index - _levelIndex)
          .abs()
          .compareTo((b.index - _levelIndex).abs()));

    for (final d in byNearest) {
      final list = _pool[d]!;
      if (list.isNotEmpty) return list.removeLast();
    }
    return null;
  }

  bool get _isDaily => widget.dailyQuestions != null;

  // Bagong halo kada laro, kaya hindi na-memorize ang pagkakasunod-sunod.
  // Ang daily lang ang hindi hinahalo — nakatakda na ito para sa araw na ito.
  late List<Question> _questions = _freshQuestions();

  List<Question> _freshQuestions() {
    if (_isDaily) return widget.dailyQuestions!;
    return widget.adaptive ? [_draw()!] : _shuffledQuestions();
  }

  List<Question> _shuffledQuestions() {
    final source =
        widget.category.questions[widget.difficulty] ?? const <Question>[];
    return source.map(shuffleAnswers).toList()..shuffle();
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _ticker?.cancel();
    _timeLeft = _secondsPerQuestion;
    _ticker = Timer.periodic(_tick, (_) {
      setState(() {
        _timeLeft -= _tick.inMilliseconds / 1000;
        if (_timeLeft <= 0) {
          _timeLeft = 0;
          _timeUp();
        }
      });
    });
  }

  // Naubos ang oras: ituring na sagot na (walang puntos), ipakita ang tama.
  void _timeUp() {
    _ticker?.cancel();
    _answered = true;
    _timedOut = true;
    _selected = null;
    _adapt(false); // ang naubusan ng oras ay parang mali rin — bumaba ang level
    _breakStreak();
    Sfx.instance.buzz();
  }

  void _answer(int i) {
    if (_answered) return;
    _ticker?.cancel();
    setState(() {
      _answered = true;
      _selected = i;
      final tama = i == _questions[_current].correct;
      _adapt(tama);
      if (tama) {
        _correctCount++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
        if (_secondsPerQuestion - _timeLeft <= _fastAnswerSeconds) {
          _fastAnswers++;
        }
        _lastGain = _basePoints + _bonusFor(_streak);
        _points += _lastGain;
        Sfx.instance.ding();
      } else {
        _breakStreak();
        Sfx.instance.buzz();
      }
    });
  }

  // Mali o naubusan ng oras: bumabalik sa zero ang streak.
  void _breakStreak() {
    _streak = 0;
    _lastGain = 0;
  }

  void _next() {
    setState(() {
      // Sa adaptive, ngayon lang pinipili ang susunod na tanong — pagkatapos
      // ma-adjust ang level base sa kasasagot mo lang.
      if (widget.adaptive && _questions.length < _totalQuestions) {
        final q = _draw();
        if (q != null) _questions.add(q);
      }

      if (_current < _questions.length - 1) {
        _current++;
        _answered = false;
        _timedOut = false;
        _selected = null;
        _lastGain = 0; // itago ang banner hanggang may bagong sagot
        _startTimer();
      } else {
        _ticker?.cancel();
        _finished = true;
        _finishGame();
        Sfx.instance.victory();
      }
    });
  }

  // Hiwalay ang record ng Adaptive sa Easy/Medium/Hard — ibang laro ito, kaya
  // hindi patas na paghambingin. Ito rin ang dahilan kung bakit hindi kasama
  // ang Adaptive sa ✅ progress tracking.
  String get _modeKey {
    if (_isDaily) return 'daily';
    return widget.adaptive ? 'adaptive' : widget.difficulty.name;
  }

  String get _modeLabel {
    if (_isDaily) return '📅 Daily Challenge';
    return widget.adaptive ? '🎯 Adaptive' : widget.difficulty.label;
  }

  // Lahat ng itinatala kapag tapos ang laro, sa tamang pagkakasunod-sunod.
  void _finishGame() {
    // Ang badges ay kinukuha BAGO baguhin ang kahit ano — ito ang basehan ng
    // "bago" sa dulo. Kung pagkatapos ito kunin, mukhang bukas na ang lahat at
    // wala nang maipapakitang bagong badge kahit kaka-unlock lang.
    final badgesBefore = unlockedBadgeIds();

    final cat = widget.category.name;
    final diff = _modeKey;
    // Tinitingnan muna kung record bago mag-save — kapag naunang nag-save,
    // hindi na ito magiging record dahil ito na mismo ang pinakamataas.
    _previousBest = HighScores.instance.best(cat, diff);
    _isNewRecord = _points > _previousBest;
    HighScores.instance.save(cat, diff, points: _points, correct: _correctCount);

    // Itinatala ang araw at ang day streak. Hindi ito naaapektuhan ng "Play
    // Again" — may sariling guard ang complete() kapag tapos na ngayong araw.
    if (_isDaily) Daily.instance.complete(_points);

    _awardXp();

    Achievements.instance.recordGame(
      perfect: _correctCount == _totalQuestions,
      fastAnswers: _fastAnswers,
      bestStreak: _bestStreak,
    );

    _newBadges =
        achievements.where((a) => a.unlocked && !badgesBefore.contains(a.id)).toList();
  }

  // Ang puntos mo ang XP mo — kasama na ang streak bonus, kaya ang mahusay na
  // laro ay mas mabilis magpataas ng level kaysa sa dami ng laro.
  void _awardXp() {
    _xpGained = _points;
    final before = Profile.instance.level;
    Profile.instance.addXp(_xpGained);
    _newLevel = Profile.instance.level;
    _leveledUp = _newLevel > before;
  }

  void _restart() {
    setState(() {
      // Bagong halo at bagong buong pool kada "Play Again".
      _pool = _buildPool();
      _levelIndex = widget.difficulty.index;
      _atLevel = 0;
      _questions = _freshQuestions();
      _current = 0;
      _correctCount = 0;
      _points = 0;
      _streak = 0;
      _bestStreak = 0;
      _lastGain = 0;
      _isNewRecord = false;
      _xpGained = 0;
      _leveledUp = false;
      _fastAnswers = 0;
      _newBadges = const [];
      _answered = false;
      _timedOut = false;
      _selected = null;
      _finished = false;
      _startTimer();
    });
  }

  // Sa result: "New high score!" kung natalo ang record, kung hindi ay ang
  // dapat abutin sa susunod na laro.
  // Sa result: kung nag-level up, ito ang bida. Kung hindi, ipinapakita kung
  // gaano na kalapit ang susunod na level — para may susunod na target.
  Widget _xpLine() {
    final info = Profile.instance.levelInfo;
    final rank = Profile.instance.rank;

    if (_leveledUp) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: rank.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: rank.color, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⬆️ LEVEL UP! → Level $_newLevel',
                style: TextStyle(
                    color: rank.color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            Text('${rank.emoji} ${rank.label} • +$_xpGained XP',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text('+$_xpGained XP',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: info.progress,
              minHeight: 6,
              backgroundColor: _card,
              valueColor: AlwaysStoppedAnimation(rank.color),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
            '${rank.emoji} Level ${info.level} • ${info.need - info.into} XP to next',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  // Ang bagong na-unlock na badge ang pinaka-satisfying na bahagi ng result,
  // kaya buo ang pangalan at hint — hindi lang emoji.
  Widget _newBadgesLine() {
    return Column(
      children: [
        for (final b in _newBadges)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(b.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎖️ BADGE UNLOCKED',
                        style: TextStyle(
                            color: _gold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    Text(b.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _highScoreLine() {
    if (_isNewRecord) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold),
        ),
        child: Text(
          _previousBest == 0
              ? '🏆 First high score!'
              : '🏆 New high score! (dati: $_previousBest)',
          style: const TextStyle(
              color: _gold, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Text('🏆 Best: $_previousBest points',
        style: const TextStyle(color: Colors.white54, fontSize: 14));
  }

  // Maliit na kahon sa result: emoji, malaking numero, at label.
  Widget _resultStat(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$emoji $value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  // Lumalabas lang ang apoy kapag may 2 pataas na sunod-sunod na tama, para
  // may makita kang paparating bago pa umabot sa bonus sa pangatlo.
  Widget _streakBadge() {
    final active = _streak >= _streakNeeded;
    final color = active ? _fire : Colors.white38;

    return AnimatedScale(
      scale: active ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text('🔥 $_streak',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _gradientButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_accent, _accent2]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _accent.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Kulay ng timer: berde → dilaw → pula habang nauubos ang oras.
  Color get _timerColor {
    if (_timeLeft > 10) return _correct;
    if (_timeLeft > 5) return const Color(0xFFFFB020);
    return _wrong;
  }

  Widget _countdownBar() {
    final seconds = _timeLeft.ceil();
    final urgent = _timeLeft <= 5 && !_answered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Question ${_current + 1}/$_totalQuestions',
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            AnimatedScale(
              scale: urgent ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text('⏱️ ${seconds}s',
                  style: TextStyle(
                      color: _timerColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _timeLeft / _secondsPerQuestion,
            minHeight: 6,
            backgroundColor: _card,
            valueColor: AlwaysStoppedAnimation(_timerColor),
          ),
        ),
      ],
    );
  }

  // Pagkatapos ng tamang sagot: ipakita kung magkano ang nakuha at kung may
  // bonus. Dito nakikita ng player kung bakit sulit ang mag-ingat.
  Widget _gainBanner() {
    final bonus = _bonusFor(_streak);
    final color = bonus > 0 ? _fire : _correct;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('+$_lastGain',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(
            bonus > 0
                ? '🔥 $_streak in a row! (+$bonus bonus)'
                : 'Tama!',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _timesUpBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _wrong.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _wrong),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('⏰', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text("Time's up!",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _answerCard(int index, String text, int correctIndex) {
    Color bg = _card;
    Color border = _cardBorder;
    IconData? icon;
    Color iconColor = Colors.white;

    if (_answered) {
      if (index == correctIndex) {
        bg = _correct.withValues(alpha: 0.16);
        border = _correct;
        icon = Icons.check_circle_rounded;
        iconColor = _correct;
      } else if (index == _selected) {
        bg = _wrong.withValues(alpha: 0.16);
        border = _wrong;
        icon = Icons.cancel_rounded;
        iconColor = _wrong;
      }
    }

    final letter = String.fromCharCode(65 + index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _answer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: border == _cardBorder
                      ? _accent.withValues(alpha: 0.25)
                      : border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(letter,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500)),
              ),
              if (icon != null) Icon(icon, color: iconColor, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    // Sa adaptive, ang kasalukuyang level ang nagdidikta ng kulay ng progress
    // bar at ng mga accent — kaya nakikita mong gumagalaw ang laro.
    final diff = widget.adaptive ? _level : widget.difficulty;

    // ---- RESULT ----
    if (_finished) {
      // Ang porsyento at ang ring ay base sa tamang sagot, hindi sa puntos —
      // ang bonus ay puwedeng lumampas sa 100% kung isasama.
      final pct = (_correctCount / _totalQuestions * 100).round();
      String message;
      String emoji;
      if (pct == 100) {
        message = 'Perfect!';
        emoji = '🏆';
      } else if (pct >= 60) {
        message = 'Great job!';
        emoji = '🎉';
      } else {
        message = 'Try again!';
        emoji = '💪';
      }

      return Scaffold(
        body: appBackground(
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
                Text(_isDaily ? _modeLabel : '${cat.name} • $_modeLabel',
                    style: const TextStyle(color: Colors.white54, fontSize: 15)),
                const SizedBox(height: 36),
                SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CircularProgressIndicator(
                          value: _correctCount / _totalQuestions,
                          strokeWidth: 14,
                          backgroundColor: _card,
                          valueColor: AlwaysStoppedAnimation(diff.color),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_correctCount/$_totalQuestions',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold)),
                          Text('$pct%',
                              style: TextStyle(
                                  color: diff.color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _resultStat('⭐', '$_points', 'points', _accent),
                    const SizedBox(width: 14),
                    _resultStat('🔥', '$_bestStreak', 'best streak', _fire),
                  ],
                ),
                const SizedBox(height: 18),
                _xpLine(),
                const SizedBox(height: 12),
                if (_newBadges.isNotEmpty) ...[
                  _newBadgesLine(),
                  const SizedBox(height: 12),
                ],
                _highScoreLine(),
                const SizedBox(height: 26),
                // Walang "Play Again" sa daily: pareho ang 6 na tanong sa buong
                // araw, kaya ang pag-ulit ay pagsagot lang sa nakita mo na.
                if (_isDaily)
                  _gradientButton(
                      '← Back to Home',
                      () => Navigator.of(context)
                          .popUntil((route) => route.isFirst))
                else
                  _gradientButton('Play Again', _restart),
                const SizedBox(height: 14),
                if (!_isDaily)
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('← Back to Home',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // ---- QUESTION ----
    final q = _questions[_current];
    final progress = (_current + 1) / _totalQuestions;

    return Scaffold(
      body: appBackground(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios,
                            color: Colors.white70, size: 16),
                        Text(
                            _isDaily
                                ? '📅 Daily Challenge'
                                : widget.adaptive
                                    ? '${cat.emoji} 🎯 ${diff.label}'
                                    : '${cat.emoji} ${cat.name} • ${diff.label}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (_streak >= 2) _streakBadge(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('⭐ $_points',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: _card,
                  valueColor: AlwaysStoppedAnimation(diff.color),
                ),
              ),
              const SizedBox(height: 8),
              _countdownBar(),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _card.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Text(q.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                                height: 1.3)),
                      ),
                      const SizedBox(height: 28),
                      if (_timedOut) _timesUpBanner(),
                      if (_lastGain > 0) _gainBanner(),
                      ...q.answers.asMap().entries.map(
                            (e) => _answerCard(e.key, e.value, q.correct),
                          ),
                    ],
                  ),
                ),
              ),
              if (_answered)
                // Base sa _totalQuestions, hindi sa _questions.length: sa
                // adaptive ay hindi pa nahuhugot ang susunod na tanong dito,
                // kaya "Finish" ang lalabas sa bawat tanong kung length ang
                // gagamitin.
                _gradientButton(
                  _current < _totalQuestions - 1 ? 'Next Question' : 'Finish',
                  _next,
                ),
            ],
          ),
        ),
      ),
    );
  }
}