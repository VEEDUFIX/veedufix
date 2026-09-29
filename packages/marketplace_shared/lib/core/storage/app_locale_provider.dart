import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePreferenceKey = 'veedufix.app.locale';

final appLocaleProvider = StateNotifierProvider<AppLocaleController, Locale>(
  (ref) => AppLocaleController(),
);

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController() : super(const Locale('en')) {
    unawaited(_restore());
  }

  bool _selectionStarted = false;

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final languageCode = preferences.getString(_localePreferenceKey);
      if (!_selectionStarted && (languageCode == 'en' || languageCode == 'ta')) {
        state = Locale(languageCode!);
      }
    } catch (_) {
      // Keep English as a usable fallback when local storage is unavailable.
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'ta') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    _selectionStarted = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localePreferenceKey, languageCode);
    state = Locale(languageCode);
  }
}

String appLanguageName(Locale locale) => locale.languageCode == 'ta'
    ? 'தமிழ்'
    : 'English';

String appText(BuildContext context, String english, String tamil) =>
    Localizations.localeOf(context).languageCode == 'ta' ? tamil : english;
