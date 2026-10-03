import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../app_state/user_provider.dart';
import '../../../models/place.dart';
import '../../../repositories/places_repository.dart';
import '../../../services/sos_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import 'place_detail_sheet.dart';

/// Local Guide tab: map of clinics, pharmacies, offices and stores, with a
/// list below it (the list works offline even when the map cannot load).
class LocalGuideMapView extends StatefulWidget {
  const LocalGuideMapView({super.key});

  @override
  State<LocalGuideMapView> createState() => _LocalGuideMapViewState();
}

class _LocalGuideMapViewState extends State<LocalGuideMapView> {
  /// Change this to your app's package id (OpenStreetMap asks apps to
  /// identify themselves).
  static const String _userAgentPackageName = 'com.seniorcompanion.app';

  /// Ubay, Bohol. Used before the places are loaded.
  static final LatLng _defaultCenter = LatLng(10.0567, 124.4727);

  final MapController _mapController = MapController();
  late Future<List<Place>> _future;
  PlaceCategory? _filter; // null = all

  @override
  void initState() {
    super.initState();
    _future = context.read<PlacesRepository>().loadPlaces();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = context.read<PlacesRepository>().loadPlaces();
    });
  }

  LatLng _centerOf(List<Place> places) {
    if (places.isEmpty) return _defaultCenter;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in places) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / places.length, lng / places.length);
  }

  void _openPlace(Place place) {
    try {
      _mapController.move(LatLng(place.latitude, place.longitude), 17);
    } catch (_) {
      // The map is not on screen yet. Opening the sheet is enough.
    }
    showPlaceDetailSheet(context, place);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final location = context.watch<UserProvider>().profile?.shortAddress ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.tr('guideTitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (location.isNotEmpty)
                  Text(
                    location,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: context.tr('guideAll'),
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final c in PlaceCategory.values)
                        _CategoryChip(
                          label: context.tr(c.labelKey),
                          selected: _filter == c,
                          onTap: () => setState(() => _filter = c),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Place>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 56, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load places. Please check your internet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        BigButton(
                          label: 'Try again',
                          icon: Icons.refresh,
                          onPressed: _reload,
                        ),
                      ],
                    ),
                  );
                }
                final all = snapshot.data ?? const <Place>[];
                final places = _filter == null
                    ? all
                    : all.where((p) => p.category == _filter).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _buildMap(all, places)),
                    Expanded(
                      flex: 4,
                      child: places.isEmpty
                          ? const Center(
                              child: Text(
                                'No places in this group yet.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                              itemCount: places.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => _PlaceTile(
                                place: places[index],
                                onTap: () => _openPlace(places[index]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<Place> all, List<Place> shown) {
    final sos = context.read<SosService>();
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _centerOf(all),
        initialZoom: 15,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: _userAgentPackageName,
        ),
        MarkerLayer(
          markers: [
            for (final place in shown)
              Marker(
                point: LatLng(place.latitude, place.longitude),
                width: 56,
                height: 56,
                child: Semantics(
                  button: true,
                  label: place.name,
                  child: GestureDetector(
                    onTap: () => _openPlace(place),
                    child: Container(
                      decoration: BoxDecoration(
                        color: placeColor(place.category),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 6),
                        ],
                      ),
                      child: Icon(
                        placeIcon(place.category),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => sos.openWebsite('https://www.openstreetmap.org/copyright'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.primary : Colors.white,
        ),
        selectedColor: Colors.white,
        backgroundColor: AppColors.primaryDark,
        side: const BorderSide(color: Colors.white, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _PlaceTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = placeColor(place.category);
    return InfoCard(
      outlined: true,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color,
            child: Icon(placeIcon(place.category), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  place.address,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 28),
        ],
      ),
    );
  }
}
