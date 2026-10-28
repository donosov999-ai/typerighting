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
  });
  final bool hide, block, keyboard, heat, hardKeys, bridge;
  final String layout;
  final int targetWpm, bpm;
  final bool sound, voice, voiceAvailable, metronome, pet, motion;
  final double textSize;
  final String version;
}

typedef SettingChanged = void Function(String key, Object value);

String settingsCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'input': ['Настройки ввода', 'Input settings', 'Ajustes de escritura', 'Eingabe', 'Saisie', 'Impostazioni di input', 'Definições de entrada'],
    'input.d': ['Текст, ошибки, клавиатура, раскладка', 'Text, errors, keyboard, layout', 'Texto, errores, teclado, distribución', 'Text, Fehler, Tastatur, Layout', 'Texte, erreurs, clavier, disposition', 'Testo, errori, tastiera, layout', 'Texto, erros, teclado, layout'],
    'sound': ['Звук и оформление', 'Sound and appearance', 'Sonido y apariencia', 'Ton und Darstellung', 'Son et apparence', 'Suono e aspetto', 'Som e aparência'],
    'sound.d': ['Звуки, метроном, тема, размер текста', 'Sounds, metronome, theme, text size', 'Sonidos, metrónomo, tema, tamaño del texto', 'Töne, Metronom, Thema, Textgröße', 'Sons, métronome, thème, taille du texte', 'Suoni, metronomo, tema, dimensione testo', 'Sons, metrónomo, tema, tamanho do texto'],
    'hide.d': ['Тренировка по памяти', 'Practice from memory', 'Práctica de memoria', 'Aus dem Gedächtnis üben', 'S’entraîner de mémoire', 'Esercizio a memoria', 'Treino de memória'],
    'block.d': ['Не идти дальше, пока символ неверный', 'Stay on a key until it is right', 'No avanzar hasta acertar', 'Erst weiter, wenn die Taste stimmt', 'Ne pas avancer avant la bonne touche', 'Non avanzare finché il tasto è errato', 'Não avançar até acertar'],
    'keyb.d': ['Схема клавиатуры под текстом', 'Keyboard guide under the text', 'Guía del teclado bajo el texto', 'Tastaturhilfe unter dem Text', 'Guide du clavier sous le texte', 'Guida tastiera sotto il testo', 'Guia do teclado sob o texto'],
    'layout.d': ['Как расположены буквы на вашей клавиатуре', 'Letter positions on your keyboard', 'Posición de letras en tu teclado', 'Buchstabenlage auf Ihrer Tastatur', 'Position des lettres sur votre clavier', 'Posizione lettere sulla tua tastiera', 'Posição das letras no seu teclado'],
    'heat.d': ['Клавиши с ошибками на схеме', 'Keys you miss, on the guide', 'Teclas con errores en la guía', 'Fehlertasten auf der Hilfe', 'Touches fautives sur le guide', 'Tasti con errori sulla guida', 'Teclas com erros no guia'],
    'hard.d': ['Только для русской раскладки', 'Russian layout only', 'Solo distribución rusa', 'Nur russisches Layout', 'Disposition russe uniquement', 'Solo layout russo', 'Apenas layout russo'],
    'bridge.d': ['Не нужно переключать раскладку ОС', 'No need to switch the OS layout', 'Sin cambiar la distribución del sistema', 'Kein Umschalten des System-Layouts', 'Sans changer la disposition du système', 'Senza cambiare il layout di sistema', 'Sem mudar o layout do sistema'],
    'target.d': ['Для прогноза в «Прогрессе»', 'Used by the forecast in Progress', 'Para el pronóstico en Progreso', 'Für die Prognose im Fortschritt', 'Pour la prévision dans Progrès', 'Per la previsione in Progressi', 'Para a previsão no Progresso'],
    'sound.sfx.d': ['Ошибка, завершение, рекорд, звёзды', 'Error, finish, record, stars', 'Error, final, récord, estrellas', 'Fehler, Abschluss, Rekord, Sterne', 'Erreur, fin, record, étoiles', 'Errore, fine, record, stelle', 'Erro, fim, recorde, estrelas'],
    'voice.d': ['Произносит верно набранную букву (RU/EN)', 'Says each correct letter (RU/EN)', 'Dice cada letra correcta (RU/EN)', 'Spricht jeden richtigen Buchstaben (RU/EN)', 'Dit chaque lettre juste (RU/EN)', 'Pronuncia ogni lettera giusta (RU/EN)', 'Diz cada letra certa (RU/EN)'],
    'metro.d': ['Ровный тик в тренировке', 'Steady tick during practice', 'Tic constante al practicar', 'Gleichmäßiger Takt beim Üben', 'Tic régulier à l’entraînement', 'Tic costante in esercizio', 'Tique constante no treino'],
    'look': ['Оформление', 'Appearance', 'Apariencia', 'Darstellung', 'Apparence', 'Aspetto', 'Aparência'],
    'template': ['Шаблон', 'Template', 'Plantilla', 'Vorlage', 'Modèle', 'Modello', 'Modelo'],
    'theme': ['Тема', 'Theme', 'Tema', 'Thema', 'Thème', 'Tema', 'Tema'],
    'dark': ['Тёмная', 'Dark', 'Oscuro', 'Dunkel', 'Sombre', 'Scuro', 'Escuro'],
    'light': ['Светлая', 'Light', 'Claro', 'Hell', 'Clair', 'Chiaro', 'Claro'],
    'system': ['Системная', 'System', 'Sistema', 'System', 'Système', 'Sistema', 'Sistema'],
    'preview': ['Предпросмотр — не сохранено', 'Preview — not saved', 'Vista previa: sin guardar', 'Vorschau – nicht gespeichert', 'Aperçu — non enregistré', 'Anteprima — non salvata', 'Pré-visualização — não guardada'],
    'apply': ['Применить', 'Apply', 'Aplicar', 'Übernehmen', 'Appliquer', 'Applica', 'Aplicar'],
    'cancel': ['Отмена', 'Cancel', 'Cancelar', 'Abbrechen', 'Annuler', 'Annulla', 'Cancelar'],
    'textSize': ['Размер текста', 'Text size', 'Tamaño del texto', 'Textgröße', 'Taille du texte', 'Dimensione testo', 'Tamanho do texto'],
    'pet.d': ['Синапс в шапке и его реплики', 'Synapse in the header and its notes', 'Synapse en la cabecera y sus frases', 'Synapse oben und seine Hinweise', 'Synapse en haut et ses remarques', 'Synapse in alto e i suoi messaggi', 'Synapse no topo e as suas falas'],
    'motion': ['Анимация', 'Animation', 'Animación', 'Animation', 'Animation', 'Animazione', 'Animação'],
    'motion.d': ['Выключите, если движение мешает', 'Turn off if motion distracts you', 'Desactívala si el movimiento molesta', 'Ausschalten, wenn Bewegung stört', 'Désactivez si le mouvement gêne', 'Disattiva se il movimento disturba', 'Desligue se o movimento incomodar'],
    'version': ['Версия', 'Version', 'Versión', 'Version', 'Version', 'Versione', 'Versão'],
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
      _NavRow(
        icon: Icons.keyboard_outlined,
        accent: const Color(0xFF4F8DFD),
        title: settingsCopy(language, 'input'),
        subtitle: settingsCopy(language, 'input.d'),
        onTap: onInput,
      ),
      _NavRow(
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
            _SwitchRow(Icons.visibility_off_outlined, tr('tb.hide'), c('hide.d'), values.hide, (v) => onChanged('hide', v)),
            _SwitchRow(Icons.block_outlined, tr('tb.block'), c('block.d'), values.block, (v) => onChanged('block', v)),
            _SwitchRow(Icons.keyboard_alt_outlined, tr('tb.keyb'), c('keyb.d'), values.keyboard, (v) => onChanged('keyboard', v)),
            _Row(
              icon: Icons.language,
              title: tr('set.layout'),
              subtitle: c('layout.d'),
              trailing: DropdownButton<String>(
                value: values.layout,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 'auto', child: Text(tr('set.layout.auto'))),
                  const DropdownMenuItem(value: 'qwerty', child: Text('QWERTY')),
                  const DropdownMenuItem(value: 'azerty', child: Text('AZERTY · FR')),
                  const DropdownMenuItem(value: 'qwertz', child: Text('QWERTZ · DE')),
                ],
                onChanged: (v) => onChanged('layout', v!),
              ),
            ),
            _SwitchRow(Icons.local_fire_department_outlined, tr('tb.heat'), c('heat.d'), values.heat, (v) => onChanged('heat', v)),
            _SwitchRow(Icons.keyboard_double_arrow_up, tr('set.hardkeys'), c('hard.d'), values.hardKeys, (v) => onChanged('hardkeys', v)),
            _SwitchRow(Icons.compare_arrows, tr('set.bridge'), c('bridge.d'), values.bridge, (v) => onChanged('bridge', v)),
            _SliderRow(
              icon: Icons.speed,
              title: tr('set.targetwpm'),
              subtitle: c('target.d'),
              value: values.targetWpm,
              min: 10,
              max: 200,
              step: 5,
              unit: 'WPM',
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
            _SwitchRow(Icons.volume_up_outlined, tr('tb.sound'), c('sound.sfx.d'), values.sound, (v) => onChanged('sound', v)),
            if (values.voiceAvailable)
              _SwitchRow(Icons.record_voice_over_outlined, tr('set.voice').replaceFirst('🔊 ', ''), c('voice.d'), values.voice, (v) => onChanged('voice', v)),
            _SwitchRow(Icons.music_note_outlined, tr('set.metro'), c('metro.d'), values.metronome, (v) => onChanged('metronome', v)),
            _SliderRow(
              icon: Icons.av_timer,
              title: tr('set.metro.bpm'),
              subtitle: '',
              value: values.bpm,
              min: 60,
              max: 200,
              step: 10,
              unit: 'BPM',
              onChanged: (v) => onChanged('bpm', v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
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
                    ChoiceChip(
                      label: Text(t.title),
                      selected: sel.templateId == t.id,
                      onSelected: (_) => appearance.preview(t.id, sel.brightness),
                    ),
                ],
              ),
            ),
            _Row(
              icon: Icons.contrast,
              title: c('theme'),
              subtitle: '',
              below: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.dark, label: Text(c('dark'))),
                  ButtonSegment(value: ThemeMode.light, label: Text(c('light'))),
                  ButtonSegment(value: ThemeMode.system, label: Text(c('system'))),
                ],
                selected: {sel.brightness},
                onSelectionChanged: (m) => appearance.preview(sel.templateId, m.first),
              ),
            ),
            if (appearance.previewing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: appearance.cancel, child: Text(c('cancel'))),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => appearance.apply(), child: Text(c('apply'))),
                  ],
                ),
              ),
            _Row(
              icon: Icons.format_size,
              title: c('textSize'),
              subtitle: '',
              below: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: .9, label: Text('A', style: TextStyle(fontSize: 13))),
                  ButtonSegment(value: 1, label: Text('A', style: TextStyle(fontSize: 16))),
                  ButtonSegment(value: 1.15, label: Text('A', style: TextStyle(fontSize: 20))),
                ],
                selected: {values.textSize},
                onSelectionChanged: (v) => onChanged('textSize', v.first),
              ),
            ),
            _SwitchRow(Icons.pets_outlined, tr('set.pet').replaceFirst('🐾 ', ''), c('pet.d'), values.pet, (v) => onChanged('pet', v)),
            _SwitchRow(Icons.animation, c('motion'), c('motion.d'), values.motion, (v) => onChanged('motion', v)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
      child: Column(children: children),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, this.trailing, this.below});
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing, below;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: muted),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (below != null)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: Align(alignment: Alignment.centerLeft, child: below),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(this.icon, this.title, this.subtitle, this.value, this.onChanged);
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
  });
  final IconData icon;
  final String title, subtitle, unit;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => _Row(
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: Text('$value $unit', style: const TextStyle(fontWeight: FontWeight.w700)),
    below: Slider(
      value: value.clamp(min, max).toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: (max - min) ~/ step,
      label: '$value',
      onChanged: (v) => onChanged(v.round()),
    ),
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.accent, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color accent;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      minTileHeight: 64,
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
