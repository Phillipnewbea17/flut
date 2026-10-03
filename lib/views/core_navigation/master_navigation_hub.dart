import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state/accessibility_provider.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../widgets/sos_button.dart';
import '../tabs/account/account_view.dart';
import '../tabs/home/home_dashboard_view.dart';
import '../tabs/local_guide/local_guide_map_view.dart';
import '../tabs/wallet/wallet_view.dart';

/// The app after login: Home, My Wallet, Local Guide and Account.
class MasterNavigationHub extends StatefulWidget {
  const MasterNavigationHub({super.key});

  @override
  State<MasterNavigationHub> createState() => _MasterNavigationHubState();
}

class _MasterNavigationHubState extends State<MasterNavigationHub> {
  int _index = 0;

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
    });
  }

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive, so scrolling and typing are not
      // lost when you switch tabs.
      body: IndexedStack(
        index: _index,
        children: [
          HomeDashboardView(onOpenAccount: () => _select(3)),
          const WalletView(),
          const LocalGuideMapView(),
          const AccountView(),
        ],
      ),
      floatingActionButton: _index == 0 ? const SosButton() : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.tr('tabHome'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: context.tr('tabWallet'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: context.tr('tabLocalGuide'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.tr('tabAccount'),
          ),
        ],
      ),
    );
  }
}
