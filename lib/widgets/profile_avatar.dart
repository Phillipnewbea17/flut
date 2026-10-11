import 'dart:io';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// The round app-profile photo (Account card and Personal information).
/// Without a photo it shows the user's initials.
class ProfileAvatar extends StatelessWidget {
  final UserProfile? profile;
  final double radius;

  const ProfileAvatar({super.key, required this.profile, this.radius = 30});

  @override
  Widget build(BuildContext context) {
    final path = profile?.photoPath;
    final initials = profile?.initials ?? '';

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: initials.isEmpty
          ? Icon(Icons.person_outline,
              color: AppColors.primary, size: radius * 1.05)
          : Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
    );

    final photo = path == null
        ? fallback
        : ClipOval(
            child: Image.file(
              File(path),
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              // The file was removed (e.g. phone cleanup): show initials.
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          );

    return Semantics(
      image: true,
      label: path == null ? 'Profile picture: initials $initials' : 'Profile picture',
      excludeSemantics: true,
      child: photo,
    );
  }
}
