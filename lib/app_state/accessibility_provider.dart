import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../storage/preferences.dart';

enum AppLanguage {
  english('en', 'English'),
  filipino('fil', 'Filipino'),
  cebuano('ceb', 'Cebuano (Bisaya)');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
          (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

/// Text size, high contrast and language. Saved on the phone and kept after
/// log out.
///
/// Translations live in lib/l10n/app_en.arb, app_fil.arb and app_ceb.arb.
/// They are loaded here directly, so the app can use Cebuano even though
/// Flutter's built-in widgets have no Cebuano translation.
class AccessibilityProvider extends ChangeNotifier {
  AccessibilityProvider._({
    required Preferences prefs,
    required AssetBundle bundle,
    required double textScale,
    required bool highContrast,
    required AppLanguage language,
    required Map<String, String> english,
    required Map<String, String> strings,
  })  : _prefs = prefs,
        _bundle = bundle,
        _textScale = textScale,
        _highContrast = highContrast,
        _language = language,
        _english = english,
        _strings = strings;

  final Preferences _prefs;
  final AssetBundle _bundle;
  double _textScale;
  bool _highContrast;
  AppLanguage _language;
  final Map<String, String> _english;
  Map<String, String> _strings;

  /// Choices on the Accessibility screen.
  /// (size, name) pairs. A list, because Dart does not allow decimal
  /// numbers as keys of a constant map.
  static const List<(double, String)> textScaleOptions = [
    (1.0, 'Normal'),
    (1.15, 'Large'),
    (1.3, 'Larger'),
    (1.5, 'Largest'),
  ];

  static Future<AccessibilityProvider> load(
      Preferences prefs, {
        AssetBundle? bundle,
      }) async {
    final assets = bundle ?? rootBundle;
    final language = AppLanguage.fromCode(prefs.language);
    final english = await _loadArb(assets, AppLanguage.english);
    final strings = language == AppLanguage.english
        ? english
        : await _loadArb(assets, language);
    return AccessibilityProvider._(
      prefs: prefs,
      bundle: assets,
      textScale: prefs.textScale,
      highContrast: prefs.highContrast,
      language: language,
      english: english,
      strings: strings,
    );
  }

  static Future<Map<String, String>> _loadArb(
      AssetBundle bundle,
      AppLanguage language,
      ) async {
    try {
      final raw = await bundle.loadString('lib/l10n/app_${language.code}.arb');
      final Object? decoded = jsonDecode(raw);
      final result = <String, String>{};
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          if (!key.startsWith('@') && value is String) result[key] = value;
        });
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  AppLanguage get language => _language;

  /// Translated text for [key]. Falls back to English, then to the key.
  /// [args] fills placeholders: t('homeGreeting', {'name': 'Rosela'}).
  String t(String key, [Map<String, String> args = const {}]) {
    var text = _strings[key] ?? _english[key] ?? key;
    args.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
    return text;
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;
    notifyListeners();
    await _prefs.setTextScale(value);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    await _prefs.setHighContrast(value);
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (value == _language) return;
    final strings = value == AppLanguage.english
        ? _english
        : await _loadArb(_bundle, value);
    _language = value;
    _strings = strings;
    notifyListeners();
    await _prefs.setLanguage(value.code);
  }
}

extension TranslateContext on BuildContext {
  /// Translated text. Use inside build() only (it rebuilds when the
  /// language changes). In button callbacks use
  /// context.read<AccessibilityProvider>().t(key) instead.
  String tr(String key, [Map<String, String> args = const {}]) =>
      Provider.of<AccessibilityProvider>(this).t(key, args);
}