import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class LanguageSwitcher extends StatelessWidget {
  final Function(String) onLanguageSelected;
  const LanguageSwitcher({super.key, required this.onLanguageSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.white),
      onSelected: (value) {
        onLanguageSelected(value);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              const SizedBox(width: 8),
              Text(l10n.english),
              if (currentLocale.languageCode == 'en')
                const Icon(Icons.check, color: Colors.blue),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'am',
          child: Row(
            children: [
              const SizedBox(width: 8),
              Text(l10n.amharic),
              if (currentLocale.languageCode == 'am')
                const Icon(Icons.check, color: Colors.blue),
            ],
          ),
        ),
      ],
    );
  }
}
