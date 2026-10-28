import 'package:flutter/material.dart';

import '../design_system/templates.dart';

/// «Профиль и язык» (A6): profile style, interface language and theme.
/// Profiles and their captions are the source ones (src/profiles.ts,
/// profile.<id> keys); the sketch's «Мужской/Женский» are generated captions.
const profileIds = ['m', 'f', 'kids'];
const profileEmoji = {'m': '⌨️', 'f': '🌸', 'kids': '🐱'};
const profileAccent = {
  'm': Color(0xFF4F8DFD),
  'f': Color(0xFFE879A6),
  'kids': Color(0xFF34C77B),
};
const languageNames = {
  'ru': 'Русский',
  'en': 'English',
  'es': 'Español',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
  'pt': 'Português',
};

String profileCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'title': [
      'Профиль и язык',
      'Profile and language',
      'Perfil e idioma',
      'Profil und Sprache',
      'Profil et langue',
      'Profilo e lingua',
      'Perfil e idioma',
    ],
    'title.d': [
      'Стиль профиля, язык, тема',
      'Profile style, language, theme',
      'Estilo de perfil, idioma, tema',
      'Profilstil, Sprache, Thema',
      'Style du profil, langue, thème',
      'Stile del profilo, lingua, tema',
      'Estilo do perfil, idioma, tema',
    ],
    'style': [
      'Стиль профиля',
      'Profile style',
      'Estilo de perfil',
      'Profilstil',
      'Style du profil',
      'Stile del profilo',
      'Estilo do perfil',
    ],
    'lang': [
      'Язык интерфейса',
      'Interface language',
      'Idioma de la interfaz',
      'Sprache der Oberfläche',
      'Langue de l’interface',
      'Lingua dell’interfaccia',
      'Idioma da interface',
    ],
    'theme': [
      'Тема оформления',
      'Theme',
      'Tema',
      'Thema',
      'Thème',
      'Tema',
      'Tema',
    ],
    'dark': ['Тёмная', 'Dark', 'Oscuro', 'Dunkel', 'Sombre', 'Scuro', 'Escuro'],
    'light': ['Светлая', 'Light', 'Claro', 'Hell', 'Clair', 'Chiaro', 'Claro'],
    'system': [
      'Системная',
      'System',
      'Sistema',
      'System',
      'Système',
      'Sistema',
      'Sistema',
    ],
    'more.d': [
      'Все возможности TypeFree в одном месте',
      'Everything TypeFree can do, in one place',
      'Todo TypeFree en un solo lugar',
      'Alles von TypeFree an einem Ort',
      'Tout TypeFree au même endroit',
      'Tutto TypeFree in un unico posto',
      'Tudo do TypeFree num só lugar',
    ],
    'ach.d': [
      'Награды за вехи и прогресс к ним',
      'Milestone badges and progress towards them',
      'Insignias por hitos y tu avance',
      'Abzeichen für Meilensteine und Fortschritt',
      'Badges d’étapes et progression',
      'Badge dei traguardi e progressi',
      'Medalhas de marcos e progresso',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class ProfileLanguagePage extends StatelessWidget {
  const ProfileLanguagePage({
    super.key,
    required this.language,
    required this.profile,
    required this.tr,
    required this.appearance,
    required this.onProfile,
    required this.onLanguage,
    this.busy = false,
  });
  final String language, profile;
  final String Function(String) tr;
  final AppearanceController appearance;
  final ValueChanged<String> onProfile, onLanguage;

  /// A result is being saved: language/profile changes wait (source rule).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    String c(String k) => profileCopy(language, k);
    final sel = appearance.selection;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Title(c('style')),
            _Grid(
              min: 110,
              children: [
                for (final id in profileIds)
                  _Option(
                    selected: profile == id,
                    label: tr('profile.$id'),
                    onTap: busy ? null : () => onProfile(id),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: profileAccent[id]!.withValues(alpha: .22),
                            border: Border.all(color: profileAccent[id]!),
                          ),
                          child: Text(
                            profileEmoji[id]!,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('profile.$id'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('profile.$id.desc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            _Title(c('lang')),
            _Grid(
              min: 84,
              children: [
                for (final entry in languageNames.entries)
                  _Option(
                    selected: language == entry.key,
                    label: entry.value,
                    onTap: busy ? null : () => onLanguage(entry.key),
                    child: Column(
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            _Title(c('theme')),
            _Grid(
              min: 112,
              children: [
                for (final (mode, icon) in [
                  (ThemeMode.dark, Icons.desktop_windows_outlined),
                  (ThemeMode.light, Icons.light_mode_outlined),
                  (ThemeMode.system, Icons.contrast),
                ])
                  _Option(
                    selected: sel.brightness == mode,
                    label: c(mode.name),
                    onTap: appearance.busy
                        ? null
                        : () {
                            appearance.preview(sel.templateId, mode);
                            appearance.apply();
                          },
                    child: Column(
                      children: [
                        Icon(icon, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          c(mode.name),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Equal-width cells; as many per row as fit [min] at the current text size.
class _Grid extends StatelessWidget {
  const _Grid({required this.min, required this.children});
  final double min;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final per = (box.maxWidth / (min * scale)).floor().clamp(
        1,
        children.length,
      );
      const gap = 8.0;
      final w = (box.maxWidth - gap * (per - 1)) / per;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}

/// Selectable card: accent border and a check badge when chosen.
class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: tokens['raisedSurface'],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? scheme.primary : tokens['border'],
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 15, color: scheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
