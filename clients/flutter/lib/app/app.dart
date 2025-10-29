import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/auth/auth_gate.dart';
import '../data/providers.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/quick_add/quick_add_sheet.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transactions_screen.dart';

class AlphaWalletApp extends ConsumerWidget {
  const AlphaWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Alpha Wallet',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: const AuthGate(child: HomeShell()),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      _Destination(
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        builder: (_) => const DashboardScreen(),
      ),
      _Destination(
        label: 'Transactions',
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt,
        builder: (_) => const TransactionsScreen(),
      ),
      _Destination(
        label: 'Budgets',
        icon: Icons.pie_chart_outline,
        selectedIcon: Icons.pie_chart,
        builder: (_) => const BudgetsScreen(),
      ),
      _Destination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        builder: (_) => const SettingsScreen(),
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(destinations[_index].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync now',
            onPressed: () => ref.read(financeControllerProvider.notifier).syncNow(),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: destinations[_index].builder(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => const QuickAddSheet(),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}
