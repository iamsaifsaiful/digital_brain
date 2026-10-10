import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

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
    await brain.setAlarmSound(_chosen == _alarmTone ? null : _chosen, _chosenTitle);
    if (!mounted) return;
    toast(context, _chosen == _alarmTone ? 'ফোনের অ্যালার্ম টোনে বাজবে' : 'রিমাইন্ডার এখন “$_chosenTitle” দিয়ে বাজবে');
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
            tooltip: playing ? 'থামান' : 'শুনুন',
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
    const names = {'alarm': 'অ্যালার্ম টোন', 'ringtone': 'রিংটোন', 'notification': 'নোটিফিকেশন টোন'};
    final custom = _chosen != null && _chosen != _alarmTone && !(l ?? const []).any((s) => s.uri == _chosen);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'রিমাইন্ডারের রিংটোন'),
          Expanded(
            child: l == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                    Text('নাম চাপলে ৮ সেকেন্ড বাজিয়ে শোনাবে। শব্দ না এলে ফোনের অ্যালার্ম ভলিউম বাড়ান।', style: body(13, color: C.muted)),
                    const SizedBox(height: 10),
                    Panel(
                      child: Rows(children: [
                        _row(_alarmTone, 'ফোনের অ্যালার্ম টোন', sub: 'আগের মতো'),
                        if (custom) _row(_chosen!, _chosenTitle.isEmpty ? 'নিজের বেছে নেওয়া' : _chosenTitle, sub: 'ফোন থেকে বেছে নেওয়া'),
                      ]),
                    ),
                    for (final k in const ['alarm', 'ringtone', 'notification'])
                      if (groups[k] != null) ...[
                        const SizedBox(height: 16),
                        SectionTitle(names[k]!),
                        Panel(child: Rows(children: [for (final s in groups[k]!) _row(s.uri, s.title)])),
                      ],
                    const SizedBox(height: 14),
                    SecondaryButton(label: 'নিজের গান বা অন্য শব্দ (ফোনের তালিকা)', icon: Icons.library_music_outlined, onPressed: _fromPhone),
                  ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(label: 'রাখুন', onPressed: _chosen == null ? null : _save),
          ),
        ]),
      ),
    );
  }
}
