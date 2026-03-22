// pubspec.yaml dependencies:
// flutter:
//   sdk: flutter
// cupertino_icons: ^1.0.2
// fl_chart: ^0.65.0
// shared_preferences: ^2.2.2
// intl: ^0.19.0
// provider: ^6.1.1
// uuid: ^4.2.1

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: DailyTrackerApp(),
    ),
  );
}

// ─────────────────────────── APP ROOT ───────────────────────────

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'DailyTracker',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          home: ExpenseTrackerHome(),
        );
      },
    );
  }
}

// ─────────────────────────── THEMES ───────────────────────────

class AppThemes {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.light,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A73E8),
      brightness: Brightness.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _save();
  }

  void _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', _themeMode.toString());
  }

  void load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('theme_mode');
    if (s != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.toString() == s,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }
}

// ─────────────────────────── MODELS ───────────────────────────

class Expense {
  final String id;
  final String categoryId;
  final String categoryName;
  final double amount;
  final DateTime date;
  final String? note;
  final String icon;
  final Color color;

  Expense({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.date,
    this.note,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'icon': icon,
        'color': color.value,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] ?? '',
        categoryId: j['categoryId'] ?? '',
        categoryName: j['categoryName'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        note: j['note'],
        icon: j['icon'] ?? '💰',
        color: Color(j['color'] ?? Colors.grey.value),
      );
}

class ExpenseCategory {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final double suggestedAmount;
  double monthlyBudget;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.suggestedAmount,
    this.monthlyBudget = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color.value,
        'suggestedAmount': suggestedAmount,
        'monthlyBudget': monthlyBudget,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        icon: j['icon'] ?? '💰',
        color: Color(j['color'] ?? Colors.grey.value),
        suggestedAmount: (j['suggestedAmount'] ?? 0).toDouble(),
        monthlyBudget: (j['monthlyBudget'] ?? 0).toDouble(),
      );
}

class SavingsGoal {
  String id;
  String name;
  double targetAmount;
  double savedAmount;
  String emoji;
  DateTime createdAt;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    this.emoji = '🎯',
    required this.createdAt,
  });

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remaining => math.max(0, targetAmount - savedAmount);
  bool get isCompleted => savedAmount >= targetAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'emoji': emoji,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        targetAmount: (j['targetAmount'] ?? 0).toDouble(),
        savedAmount: (j['savedAmount'] ?? 0).toDouble(),
        emoji: j['emoji'] ?? '🎯',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

