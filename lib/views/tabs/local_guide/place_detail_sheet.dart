import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../models/place.dart';
import '../../../services/sos_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';

/// Icon and color for each kind of place (used by the map and the list).
IconData placeIcon(PlaceCategory category) {
  switch (category) {
    case PlaceCategory.health:
      return Icons.local_hospital_outlined;
    case PlaceCategory.pharmacy:
      return Icons.medication_outlined;
    case PlaceCategory.government:
      return Icons.account_balance_outlined;
    case PlaceCategory.discount:
      return Icons.sell_outlined;
  }
}

Color placeColor(PlaceCategory category) {
  switch (category) {
    case PlaceCategory.health:
      return AppColors.danger;
    case PlaceCategory.pharmacy:
      return AppColors.primaryBright;
    case PlaceCategory.government:
      return AppColors.primaryDark;
    case PlaceCategory.discount:
      return const Color(0xFFB26A00);
  }
}

Future<void> showPlaceDetailSheet(BuildContext context, Place place) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => PlaceDetailSheet(place: place),
  );
}

class PlaceDetailSheet extends StatelessWidget {
  final Place place;

  const PlaceDetailSheet({super.key, required this.place});

  Future<void> _open(BuildContext context, Future<bool> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await action();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the app on this phone.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.read<SosService>();
    final color = placeColor(place.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(placeIcon(place.category), color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      context.tr(place.category.labelKey),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Detail(icon: Icons.place_outlined, text: place.address),
          if (place.hours.isNotEmpty)
            _Detail(icon: Icons.schedule, text: place.hours),
          if (place.phone.isNotEmpty)
            _Detail(icon: Icons.call_outlined, text: place.phone),
          if (place.note.isNotEmpty)
            _Detail(icon: Icons.info_outline, text: place.note),
          const SizedBox(height: 20),
          BigButton(
            label: 'Directions',
            icon: Icons.directions_outlined,
            onPressed: () => _open(
              context,
              () => sos.openDirections(place.latitude, place.longitude),
            ),
          ),
          if (place.phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            BigButton(
              label: 'Call',
              icon: Icons.call,
              style: BigButtonStyle.tonal,
              onPressed: () => _open(context, () => sos.call(place.phone)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
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
