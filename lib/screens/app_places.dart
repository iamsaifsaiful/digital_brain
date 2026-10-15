import 'package:flutter/material.dart';

import 'alarm_list_screen.dart';
import 'assistant_settings.dart';
import 'calendar_screen.dart';
import 'calls_screen.dart';
import 'docs_screen.dart';
import 'health_hub.dart';
import 'health_screens.dart';
import 'help_screen.dart';
import 'inbox_screen.dart';
import 'home_shell.dart';
import 'ledger_screen.dart' show MoneyPart;
import 'money_more_screens.dart';
import 'more_screen.dart';
import 'notes_screen.dart';
import 'notification_settings.dart';
import 'onboarding_screen.dart' show TemplatesScreen;
import 'plan_screens.dart';
import 'search_screen.dart';
import 'sound_screen.dart';
import 'special_days_screen.dart';
import 'store_more_screens.dart';
import 'vault_screen.dart';
import '../ui/pdf_export.dart';

/// The page for a part of the app (see logic/app_map.dart), or null for the
/// four main tabs (opened with [openPlace]).
Widget? placePage(String id, {String? folder}) => switch (id) {
      'tasks' || 'reminders' => const AllTasksScreen(),
      'alarms' => const AlarmsScreen(),
      'calendar' => const CalendarScreen(),
      'special' => const SpecialDaysScreen(),
      'notes' => NotesScreen(category: folder),
      'docs' => DocsScreen(folder: folder),
      'vault' => const VaultScreen(),
      'contacts' => const CallsScreen(),
      'inbox' => const InboxScreen(),
      'report' => const ReportScreen(),
      'accounts' => const AccountsScreen(),
      'savings' => const SavingsScreen(),
      'zakat' => const ZakatScreen(),
      'split' => const SplitScreen(),
      'shop' => const ShopScreen(),
      'health' => const HealthScreen(),
      'medicines' => const MedicinesScreen(),
      'habits' => const HabitsScreen(),
      'emergency' => const EmergencyScreen(),
      'expiry' => const ExpiryScreen(),
      'tags' => const TagsScreen(),
      'memory' => const MemoryScreen(),
      'templates' => const TemplatesScreen(),
      'search' => const SearchScreen(),
      'settings' => const MenuPage(child: MoreScreen()),
      'notifications' => const NotificationSettingsScreen(),
      'sound' => const SoundScreen(),
      'backup' => const BackupScreen(),
      'help' => const HelpScreen(),
      _ => null,
    };

/// Opens a part of the app by its id: a main tab, or a page on top.
Future<void> openPlace(BuildContext context, String id, {String? folder}) async {
  switch (id) {
    case 'home':
      goToTab(context, ShellTab.home);
    case 'diary':
      goToTab(context, ShellTab.diary);
    case 'store':
      goToTab(context, ShellTab.store);
    case 'money':
      goToTab(context, ShellTab.money, money: MoneyPart.cash);
    case 'ledger':
      goToTab(context, ShellTab.money, money: MoneyPart.loans);
    case 'projects':
      goToTab(context, ShellTab.money, money: MoneyPart.projects);
    case 'pdf':
      await exportEverything(context);
    default:
      final page = placePage(id, folder: folder);
      if (page != null) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