// ─────────────────────────── PROVIDER ───────────────────────────

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  List<SavingsGoal> _goals = [];
  bool _isLoading = false;
  String? _error;

  List<Expense> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  List<SavingsGoal> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Expense> get todaysExpenses {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .toList();
  }

  double get todaysTotalExpenses =>
      todaysExpenses.fold(0.0, (s, e) => s + e.amount);

  double getMonthlyTotal() {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double getTotalBudget() =>
      _categories.fold(0.0, (s, c) => s + c.monthlyBudget);

  Map<String, double> getWeeklyTotals() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final result = <String, double>{};
    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final key = DateFormat('EEE').format(d);
      result[key] = _expenses
          .where((e) =>
              e.date.year == d.year &&
              e.date.month == d.month &&
              e.date.day == d.day)
          .fold(0.0, (s, e) => s + e.amount);
    }
    return result;
  }

  /// Returns a map of day-of-month → total for the current month (heatmap)
  Map<int, double> getMonthlyHeatmap() {
    final now = DateTime.now();
    final result = <int, double>{};
    for (var e in _expenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        result[e.date.day] = (result[e.date.day] ?? 0) + e.amount;
      }
    }
    return result;
  }

  /// Returns spent amount for a category this month
  double getCategoryMonthlySpent(String categoryId) {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.categoryId == categoryId &&
            e.date.year == now.year &&
            e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  Map<String, double> get todaysCategoryTotals {
    final result = <String, double>{};
    for (var e in todaysExpenses) {
      result[e.categoryName] = (result[e.categoryName] ?? 0) + e.amount;
    }
    return result;
  }

  // ── Init ──

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadCategories();
      await _loadExpenses();
      await _loadGoals();
      _error = null;
    } catch (e) {
      _error = 'Failed to load data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Categories ──

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('categories');
    if (raw != null) {
      final list = json.decode(raw) as List;
      _categories = list.map((c) => ExpenseCategory.fromJson(c)).toList();
    } else {
      _categories = _defaultCategories();
      await _saveCategories();
    }
  }

  List<ExpenseCategory> _defaultCategories() => [
        ExpenseCategory(
            id: 'transport',
            name: 'Transport',
            icon: '🚍',
            color: Colors.orange,
            suggestedAmount: 20,
            monthlyBudget: 500),
        ExpenseCategory(
            id: 'food',
            name: 'Food',
            icon: '🍔',
            color: Colors.red,
            suggestedAmount: 35,
            monthlyBudget: 1500),
        ExpenseCategory(
            id: 'airtime',
            name: 'Airtime',
            icon: '📱',
            color: Colors.blue,
            suggestedAmount: 10,
            monthlyBudget: 200),
        ExpenseCategory(
            id: 'shopping',
            name: 'Shopping',
            icon: '🛒',
            color: Colors.green,
            suggestedAmount: 50,
            monthlyBudget: 800),
        ExpenseCategory(
            id: 'entertainment',
            name: 'Entertainment',
            icon: '🎬',
            color: Colors.purple,
            suggestedAmount: 25,
            monthlyBudget: 400),
        ExpenseCategory(
            id: 'health',
            name: 'Health',
            icon: '🏥',
            color: Colors.teal,
            suggestedAmount: 40,
            monthlyBudget: 300),
        ExpenseCategory(
            id: 'other',
            name: 'Other',
            icon: '💰',
            color: Colors.grey,
            suggestedAmount: 15,
            monthlyBudget: 200),
      ];

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'categories', json.encode(_categories.map((c) => c.toJson()).toList()));
  }

  Future<void> updateCategoryBudget(String categoryId, double budget) async {
    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx != -1) {
      _categories[idx].monthlyBudget = budget;
      await _saveCategories();
      notifyListeners();
    }
  }

  // ── Expenses ──

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('expenses') ?? '[]';
    final list = json.decode(raw) as List;
    _expenses = list.map((e) => Expense.fromJson(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'expenses', json.encode(_expenses.map((e) => e.toJson()).toList()));
  }

  Future<void> addExpense({
    required String categoryId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      categoryId: categoryId,
      categoryName: cat.name,
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
      icon: cat.icon,
      color: cat.color,
    );
    _expenses.insert(0, expense);
    await _saveExpenses();
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _saveExpenses();
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  // ── Goals ──

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('goals') ?? '[]';
    final list = json.decode(raw) as List;
    _goals = list.map((g) => SavingsGoal.fromJson(g)).toList();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'goals', json.encode(_goals.map((g) => g.toJson()).toList()));
  }

  Future<void> addGoal(SavingsGoal goal) async {
    _goals.add(goal);
    await _saveGoals();
    notifyListeners();
  }

  Future<void> contributeToGoal(String goalId, double amount) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      _goals[idx].savedAmount =
          math.min(_goals[idx].savedAmount + amount, _goals[idx].targetAmount);
      await _saveGoals();
      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _saveGoals();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ─────────────────────────── HOME SHELL ───────────────────────────

class ExpenseTrackerHome extends StatefulWidget {
  const ExpenseTrackerHome({super.key});

  @override
  State<ExpenseTrackerHome> createState() => _ExpenseTrackerHomeState();
}

class _ExpenseTrackerHomeState extends State<ExpenseTrackerHome> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    DashboardTab(),
    BudgetTab(),
    SavingsTab(),
    HistoryTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().initialize();
      context.read<ThemeProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: _tabs[_currentIndex],
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddExpense(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Budget'),
              NavigationDestination(
                  icon: Icon(Icons.savings_outlined),
                  selectedIcon: Icon(Icons.savings),
                  label: 'Savings'),
              NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History'),
            ],
          ),
        );
      },
    );
  }

  void _showAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseBottomSheet(),
    );
  }
}

