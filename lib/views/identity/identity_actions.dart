import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/identity_repository.dart';
import '../../routes/app_router.dart';

/// The "other ways forward" offered on every identity setup screen, so a
/// failed scan or photo never traps the user.
class IdentityActions {
  IdentityActions._();

  static void contactOsca(BuildContext context) => context.push(Routes.contact);

  static void enterManually(BuildContext context) {
    context.read<IdentityRepository>().useManualEntry();
    context.pushReplacement(Routes.manualInfo);
  }

  static void takePhoto(BuildContext context) =>
      context.pushReplacement(Routes.captureId);

  static void scanAgain(BuildContext context) =>
      context.pushReplacement(Routes.scanId);

  /// Back to the three choices.
  static void otherMethods(BuildContext context) =>
      context.go(Routes.personalInfoSetup);

  static void review(BuildContext context) =>
      context.pushReplacement(Routes.reviewInfo);
}
