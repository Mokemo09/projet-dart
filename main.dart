// ╔═══════════════════════════════════════════════════════════════════╗
// ║  FINANCE — gestion d'argent personnelle, UN SEUL FICHIER (main.dart) ║
// ║  pubspec.yaml et tests : voir tout en bas du fichier.                ║
// ╚═══════════════════════════════════════════════════════════════════╝
// Installation : collez ce fichier dans lib/main.dart, puis
//   flutter pub add shared_preferences crypto
//   flutter run

import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.init();
  runApp(FinanceApp(store: store));
}

/* ══════════════════════ FORMATS ══════════════════════ */
const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _monthsShort = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const kCurrencies = ['USD', 'FC', 'EUR'];

double cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;
bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
String monthLabel(DateTime d) => '${_months[d.month - 1][0].toUpperCase()}${_months[d.month - 1].substring(1)} ${d.year}';
String curSym(String c) => c == 'USD' ? r'$' : (c == 'EUR' ? '€' : 'FC');
int curDec(String c) => c == 'FC' ? 0 : 2;

String fmtNum(double v, int dec) {
  final parts = v.abs().toStringAsFixed(dec).split('.');
  final ip = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) b.write('\u00A0');
    b.write(ip[i]);
  }
  return dec > 0 ? '$b,${parts[1]}' : b.toString();
}

String money(double v, String cur, {bool hide = false, bool sign = false}) {
  if (hide) return '••••';
  final prefix = v < -0.0000001 ? '-' : (sign && v > 0.0000001 ? '+' : '');
  return '$prefix${fmtNum(v, curDec(cur))}\u00A0${curSym(cur)}';
}

String compact(double v) {
  final a = v.abs();
  if (a >= 1000000) return '${(a / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
  if (a >= 1000) return '${(a / 1000).toStringAsFixed(a >= 10000 ? 0 : 1).replaceAll('.', ',')}k';
  return a.toStringAsFixed(0);
}

String dayLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  final x = dateOnly(d);
  if (x == today) return "Aujourd'hui";
  if (x == DateTime(today.year, today.month, today.day - 1)) return 'Hier';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]}';
}

String dateFr(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

/* ══════════════════════ THÈME ══════════════════════ */
const kPrimary = Color(0xFF4F46E5);
const kGreen = Color(0xFF10B981);
const kRed = Color(0xFFF43F5E);
const kAmber = Color(0xFFF59E0B);
const kGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: kPrimary, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: dark ? const Color(0xFF0B0F1A) : const Color(0xFFF5F6FB),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, color: dark ? const Color(0xFF141A2B) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: .5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(64, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: dark ? const Color(0xFF141A2B) : Colors.white, indicatorColor: cs.primaryContainer),
  );
}

/* ══════════════════════ CATÉGORIES ══════════════════════ */
class Cat {
  const Cat(this.id, this.name, this.icon, this.color);
  final String id, name;
  final IconData icon;
  final Color color;
}

const kExpenseCats = <Cat>[
  Cat('food', 'Alimentation', Icons.restaurant_rounded, Color(0xFFFF7043)),
  Cat('transport', 'Transport', Icons.directions_bus_rounded, Color(0xFF42A5F5)),
  Cat('home', 'Logement', Icons.home_rounded, Color(0xFF8D6E63)),
  Cat('bills', 'Factures', Icons.receipt_long_rounded, Color(0xFFFFB300)),
  Cat('health', 'Santé', Icons.favorite_rounded, Color(0xFFEF5350)),
  Cat('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFFAB47BC)),
  Cat('fun', 'Loisirs', Icons.sports_esports_rounded, Color(0xFF26C6DA)),
  Cat('edu', 'Éducation', Icons.school_rounded, Color(0xFF5C6BC0)),
  Cat('family', 'Famille', Icons.family_restroom_rounded, Color(0xFFEC407A)),
  Cat('other', 'Autres', Icons.more_horiz_rounded, Color(0xFF78909C)),
];
const kIncomeCats = <Cat>[
  Cat('salary', 'Salaire', Icons.account_balance_wallet_rounded, Color(0xFF10B981)),
  Cat('business', 'Activité', Icons.storefront_rounded, Color(0xFF14B8A6)),
  Cat('gift', 'Cadeau', Icons.card_giftcard_rounded, Color(0xFFF59E0B)),
  Cat('otherin', 'Autre revenu', Icons.add_circle_rounded, Color(0xFF64748B)),
];
const _catTransfer = Cat('transfer', 'Virement', Icons.swap_horiz_rounded, Color(0xFF6366F1));
const _catSaving = Cat('saving', 'Épargne', Icons.savings_rounded, Color(0xFFF59E0B));

Cat catOf(String id) {
  for (final c in [...kExpenseCats, ...kIncomeCats, _catTransfer, _catSaving]) {
    if (c.id == id) return c;
  }
  return kExpenseCats.last;
}

const kAccountTypes = ['cash', 'bank', 'mobile', 'savings'];
String accountTypeName(String t) => const {'cash': 'Espèces', 'bank': 'Banque', 'mobile': 'Mobile Money', 'savings': 'Épargne'}[t] ?? t;
IconData accountIcon(String t) => const {'cash': Icons.payments_rounded, 'bank': Icons.account_balance_rounded, 'mobile': Icons.smartphone_rounded, 'savings': Icons.savings_rounded}[t] ?? Icons.wallet_rounded;

/* ══════════════════════ MODÈLES ══════════════════════ */
enum TxType { expense, income, transfer, saving }

class Account {
  Account({required this.id, required this.name, required this.type, required this.currency, required this.opening});
  final String id;
  String name, type, currency;
  double opening;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'cur': currency, 'open': opening};
  factory Account.fromJson(Map<String, dynamic> j) => Account(id: j['id'], name: j['name'], type: j['type'], currency: j['cur'], opening: (j['open'] as num).toDouble());
}

