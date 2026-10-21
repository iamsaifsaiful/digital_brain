// The NLU spec's intent names (docs/nlu-spec.md) for the app's Command
// classes: how the old rules' (and later the AI's) readings are compared
// with the gold set and with the new understanding (shadow mode).
import '../logic/parser.dart';

/// The spec intent of one command.
String intentOfCommand(Command c) {
  switch (c) {
    case TaskAdd():
      return 'task_add';
    case TaskDone(:final done):
      return done ? 'task_done' : 'task_reopen';
    case TaskEdit():
      if (c.title != null) return 'rename';
      if (c.delete) return 'task_delete';
      if (c.stopReminder) return 'reminder_stop';
      if (c.remindAt != null || c.remindNeedsTime || c.remindHour != null) return 'task_remind';
      if (c.skipOnce) return 'task_skip_once';
      if (c.keep) return 'cancel';
      if (c.say != null && c.ref.isEmpty) return 'correct';
      return 'task_edit';
    case TaskRestore():
      return 'menu_trash';
    case TasksClear():
      return 'task_delete';
    case TaskQuery():
      return 'task_query';
    case ReminderAdd():
      return 'reminder_add';
    case ReminderSnooze():
      return 'reminder_snooze';
    case ReminderQuery():
      return 'reminder_query';
    case ManageItem(:final action):
      return switch (action) { 'delete' => 'item_delete', 'stop' => 'reminder_stop', _ => 'reminder_edit' };
    case LedgerAdd():
      return 'ledger_add';
    case LedgerSet():
      return 'ledger_set';
    case LedgerQuery():
      return 'ledger_query';
    case CashAdd():
      return 'cash_add';
    case CashQuery() || MoneyListQuery():
      return 'cash_query';
    case NoteAdd():
      return 'note_add';
    case SearchQuery():
      return 'note_query';
    case VaultAdd():
      return 'vault_add';
    case VaultQuery():
      return 'vault_query';
    case ContactAdd():
      return 'contact_add';
    case ContactsQuery():
      return 'contact_query';
    case CallPerson():
      return 'call';
    case SpecialAdd():
      return 'special_add';
    case MemoryAdd() || ProfileSet():
      return 'memory_add';
    case ProfileQuery():
      return 'profile_query';
    case HealthAdd():
      return 'health_add';
    case HealthQuery():
      return 'menu_health';
    case OpenPlace():
      return 'open_page';
    case Briefing():
      return 'briefing';
    case MenuAction(:final domain):
      return switch (domain) { 'docs' => 'doc_query', 'diary' || 'requests' || 'emergency' => 'open_page', _ => 'menu_$domain' };
    case BulkAction(:final op, :final domain):
      return switch (op) {
        'delete' => domain == 'tasks' || domain.isEmpty ? 'task_delete' : (domain == 'reminders' ? 'reminder_delete' : 'item_delete'),
        'done' => 'task_done',
        'reopen' || 'not_done' => 'task_reopen',
        'move' => 'task_edit',
        'remind' => 'task_remind',
        'reminder_off' => 'reminder_stop',
        'restore' => 'menu_trash',
        'show' => domain == 'reminders' ? 'reminder_query' : 'task_query',
        _ => 'bulk_$op',
      };
    case SmallTalk(:final kind):
      return switch (kind) {
        Talk.time || Talk.date || Talk.calendar => 'calendar_query',
        Talk.cancelled => 'cancel',
        Talk.wontDo => 'correct',
        Talk.whatCanYouDo || Talk.understand || Talk.sorry || Talk.listenOverMe || Talk.nothingDone => 'complain_help',
        _ => 'smalltalk',
      };
    case Clarify(:final options):
      return options.isEmpty ? 'none' : intentOfCommand(options.first.$2);
    case NotUnderstood():
      return 'none';
    case AiReply():
      return 'reply';
  }
}

/// The spec intents of a reading (several requests in one message), in order, without repeats.
List<String> intentsOfCommands(List<Command> cs) {
  final out = <String>[];
  for (final c in cs) {
    final i = intentOfCommand(c);
    if (!out.contains(i)) out.add(i);
  }
  return out;
}
