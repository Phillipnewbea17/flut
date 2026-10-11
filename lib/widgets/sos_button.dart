import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_state/accessibility_provider.dart';
import '../app_state/user_provider.dart';
import '../models/emergency_contact.dart';
import '../routes/app_router.dart';
import '../services/sos_service.dart';
import '../theme/app_colors.dart';
import 'big_button.dart';

/// Big red SOS button on the Home tab. Opens a sheet with a 5-second
/// countdown so a wrong tap can still be cancelled.
class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS. Get help now',
      child: SizedBox(
        height: 56,
        child: FloatingActionButton.extended(
          heroTag: 'sos-button',
          onPressed: () => showSosSheet(context),
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          icon: const Icon(Icons.call, size: 22),
          label: Text(
            context.tr('sosLabel'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

Future<void> showSosSheet(BuildContext context) {
  HapticFeedback.heavyImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => const _SosSheet(),
  );
}

enum _Phase { countdown, called }

/// SOS: 5 seconds to cancel, then the first contact is called. When the
/// call ends and the senior is back in the app, the messages app opens
/// with a text to every contact that has the phone's location.
class _SosSheet extends StatefulWidget {
  const _SosSheet();

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _countdown = Duration(seconds: 5);

  late final AnimationController _timer;
  late final List<EmergencyContact> _contacts;
  late final SosService _sos;
  late final String _senderName;

  /// Started when the sheet opens so it is ready when the text is sent.
  late final Future<String?> _location;

  _Phase _phase = _Phase.countdown;
  int _lastSecond = 5;

  /// Who was called last: an index in [_contacts], or null for a hotline.
  int? _calledIndex;
  String _calledName = '';

  bool _leftApp = false;
  bool _texted = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _contacts = user.emergencyContacts;
    _senderName = user.profile?.fullName.trim() ?? '';
    _sos = context.read<SosService>();
    _location = _sos.locationLink();
    WidgetsBinding.instance.addObserver(this);

    _timer = AnimationController(vsync: this, duration: _countdown)
      ..addListener(_tick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _callContact(0);
      });
    if (_contacts.isNotEmpty) _timer.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _Phase.called) return;
    if (state == AppLifecycleState.paused) _leftApp = true;
    // Back from the call: now the text with the location.
    if (state == AppLifecycleState.resumed && _leftApp && !_texted) {
      _leftApp = false;
      _textFamily();
    }
  }

  int get _secondsLeft {
    final left = _countdown.inMilliseconds * (1 - _timer.value);
    return (left / 1000).ceil().clamp(0, _countdown.inSeconds);
  }

  void _tick() {
    final s = _secondsLeft;
    if (s != _lastSecond) {
      _lastSecond = s;
      if (s > 0) HapticFeedback.mediumImpact();
      setState(() {});
    }
  }

  Future<void> _callContact(int index) =>
      _callNumber(_contacts[index].dialNumber, _contacts[index].name, index);

  Future<void> _callNumber(String number, String name, int? index) async {
    _timer.stop();
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.called;
      _calledIndex = index;
      _calledName = name;
    });
    final ok = await _sos.callNow(number);
    if (!mounted) return;
    if (!ok) {
      _say('Could not open the phone app. Please dial $number yourself.');
      // No call screen to come back from: send the text now.
      if (!_texted) await _textFamily();
    }
  }

  Future<void> _textFamily() async {
    if (_contacts.isEmpty) return;
    _texted = true;
    final link = await _location;
    final who = _senderName.isEmpty ? 'your family member' : _senderName;
    final message = StringBuffer('SOS from $who. I need help. '
        'Please call me now.');
    if (link != null) message.write(' My location: $link');
    final ok = await _sos.textContacts(_contacts, message.toString());
    if (!ok && mounted) {
      _say('Could not open your messages app.');
    } else if (link == null && mounted) {
      _say('Your location is off, so the text was sent without it.');
    }
  }

  void _cancel() {
    _timer.stop();
    Navigator.of(context).pop();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontSize: 16))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _contacts.isEmpty
            ? _noContacts()
            : _phase == _Phase.countdown
                ? _countdownView()
                : _calledView(),
      ),
    );
  }

  List<Widget> _countdownView() {
    final first = _contacts.first;
    return [
      const _Eyebrow('SOS STARTING', color: AppColors.danger),
      const _Title('Get help now'),
      const SizedBox(height: 20),
      Center(
        child: _CountdownRing(progress: 1 - _timer.value, seconds: _secondsLeft),
      ),
      const SizedBox(height: 20),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Calling '),
          TextSpan(
            text: first.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: ' and texting your location to your family.'),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 17, color: AppColors.textPrimary, height: 1.4),
      ),
      const SizedBox(height: 20),
      BigButton(
        label: "Cancel, I'm okay",
        style: BigButtonStyle.tonal,
        onPressed: _cancel,
      ),
      const SizedBox(height: 12),
      _call911Button(),
      const SizedBox(height: 16),
      _backupRow(label: 'If no answer:', from: 1),
    ];
  }

  List<Widget> _calledView() {
    final next = _calledIndex == null ? 0 : _calledIndex! + 1;
    final hasNext = next < _contacts.length;
    return [
      const _Eyebrow('SOS SENT', color: AppColors.primary),
      _Title(_calledName.isEmpty ? 'Did someone answer?' : 'Did $_calledName answer?'),
      const SizedBox(height: 10),
      Text(
        _texted
            ? 'We called $_calledName and opened a text with your location '
                'for your family. Press Send in your messages app.'
            : 'We are calling $_calledName. When the call ends, we will open '
                'a text with your location for your family.',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 17, color: AppColors.textPrimary, height: 1.4),
      ),
      const SizedBox(height: 20),
      if (hasNext) ...[
        BigButton(
          label: 'Call ${_contacts[next].firstName} next',
          icon: Icons.call,
          onPressed: () => _callContact(next),
        ),
        const SizedBox(height: 12),
      ],
      BigButton(
        label: 'Text my location again',
        icon: Icons.sms_outlined,
        style: BigButtonStyle.tonal,
        onPressed: _textFamily,
      ),
      const SizedBox(height: 12),
      _call911Button(),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(minimumSize: const Size(48, 56)),
        child: const Text(
          "I'm safe now, close",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    ];
  }

  List<Widget> _noContacts() => [
        const _Eyebrow('SOS', color: AppColors.danger),
        const _Title('Get help now'),
        const SizedBox(height: 10),
        const Text(
          'You have no emergency contacts yet. Add the people we should '
          'call when you press SOS.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 17, color: AppColors.textPrimary, height: 1.4),
        ),
        const SizedBox(height: 20),
        _call911Button(),
        const SizedBox(height: 12),
        BigButton(
          label: 'Add emergency contacts',
          icon: Icons.person_add_alt_1_outlined,
          style: BigButtonStyle.tonal,
          onPressed: () {
            Navigator.of(context).pop();
            context.push(Routes.emergencyContact);
          },
        ),
        const SizedBox(height: 16),
        _backupRow(label: 'Other help:', from: 0),
      ];

  Widget _call911Button() => BigButton(
        label: 'Call ${SosService.nationalEmergency} now',
        icon: Icons.call_outlined,
        color: AppColors.danger,
        onPressed: () =>
            _callNumber(SosService.nationalEmergency, SosService.nationalEmergency, null),
      );

  /// "If no answer: Pedro  Red Cross 143" - each one calls right away.
  Widget _backupRow({required String label, required int from}) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        for (var i = from; i < _contacts.length; i++)
          _BackupChip(
            label: _contacts[i].firstName,
            semantics: 'Call ${_contacts[i].name}',
            onTap: () => _callContact(i),
          ),
        _BackupChip(
          label: 'Red Cross ${SosService.redCross}',
          semantics: 'Call the Red Cross, ${SosService.redCross}',
          onTap: () => _callNumber(SosService.redCross, 'the Red Cross', null),
        ),
      ],
    );
  }
}

// =============================================================================
// Small widgets
// =============================================================================

class _Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const _Eyebrow(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: color,
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final double progress;
  final int seconds;

  const _CountdownRing({required this.progress, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Calling in $seconds seconds',
      excludeSemantics: true,
      child: SizedBox(
        width: 170,
        height: 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.primaryLight,
              color: AppColors.primary,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$seconds',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const Text(
                  'seconds',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupChip extends StatelessWidget {
  final String label;
  final String semantics;
  final VoidCallback onTap;

  const _BackupChip({
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryLight,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
