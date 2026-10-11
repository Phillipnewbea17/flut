import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/identity_verification.dart';
import '../../models/personal_info.dart';
import '../../repositories/identity_repository.dart';
import '../../services/id_text_reader.dart';
import '../../services/identity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/id_text_parser.dart';
import '../../utils/image_quality.dart';
import '../../widgets/big_button.dart';
import '../../widgets/camera_frame_overlay.dart';
import '../../widgets/camera_gate.dart';
import '../../widgets/help_panel.dart';
import '../../widgets/info_card.dart';
import 'identity_actions.dart';

enum _Step { camera, preview, checking, poorQuality, unreadable, found, alreadyLinked, cameraError }

/// Photo of the ID -> quality check -> text reading (on the phone) ->
/// "Information found" -> review. The photo is only used on the phone and
/// is deleted as soon as it has been read; it is never uploaded.
class CaptureIdView extends StatefulWidget {
  const CaptureIdView({super.key});

  @override
  State<CaptureIdView> createState() => _CaptureIdViewState();
}

class _CaptureIdViewState extends State<CaptureIdView>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _cameraStarting = false;
  bool _capturing = false;
  bool _paused = false;
  _Step _step = _Step.camera;

  String? _photoPath;
  Uint8List? _photo;
  ImageQualityIssue? _issue;
  IdExtraction _extraction = IdExtraction.nothing;
  RecordLookup? _lookup;
  String? _lookupError;
  String? _cameraErrorText;
  bool _permissionProblem = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _discardPhoto();
    super.dispose();
  }

  /// Release the camera while the app is in the background.
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
    if (_cameraStarting || _camera != null) return;
    _cameraStarting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', null);
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
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
      _cameraStarting = false;
    }
  }

  void _cameraFailed(String code) {
    setState(() {
      _permissionProblem = code.startsWith('CameraAccess');
      _cameraErrorText = _permissionProblem
          ? 'Please allow the camera for this app in your phone settings.'
          : 'Close other apps that use the camera, then try again.';
      _step = _Step.cameraError;
    });
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _capturing || !camera.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      _discardPhoto();
      _photoPath = file.path;
      _photo = bytes;
      _camera = null;
      await camera.dispose();
      if (mounted) setState(() => _step = _Step.preview);
    } on CameraException catch (e) {
      if (mounted) _cameraFailed(e.code);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _retake() {
    _discardPhoto();
    setState(() {
      _issue = null;
      _extraction = IdExtraction.nothing;
      _lookup = null;
      _lookupError = null;
      _step = _Step.camera;
    });
  }

  /// Deletes the photo from the phone.
  void _discardPhoto() {
    final path = _photoPath;
    _photoPath = null;
    _photo = null;
    if (path != null) {
      File(path).delete().catchError((_) => File(path));
    }
  }

  Future<void> _usePhoto() async {
    final bytes = _photo;
    final path = _photoPath;
    if (bytes == null || path == null) return;
    final reader = context.read<IdTextReader>();
    final identity = context.read<IdentityRepository>();
    setState(() => _step = _Step.checking);

    final issue = await compute(ImageQualityChecker.check, bytes);
    if (!mounted) return;
    if (issue != null) {
      setState(() {
        _issue = issue;
        _step = _Step.poorQuality;
      });
      return;
    }

    IdExtraction extraction;
    try {
      extraction = await reader.read(path);
    } catch (_) {
      extraction = IdExtraction.nothing;
    }
    _discardPhoto(); // Read: the photo is not needed any more.
    if (!mounted) return;
    if (!extraction.isUseful) {
      setState(() => _step = _Step.unreadable);
      return;
    }

    RecordLookup? lookup;
    String? lookupError;
    try {
      lookup = await identity.applyExtraction(extraction);
    } on IdentityException catch (e) {
      lookupError = e.message;
    } catch (_) {
      lookupError = 'We could not check your ID with the OSCA office right now.';
    }
    if (!mounted) return;
    setState(() {
      _extraction = extraction;
      _lookup = lookup;
      _lookupError = lookupError;
      _step = lookup?.status == LookupStatus.alreadyLinked
          ? _Step.alreadyLinked
          : _Step.found;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Photo of your ID'),
      body: switch (_step) {
        _Step.camera => CameraGate(
            onUseAnotherMethod: () => IdentityActions.otherMethods(context),
            builder: (_) => _cameraView(),
          ),
        _Step.preview => _previewView(),
        _ => ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            children: [_panel()],
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
              width: camera.value.previewSize?.height ?? 1080,
              height: camera.value.previewSize?.width ?? 1920,
              child: CameraPreview(camera),
            ),
          ),
        ),
        const CameraFrameOverlay(shape: FrameShape.card),
        const Positioned(
          left: 20,
          right: 20,
          top: 20,
          child: CameraInstruction('Place your ID inside the frame.'),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: BigButton(
            label: _capturing ? 'Taking photo...' : 'Take photo',
            icon: Icons.photo_camera,
            onPressed: _capturing ? null : _capture,
          ),
        ),
      ],
    );
  }

  Widget _previewView() {
    final bytes = _photo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(bytes, fit: BoxFit.contain, height: 280),
          ),
        const SizedBox(height: 24),
        const Text(
          'Is the whole ID clear and easy to read?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        BigButton(label: 'Use this photo', icon: Icons.check, onPressed: _usePhoto),
        const SizedBox(height: 12),
        BigButton(
          label: 'Retake',
          icon: Icons.refresh,
          style: BigButtonStyle.tonal,
          onPressed: _retake,
        ),
      ],
    );
  }

  Widget _panel() {
    switch (_step) {
      case _Step.camera:
      case _Step.preview:
        return const SizedBox.shrink();
      case _Step.checking:
        return const Padding(
          padding: EdgeInsets.only(top: 48),
          child: BusyPanel(
            title: 'Reading your ID...',
            message: 'This takes a few seconds. Please wait.',
          ),
        );
      case _Step.poorQuality:
        return HelpPanel(
          icon: Icons.image_not_supported_outlined,
          title: 'The photo is difficult to read.',
          message: _issue?.advice ??
              'Please take another photo with better lighting.',
          tips: const [
            'Put the ID on a dark, flat table.',
            'Stand near a window or a bright light, but not in direct sun.',
            'Hold the phone straight above the ID.',
          ],
          actions: [
            HelpAction('Retake', Icons.refresh, _retake),
            HelpAction('Enter manually', Icons.edit_note,
                () => IdentityActions.enterManually(context)),
          ],
        );
      case _Step.unreadable:
        return HelpPanel(
          icon: Icons.text_snippet_outlined,
          title: "We couldn't read your ID clearly.",
          message: 'Please take another photo, or type your information '
              'yourself.',
          actions: [
            HelpAction('Retake', Icons.refresh, _retake),
            HelpAction('Enter manually', Icons.edit_note,
                () => IdentityActions.enterManually(context)),
          ],
        );
      case _Step.alreadyLinked:
        return HelpPanel(
          icon: Icons.link_off,
          color: AppColors.danger,
          title: 'This senior citizen record is already linked to an account.',
          message: 'One record can only be linked to one account. If this is '
              'your record, the OSCA office can help you.',
          actions: [
            HelpAction('Contact OSCA', Icons.support_agent_outlined,
                () => IdentityActions.contactOsca(context)),
            HelpAction('Go back', Icons.arrow_back,
                () => IdentityActions.otherMethods(context)),
          ],
        );
      case _Step.cameraError:
        return HelpPanel(
          icon: Icons.no_photography_outlined,
          color: AppColors.danger,
          title: _permissionProblem
              ? 'Camera permission is needed for this feature.'
              : "We couldn't access the camera.",
          message: _cameraErrorText ?? '',
          actions: [
            HelpAction('Try again', Icons.refresh, _retake),
            HelpAction('Enter manually', Icons.edit_note,
                () => IdentityActions.enterManually(context)),
          ],
        );
      case _Step.found:
        return _foundView();
    }
  }

  Widget _foundView() {
    final info = context.watch<IdentityRepository>().draft;
    final lookup = _lookup;
    final rows = <(String, String)>[
      if (info.fullName.isNotEmpty) ('Full name', info.fullName),
      if (info.birthDate != null) ('Date of birth', info.birthDateLabel),
      if (info.seniorId.isNotEmpty) ('Senior Citizen ID', info.seniorId),
      if (info.fullAddress.isNotEmpty) ('Address', info.fullAddress),
    ];
    final missing = !_extraction.found.containsAll(const {
      PersonalField.birthDate,
      PersonalField.sex,
      PersonalField.seniorId,
    });

    final (IconData noteIcon, Color noteColor, String note) = switch (lookup?.status) {
      LookupStatus.found => (
          Icons.verified_outlined,
          AppColors.success,
          'We found your record at the OSCA office. Official details come from '
              'the OSCA record.',
        ),
      LookupStatus.notFound => (
          Icons.info_outline,
          AppColors.warning,
          'We could not find this ID number in the OSCA records. Please check '
              'it on the next screen.',
        ),
      LookupStatus.unavailable => (
          Icons.info_outline,
          AppColors.warning,
          lookup?.message ?? ApiIdentityService.unavailableMessage,
        ),
      _ => (
          Icons.info_outline,
          AppColors.info,
          _lookupError ??
              'No ID number was read. You can type it on the next screen.',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Information Found',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This is what we read from your ID. You will check it on the next '
          'screen.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows) ...[
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(noteIcon, color: noteColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(note,
                  style: const TextStyle(
                      fontSize: 17, color: AppColors.textPrimary, height: 1.4)),
            ),
          ],
        ),
        if (missing) ...[
          const SizedBox(height: 12),
          const Text(
            'Some information could not be read. You can fill it in on the '
            'next screen.',
            style: TextStyle(fontSize: 17, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
        const SizedBox(height: 24),
        BigButton(
          label: 'Review information',
          icon: Icons.arrow_forward,
          trailingIcon: true,
          onPressed: () => IdentityActions.review(context),
        ),
        const SizedBox(height: 12),
        BigButton(
          label: 'Retake',
          icon: Icons.refresh,
          style: BigButtonStyle.tonal,
          onPressed: _retake,
        ),
      ],
    );
  }
}
