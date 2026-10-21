import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/document_item.dart';
import '../../../repositories/document_repository.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/image_compressor.dart';
import '../../../widgets/big_button.dart';

/// 2x2 face photo for the Senior Citizen ID: tips first, then the camera,
/// then "Use this photo" or "Take again".
class IdPhotoCaptureView extends StatefulWidget {
  const IdPhotoCaptureView({super.key});

  @override
  State<IdPhotoCaptureView> createState() => _IdPhotoCaptureViewState();
}

class _IdPhotoCaptureViewState extends State<IdPhotoCaptureView> {
  Uint8List? _bytes;
  bool _saving = false;

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontSize: 18))),
    );
  }

  Future<void> _take(ImageSource source) async {
    final compressor = context.read<ImageCompressor>();
    try {
      final bytes = await compressor.pickIdPhoto(source);
      if (bytes != null && mounted) setState(() => _bytes = bytes);
    } on PlatformException {
      if (!mounted) return;
      _say('Could not open the camera. Please allow camera access in your '
          'phone settings.');
    }
  }

  Future<void> _use() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final documents = context.read<DocumentRepository>();
    setState(() => _saving = true);
    final DocumentItem item;
    try {
      item = await documents.add(DocumentType.idPhoto, bytes);
    } on ApiException catch (e) {
      // The office refused it (e.g. a new photo is not asked for now).
      if (!mounted) return;
      setState(() => _saving = false);
      _say(e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _say(item.isUploaded
        ? (documents.sendsToOffice
            ? 'Your photo was sent.'
            : 'Your photo was NOT sent: the app is not connected to the OSCA office.')
        : 'Your photo was saved, but not sent yet. Please check your internet.');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      appBar: AppTheme.appBar('2x2 photo'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: bytes == null ? _tips() : _preview(bytes),
      ),
    );
  }

  List<Widget> _tips() {
    return [
      const Center(child: _OvalGuide()),
      const SizedBox(height: 24),
      const Text(
        'Tips for a good photo',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      const _Tip(icon: Icons.wb_sunny_outlined, text: 'Stand facing a window or a bright light.'),
      const _Tip(icon: Icons.crop_square, text: 'Use a plain white wall behind you.'),
      const _Tip(icon: Icons.face_outlined, text: 'Look straight at the camera. No hat, no dark glasses.'),
      const _Tip(icon: Icons.people_outline, text: 'Ask a family member to take it if that is easier.'),
      const SizedBox(height: 24),
      BigButton(
        label: 'Open camera',
        icon: Icons.photo_camera_outlined,
        onPressed: () => _take(ImageSource.camera),
      ),
      const SizedBox(height: 12),
      BigButton(
        label: 'Choose from gallery',
        icon: Icons.photo_library_outlined,
        style: BigButtonStyle.tonal,
        onPressed: () => _take(ImageSource.gallery),
      ),
    ];
  }

  List<Widget> _preview(Uint8List bytes) {
    return [
      Center(
        child: ClipOval(
          child: SizedBox(
            width: 240,
            height: 300,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Is your face clear and in the middle?',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 24),
      if (_saving)
        const Center(child: CircularProgressIndicator())
      else ...[
        BigButton(
          label: 'Use this photo',
          icon: Icons.check,
          onPressed: _use,
        ),
        const SizedBox(height: 12),
        BigButton(
          label: 'Take again',
          icon: Icons.refresh,
          style: BigButtonStyle.tonal,
          onPressed: () => setState(() => _bytes = null),
        ),
      ],
    ];
  }
}

class _OvalGuide extends StatelessWidget {
  const _OvalGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 250,
      decoration: ShapeDecoration(
        color: AppColors.primaryLight,
        shape: const OvalBorder(
          side: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: const Icon(Icons.person, size: 140, color: AppColors.primary),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
