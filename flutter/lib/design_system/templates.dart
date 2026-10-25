import 'package:flutter/material.dart';

const appearanceKey = 'typefree.appearance.v1';
const templateRoles = <String>[
  'canvas',
  'surface',
  'raisedSurface',
  'border',
  'text',
  'mutedText',
  'primary',
  'onPrimary',
  'success',
  'danger',
  'focusRing',
  'keyboardFace',
  'keyboardBase',
  'keyboardLegend',
  'keyboardSecondaryLegend',
  'expectedKey',
  'onExpectedKey',
  'shiftKey',
  'onShiftKey',
  'assistantPanel',
];

Map<String, dynamic> _map(Object? v) {
  if (v is! Map<String, dynamic>)
    throw const FormatException('Expected object');
  return v;
}

Color _color(Object? v) {
  if (v is! String || !RegExp(r'^#[0-9A-F]{6}$').hasMatch(v)) {
    throw const FormatException('Invalid color');
  }
  return Color(0xFF000000 | int.parse(v.substring(1), radix: 16));
}

/// Visual tokens only. No feature gates, domain data or account permissions.
class DesignTemplate {
  DesignTemplate._(
    this.id,
    this.title,
    this.light,
    this.dark,
    this.profileAccents,
  );
  final String id;
  final String title;
  final Map<String, Color> light;
  final Map<String, Color> dark;
  final Map<String, Map<String, Color>> profileAccents;

  factory DesignTemplate.parse(Map<String, dynamic> json) {
    const allowed = {
      'id',
      'revision',
      'title',
      'layoutId',
      'preview',
      'variants',
      'profileAccents',
    };
    if (json.keys.toSet().difference(allowed).isNotEmpty ||
        json['id'] is! String ||
        !RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(json['id'] as String) ||
        json['title'] is! String ||
        json['revision'] is! int ||
        (json['revision'] as int) < 1 ||
        json['layoutId'] != 'adaptive-workspace-v1' ||
        json['preview'] is! String ||
        !RegExp(r'^[a-zA-Z0-9-]+\.png$').hasMatch(json['preview'] as String)) {
      throw const FormatException('Invalid template contract');
    }
    Map<String, Color> variant(Object? value) {
      final map = _map(value);
      if (map.length != templateRoles.length ||
          !templateRoles.every(map.containsKey)) {
        throw const FormatException('Incomplete semantic tokens');
      }
      return Map.unmodifiable({
        for (final role in templateRoles) role: _color(map[role]),
      });
    }

    final variants = _map(json['variants']);
    if (variants.length != 2) throw const FormatException('Invalid variants');
    final profiles = _map(json['profileAccents']);
    if (profiles.length != 3 ||
        !['m', 'f', 'kids'].every(profiles.containsKey)) {
      throw const FormatException('Missing profiles');
    }
    final accents = <String, Map<String, Color>>{};
    for (final entry in profiles.entries) {
      final value = entry.value;
      final pair = _map(value);
      if (pair.length != 2)
        throw const FormatException('Invalid profile tokens');
      accents[entry.key] = Map.unmodifiable({
        'light': _color(pair['light']),
        'dark': _color(pair['dark']),
      });
    }
    return DesignTemplate._(
      json['id'] as String,
      json['title'] as String,
      variant(variants['light']),
      variant(variants['dark']),
      Map.unmodifiable(accents),
    );
  }