// ─────────────────────────── DASHBOARD TAB ───────────────────────────

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final monthlyTotal = provider.getMonthlyTotal();
        final totalBudget = provider.getTotalBudget();
        final budgetUsedPct = totalBudget > 0
            ? (monthlyTotal / totalBudget).clamp(0.0, 1.0)
            : 0.0;
        final heatmap = provider.getMonthlyHeatmap();
        final weeklyTotals = provider.getWeeklyTotals();
        final todayTotal = provider.todaysTotalExpenses;
        final catTotals = provider.todaysCategoryTotals;

        return CustomScrollView(
          slivers: [
            // ── App bar ──
            SliverAppBar(
              floating: true,
              title: const Text('DailyTracker'),
              actions: [
                Consumer<ThemeProvider>(
                  builder: (_, tp, __) => IconButton(
                    icon: Icon(tp.themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                    onPressed: tp.toggleTheme,
                  ),
                ),
              ],
            ),

            // ── Hero spend card ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _HeroCard(
                  monthlyTotal: monthlyTotal,
                  totalBudget: totalBudget,
                  budgetUsedPct: budgetUsedPct,
                  todayTotal: todayTotal,
                  month: DateFormat('MMMM').format(now),
                ),
              ),
            ),

            // ── Today's breakdown ──
            if (catTotals.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _TodayBreakdownCard(
                      catTotals: catTotals, total: todayTotal),
                ),
              ),

            // ── Weekly bar chart ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _WeeklyChartCard(weeklyTotals: weeklyTotals),
              ),
            ),

            // ── Heatmap calendar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: _HeatmapCard(heatmap: heatmap, month: now),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Hero Card ──

class _HeroCard extends StatelessWidget {
  final double monthlyTotal;
  final double totalBudget;
  final double budgetUsedPct;
  final double todayTotal;
  final String month;

  const _HeroCard({
    required this.monthlyTotal,
    required this.totalBudget,
    required this.budgetUsedPct,
    required this.todayTotal,
    required this.month,
  });

