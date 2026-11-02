import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/api.dart';
import '../state/hisab.dart';
import 'kit.dart';

/// What an admin may do; the server keeps the same list.
const permLabels = {
  'send': 'নতুন পাঠানো (গ্রাহক যোগসহ)',
  'deposit': 'রিয়াল জমা নেওয়া',
  'edit': 'লেনদেন সংশোধন ও বাতিল',
  'customers': 'গ্রাহকের প্রোফাইল বদল',
  'loss': 'লস ধরা',
  'agent_pay': 'এজেন্টকে টাকা দেওয়া',
  'agents': 'এজেন্ট যোগ ও বদল',
  'expense': 'খরচ ও দিন শেষের হিসাব',
  'reports': 'রিপোর্ট, লগ ও PDF দেখা',
  'users': 'এডমিন ও এজেন্টের লগইন',
  'settings': 'সেটিংস বদল',
};

class AppUser {
  AppUser(Map<String, Object?> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        role = '${j['role']}',
        name = '${j['name'] ?? ''}',
        login = '${j['login'] ?? ''}',
        agentRid = '${j['agent_rid'] ?? ''}',
        active = j['status'] == 'active',
        perms = [for (final p in (j['perms'] as List?) ?? const []) '$p'],
        lastSeen = DateTime.tryParse('${j['last_seen']}')?.toLocal();
  final int id;
  final String role;
  final String name;
  final String login;
  final String agentRid;
  final bool active;
  final List<String> perms;
  final DateTime? lastSeen;

  String get roleName => const {'owner': 'মূল এডমিন', 'admin': 'এডমিন', 'agent': 'এজেন্ট'}[role] ?? role;
}

String _err(Object e) => switch (e) {
      ApiOffline() => 'ইন্টারনেট নেই বা সার্ভারে পৌঁছানো যাচ্ছে না',
      ApiError(status: 409) => 'এই লগইন আগেই কেউ ব্যবহার করছেন',
      ApiError(status: 403) => 'এটা করার অনুমতি আপনার নেই',
      ApiError(status: 400) => 'নাম, লগইন (অন্তত ৪ অক্ষর, ইংরেজি/সংখ্যা) আর অন্তত ৬ অক্ষরের পাসওয়ার্ড দিন',
      _ => 'হয়নি, আবার চেষ্টা করুন',
    };

/// Admins and agents who can sign in, and what each admin may do.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser>? _users;
  Object? _error;

  Hisab get h => widget.h;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await h.s.api.get('/users');
      setState(() {
        _users = [for (final u in ((r['users'] as List?) ?? const []).cast<Map>()) AppUser(u.cast<String, Object?>())];
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _edit(AppUser? u, String role) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => UserEdit(h: h, user: u, role: role)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _users;
    final mine = h.session;
    return Screen(
      title: 'লগইন ও অনুমতি',
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
          const Note('মূল এডমিন ঠিক করা হয় সার্ভারে। এখানে অন্য এডমিন আর এজেন্টদের লগইন যোগ, বন্ধ আর অনুমতি ঠিক করা যায়।', icon: Icons.info_outline_rounded),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Pill(label: 'নতুন এডমিন', icon: Icons.admin_panel_settings_outlined, height: 48, onTap: () => _edit(null, 'admin'))),
            const SizedBox(width: 10),
            Expanded(child: Pill(label: 'এজেন্টের লগইন', icon: Icons.storefront_outlined, color: K.navy, height: 48, onTap: () => _edit(null, 'agent'))),
          ]),
          const SizedBox(height: 12),
          if (_error != null) Note(_err(_error!), color: K.redTint, textColor: K.red),
          if (list == null && _error == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (list != null)
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, u) in list.indexed)
                  Row2(
                    lead: dotIcon(u.role == 'agent' ? Icons.storefront_rounded : (u.role == 'owner' ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded), u.active ? K.blueTint : K.chip,
                        u.active ? K.blue : K.muted,
                        size: 40),
                    title: '${u.name}${u.id == mine?.id ? ' (আপনি)' : ''}',
                    sub: '${u.roleName} · ${bn(u.login)}${u.role == 'agent' ? ' · ${agentById(h, u.agentRid)}' : ''}'
                        '${u.role == 'admin' ? ' · ${u.perms.length == permLabels.length ? 'সব অনুমতি' : '${bn('${u.perms.length}')}টা অনুমতি'}' : ''}',
                    value: u.active ? 'চালু' : 'বন্ধ',
                    valueColor: u.active ? K.green : K.muted,
                    valueSub: u.lastSeen == null ? 'এখনো ঢোকেননি' : ago(u.lastSeen!, h.now),
                    last: i == list.length - 1,
                    onTap: u.role == 'owner' ? null : () => _edit(u, u.role),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  static String agentById(Hisab h, String id) {
    for (final a in h.d.agents) {
      if (a.id == id) return a.name;
    }
    return '—';
  }
}