class Tx {
  Tx({required this.id, required this.accountId, required this.categoryId, required this.type, required this.amount, required this.date, this.note = '', this.toAccountId, this.toAmount = 0, this.goalId, this.auto = false});
  final String id, accountId, categoryId, note;
  final TxType type;
  final double amount, toAmount;
  final DateTime date;
  final String? toAccountId, goalId;
  final bool auto;
  Map<String, dynamic> toJson() => {'id': id, 'acc': accountId, 'cat': categoryId, 'type': type.name, 'amount': amount, 'date': date.toIso8601String(), 'note': note, 'to': toAccountId, 'toAmount': toAmount, 'goal': goalId, 'auto': auto};
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
    id: j['id'],
    accountId: j['acc'],
    categoryId: j['cat'],
    type: TxType.values.byName(j['type']),
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
    note: j['note'] ?? '',
    toAccountId: j['to'],
    toAmount: (j['toAmount'] as num?)?.toDouble() ?? 0,
    goalId: j['goal'],
    auto: j['auto'] ?? false,
  );
}

class Goal {
  Goal({required this.id, required this.name, required this.target, this.saved = 0, this.deadline, required this.image});
  final String id, image;
  String name;
  double target, saved;
  DateTime? deadline;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'target': target, 'saved': saved, 'deadline': deadline?.toIso8601String(), 'image': image};
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(id: j['id'], name: j['name'], target: (j['target'] as num).toDouble(), saved: (j['saved'] as num).toDouble(), deadline: j['deadline'] == null ? null : DateTime.parse(j['deadline']), image: j['image']);
}

class Debt {
  Debt({required this.id, required this.person, required this.amount, this.paid = 0, required this.lent, this.due, this.note = ''});
  final String id;
  String person, note;
  double amount, paid;
  bool lent; // true = on me doit ; false = je dois
  DateTime? due;
  double get left => amount - paid;
  bool get overdue {
    final d = due;
    return d != null && left > 0 && d.isBefore(dateOnly(DateTime.now()));
  }

  Map<String, dynamic> toJson() => {'id': id, 'person': person, 'amount': amount, 'paid': paid, 'lent': lent, 'due': due?.toIso8601String(), 'note': note};
  factory Debt.fromJson(Map<String, dynamic> j) => Debt(id: j['id'], person: j['person'], amount: (j['amount'] as num).toDouble(), paid: (j['paid'] as num).toDouble(), lent: j['lent'], due: j['due'] == null ? null : DateTime.parse(j['due']), note: j['note'] ?? '');
}

class Recurring {
  Recurring({required this.id, required this.name, required this.amount, required this.categoryId, required this.accountId, required this.day, this.active = true, required this.lastApplied});
  final String id;
  String name, categoryId, accountId;
  double amount;
  int day, lastApplied;
  bool active;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount, 'cat': categoryId, 'acc': accountId, 'day': day, 'active': active, 'last': lastApplied};
  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(id: j['id'], name: j['name'], amount: (j['amount'] as num).toDouble(), categoryId: j['cat'], accountId: j['acc'], day: j['day'], active: j['active'] ?? true, lastApplied: j['last']);
}

class Insight {
  const Insight(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;
}

class SafeInfo {
  const SafeInfo({required this.leftToday, required this.allowance, required this.spentToday, required this.remaining, required this.pool, required this.upcoming, required this.daysLeft});
  final double leftToday, allowance, spentToday, remaining, pool, upcoming;
  final int daysLeft;
}

class Forecast {
  const Forecast({required this.endBalance, required this.avgDaily, required this.upcoming, required this.extra});
  final double endBalance, avgDaily, upcoming, extra;
}

class Health {
  const Health(this.score, this.tips);
  final int score;
  final List<String> tips;
  String get label => score >= 80 ? 'Excellente' : (score >= 60 ? 'Bonne' : (score >= 40 ? 'À surveiller' : 'Fragile'));
  Color get color => score >= 80 ? kGreen : (score >= 60 ? const Color(0xFF84CC16) : (score >= 40 ? kAmber : kRed));
}