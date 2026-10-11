import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/camera_access.dart';
import '../theme/app_colors.dart';
import 'help_panel.dart';

/// Asks for the camera when the screen opens, and shows [child] only when
/// it is allowed. Otherwise it explains why the camera is needed, with
/// "Open settings" and "Use another method". Coming back from the phone
/// settings checks again by itself.
class CameraGate extends StatefulWidget {
  final WidgetBuilder builder;
  final VoidCallback onUseAnotherMethod;
  final String anotherMethodLabel;

  const CameraGate({
    super.key,
    required this.builder,
    required this.onUseAnotherMethod,
    this.anotherMethodLabel = 'Use another method',
  });

  @override
  State<CameraGate> createState() => _CameraGateState();
}

class _CameraGateState extends State<CameraGate> with WidgetsBindingObserver {
  CameraPermission? _permission;
  bool _openedSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ask();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedSettings) {
      _openedSettings = false;
      _ask();
    }
  }

  Future<void> _ask() async {
    final access = context.read<CameraAccess>();
    CameraPermission result;
    try {
      result = await access.request();
    } catch (_) {
      result = CameraPermission.denied;
    }
    if (mounted) setState(() => _permission = result);
  }

  Future<void> _openSettings() async {
    _openedSettings = true;
    await context.read<CameraAccess>().openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final permission = _permission;
    if (permission == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (permission == CameraPermission.granted) return widget.builder(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      children: [
        HelpPanel(
          icon: Icons.no_photography_outlined,
          color: AppColors.danger,
          title: 'Camera permission is needed for this feature.',
          message: permission == CameraPermission.blocked
              ? 'The camera is turned off for this app. Open your phone '
                  'settings, tap Permissions, then allow Camera.'
              : 'Please allow the camera when your phone asks. We only use it '
                  'while this screen is open.',
          actions: [
            if (permission != CameraPermission.blocked)
              HelpAction('Allow camera', Icons.photo_camera_outlined, _ask),
            HelpAction('Open settings', Icons.settings_outlined, _openSettings),
            HelpAction(widget.anotherMethodLabel, Icons.swap_horiz,
                widget.onUseAnotherMethod),
          ],
        ),
      ],
    );
  }
}
