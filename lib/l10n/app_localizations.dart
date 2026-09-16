import 'dart:async';
import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_am.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _strings;

  Future<void> load() async {
    if (locale.languageCode == 'am') {
      _strings = AppLocalizationsAm.strings;
    } else {
      _strings = AppLocalizationsEn.strings;
    }
  }

  String translate(String key) {
    return _strings[key] ?? key;
  }

  String get login => translate('login');
  String get phoneNumber => translate('phoneNumber');
  String get password => translate('password');
  String get submit => translate('submit');
  String get routeAssignments => translate('routeAssignments');
  String get payments => translate('payments');
  String get profile => translate('profile');
  String get searchPlate => translate('searchPlate');
  String get driverInfo => translate('driverInfo');
  String get driverName => translate('driverName');
  String get plateNumber => translate('plateNumber');
  String get association => translate('association');
  String get paidUntil => translate('paidUntil');
  String get maintenance => translate('maintenance');
  String get notFulfilled => translate('notFulfilled');
  String get noAssignments => translate('noAssignments');
  String get assigned => translate('assigned');
  String get changePassword => translate('changePassword');
  String get currentPassword => translate('currentPassword');
  String get newPassword => translate('newPassword');
  String get logout => translate('logout');
  String get total => translate('total');
  String get week => translate('week');
  String get month => translate('month');
  String get weekly => translate('weekly');
  String get monthly => translate('monthly');
  String get pay => translate('pay');
  String get feeSummary => translate('feeSummary');
  String get overdue => translate('overdue');
  String get interest => translate('interest');
  String get prepay => translate('prepay');
  String get language => translate('language');
  String get english => translate('english');
  String get amharic => translate('amharic');
  String get cancel => translate('cancel');
  String get confirmDelete => translate('confirmDelete');
  String get delete => translate('delete');
  String get error => translate('error');
  String get networkError => translate('networkError');
  String get unauthorized => translate('unauthorized');
  String get appTitle => translate('appTitle');
  String get noPayment => translate('noPayment');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'am'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
