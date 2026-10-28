import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/templates.dart';

/// Settings: hub, «Настройки ввода» (F3) and «Звук и оформление» (F4/M4).
/// Every switch is an existing source setting (src/main.ts settings modal);
/// titles reuse the source dictionary keys, subtitles are local copy.
class SettingsValues {
  const SettingsValues({
    required this.hide,
    required this.block,
    required this.keyboard,
    required this.layout,
    required this.heat,
    required this.hardKeys,
    required this.bridge,
    required this.targetWpm,
    required this.sound,
    required this.voice,
    required this.voiceAvailable,
    required this.metronome,
    required this.bpm,
    required this.pet,
    required this.motion,
    required this.textSize,
    required this.version,
    this.companion = false,
  });
  final bool hide, block, keyboard, heat, hardKeys, bridge;
  final String layout;
  final int targetWpm, bpm;
  final bool sound, voice, voiceAvailable, metronome, pet, motion;
  final double textSize;
  final String version;

  /// Phone mode (A4 companion) is the start screen.
  final bool companion;
}

typedef SettingChanged = void Function(String key, Object value);

String settingsCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'input': [
      'Настройки ввода',
      'Input settings',
      'Ajustes de escritura',
      'Eingabe',
      'Saisie',
      'Impostazioni di input',
      'Definições de entrada',
    ],
    'input.d': [
      'Текст, ошибки, клавиатура, раскладка',
      'Text, errors, keyboard, layout',
      'Texto, errores, teclado, distribución',
      'Text, Fehler, Tastatur, Layout',
      'Texte, erreurs, clavier, disposition',
      'Testo, errori, tastiera, layout',
      'Texto, erros, teclado, layout',
    ],
    'sound': [
      'Звук и оформление',
      'Sound and appearance',
      'Sonido y apariencia',
      'Ton und Darstellung',
      'Son et apparence',
      'Suono e aspetto',
      'Som e aparência',
    ],
    'sound.d': [
      'Звуки, метроном, тема, размер текста',
      'Sounds, metronome, theme, text size',
      'Sonidos, metrónomo, tema, tamaño del texto',
      'Töne, Metronom, Thema, Textgröße',
      'Sons, métronome, thème, taille du texte',
      'Suoni, metronomo, tema, dimensione testo',
      'Sons, metrónomo, tema, tamanho do texto',
    ],
    'hide.d': [
      'Тренировка по памяти',
      'Practice from memory',
      'Práctica de memoria',
      'Aus dem Gedächtnis üben',
      'S’entraîner de mémoire',
      'Esercizio a memoria',
      'Treino de memória',
    ],
    'block.d': [
      'Не идти дальше, пока символ неверный',
      'Stay on a key until it is right',
      'No avanzar hasta acertar',
      'Erst weiter, wenn die Taste stimmt',
      'Ne pas avancer avant la bonne touche',
      'Non avanzare finché il tasto è errato',
      'Não avançar até acertar',
    ],
    'keyb.d': [
      'Схема клавиатуры под текстом',
      'Keyboard guide under the text',
      'Guía del teclado bajo el texto',
      'Tastaturhilfe unter dem Text',
      'Guide du clavier sous le texte',
      'Guida tastiera sotto il testo',
      'Guia do teclado sob o texto',
    ],
    'layout.d': [
      'Как расположены буквы на вашей клавиатуре',
      'Letter positions on your keyboard',
      'Posición de letras en tu teclado',
      'Buchstabenlage auf Ihrer Tastatur',
      'Position des lettres sur votre clavier',
      'Posizione lettere sulla tua tastiera',
      'Posição das letras no seu teclado',
    ],
    'heat.d': [
      'Клавиши с ошибками на схеме',
      'Keys you miss, on the guide',
      'Teclas con errores en la guía',
      'Fehlertasten auf der Hilfe',
      'Touches fautives sur le guide',
      'Tasti con errori sulla guida',
      'Teclas com erros no guia',
    ],
    'hard.d': [
      'Только для русской раскладки',
      'Russian layout only',
      'Solo distribución rusa',
      'Nur russisches Layout',
      'Disposition russe uniquement',
      'Solo layout russo',
      'Apenas layout russo',
    ],
    'bridge.d': [
      'Не нужно переключать раскладку ОС',
      'No need to switch the OS layout',
      'Sin cambiar la distribución del sistema',
      'Kein Umschalten des System-Layouts',
      'Sans changer la disposition du système',
      'Senza cambiare il layout di sistema',
      'Sem mudar o layout do sistema',
    ],
    'target.d': [
      'Для прогноза в «Прогрессе»',
      'Used by the forecast in Progress',
      'Para el pronóstico en Progreso',
      'Für die Prognose im Fortschritt',
      'Pour la prévision dans Progrès',
      'Per la previsione in Progressi',
      'Para a previsão no Progresso',
    ],
    'sfx': [
      'Звуковые эффекты',
      'Sound effects',
      'Efectos de sonido',
      'Soundeffekte',
      'Effets sonores',
      'Effetti sonori',
      'Efeitos sonoros',
    ],
    'sound.sfx.d': [
      'Ошибка, завершение, рекорд, звёзды',
      'Error, finish, record, stars',
      'Error, final, récord, estrellas',
      'Fehler, Abschluss, Rekord, Sterne',
      'Erreur, fin, record, étoiles',
      'Errore, fine, record, stelle',
      'Erro, fim, recorde, estrelas',
    ],
    'voice.d': [
      'Произносит верно набранную букву (RU/EN)',
      'Says each correct letter (RU/EN)',
      'Dice cada letra correcta (RU/EN)',
      'Spricht jeden richtigen Buchstaben (RU/EN)',
      'Dit chaque lettre juste (RU/EN)',
      'Pronuncia ogni lettera giusta (RU/EN)',
      'Diz cada letra certa (RU/EN)',
    ],
    'metro.d': [
      'Ровный тик в тренировке',
      'Steady tick during practice',
      'Tic constante al practicar',
      'Gleichmäßiger Takt beim Üben',
      'Tic régulier à l’entraînement',
      'Tic costante in esercizio',
      'Tique constante no treino',
    ],
    'look': [
      'Оформление',
      'Appearance',
      'Apariencia',
      'Darstellung',
      'Apparence',
      'Aspetto',
      'Aparência',
    ],
    'template': [
      'Шаблон',
      'Template',
      'Plantilla',
      'Vorlage',
      'Modèle',
      'Modello',
      'Modelo',
    ],
    'theme': ['Тема', 'Theme', 'Tema', 'Thema', 'Thème', 'Tema', 'Tema'],
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
    'preview': [
      'Предпросмотр — не сохранено',
      'Preview — not saved',
      'Vista previa: sin guardar',
      'Vorschau – nicht gespeichert',
      'Aperçu — non enregistré',
      'Anteprima — non salvata',
      'Pré-visualização — não guardada',
    ],
    'apply': [
      'Применить',
      'Apply',
      'Aplicar',
      'Übernehmen',
      'Appliquer',
      'Applica',
      'Aplicar',
    ],
    'cancel': [
      'Отмена',
      'Cancel',
      'Cancelar',
      'Abbrechen',
      'Annuler',
      'Annulla',
      'Cancelar',
    ],
    'textSize': [
      'Размер текста',
      'Text size',
      'Tamaño del texto',
      'Textgröße',
      'Taille du texte',
      'Dimensione testo',
      'Tamanho do texto',
    ],
    'pet.d': [
      'Синапс в шапке и его реплики',
      'Synapse in the header and its notes',
      'Synapse en la cabecera y sus frases',
      'Synapse oben und seine Hinweise',
      'Synapse en haut et ses remarques',
      'Synapse in alto e i suoi messaggi',
      'Synapse no topo e as suas falas',
    ],
    'motion': [
      'Анимация',
      'Animation',
      'Animación',
      'Animation',
      'Animation',
      'Animazione',
      'Animação',
    ],
    'motion.d': [
      'Выключите, если движение мешает',
      'Turn off if motion distracts you',
      'Desactívala si el movimiento molesta',
      'Ausschalten, wenn Bewegung stört',
      'Désactivez si le mouvement gêne',
      'Disattiva se il movimento disturba',
      'Desligue se o movimento incomodar',
    ],
    'companion': [
      'Компаньон',
      'Companion',
      'Compañero',
      'Begleiter',
      'Compagnon',
      'Compagno',
      'Companheiro',
    ],
    'companion.d': [
      'На телефоне без клавиатуры открывать прогресс и обучение',
      'On a phone without a keyboard, open progress and learning',
      'En un móvil sin teclado, abrir progreso y aprendizaje',
      'Auf dem Handy ohne Tastatur Fortschritt und Lernen öffnen',
      'Sur un téléphone sans clavier, ouvrir progrès et apprentissage',
      'Su un telefono senza tastiera, apri progressi e apprendimento',
      'Num telemóvel sem teclado, abrir progresso e aprendizagem',
    ],
    'version': [
      'Версия',
      'Version',
      'Versión',
      'Version',
      'Version',
      'Versione',
      'Versão',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class SettingsHub extends StatelessWidget {
  const SettingsHub({
    super.key,
    required this.language,
    required this.values,
    required this.onInput,
    required this.onSound,
  });
  final String language;
  final SettingsValues values;
  final VoidCallback onInput, onSound;
  @override
  Widget build(BuildContext context) => _Page(
    children: [
      NavTile(
        icon: Icons.keyboard_outlined,
        accent: const Color(0xFF4F8DFD),
        title: settingsCopy(language, 'input'),
        subtitle: settingsCopy(language, 'input.d'),
        onTap: onInput,
      ),
      NavTile(
        icon: Icons.volume_up_outlined,
        accent: const Color(0xFF8B5CF6),
        title: settingsCopy(language, 'sound'),
        subtitle: settingsCopy(language, 'sound.d'),
        onTap: onSound,
      ),
      const SizedBox(height: 16),
      Text(
        'TypeFree · ${settingsCopy(language, 'version')} ${values.version}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class InputSettingsPage extends StatelessWidget {
  const InputSettingsPage({
    super.key,
    required this.language,
    required this.tr,
    required this.values,
    required this.onChanged,
  });
  final String language;
  final String Function(String) tr;
  final SettingsValues values;
  final SettingChanged onChanged;
  @override
  Widget build(BuildContext context) {
    String c(String k) => settingsCopy(language, k);
    return _Page(
      children: [
        _Card(
          children: [
            _SwitchRow(
              Icons.visibility_off_outlined,
              tr('tb.hide'),
              c('hide.d'),
              values.hide,
              (v) => onChanged('hide', v),
            ),
            _SwitchRow(
              Icons.block_outlined,
              tr('tb.block'),
              c('block.d'),
              values.block,
              (v) => onChanged('block', v),
            ),
            _SwitchRow(
              Icons.keyboard_alt_outlined,
              tr('tb.keyb'),
              c('keyb.d'),
              values.keyboard,
              (v) => onChanged('keyboard', v),
            ),
            _Row(
              icon: Icons.language,
              title: tr('set.layout'),
              subtitle: c('layout.d'),
              inline: true,
              below: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: DropdownButton<String>(
                      value: values.layout,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                          value: 'auto',
                          child: Text(tr('set.layout.auto')),
                        ),
                        const DropdownMenuItem(
                          value: 'qwerty',
                          child: Text('QWERTY'),
                        ),
                        const DropdownMenuItem(
                          value: 'azerty',
                          child: Text('AZERTY · FR'),
                        ),
                        const DropdownMenuItem(
                          value: 'qwertz',
                          child: Text('QWERTZ · DE'),
                        ),
                      ],
                      onChanged: (v) => onChanged('layout', v!),
                    ),
                  ),
                ),
              ),
            ),
            _SwitchRow(
              Icons.local_fire_department_outlined,
              tr('tb.heat'),
              c('heat.d'),
              values.heat,
              (v) => onChanged('heat', v),
            ),
            _SwitchRow(
              Icons.keyboard_double_arrow_up,
              tr('set.hardkeys'),
              c('hard.d'),
              values.hardKeys,
              (v) => onChanged('hardkeys', v),
            ),
            _SwitchRow(
              Icons.compare_arrows,
              tr('set.bridge'),
              c('bridge.d'),
              values.bridge,
              (v) => onChanged('bridge', v),
            ),
            _SliderRow(
              icon: Icons.speed,
              title: tr('set.targetwpm'),
              subtitle: c('target.d'),
              value: values.targetWpm,
              min: 10,
              max: 200,
              step: 5,
              unit: 'WPM',
              ticks: const [10, 50, 100, 150, 200],
              onChanged: (v) => onChanged('targetWpm', v),
            ),
          ],
        ),
      ],
    );
  }
}

