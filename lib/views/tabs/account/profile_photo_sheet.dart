import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/camera_access.dart';
import '../../../services/profile_photo_store.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/image_compressor.dart';

enum _PhotoAction { camera, gallery, remove }

/// "Change photo": Take photo, Choose from gallery, Remove photo. The photo
/// is cropped to a circle, saved on this phone, and sent to the OSCA office
/// so staff see it in User Management. It is for the app profile only (it
/// does not change the Senior ID). A change that cannot be sent now is sent
/// the next time the app opens with internet (UserRepository).
Future<void> changeProfilePhoto(BuildContext context) async {
  final user = context.read<UserProvider>();
  final hasPhoto = user.profile?.photoPath != null;

  final action = await showModalBottomSheet<_PhotoAction>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'Profile photo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _SheetOption(
              icon: Icons.photo_camera_outlined,
              label: 'Take photo',
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.camera),
            ),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
            ),
            _SheetOption(
              icon: Icons.delete_outline,
              label: 'Remove photo',
              color: AppColors.danger,
              onTap: hasPhoto
                  ? () => Navigator.of(sheetContext).pop(_PhotoAction.remove)
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final store = context.read<ProfilePhotoStore>();
  final users = context.read<UserRepository>();
  final old = user.profile?.photoPath;

  if (action == _PhotoAction.remove) {
    await user.setPhotoPath(null);
    await store.delete(old);
    final removed = await users.removePhoto();
    if (removed) {
      await store.clearPending();
    } else {
      await store.markPending(PendingPhoto.remove);
    }
    if (context.mounted) {
      _say(
        context,
        removed
            ? 'Photo removed.'
            : 'Photo removed from this phone. The OSCA office will stop '
                'seeing it the next time you open the app with internet.',
      );
    }
    return;
  }

  // A short, plain reason before the phone asks for permission.
  if (!await _explain(context) || !context.mounted) return;

  final source =
      action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery;
  if (source == ImageSource.camera) {
    final permission = await context.read<CameraAccess>().request();
    if (permission != CameraPermission.granted) {
      if (context.mounted) await _denied(context);
      return;
    }
  }
  if (!context.mounted) return;

  Uint8List? bytes;
  try {
    bytes = await context.read<ImageCompressor>().pickProfilePhoto(source);
  } on PlatformException {
    if (context.mounted) await _denied(context);
    return;
  }
  if (bytes == null || !context.mounted) return; // cancelled

  final path = await store.save(bytes);
  if (!context.mounted) return;
  if (path == null) {
    _say(context, 'That photo could not be used. Please try another one.');
    return;
  }
  await user.setPhotoPath(path);
  await store.delete(old);

  // Send it to OSCA so it shows in User Management. The photo is already
  // saved on this phone; when the upload fails it is sent again the next
  // time the app opens (UserRepository.sendPendingPhoto).
  final synced = await users.uploadPhoto(bytes);
  if (synced) {
    await store.clearPending();
  } else {
    await store.markPending(PendingPhoto.upload);
  }
  if (context.mounted) {
    _say(
      context,
      synced
          ? 'Photo updated.'
          : 'Photo saved on this phone. It will be sent to the OSCA office '
              'the next time you open the app with internet.',
    );
  }
}

Future<bool> _explain(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.photo_camera_front_outlined,
          color: AppColors.primary, size: 40),
      title: const Text('Profile picture', style: TextStyle(fontSize: 22)),
      content: const Text(
        'So you can take your profile picture.',
        style: TextStyle(fontSize: 18, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> _denied(BuildContext context) async {
  final camera = context.read<CameraAccess>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('We need your permission',
          style: TextStyle(fontSize: 22)),
      content: const Text(
        'The app could not open your camera or photos. You can allow it in '
        'your phone settings, then try again.',
        style: TextStyle(fontSize: 18, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Not now', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            camera.openSettings();
          },
          child: const Text('Open settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text(text, style: const TextStyle(fontSize: 18))));
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon,
                  size: 30, color: enabled ? color : AppColors.textSecondary),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
