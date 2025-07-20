// pubspec.yaml dependencies:
// flutter:
//   sdk: flutter
// cupertino_icons: ^1.0.2
// fl_chart: ^0.65.0
// shared_preferences: ^2.2.2
// intl: ^0.19.0
// provider: ^6.1.1
// sqflite: ^2.3.0
// path: ^1.8.3
// uuid: ^4.2.1

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
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

class DailyTrackerApp extends StatelessWidget {
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

// Theme Management
class AppThemes {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
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
    _saveTheme();
  }

  void _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme_mode', _themeMode.toString());
  }

  void loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == themeString,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }
}

// Models
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'icon': icon,
      'color': color.value,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      note: json['note'],
      icon: json['icon'] ?? '💰',
      color: Color(json['color'] ?? Colors.grey.value),
    );
  }

  Expense copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    double? amount,
    DateTime? date,
    String? note,
    String? icon,
    Color? color,
  }) {
    return Expense(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

class ExpenseCategory {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final double suggestedAmount;
  final bool isDefault;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.suggestedAmount,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color.value,
      'suggestedAmount': suggestedAmount,
      'isDefault': isDefault,
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '💰',
      color: Color(json['color'] ?? Colors.grey.value),
      suggestedAmount: (json['suggestedAmount'] ?? 0).toDouble(),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

// Data Management
class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  // Getters
  List<Expense> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;

  List<Expense> get todaysExpenses {
    final today = DateTime.now();
    return _expenses.where((expense) {
      return expense.date.year == today.year &&
          expense.date.month == today.month &&
          expense.date.day == today.day;
    }).toList();
  }

  List<Expense> get selectedDateExpenses {
    return _expenses.where((expense) {
      return expense.date.year == _selectedDate.year &&
          expense.date.month == _selectedDate.month &&
          expense.date.day == _selectedDate.day;
    }).toList();
  }

  double get todaysTotalExpenses {
    return todaysExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double get selectedDateTotalExpenses {
    return selectedDateExpenses.fold(
        0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> get todaysCategoryTotals {
    Map<String, double> totals = {};
    for (var expense in todaysExpenses) {
      totals[expense.categoryName] =
          (totals[expense.categoryName] ?? 0) + expense.amount;
    }
    return totals;
  }

  Map<String, double> get selectedDateCategoryTotals {
    Map<String, double> totals = {};
    for (var expense in selectedDateExpenses) {
      totals[expense.categoryName] =
          (totals[expense.categoryName] ?? 0) + expense.amount;
    }
    return totals;
  }

  // Initialize data
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadCategories();
      await _loadExpenses();
      _setError(null);
    } catch (e) {
      _setError('Failed to load data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Category management
  Future<void> _loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString('categories');

      if (categoriesJson != null) {
        final List<dynamic> categoriesList = json.decode(categoriesJson);
        _categories =
            categoriesList.map((c) => ExpenseCategory.fromJson(c)).toList();
      } else {
        _categories = _getDefaultCategories();
        await _saveCategories();
      }
    } catch (e) {
      _categories = _getDefaultCategories();
    }
  }

  List<ExpenseCategory> _getDefaultCategories() {
    return [
      ExpenseCategory(
        id: 'taxi',
        name: 'Transport',
        icon: '🚍',
        color: Colors.orange,
        suggestedAmount: 20.0,
        isDefault: true,
      ),
      ExpenseCategory(
        id: 'food',
        name: 'Food',
        icon: '🍔',
        color: Colors.red,
        suggestedAmount: 35.0,
        isDefault: true,
      ),
      ExpenseCategory(
        id: 'airtime',
        name: 'Airtime',
        icon: '📱',
        color: Colors.blue,
        suggestedAmount: 10.0,
        isDefault: true,
      ),
      ExpenseCategory(
        id: 'shopping',
        name: 'Shopping',
        icon: '🛒',
        color: Colors.green,
        suggestedAmount: 50.0,
        isDefault: true,
      ),
      ExpenseCategory(
        id: 'entertainment',
        name: 'Entertainment',
        icon: '🎬',
        color: Colors.purple,
        suggestedAmount: 25.0,
        isDefault: true,
      ),
      ExpenseCategory(
        id: 'health',
        name: 'Health',
        icon: '🏥',
        color: Colors.teal,
        suggestedAmount: 40.0,
        isDefault: true,
      ),
      ExpenseCategory(
        id: 'other',
        name: 'Other',
        icon: '💰',
        color: Colors.grey,
        suggestedAmount: 15.0,
        isDefault: true,
      ),
    ];
  }

  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson =
          json.encode(_categories.map((c) => c.toJson()).toList());
      await prefs.setString('categories', categoriesJson);
    } catch (e) {
      _setError('Failed to save categories: $e');
    }
  }

  // Expense management
  Future<void> _loadExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getString('expenses') ?? '[]';
      final List<dynamic> expensesList = json.decode(expensesJson);

      _expenses = expensesList.map((e) => Expense.fromJson(e)).toList();
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _expenses = [];
      _setError('Failed to load expenses: $e');
    }
  }

  Future<void> _saveExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson =
          json.encode(_expenses.map((e) => e.toJson()).toList());
      await prefs.setString('expenses', expensesJson);
    } catch (e) {
      _setError('Failed to save expenses: $e');
    }
  }

  Future<void> addExpense({
    required String categoryId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    try {
      final category = _categories.firstWhere((c) => c.id == categoryId);
      final expense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        categoryId: categoryId,
        categoryName: category.name,
        amount: amount,
        date: date ?? DateTime.now(),
        note: note,
        icon: category.icon,
        color: category.color,
      );

      _expenses.insert(0, expense);
      await _saveExpenses();
      notifyListeners();

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      _setError('Failed to add expense: $e');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      _expenses.removeWhere((expense) => expense.id == id);
      await _saveExpenses();
      notifyListeners();

      // Haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      _setError('Failed to delete expense: $e');
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
        await _saveExpenses();
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update expense: $e');
    }
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Analytics
  Map<String, double> getWeeklyTotals() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    Map<String, double> weeklyTotals = {};

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateKey = DateFormat('EEE').format(date);
      final dayExpenses = _expenses.where((expense) {
        return expense.date.year == date.year &&
            expense.date.month == date.month &&
            expense.date.day == date.day;
      });
      weeklyTotals[dateKey] =
          dayExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    }

    return weeklyTotals;
  }

  double getMonthlyTotal() {
    final now = DateTime.now();
    return _expenses.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;
    }).fold(0.0, (sum, expense) => sum + expense.amount);
  }
}

