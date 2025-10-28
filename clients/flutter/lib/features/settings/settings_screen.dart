import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final controller = ref.read(financeControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account'),
            subtitle: Text('Primary currency ${state.settings.primaryCurrency}\nLocale ${state.settings.locale}'),
            trailing: state.settings.premium
                ? const Chip(label: Text('Premium'))
                : const Chip(label: Text('Free')),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: state.settings.premium,
                onChanged: controller.togglePremium,
                secondary: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Premium features'),
                subtitle: const Text('Shared wallets, advanced reports, OCR'),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).state = mode;
                    }
                  },
                ),
              ),
              const Divider(height: 0),
              SwitchListTile(
                value: state.settings.appLockEnabled,
                onChanged: controller.toggleAppLock,
                secondary: const Icon(Icons.lock_outline),
                title: const Text('App lock'),
                subtitle: Text('Lock after ${state.settings.appLockTimeoutMinutes} minutes'),
              ),
              const Divider(height: 0),
              SwitchListTile(
                value: state.settings.dailyReminderEnabled,
                onChanged: (value) => controller.updateReminder(enabled: value),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Daily reminder'),
                subtitle: const Text('Remind me to log expenses every evening'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Cloud sync'),
                subtitle: Text('Last synced ${formatDate(state.lastSyncedAt)} at ${formatTime(state.lastSyncedAt)}'),
                trailing: state.isSyncing
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : ElevatedButton(
                        onPressed: controller.syncNow,
                        child: const Text('Sync now'),
                      ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export to CSV'),
                subtitle: const Text('Generate a monthly CSV report'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export queued — check your email shortly.')),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: const Text('English / Arabic'),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Localization roadmap'),
                      content: const Text(
                        'Arabic RTL layout and translations are bundled in the premium roadmap. '
                        'Language will automatically follow your system settings once released.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