/// Adding or changing one login. For an admin: the access checklist.
class UserEdit extends StatefulWidget {
  const UserEdit({super.key, required this.h, required this.user, required this.role});
  final Hisab h;
  final AppUser? user;
  final String role;

  @override
  State<UserEdit> createState() => _UserEditState();
}

class _UserEditState extends State<UserEdit> {
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _login = TextEditingController(text: widget.user?.login ?? '');
  final _pass = TextEditingController();
  late final Set<String> _perms = {
    ...(widget.user?.perms ?? const ['send', 'deposit', 'customers', 'reports'])
  };
  late String? _agent = widget.user?.agentRid ?? (widget.h.d.agents.isEmpty ? null : widget.h.d.agents.first.id);
  late bool _active = widget.user?.active ?? true;
  bool _busy = false;
  String? _msg;

  Hisab get h => widget.h;
  bool get _isNew => widget.user == null;
  bool get _admin => widget.role == 'admin';

  /// An admin can give only what they have themselves.
  bool _mayGive(String p) => h.can(p);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (_isNew) {
        await h.s.api.post('/users', {
          'role': widget.role,
          'name': _name.text.trim(),
          'login': en(_login.text.trim()),
          'password': _pass.text,
          if (_admin) 'perms': _perms.toList(),
          if (!_admin) 'agent_rid': _agent,
        });
        if (!_admin && _agent != null) {
          // The agent now gets requests in the app, not on WhatsApp.
          final a = h.d.agents.firstWhere((x) => x.id == _agent);
          if (!a.usesApp) await h.setAgentChannel(a, 'app');
        }
      } else {
        await h.s.api.post('/users/update', {
          'id': widget.user!.id,
          'name': _name.text.trim(),
          if (_pass.text.isNotEmpty) 'password': _pass.text,
          'status': _active ? 'active' : 'off',
          if (_admin) 'perms': _perms.toList(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _msg = _err(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
        title: _isNew ? (_admin ? 'নতুন এডমিন' : 'এজেন্টের লগইন') : widget.user!.name,
        bottom: Pill(label: _busy ? 'রাখা হচ্ছে…' : 'রাখুন', onTap: _busy ? null : _save),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
          if (!_admin && _isNew) ...[
            if (h.d.agents.isEmpty) const Note('আগে এজেন্ট ট্যাবে এজেন্ট যোগ করুন।', color: K.amberTint, textColor: K.amberText),
            Tx('কোন এজেন্টের লগইন', style: t(13, c: K.muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in h.d.agents) ChoiceChipX(label: a.name, on: a.id == _agent, onTap: () => setState(() => _agent = a.id)),
            ]),
            const SizedBox(height: 14),
          ],
          Field(label: 'নাম', controller: _name),
          const SizedBox(height: 12),
          if (_isNew) ...[
            Field(label: 'লগইন (মোবাইল নম্বর বা ইংরেজি নাম)', controller: _login, hint: '01XXXXXXXXX'),
            const SizedBox(height: 12),
          ],
          Field(label: _isNew ? 'পাসওয়ার্ড (অন্তত ৬ অক্ষর)' : 'নতুন পাসওয়ার্ড (বদলাতে চাইলে)', controller: _pass),
          if (!_isNew) ...[
            const SizedBox(height: 12),
            CardBox(
              padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Tx('লগইন চালু', style: t(15, w: FontWeight.w500)),
                subtitle: Tx('বন্ধ করলে সাথে সাথে তাঁর ফোন থেকে বের করে দেওয়া হবে', style: t(12.5, c: K.muted)),
              ),
            ),
          ],
          if (_admin) ...[
            SectionHead('যা করতে পারবেন', action: 'সব', onAction: () => setState(() => _perms.addAll(permLabels.keys.where(_mayGive)))),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(children: [
                for (final e in permLabels.entries)
                  CheckboxListTile(
                    value: _perms.contains(e.key),
                    onChanged: _mayGive(e.key) ? (v) => setState(() => v == true ? _perms.add(e.key) : _perms.remove(e.key)) : null,
                    title: Tx(e.value, style: t(14.5)),
                    subtitle: _mayGive(e.key) ? null : Tx('আপনার নিজের এই অনুমতি নেই', style: t(12, c: K.muted)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ]),
            ),
          ],
          if (_msg != null) ...[const SizedBox(height: 12), Note(_msg!, color: K.redTint, textColor: K.red)],
        ]),
      );
}

/// For tests and screens that only need a name.
String roleName(Agent a) => a.usesApp ? 'অ্যাপে' : 'হোয়াটসঅ্যাপে';
