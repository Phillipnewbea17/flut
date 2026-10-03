import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../repositories/wallet_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Big QR code and ID number to show the cashier.
class QrCashierView extends StatelessWidget {
  const QrCashierView({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.watch<WalletRepository>().seniorId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTheme.appBar('Show to cashier'),
      body: SafeArea(
        child: id == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Your Senior Citizen ID is not ready yet. It will appear '
                    'when your application is approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Please scan or check my Senior Citizen ID.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary, width: 3),
                      ),
                      child: Semantics(
                        label: 'QR code of Senior Citizen ID ${id.idNumber}',
                        child: QrImageView(
                          data: id.qrData,
                          version: QrVersions.auto,
                          size: 260,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    id.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ID NUMBER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SelectableText(
                    id.idNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    id.issuedBy,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tip: turn up your screen brightness so the code is easy to scan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}
