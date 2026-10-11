import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_state/accessibility_provider.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/identity_repository.dart';
import '../../repositories/requests_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/section_title.dart';
import '../../widgets/sos_button.dart';

/// The app after login: Home | Applications | My ID | Benefits | Account.
/// The tabs themselves are routes (see Routes.tabs in app_router.dart).
class MasterNavigationHub extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MasterNavigationHub({super.key, required this.navigationShell});

  @override
  State<MasterNavigationHub> createState() => _MasterNavigationHubState();
}

class _MasterNavigationHubState extends State<MasterNavigationHub> {
  @override
  void initState() {
    super.initState();
    // Load saved data first, then refresh from the server.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ApplicationRepository>().load();
      context.read<DocumentRepository>().load();
      context.read<WalletRepository>().load();
      context.read<UserRepository>().load();
      context.read<RequestsRepository>().load();
      _checkIdentity();
    });
  }

  /// Loads the linked senior record (Personal Information). Linking it is
  /// not part of signing in, so Home never redirects for it.
  Future<void> _checkIdentity() async {
    await context.read<IdentityRepository>().load();
  }

  void _select(int index) {
    final shell = widget.navigationShell;
    // Tapping the open tab again goes back to its first page.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    final highContrast = context.watch<AccessibilityProvider>().highContrast;
    final scaffold = Scaffold(
      backgroundColor: highContrast ? null : Colors.transparent,
      body: widget.navigationShell,
      // SOS is for emergencies, so it stays on Home, apart from the
      // everyday Quick actions.
      floatingActionButton: index == 0 ? const SosButton() : null,
      bottomNavigationBar: _TabBar(
        selectedIndex: index,
        onSelected: _select,
        tabs: [
          (Icons.home_outlined, Icons.home, context.tr('tabHome')),
          (
            Icons.description_outlined,
            Icons.description,
            context.tr('tabApplications'),
          ),
          (Icons.badge_outlined, Icons.badge, context.tr('tabMyId')),
          (
            Icons.card_giftcard_outlined,
            Icons.card_giftcard,
            context.tr('tabBenefits'),
          ),
          (Icons.person_outline, Icons.person, context.tr('tabAccount')),
        ],
      ),
    );
    return highContrast ? scaffold : MintBackground(child: scaffold);
  }
}

/// Five tabs with an icon and a label each, on a floating dark green bar.
/// Unlike NavigationBar, a long label ("Applications") shrinks to fit its
/// tab instead of running into the next one when the text is made bigger.
class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// (icon, selected icon, label) for each tab.
  final List<(IconData, IconData, String)> tabs;

  const _TabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Container(
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x660E3B25),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  // The open tab is a little wider, like the mockup.
                  flex: i == selectedIndex ? 6 : 5,
                  child: _Tab(
                    icon: i == selectedIndex ? tabs[i].$2 : tabs[i].$1,
                    label: tabs[i].$3,
                    selected: i == selectedIndex,
                    position: '${i + 1} of ${tabs.length}',
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final String position;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xB3FFFFFF);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, tab $position',
      excludeSemantics: true,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 2),
                // Flexible gives the label a height limit, so FittedBox also
                // shrinks it when the user's text size would not fit.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