class SoundSettingsPage extends StatelessWidget {
  const SoundSettingsPage({
    super.key,
    required this.language,
    required this.tr,
    required this.values,
    required this.onChanged,
    required this.onTestSound,
    required this.appearance,
  });
  final String language;
  final String Function(String) tr;
  final SettingsValues values;
  final SettingChanged onChanged;
  final VoidCallback onTestSound;
  final AppearanceController appearance;
  @override
  Widget build(BuildContext context) {
    String c(String k) => settingsCopy(language, k);
    final sel = appearance.selection;
    return _Page(
      children: [
        _Card(
          children: [
            _SwitchRow(
              Icons.volume_up_outlined,
              c('sfx'),
              c('sound.sfx.d'),
              values.sound,
              (v) => onChanged('sound', v),
            ),
            if (values.voiceAvailable)
              _SwitchRow(
                Icons.record_voice_over_outlined,
                tr('set.voice').replaceFirst('🔊 ', ''),
                c('voice.d'),
                values.voice,
                (v) => onChanged('voice', v),
              ),
            MergeSemantics(
              child: _SliderRow(
                icon: Icons.music_note_outlined,
                title: tr('set.metro'),
                subtitle: c('metro.d'),
                value: values.bpm,
                min: 60,
                max: 200,
                step: 10,
                unit: 'BPM',
                ticks: const [60, 80, 100, 120, 140, 160, 180, 200],
                leadingSwitch: Switch(
                  value: values.metronome,
                  onChanged: (v) => onChanged('metronome', v),
                ),
                onChanged: (v) => onChanged('bpm', v),
                action: OutlinedButton.icon(
                  onPressed: onTestSound,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(tr('set.soundtest')),
                ),
              ),
            ),
          ],
        ),
        _Header(c('look')),
        _Card(
          children: [
            _Row(
              icon: Icons.palette_outlined,
              title: c('template'),
              subtitle: appearance.previewing ? c('preview') : '',
              below: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in appearance.registry.templates.values)
                    _TemplateCard(
                      template: t,
                      brightness: Theme.of(context).brightness,
                      selected: sel.templateId == t.id,
                      onTap: () => appearance.preview(t.id, sel.brightness),
                    ),
                ],
              ),
            ),
            _Row(
              icon: Icons.contrast,
              title: c('theme'),
              subtitle: '',
              inline: true,
              below: _Choice<ThemeMode>(
                options: [
                  (ThemeMode.dark, Text(c('dark'))),
                  (ThemeMode.light, Text(c('light'))),
                  (ThemeMode.system, Text(c('system'))),
                ],
                selected: sel.brightness,
                onSelected: (m) => appearance.preview(sel.templateId, m),
              ),
            ),
            if (appearance.previewing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: appearance.cancel,
                      child: Text(c('cancel')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => appearance.apply(),
                      child: Text(c('apply')),
                    ),
                  ],
                ),
              ),
            _Row(
              icon: Icons.format_size,
              title: c('textSize'),
              subtitle: '',
              inline: true,
              below: _Choice<double>(
                options: const [
                  (.9, Text('A', style: TextStyle(fontSize: 13))),
                  (1.0, Text('A', style: TextStyle(fontSize: 16))),
                  (1.15, Text('A', style: TextStyle(fontSize: 20))),
                ],
                selected: values.textSize,
                onSelected: (v) => onChanged('textSize', v),
              ),
            ),
            _SwitchRow(
              Icons.smartphone_outlined,
              c('companion'),
              c('companion.d'),
              values.companion,
              (v) => onChanged('companion', v),
            ),
            _SwitchRow(
              Icons.pets_outlined,
              tr('set.pet').replaceFirst('🐾 ', ''),
              c('pet.d'),
              values.pet,
              (v) => onChanged('pet', v),
            ),
            _SwitchRow(
              Icons.animation,
              c('motion'),
              c('motion.d'),
              values.motion,
              (v) => onChanged('motion', v),
            ),
          ],
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56, endIndent: 16),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.below,
    this.inline = false,
  });
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing, below;

  /// Put [below] at the end of the row when there is room (F4 layout),
  /// otherwise under the title — never clipped.
  final bool inline;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Room for the title plus a three-way control at the current text size.
      final need = 400 * MediaQuery.textScalerOf(context).scale(14) / 14;
      final side = inline && below != null && box.maxWidth >= need;
      return _layout(context, side ? below : trailing, side ? null : below);
    },
  );

  Widget _layout(BuildContext context, Widget? trailing, Widget? below) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: muted),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (below != null)
              Padding(
                padding: const EdgeInsets.only(left: 38, top: 4),
                child: Align(alignment: Alignment.centerLeft, child: below),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(
    this.icon,
    this.title,
    this.subtitle,
    this.value,
    this.onChanged,
  );
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: _Row(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.ticks = const [],
    this.action,
    this.leadingSwitch,
  });
  final IconData icon;
  final String title, subtitle, unit;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;

  /// Scale labels under the slider (F3/F4 sketches show them).
  final List<int> ticks;
  final Widget? action, leadingSwitch;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final slider = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leadingSwitch != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '$value $unit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ step,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        if (ticks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, box) {
                // Thin the scale to what fits; the ends always stay.
                final label =
                    11 * 3.4 * MediaQuery.textScalerOf(context).scale(14) / 14;
                final fit = math.max(
                  2,
                  math.min(ticks.length, (box.maxWidth / (label + 6)).floor()),
                );
                final shown = [
                  for (var i = 0; i < fit; i++)
                    ticks[(i * (ticks.length - 1) / math.max(1, fit - 1))
                        .round()],
                ];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final t in shown)
                      Text('$t', style: TextStyle(fontSize: 11, color: muted)),
                  ],
                );
              },
            ),
          ),
      ],
    );
    return _Row(
      icon: icon,
      title: title,
      subtitle: subtitle,
      // With a switch the value moves next to the slider, so large text
      // never pushes the switch out of the row.
      trailing:
          leadingSwitch ??
          Text(
            '$value $unit',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
      below: action == null
          ? slider
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 360,
                  ),
                  child: slider,
                ),
                action!,
              ],
            ),
    );
  }
}

