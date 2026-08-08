import 'package:flutter/material.dart';
import '../i18n/app_translations.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedThemeLabel = "Systeme"; // "Clair", "Sombre", "Systeme"
  String _selectedLanguage = "Français"; // "Français", "Kreyòl", "English", "Español"

  ThemeMode get themeMode => _themeMode;
  String get selectedThemeLabel => _selectedThemeLabel;
  String get selectedLanguage => _selectedLanguage;

  String tr(String key) => AppTranslations.getText(_selectedLanguage, key);

  void setTheme(String themeLabel) {
    _selectedThemeLabel = themeLabel;
    if (themeLabel == "Clair") {
      _themeMode = ThemeMode.light;
    } else if (themeLabel == "Sombre") {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }
}