  Map<String, Color> colors(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

class TemplateRegistry {
  TemplateRegistry._(this.templates, this.fallbackId, this.newInstallId);
  final Map<String, DesignTemplate> templates;
  final String fallbackId;
  final String newInstallId;

  factory TemplateRegistry.parse(Map<String, dynamic> json) {
    const slots = {
      'app.header',
      'app.navigation',
      'practice.controls',
      'practice.text',
      'practice.keyboard',
      'assistant.header',
      'assistant.panel',
    };
    final declared = json['requiredSlots'];
    if (json['schemaVersion'] != 1 ||
        json['preferenceKey'] != appearanceKey ||
        declared is! List ||
        declared.length != slots.length ||
        declared.toSet().length != slots.length ||
        !declared.toSet().containsAll(slots)) {
      throw const FormatException('Unsupported registry contract');
    }
    final raw = json['templates'];
    if (raw is! List || raw.isEmpty)
      throw const FormatException('Empty registry');
    final parsed = <String, DesignTemplate>{};
    for (final value in raw) {
      final item = DesignTemplate.parse(_map(value));
      if (parsed.containsKey(item.id))
        throw const FormatException('Duplicate template');
      parsed[item.id] = item;
    }
    final fallback = json['fallbackTemplateId'];
    final initial = json['defaultForNewInstall'];
    if (!parsed.containsKey(fallback) || !parsed.containsKey(initial)) {
      throw const FormatException('Missing fallback');
    }
    return TemplateRegistry._(
      Map.unmodifiable(parsed),
      fallback as String,
      initial as String,
    );
  }

  DesignTemplate resolve(String id) => templates[id] ?? templates[fallbackId]!;
}

class AppearanceSelection {
  const AppearanceSelection(this.templateId, this.brightness);
  final String templateId;
  final ThemeMode brightness;
  Map<String, Object> toJson() => {
    'schema': 1,
    'templateId': templateId,
    'brightness': brightness.name,
  };
}

abstract interface class AppearanceStore {
  /// Implementations write only appearanceKey atomically. Never history/vault.
  Future<void> save(Map<String, Object> value);
}

/// Kept above route/session widgets. Changing a template never recreates them.
class AppearanceController extends ChangeNotifier {
  AppearanceController(
    this.registry,
    this.store, {
    required bool existingInstall,
    Map<String, dynamic>? saved,
    bool? legacyDark,
  }) {
    final mode = legacyDark == null
        ? ThemeMode.system
        : legacyDark
        ? ThemeMode.dark
        : ThemeMode.light;
    _committed = AppearanceSelection(
      existingInstall ? registry.fallbackId : registry.newInstallId,
      mode,
    );
    if (saved != null &&
        saved['schema'] == 1 &&
        saved['templateId'] is String) {
      final name = saved['brightness'];
      final selected = ThemeMode.values.where((m) => m.name == name);
      _committed = AppearanceSelection(
        registry.resolve(saved['templateId'] as String).id,
        selected.isEmpty ? mode : selected.first,
      );
    }
  }
  final TemplateRegistry registry;
  final AppearanceStore store;
  late AppearanceSelection _committed;
  AppearanceSelection? _preview;
  bool _busy = false;
  bool _disposed = false;
  AppearanceSelection get selection => _preview ?? _committed;
  bool get busy => _busy;

  void preview(String id, ThemeMode brightness) {
    if (_busy) throw StateError('Appearance save in progress');
    if (!registry.templates.containsKey(id))
      throw const FormatException('Unknown template');
    _preview = AppearanceSelection(id, brightness);
    notifyListeners();
  }

  void cancel() {
    if (_busy) throw StateError('Appearance save in progress');
    _preview = null;
    notifyListeners();
  }

  Future<bool> apply() async {
    if (_busy) return false;
    final next = selection;
    _busy = true;
    notifyListeners();
    try {
      await store.save(next.toJson());
      _committed = next;
      _preview = null;
      return true;
    } catch (_) {
      _preview = null; // Storage failed: restore committed appearance.
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  ThemeData theme(Brightness systemBrightness, {String profileId = 'm'}) {
    final selected = selection;
    final brightness = switch (selected.brightness) {
      ThemeMode.system => systemBrightness,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
    final template = registry.resolve(selected.templateId);
    final accents =
        template.profileAccents[profileId] ?? template.profileAccents['m']!;
    final accent = accents[brightness.name]!;
    final c = {
      ...template.colors(brightness),
      'primary': accent,
      'expectedKey': accent,
    };
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c['primary']!,
          brightness: brightness,
        ).copyWith(
          primary: c['primary'],
          onPrimary: c['onPrimary'],
          surface: c['surface'],
          onSurface: c['text'],
          error: c['danger'],
        );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: c['canvas'],
      extensions: [TypeFreeTokens(c)],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class TypeFreeTokens extends ThemeExtension<TypeFreeTokens> {
  TypeFreeTokens(Map<String, Color> colors) : colors = Map.unmodifiable(colors);
  final Map<String, Color> colors;
  Color operator [](String role) => colors[role]!;
  @override
  TypeFreeTokens copyWith({Map<String, Color>? colors}) =>
      TypeFreeTokens(colors ?? this.colors);
  @override
  TypeFreeTokens lerp(covariant TypeFreeTokens? other, double t) =>
      other == null
      ? this
      : TypeFreeTokens({
          for (final role in templateRoles)
            role: Color.lerp(colors[role], other.colors[role], t)!,
        });
}

class AppearanceTheme extends StatelessWidget {
  const AppearanceTheme({
    super.key,
    required this.controller,
    required this.systemBrightness,
    required this.child,
    this.profileId = 'm',
  });
  final AppearanceController controller;
  final Brightness systemBrightness;
  final Widget child;
  final String profileId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    child: child,
    builder: (context, child) => Theme(
      data: controller.theme(systemBrightness, profileId: profileId),
      child: child!,
    ),
  );
}
