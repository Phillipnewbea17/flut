import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';
import '../../widgets/onboarding_scaffold.dart';

/// The first screen for anyone not signed in: Create Account or Login.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        const AppLogo(size: 112),
                        const SizedBox(height: 32),
                        Semantics(
                          header: true,
                          child: const Text(
                            'Senior Citizen Management System',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your easy access to senior citizen services.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        BigButton(
                          label: 'Create Account',
                          icon: Icons.person_add_alt_1_outlined,
                          onPressed: () => context.go(Routes.register),
                        ),
                        const SizedBox(height: 16),
                        BigButton(
                          label: 'Login',
                          icon: Icons.login,
                          style: BigButtonStyle.tonal,
                          onPressed: () => context.go(Routes.login),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.push(Routes.contact),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            icon: const Icon(Icons.support_agent_outlined,
                                size: 26, color: AppColors.primary),
                            label: const Text(
                              'Need help? Contact OSCA',
                              style: OnboardingScaffold.linkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
