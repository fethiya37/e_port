import 'package:flutter/material.dart';
import '../main.dart';

class LanguageHelper {
  static void changeLanguage(BuildContext context, String languageCode) {
    final myApp = MyApp.of(context);
    if (myApp != null) {
      myApp.changeLanguage(languageCode);
    }
  }
}
