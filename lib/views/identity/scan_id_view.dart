import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/identity_verification.dart';
import '../../repositories/identity_repository.dart';
import '../../services/identity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/senior_id_qr.dart';
import '../../widgets/camera_frame_overlay.dart';
import '../../widgets/camera_gate.dart';
import '../../widgets/help_panel.dart';
import 'identity_actions.dart';

enum _Step { scanning, lookingUp, noCode, notFound, alreadyLinked, unavailable, error }

/// Scans the QR code on the Senior Citizen ID and looks the ID number up
/// in SCMS. The form is filled only from the record the backend returns.
class ScanIdView extends StatefulWidget {
  const ScanIdView({super.key});

  /// No supported QR code after this long: offer the other ways.
  static const Duration giveUpAfter = Duration(seconds: 30);

  @override
  State<ScanIdView> createState() => _ScanIdViewState();
}

class _ScanIdViewState extends State<ScanIdView> {
  MobileScannerController? _controller;
  Timer? _timer;
  _Step _step = _Step.scanning;
  ScannedSeniorId? _scanned;
  String? _message;

  @override
  void initState() {
    super.initState();
    _newScanner();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _newScanner() {
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _timer?.cancel();
    _timer = Timer(ScanIdView.giveUpAfter, () {
      if (mounted && _step == _Step.scanning) _show(_Step.noCode);
    });
  }

  void _startScanning() {
    _stopScanner();
    _newScanner();
    setState(() {
      _step = _Step.scanning;
      _scanned = null;
      _message = null;
    });
  }

  /// The scanner widget is removed in the next frame; the camera is
  /// released after that.
  void _stopScanner() {
    _timer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => controller.dispose());
    }
  }

  void _show(_Step step, {String? message}) {
    _stopScanner();
    setState(() {
      _step = step;
      _message = message;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_step != _Step.scanning) return;
    ScannedSeniorId? found;
    for (final code in capture.barcodes) {
      found = SeniorIdQr.parse(code.rawValue);
      if (found != null) break;
    }
    if (found == null) {
      // A QR code, but not one from a Senior Citizen ID.
      if (capture.barcodes.isNotEmpty) _show(_Step.noCode);
      return;
    }
    _lookUp(found);
  }

  Future<void> _lookUp(ScannedSeniorId scanned) async {
    final identity = context.read<IdentityRepository>();
    _scanned = scanned;
    _show(_Step.lookingUp);
    try {
      final result = await identity.lookupScannedId(scanned);
      if (!mounted) return;
      switch (result.status) {
        case LookupStatus.found:
          IdentityActions.review(context);
        case LookupStatus.notFound:
          _show(_Step.notFound, message: result.message);
        case LookupStatus.alreadyLinked:
          _show(_Step.alreadyLinked, message: result.message);
        case LookupStatus.unavailable:
          _show(_Step.unavailable, message: result.message);
      }
    } on IdentityException catch (e) {
      if (mounted) _show(_Step.error, message: e.message);
    } catch (_) {
      if (mounted) {
        _show(_Step.error,
            message: 'Something went wrong. Please check your internet and '
                'try again.');
      }
    }
  }

  /// "Check ID": put the number that was read on the form so the user can
  /// compare it with the card and fix it.
  void _checkIdNumber() {
    final identity = context.read<IdentityRepository>();
    final scanned = _scanned;
    if (scanned != null) {
      identity.useManualEntry();
      identity.updateDraft(identity.draft.copyWith(seniorId: scanned.seniorId));
    }
    IdentityActions.review(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Scan your ID'),
      body: _step == _Step.scanning
          ? CameraGate(
              onUseAnotherMethod: () => IdentityActions.otherMethods(context),
              builder: (_) => _scanner(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              children: [_panel()],
            ),
    );
  }

  Widget _scanner() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          key: ObjectKey(controller),
          controller: controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => ColoredBox(
            color: AppColors.background,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              children: [_cameraError(error)],
            ),
          ),
        ),
        const CameraFrameOverlay(shape: FrameShape.square),
        const Positioned(
          left: 20,
          right: 20,
          top: 20,
          child: CameraInstruction(
            'Hold the QR code on your ID inside the square.',
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => IdentityActions.otherMethods(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Text(
                  'Having trouble? Use another method',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraError(MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return HelpPanel(
      icon: Icons.no_photography_outlined,
      color: AppColors.danger,
      title: denied
          ? 'Camera permission is needed for this feature.'
          : "We couldn't access the camera.",
      message: denied
          ? 'Please allow the camera for this app in your phone settings.'
          : 'Close other apps that use the camera, then try again.',
      actions: [
        HelpAction('Try again', Icons.refresh, _startScanning),
        HelpAction('Take photo of ID', Icons.photo_camera_outlined,
            () => IdentityActions.takePhoto(context)),
        HelpAction('Enter manually', Icons.edit_note,
            () => IdentityActions.enterManually(context)),
      ],
    );
  }

  Widget _panel() {
    final scannedId = _scanned?.seniorId;
    switch (_step) {
      case _Step.scanning:
        return const SizedBox.shrink();
      case _Step.lookingUp:
        return const Padding(
          padding: EdgeInsets.only(top: 48),
          child: BusyPanel(
            title: 'Looking up your record...',
            message: 'We are checking your ID with the OSCA office. '
                'Please wait.',
          ),
        );
      case _Step.noCode:
        return HelpPanel(
          icon: Icons.qr_code_2,
          title: "Couldn't find a supported QR code.",
          message: 'Make sure the QR code on your Senior Citizen ID is inside '
              'the square, and that there is enough light.',
          actions: [
            HelpAction('Try again', Icons.refresh, _startScanning),
            HelpAction('Take photo of ID', Icons.photo_camera_outlined,
                () => IdentityActions.takePhoto(context)),
            HelpAction('Enter manually', Icons.edit_note,
                () => IdentityActions.enterManually(context)),
          ],
        );
      case _Step.notFound:
        return HelpPanel(
          icon: Icons.person_search_outlined,
          title: "We couldn't find a senior citizen record matching this ID.",
          message: scannedId == null
              ? 'Please check that this is your Senior Citizen ID.'
              : 'The ID number we read is $scannedId. Please check that it is '
                  'the same as the number on your ID.',
          tips: const [
            'We will not create a new record for you here. The OSCA office '
                'keeps the official records.',
          ],
          actions: [
            HelpAction('Check ID', Icons.fact_check_outlined, _checkIdNumber),
            HelpAction('Try again', Icons.refresh, _startScanning),
            HelpAction('Enter manually', Icons.edit_note,
                () => IdentityActions.enterManually(context)),
            HelpAction('Contact OSCA', Icons.support_agent_outlined,
                () => IdentityActions.contactOsca(context)),
          ],
        );
      case _Step.alreadyLinked:
        return HelpPanel(
          icon: Icons.link_off,
          color: AppColors.danger,
          title: 'This senior citizen record is already linked to an account.',
          message: _message?.isNotEmpty == true
              ? _message!
              : 'One record can only be linked to one account. If this is '
                  'your record, the OSCA office can help you.',
          actions: [
            HelpAction('Contact OSCA', Icons.support_agent_outlined,
                () => IdentityActions.contactOsca(context)),
            HelpAction('Go back', Icons.arrow_back,
                () => IdentityActions.otherMethods(context)),
          ],
        );
      case _Step.unavailable:
        return HelpPanel(
          icon: Icons.cloud_off_outlined,
          title: 'We could not look up your record.',
          message: _message ?? ApiIdentityService.unavailableMessage,
          actions: [
            HelpAction('Continue to the form', Icons.arrow_forward,
                () => IdentityActions.review(context)),
            HelpAction('Contact OSCA', Icons.support_agent_outlined,
                () => IdentityActions.contactOsca(context)),
          ],
        );
      case _Step.error:
        return HelpPanel(
          icon: Icons.wifi_off,
          color: AppColors.danger,
          title: 'We could not check your ID.',
          message: _message ?? 'Please try again.',
          actions: [
            HelpAction('Try again', Icons.refresh, () {
              final scanned = _scanned;
              scanned == null ? _startScanning() : _lookUp(scanned);
            }),
            HelpAction('Enter manually', Icons.edit_note,
                () => IdentityActions.enterManually(context)),
          ],
        );
    }
  }
}
