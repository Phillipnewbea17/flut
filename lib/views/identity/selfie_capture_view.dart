import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/identity_repository.dart';
import '../../routes/app_router.dart';
import '../../services/camera_access.dart';
import '../../services/identity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../../widgets/camera_frame_overlay.dart';
import '../../widgets/camera_gate.dart';
import '../../widgets/help_panel.dart';
import 'identity_actions.dart';

enum _Step { camera, sending, sendFailed, cameraError }

/// The live selfie. Only the front camera is used (no gallery), the photo
/// is sent straight to the backend from memory, and the temporary file the
/// camera made is deleted at once.
class SelfieCaptureView extends StatefulWidget {
  const SelfieCaptureView({super.key});

  static const List<String> instructions = [
    'Look at the camera.',
    'Move your face inside the circle.',
    'Make sure your face is clearly visible.',
    'Remove anything covering your face if necessary.',
    'Stay still for a moment.',
  ];

  @override
  State<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

class _SelfieCaptureViewState extends State<SelfieCaptureView>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _starting = false;
  bool _capturing = false;
  bool _paused = false;
  bool _permissionProblem = false;
  _Step _step = _Step.camera;
  String? _error;
  int _tip = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _step == _Step.camera) {
        setState(() => _tip = (_tip + 1) % SelfieCaptureView.instructions.length);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tipTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _paused = true;
      final camera = _camera;
      _camera = null;
      camera?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _startCamera() async {
    if (_starting || _camera != null) return;
    _starting = true;
    try {
      final cameras = await availableCameras();
      final front = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.front);
      if (front.isEmpty) throw CameraException('NoFrontCamera', null);
      final controller = CameraController(
        front.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } on CameraException catch (e) {
      if (mounted) _cameraFailed(e.code);
    } catch (_) {
      if (mounted) _cameraFailed('');
    } finally {
      _starting = false;
    }
  }

  void _cameraFailed(String code) {
    setState(() {
      _permissionProblem = code.startsWith('CameraAccess');
      _step = _Step.cameraError;
    });
  }

  Future<void> _takeSelfie() async {
    final camera = _camera;
    if (camera == null || _capturing || !camera.value.isInitialized) return;
    final identity = context.read<IdentityRepository>();
    setState(() => _capturing = true);

    Uint8List bytes;
    try {
      final file = await camera.takePicture();
      bytes = await file.readAsBytes();
      try {
        await File(file.path).delete();
      } catch (_) {}
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        _cameraFailed(e.code);
      }
      return;
    }

    _camera = null;
    await camera.dispose();
    if (!mounted) return;
    setState(() {
      _capturing = false;
      _step = _Step.sending;
    });

    try {
      await identity.verifySelfie(bytes);
      if (mounted) context.pushReplacement(Routes.verificationResult);
    } on IdentityException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _step = _Step.sendFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _step = _Step.sendFailed;
        });
      }
    }
  }

  void _retry() => setState(() {
        _error = null;
        _step = _Step.camera;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Take a selfie'),
      body: switch (_step) {
        _Step.camera => CameraGate(
            anotherMethodLabel: 'Contact OSCA',
            onUseAnotherMethod: () => IdentityActions.contactOsca(context),
            builder: (_) => _cameraView(),
          ),
        _Step.sending => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: BusyPanel(
                title: 'Checking your identity...',
                message: 'We are checking with the OSCA office. This can '
                    'take a little while. Please do not close the app.',
              ),
            ),
          ),
        _Step.sendFailed => ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            children: [
              HelpPanel(
                icon: Icons.wifi_off,
                color: AppColors.danger,
                title: 'We could not finish the check.',
                message: _error ?? 'Please try again.',
                tips: const ['This did not count as a failed try.'],
                actions: [
                  HelpAction('Try again', Icons.refresh, _retry),
                  HelpAction('Contact OSCA', Icons.support_agent_outlined,
                      () => IdentityActions.contactOsca(context)),
                ],
              ),
            ],
          ),
        _Step.cameraError => ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            children: [
              HelpPanel(
                icon: Icons.no_photography_outlined,
                color: AppColors.danger,
                title: "We couldn't access the camera.",
                message: _permissionProblem
                    ? 'Please allow the camera: open your phone Settings, '
                        'then Apps, SeniorCompanion, Permissions, Camera, '
                        'and choose Allow.'
                    : 'This phone needs a front camera for the selfie. Close '
                        'other apps that use the camera, then try again.',
                actions: [
                  HelpAction('Try again', Icons.refresh, _retry),
                  HelpAction('Open settings', Icons.settings_outlined,
                      () => context.read<CameraAccess>().openSettings()),
                  HelpAction('Contact OSCA', Icons.support_agent_outlined,
                      () => IdentityActions.contactOsca(context)),
                ],
              ),
            ],
          ),
      },
    );
  }

  Widget _cameraView() {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      if (!_paused) _startCamera();
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: camera.value.previewSize?.height ?? 720,
              height: camera.value.previewSize?.width ?? 1280,
              child: CameraPreview(camera),
            ),
          ),
        ),
        const CameraFrameOverlay(shape: FrameShape.oval),
        Positioned(
          left: 20,
          right: 20,
          top: 20,
          child: CameraInstruction(SelfieCaptureView.instructions[_tip]),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: BigButton(
            label: _capturing ? 'Taking selfie...' : 'Take selfie',
            icon: Icons.photo_camera_front,
            onPressed: _capturing ? null : _takeSelfie,
          ),
        ),
      ],
    );
  }
}
