import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../logic/lang.dart';

/// "রিমাইন্ডারের রিংটোন": the phone's tones, each with a play button, so the
/// user hears it before choosing.
class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  List<SoundOption>? _list;
  String? _chosen;
  String _chosenTitle = '';
  String? _playing;
  Notifier? _n;
  Timer? _stopTimer;

  /// Files added on this page (copied by the app); those not kept are removed on leaving.
  final _added = <String>{};
  String? _saved;

  static const _alarmTone = 'content://settings/system/alarm_alert';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final brain = BrainScope.read(context);
      _n = brain.services.notifier;
      final l = await brain.services.notifier.sounds();
      if (!mounted) return;
      setState(() {
        _list = l;
        _chosen = brain.services.notifier.soundUri ?? _alarmTone;
        _chosenTitle = brain.alarmSoundTitle;
      });
    });
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _n?.stopSound();
    for (final u in _added) {
      if (u != _saved) _n?.removeOwnSound(u);
    }
    super.dispose();
  }

  Future<void> _play(String uri) async {
    final n = BrainScope.read(context).services.notifier;
    if (_playing == uri) {
      await n.stopSound();
      setState(() => _playing = null);
      return;
    }
    await n.playSound(uri);
    setState(() => _playing = uri);
    // The phone stops the preview after 8 seconds.
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _playing == uri) setState(() => _playing = null);
    });
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    await brain.services.notifier.stopSound();
    _saved = _chosen;
    await brain.setAlarmSound(_chosen == _alarmTone ? null : _chosen, _chosenTitle, own: _added.contains(_chosen));
    if (!mounted) return;
    toast(context, _chosen == _alarmTone ? tr('ফোনের অ্যালার্ম টোনে বাজবে') : trf('রিমাইন্ডার এখন “{0}” দিয়ে বাজবে', [_chosenTitle]));
    Navigator.of(context).pop();
  }

  Future<void> _fromPhone() async {
    final brain = BrainScope.read(context);
    await brain.services.notifier.stopSound();
    final s = await brain.services.notifier.pickSound();
    if (s == null || !mounted) return;
    setState(() {
      _chosen = s.$1;
      _chosenTitle = s.$2;
    });
  }

  /// "নিজের অডিও ফাইল": an mp3 or any audio on the phone.
  Future<void> _fromFile() async {
    final brain = BrainScope.read(context);
    await brain.services.notifier.stopSound();
    final r = await brain.services.notifier.pickSoundFile();
    if (r == null || !mounted) return;
    if (r.error.isNotEmpty || r.uri.isEmpty) {
      toast(
          context,
          switch (r.error) {
            'too_big' => tr('ফাইলটা অনেক বড় — ১৫ MB-এর ছোট একটা অডিও বেছে নিন'),
            'not_audio' => tr('এটা অডিও ফাইল নয় — mp3 বা অন্য গান/শব্দের ফাইল বেছে নিন'),
            _ => tr('ফাইলটা যোগ করা গেল না — আরেকটা চেষ্টা করুন'),
          });
      return;
    }
    _added.add(r.uri);
    setState(() {
      _chosen = r.uri;
      _chosenTitle = r.title;
    });
    _play(r.uri);
  }

  Widget _row(String uri, String title, {String? sub}) {
    final on = _chosen == uri;
    final playing = _playing == uri;
    return InkWell(
      onTap: () {
        setState(() {
          _chosen = uri;
          _chosenTitle = uri == _alarmTone ? '' : title;
        });
        _play(uri);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(children: [
          Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? C.green : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: body(15, weight: on ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (sub != null) Text(sub, style: body(12, color: C.muted)),
            ]),
          ),
          IconButton(
            tooltip: playing ? tr('থামান') : tr('শুনুন'),
            onPressed: () => _play(uri),
            icon: Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded, color: C.green, size: 30),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    final groups = <String, List<SoundOption>>{};
    for (final s in l ?? const <SoundOption>[]) {
      groups.putIfAbsent(s.kind, () => []).add(s);
    }
    final names = {'alarm': tr('অ্যালার্ম টোন'), 'ringtone': tr('রিংটোন'), 'notification': tr('নোটিফিকেশন টোন')};
    final custom = _chosen != null && _chosen != _alarmTone && !(l ?? const []).any((s) => s.uri == _chosen);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('রিমাইন্ডারের রিংটোন'), sub: tr('কোন শব্দে মনে করাবো')),
          Expanded(
            child: l == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                    Text(tr('নাম চাপলে ৮ সেকেন্ড বাজিয়ে শোনাবে। শব্দ না এলে ফোনের অ্যালার্ম ভলিউম বাড়ান।'), style: body(13, color: C.muted)),
                    const SizedBox(height: 10),
                    Panel(
                      child: Rows(children: [
                        _row(_alarmTone, tr('ফোনের অ্যালার্ম টোন'), sub: tr('আগের মতো')),
                        if (custom) _row(_chosen!, _chosenTitle.isEmpty ? tr('নিজের বেছে নেওয়া') : _chosenTitle, sub: tr('আপনার বেছে নেওয়া')),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(key: const Key('tone-file'), label: tr('নিজের অডিও ফাইল যোগ করুন'), icon: Icons.audio_file_outlined, color: C.fill, onPressed: _fromFile),
                    const SizedBox(height: 4),
                    Text(tr('ফোনের যেকোনো গান, রেকর্ডিং বা mp3 (১৫ MB পর্যন্ত) — রিমাইন্ডার আর অ্যালার্ম সেটা দিয়ে বাজবে।'), style: body(12.5, color: C.muted)),
                    for (final k in const ['alarm', 'ringtone', 'notification'])
                      if (groups[k] != null) ...[
                        const SizedBox(height: 16),
                        SectionTitle(names[k]!),
                        Panel(child: Rows(children: [for (final s in groups[k]!) _row(s.uri, s.title)])),
                      ],
                    const SizedBox(height: 14),
                    SecondaryButton(label: tr('ফোনের শব্দের তালিকা খুলুন'), icon: Icons.library_music_outlined, onPressed: _fromPhone),
                  ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(label: tr('রাখুন'), onPressed: _chosen == null ? null : _save),
          ),
        ]),
      ),
    );
  }
}