class NavTile extends StatelessWidget {
  const NavTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color accent;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      minTileHeight: 56,
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

/// Segmented control that never overflows: a SegmentedButton when it fits,
/// otherwise wrapping chips (no scaling, no sideways scroll for a choice).
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final List<(T, Widget)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final perItem = 92 * MediaQuery.textScalerOf(context).scale(14) / 14;
      if (box.maxWidth >= perItem * options.length) {
        return SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final (v, w) in options) ButtonSegment(value: v, label: w),
          ],
          selected: {selected},
          onSelectionChanged: (v) => onSelected(v.first),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (v, w) in options)
            ChoiceChip(
              label: w,
              selected: v == selected,
              onSelected: (_) => onSelected(v),
            ),
        ],
      );
    },
  );
}

/// M4 template card: a miniature drawn from the template's own colours in
/// the current brightness (one card per template, brightness chosen apart —
/// DESIGN_TEMPLATE_REF §4).
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });
  final DesignTemplate template;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = template.colors(brightness);
    final accent = template.profileAccents['m']![brightness.name]!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: template.title,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 58,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c['canvas'],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c['border']!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 8,
                        width: 60,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      for (final w in [88.0, 70.0])
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          height: 6,
                          width: w,
                          decoration: BoxDecoration(
                            color: c['raisedSurface'],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(template.title, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