  Color _budgetColor(double pct) {
    if (pct < 0.65) return Colors.greenAccent.shade400;
    if (pct < 0.85) return Colors.orangeAccent.shade400;
    return Colors.redAccent.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = math.max(0.0, totalBudget - monthlyTotal);
    final color = _budgetColor(budgetUsedPct);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$month Spending',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'R${monthlyTotal.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Budget progress bar
          if (totalBudget > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(budgetUsedPct * 100).toStringAsFixed(0)}% of budget used',
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'R${remaining.toStringAsFixed(0)} left',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: budgetUsedPct,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Quick stats row
          Row(
            children: [
              _QuickStat(
                  label: 'Today', value: 'R${todayTotal.toStringAsFixed(0)}'),
              Container(
                  width: 1,
                  height: 32,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 16)),
              _QuickStat(
                  label: 'Monthly Budget',
                  value: totalBudget > 0
                      ? 'R${totalBudget.toStringAsFixed(0)}'
                      : 'Not set'),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Today breakdown card ──

class _TodayBreakdownCard extends StatelessWidget {
  final Map<String, double> catTotals;
  final double total;
  const _TodayBreakdownCard({required this.catTotals, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today's Breakdown",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('R${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: catTotals.entries.map((e) {
                    final pct = total > 0 ? e.value / total : 0.0;
                    return Flexible(
                      flex: (pct * 1000).round(),
                      child: Container(color: _colorForCat(e.key)),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: catTotals.entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorForCat(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('${e.key} R${e.value.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForCat(String name) {
    switch (name.toLowerCase()) {
      case 'transport':
        return Colors.orange;
      case 'food':
        return Colors.red;
      case 'airtime':
        return Colors.blue;
      case 'shopping':
        return Colors.green;
      case 'entertainment':
        return Colors.purple;
      case 'health':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

// ── Weekly Chart Card ──

class _WeeklyChartCard extends StatelessWidget {
  final Map<String, double> weeklyTotals;
  const _WeeklyChartCard({required this.weeklyTotals});

  @override
  Widget build(BuildContext context) {
    final maxVal = weeklyTotals.values.isNotEmpty
        ? weeklyTotals.values.reduce(math.max)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: maxVal > 0
                  ? BarChart(BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxVal * 1.25,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, gi, rod, rodi) =>
                              BarTooltipItem(
                            'R${rod.toY.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final days = weeklyTotals.keys.toList();
                              if (v.toInt() < days.length) {
                                return Text(days[v.toInt()],
                                    style:
                                        Theme.of(context).textTheme.bodySmall);
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (v, _) => Text(
                              'R${v.toInt()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: weeklyTotals.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) => BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 22,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              ))
                          .toList(),
                    ))
                  : Center(
                      child: Text('No data yet',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heatmap Card ──

class _HeatmapCard extends StatelessWidget {
  final Map<int, double> heatmap;
  final DateTime month;
  const _HeatmapCard({required this.heatmap, required this.month});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday =
        DateTime(month.year, month.month, 1).weekday % 7; // 0=Sun
    final maxVal =
        heatmap.values.isNotEmpty ? heatmap.values.reduce(math.max) : 1.0;
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Spending Heatmap',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(DateFormat('MMMM yyyy').format(month),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            // Day-of-week headers
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();
                final day = index - firstWeekday + 1;
                final amount = heatmap[day] ?? 0.0;
                final intensity = maxVal > 0 ? amount / maxVal : 0.0;
                final isToday = day == DateTime.now().day &&
                    month.month == DateTime.now().month &&
                    month.year == DateTime.now().year;

                return Tooltip(
                  message: amount > 0
                      ? 'Day $day: R${amount.toStringAsFixed(0)}'
                      : 'Day $day: no spend',
                  child: Container(
                    decoration: BoxDecoration(
                      color: intensity > 0
                          ? primary.withOpacity(0.15 + intensity * 0.75)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: intensity > 0.5
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              children: [
                Text('Less', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                ...List.generate(5, (i) {
                  return Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15 + i * 0.17),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                Text('More', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── BUDGET TAB ───────────────────────────

class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final totalBudget = provider.getTotalBudget();
        final monthlySpent = provider.getMonthlyTotal();

        return CustomScrollView(
          slivers: [
            const SliverAppBar(floating: true, title: Text('Monthly Budget')),
            // Summary
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Budget',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text('R${totalBudget.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: totalBudget > 0
                              ? (monthlySpent / totalBudget).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Spent: R${monthlySpent.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(
                                'Remaining: R${math.max(0, totalBudget - monthlySpent).toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Per-category budget rows
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = provider.categories[index];
                    final spent = provider.getCategoryMonthlySpent(cat.id);
                    final budget = cat.monthlyBudget;
                    final pct =
                        budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                    final overBudget = budget > 0 && spent > budget;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: cat.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                      child: Text(cat.icon,
                                          style:
                                              const TextStyle(fontSize: 20))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      Text(
                                        budget > 0
                                            ? 'R${spent.toStringAsFixed(0)} / R${budget.toStringAsFixed(0)}'
                                            : 'R${spent.toStringAsFixed(0)} spent — no budget set',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (overBudget)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Over!',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () =>
                                      _editBudget(context, provider, cat),
                                ),
                              ],
                            ),
                            if (budget > 0) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: cat.color.withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    overBudget ? Colors.red : cat.color,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: provider.categories.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editBudget(
      BuildContext context, ExpenseProvider provider, ExpenseCategory cat) {
    final ctrl = TextEditingController(
        text: cat.monthlyBudget > 0 ? cat.monthlyBudget.toString() : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${cat.icon} ${cat.name} Budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: 'R ',
            labelText: 'Monthly budget',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0;
              provider.updateCategoryBudget(cat.id, val);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── SAVINGS TAB ───────────────────────────

class SavingsTab extends StatelessWidget {
  const SavingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final goals = provider.goals;
        final totalSaved = goals.fold(0.0, (s, g) => s + g.savedAmount);
        final totalTarget = goals.fold(0.0, (s, g) => s + g.targetAmount);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Savings Goals'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addGoal(context, provider),
                ),
              ],
            ),
            if (goals.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SavingsStat(
                                label: 'Total Saved',
                                value: 'R${totalSaved.toStringAsFixed(0)}'),
                          ),
                          Container(
                              width: 1,
                              height: 40,
                              color: Theme.of(context).dividerColor),
                          Expanded(
                            child: _SavingsStat(
                                label: 'Total Target',
                                value: 'R${totalTarget.toStringAsFixed(0)}'),
                          ),
                          Container(
                              width: 1,
                              height: 40,
                              color: Theme.of(context).dividerColor),
                          Expanded(
                            child: _SavingsStat(
                                label: 'Goals', value: '${goals.length}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (goals.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('No savings goals yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _addGoal(context, provider),
                        icon: const Icon(Icons.add),
                        label: const Text('Create a goal'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = goals[index];
                      return _GoalCard(goal: goal, provider: provider);
                    },
                    childCount: goals.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _addGoal(BuildContext context, ExpenseProvider provider) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String emoji = '🎯';
    final emojis = ['🎯', '🏠', '✈️', '🚗', '📱', '💍', '📚', '🎮'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Savings Goal',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Emoji picker
                Wrap(
                  spacing: 8,
                  children: emojis
                      .map((e) => GestureDetector(
                            onTap: () => setState(() => emoji = e),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: emoji == e
                                    ? Theme.of(ctx).colorScheme.primaryContainer
                                    : Theme.of(ctx).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                  child: Text(e,
                                      style: const TextStyle(fontSize: 22))),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Goal name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: 'R ',
                    labelText: 'Target amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final target = double.tryParse(targetCtrl.text) ?? 0;
                      if (name.isNotEmpty && target > 0) {
                        provider.addGoal(SavingsGoal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          targetAmount: target,
                          savedAmount: 0,
                          emoji: emoji,
                          createdAt: DateTime.now(),
                        ));
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Create Goal'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _SavingsStat extends StatelessWidget {
  final String label;
  final String value;
  const _SavingsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final ExpenseProvider provider;
  const _GoalCard({required this.goal, required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = goal.progress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(goal.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        goal.isCompleted
                            ? '🎉 Goal reached!'
                            : 'R${goal.remaining.toStringAsFixed(0)} to go',
                        style: TextStyle(
                          color: goal.isCompleted
                              ? Colors.green
                              : scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R${goal.savedAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                          fontSize: 16),
                    ),
                    Text(
                      'of R${goal.targetAmount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress ring-style bar
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isCompleted ? Colors.green : scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${(pct * 100).toStringAsFixed(1)}% saved',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            if (!goal.isCompleted) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _contribute(context, provider, goal),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add funds'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => provider.deleteGoal(goal.id),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _contribute(
      BuildContext context, ExpenseProvider provider, SavingsGoal goal) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add funds to ${goal.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: 'R ',
            labelText: 'Amount to add',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0;
              if (val > 0) {
                provider.contributeToGoal(goal.id, val);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── HISTORY TAB ───────────────────────────

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final expenses = _filterDate != null
            ? provider.expenses
                .where((e) =>
                    e.date.year == _filterDate!.year &&
                    e.date.month == _filterDate!.month &&
                    e.date.day == _filterDate!.day)
                .toList()
            : provider.expenses;

        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: [
              if (_filterDate != null)
                IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _filterDate = null)),
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _filterDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _filterDate = picked);
                },
              ),
            ],
          ),
          body: expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        _filterDate != null
                            ? 'No expenses on this date'
                            : 'No expenses recorded yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      Card(child: _ExpenseTile(expense: expenses[i])),
                ),
        );
      },
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete expense?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) {
        context.read<ExpenseProvider>().deleteExpense(expense.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${expense.categoryName} deleted'),
          backgroundColor: Colors.red,
        ));
      },
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: expense.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
              child: Text(expense.icon, style: const TextStyle(fontSize: 22))),
        ),
        title: Text(expense.categoryName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd MMM yyyy • hh:mm a').format(expense.date),
                style: Theme.of(context).textTheme.bodySmall),
            if (expense.note != null && expense.note!.isNotEmpty)
              Text(expense.note!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(
          'R${expense.amount.toStringAsFixed(2)}',
          style: TextStyle(
              color: expense.color, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────── ADD EXPENSE SHEET ───────────────────────────

class AddExpenseBottomSheet extends StatefulWidget {
  const AddExpenseBottomSheet({super.key});

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  ExpenseCategory? _selected;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canAdd {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return _selected != null && amount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Add Expense',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: provider.categories.length,
                        itemBuilder: (context, i) {
                          final cat = provider.categories[i];
                          final sel = _selected?.id == cat.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selected = cat;
                                _amountCtrl.text =
                                    cat.suggestedAmount.toString();
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: sel
                                    ? cat.color.withOpacity(0.15)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant
                                        .withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? cat.color : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(cat.icon,
                                      style: const TextStyle(fontSize: 26)),
                                  const SizedBox(height: 4),
                                  Text(cat.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: sel
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: sel ? cat.color : null,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text('Amount',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixText: 'R ',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      Text('Note (Optional)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add a note...',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _canAdd ? _submit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _selected?.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Add Expense',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final note = _noteCtrl.text.trim();
    context.read<ExpenseProvider>().addExpense(
          categoryId: _selected!.id,
          amount: amount,
          note: note.isEmpty ? null : note,
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_selected!.name} expense added'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