// UI Components
class ExpenseTrackerHome extends StatefulWidget {
  @override
  _ExpenseTrackerHomeState createState() => _ExpenseTrackerHomeState();
}

class _ExpenseTrackerHomeState extends State<ExpenseTrackerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().initialize();
      context.read<ThemeProvider>().loadTheme();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        if (expenseProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your expenses...'),
                ],
              ),
            ),
          );
        }

        if (expenseProvider.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  Text(
                    expenseProvider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      expenseProvider.clearError();
                      expenseProvider.initialize();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('DailyTracker'),
            elevation: 0,
            actions: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return IconButton(
                    icon: Icon(
                      themeProvider.themeMode == ThemeMode.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                    onPressed: themeProvider.toggleTheme,
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: Icon(Icons.today), text: 'Today'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              TodayTab(),
              AnalyticsTab(),
              HistoryTab(),
            ],
          ),
          floatingActionButton: AnimatedScale(
            scale: _currentIndex == 0 ? 1.0 : 0.8,
            duration: Duration(milliseconds: 200),
            child: FloatingActionButton.extended(
              onPressed: () => _showAddExpenseDialog(context),
              icon: Icon(Icons.add),
              label: Text('Add Expense'),
            ),
          ),
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseBottomSheet(),
    );
  }
}

class TodayTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final todaysExpenses = provider.todaysExpenses;
        final totalAmount = provider.todaysTotalExpenses;
        final categoryTotals = provider.todaysCategoryTotals;

        return CustomScrollView(
          slivers: [
            // Total expenses card
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                child: Card(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Today\'s Expenses',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'R${totalAmount.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (todaysExpenses.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            '${todaysExpenses.length} transactions',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Pie chart
            if (todaysExpenses.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Container(
                  height: 300,
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Expense Breakdown',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 16),
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: _buildPieChartSections(
                                    categoryTotals, totalAmount, context),
                                centerSpaceRadius: 50,
                                sectionsSpace: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Recent expenses
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Today\'s Transactions',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (todaysExpenses.isNotEmpty)
                              Text(
                                '${todaysExpenses.length} items',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      if (todaysExpenses.isEmpty)
                        Container(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No expenses today',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add your first expense',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: math.min(todaysExpenses.length, 5),
                          separatorBuilder: (context, index) =>
                              Divider(height: 1),
                          itemBuilder: (context, index) {
                            final expense = todaysExpenses[index];
                            return ExpenseListTile(expense: expense);
                          },
                        ),
                      if (todaysExpenses.length > 5)
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                // Navigate to full history
                              },
                              child: Text(
                                  'View all ${todaysExpenses.length} transactions'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categoryTotals,
    double totalAmount,
    BuildContext context,
  ) {
    if (totalAmount == 0) return [];

    return categoryTotals.entries.map((entry) {
      final percentage = (entry.value / totalAmount) * 100;
      return PieChartSectionData(
        color: _getCategoryColor(entry.key),
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getCategoryColor(String categoryName) {
    // This should ideally come from the category data
    switch (categoryName.toLowerCase()) {
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

class AnalyticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final weeklyTotals = provider.getWeeklyTotals();
        final monthlyTotal = provider.getMonthlyTotal();

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly summary card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This Month',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'R${monthlyTotal.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Weekly chart
              Text(
                'This Week',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 16),
              Card(
                child: Container(
                  height: 250,
                  padding: EdgeInsets.all(16),
                  child: weeklyTotals.values.any((value) => value > 0)
                      ? BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: weeklyTotals.values.isNotEmpty
                                ? weeklyTotals.values.reduce(math.max) * 1.2
                                : 100,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (double value, TitleMeta meta) {
                                    final days = weeklyTotals.keys.toList();
                                    if (value.toInt() < days.length) {
                                      return Text(
                                        days[value.toInt()],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      );
                                    }
                                    return Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget:
                                      (double value, TitleMeta meta) {
                                    return Text(
                                      'R${value.toInt()}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    );
                                  },
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
                                .map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 20,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bar_chart,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No data for this week',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              SizedBox(height: 24),

              // Top categories
              Text(
                'Top Categories This Month',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildTopCategoriesList(context, provider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopCategoriesList(
      BuildContext context, ExpenseProvider provider) {
    final now = DateTime.now();
    final monthlyExpenses = provider.expenses.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;
    }).toList();

    if (monthlyExpenses.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Text(
            'No expenses this month',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    Map<String, double> categoryTotals = {};
    for (var expense in monthlyExpenses) {
      categoryTotals[expense.categoryName] =
          (categoryTotals[expense.categoryName] ?? 0) + expense.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedCategories.take(5).map((entry) {
        final percentage =
            (entry.value / categoryTotals.values.fold(0.0, (a, b) => a + b)) *
                100;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCategoryColor(entry.key).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getCategoryIcon(entry.key),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      valueColor:
                          AlwaysStoppedAnimation(_getCategoryColor(entry.key)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R${entry.value.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
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

  String _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'transport':
        return '🚍';
      case 'food':
        return '🍔';
      case 'airtime':
        return '📱';
      case 'shopping':
        return '🛒';
      case 'entertainment':
        return '🎬';
      case 'health':
        return '🏥';
      default:
        return '💰';
    }
  }
}

class HistoryTab extends StatefulWidget {
  @override
  _HistoryTabState createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final expenses = selectedDate != null
            ? provider.expenses.where((expense) {
                return expense.date.year == selectedDate!.year &&
                    expense.date.month == selectedDate!.month &&
                    expense.date.day == selectedDate!.day;
              }).toList()
            : provider.expenses;

        return Column(
          children: [
            // Date filter
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate != null
                            ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                            : 'All dates',
                      ),
                    ),
                  ),
                  if (selectedDate != null) ...[
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
                        });
                      },
                      icon: Icon(Icons.clear),
                    ),
                  ],
                ],
              ),
            ),

            // Expenses list
            Expanded(
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          SizedBox(height: 16),
                          Text(
                            selectedDate != null
                                ? 'No expenses on this date'
                                : 'No expenses recorded',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: expenses.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return Card(
                          child: ExpenseListTile(expense: expense),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
}

class ExpenseListTile extends StatelessWidget {
  final Expense expense;

  const ExpenseListTile({Key? key, required this.expense}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(expense.id),
      background: Container(
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete Expense'),
            content: Text('Are you sure you want to delete this expense?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<ExpenseProvider>().deleteExpense(expense.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${expense.categoryName} expense deleted'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {
                // Add undo functionality
              },
            ),
          ),
        );
      },
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: expense.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              expense.icon,
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          expense.categoryName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(expense.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (expense.note != null && expense.note!.isNotEmpty) ...[
              SizedBox(height: 2),
              Text(
                expense.note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Text(
          'R${expense.amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: expense.color,
              ),
        ),
        onTap: () => _showExpenseDetails(context, expense),
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: expense.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(expense.icon, style: TextStyle(fontSize: 20)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(expense.categoryName),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount:', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  'R${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: expense.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(DateFormat('MMM dd, yyyy').format(expense.date)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time:', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(DateFormat('hh:mm a').format(expense.date)),
              ],
            ),
            if (expense.note != null && expense.note!.isNotEmpty) ...[
              SizedBox(height: 12),
              Text('Note:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text(expense.note!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class AddExpenseBottomSheet extends StatefulWidget {
  @override
  _AddExpenseBottomSheetState createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  ExpenseCategory? selectedCategory;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();
  final FocusNode noteFocusNode = FocusNode();

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    amountFocusNode.dispose();
    noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Add Expense',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                    ),
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
                      // Category selection
                      Text(
                        'Choose Category',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: provider.categories.length,
                        itemBuilder: (context, index) {
                          final category = provider.categories[index];
                          final isSelected =
                              selectedCategory?.id == category.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategory = category;
                                amountController.text =
                                    category.suggestedAmount.toString();
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? category.color.withOpacity(0.15)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant
                                        .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? category.color
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    category.icon,
                                    style: TextStyle(fontSize: 32),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    category.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? category.color
                                              : null,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 32),

                      // Amount input
                      Text(
                        'Amount',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        focusNode: amountFocusNode,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixText: 'R ',
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),

                      SizedBox(height: 24),

                      // Note input
                      Text(
                        'Note (Optional)',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        focusNode: noteFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Add a note about this expense...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        maxLines: 3,
                      ),

                      SizedBox(height: 32),

                      // Add button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _canAddExpense() ? _addExpense : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedCategory?.color ??
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Add Expense',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  bool _canAddExpense() {
    final amount = double.tryParse(amountController.text) ?? 0;
    return selectedCategory != null && amount > 0;
  }

  void _addExpense() {
    final amount = double.tryParse(amountController.text) ?? 0;
    final note = noteController.text.trim();

    context.read<ExpenseProvider>().addExpense(
          categoryId: selectedCategory!.id,
          amount: amount,
          note: note.isEmpty ? null : note,
        );

    Navigator.of(context).pop();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedCategory!.name} expense added successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
