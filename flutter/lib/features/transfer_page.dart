import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/legacy_transfer.dart';
import '../data/history_import.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';

/// Picks a transfer file and returns its decoded JSON, or null on cancel.
typedef TransferFilePicker = Future<Map<String, dynamic>?> Function();

Future<Map<String, dynamic>?> pickTransferFile() async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (f == null) return null;
  final v = jsonDecode(utf8.decode(await f.readAsBytes()));
  if (v is! Map) throw const FormatException('Not an object');
  return Map<String, dynamic>.from(v);
}

String transferCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'historyDone': [
      'История доступна в «Прогрессе». Неоднозначные копии показаны отдельно для проверки.',
      'History is available in Progress. Unresolved copies are shown separately for review.',
      'El historial está disponible en Progreso. Las copias pendientes se muestran por separado.',
      'Der Verlauf ist unter Fortschritt verfügbar. Ungeklärte Kopien werden separat angezeigt.',
      'L’historique est disponible dans Progrès. Les copies non résolues sont affichées séparément.',
      'La cronologia è disponibile in Progressi. Le copie da verificare sono mostrate separatamente.',
      'O histórico está disponível em Progresso. As cópias pendentes aparecem separadamente.',
    ],
    'title': [
      'Переход на новую версию',
      'Moving to the new version',
      'Paso a la nueva versión',
      'Wechsel zur neuen Version',
      'Passage à la nouvelle version',
      'Passaggio alla nuova versione',
      'Passagem para a nova versão',
    ],
    'short': [
      'Перенос данных',
      'Data transfer',
      'Traspaso de datos',
      'Datenübernahme',
      'Transfert des données',
      'Trasferimento dati',
      'Transferência de dados',
    ],
    'entry': [
      'Перенести прогресс из прежней версии',
      'Move progress from the previous version',
      'Pasar el progreso de la versión anterior',
      'Fortschritt aus der vorigen Version übernehmen',
      'Reprendre les progrès de la version précédente',
      'Trasferisci i progressi dalla versione precedente',
      'Passar o progresso da versão anterior',
    ],
    'intro': [
      'Выберите файл переноса прежней версии или экспорт истории TypeFree. Всё происходит на этом устройстве.',
      'Choose a transfer file from the previous version or a TypeFree history export. Everything stays on this device.',
      'Elige un archivo de traspaso anterior o un historial exportado de TypeFree. Todo ocurre en este dispositivo.',
      'Wähle eine ältere Übertragungsdatei oder einen TypeFree-Verlaufsexport. Alles bleibt auf diesem Gerät.',
      'Choisissez un fichier de transfert ancien ou un export de l’historique TypeFree. Tout reste sur cet appareil.',
      'Scegli un file di trasferimento precedente o una cronologia TypeFree esportata. Tutto resta sul dispositivo.',
      'Escolha um ficheiro de transferência anterior ou um histórico TypeFree exportado. Tudo fica neste dispositivo.',
    ],
    'step1': [
      'Файл переноса',
      'Transfer file',
      'Archivo de traspaso',
      'Übertragungsdatei',
      'Fichier de transfert',
      'File di trasferimento',
      'Ficheiro de transferência',
    ],
    'step2': [
      'Импорт прогресса',
      'Importing progress',
      'Importación del progreso',
      'Fortschritt importieren',
      'Import des progrès',
      'Importazione dei progressi',
      'Importação do progresso',
    ],
    'step3': [
      'Завершение перехода',
      'Finishing the move',
      'Fin del paso',
      'Wechsel abschließen',
      'Fin du passage',
      'Fine del passaggio',
      'Fim da passagem',
    ],
    'choose': [
      'Выбрать файл',
      'Choose file',
      'Elegir archivo',
      'Datei wählen',
      'Choisir un fichier',
      'Scegli file',
      'Escolher ficheiro',
    ],
    'checked': [
      'Проверено',
      'Verified',
      'Verificado',
      'Geprüft',
      'Vérifié',
      'Verificato',
      'Verificado',
    ],
    'values': [
      'записей',
      'entries',
      'entradas',
      'Einträge',
      'entrées',
      'voci',
      'entradas',
    ],
    'bad': [
      'Файл не подходит или повреждён. Ничего не записано.',
      'This file is invalid or damaged. Nothing was written.',
      'El archivo no es válido o está dañado. No se escribió nada.',
      'Die Datei ist ungültig oder beschädigt. Nichts wurde geschrieben.',
      'Fichier invalide ou endommagé. Rien n’a été écrit.',
      'File non valido o danneggiato. Nulla è stato scritto.',
      'Ficheiro inválido ou danificado. Nada foi escrito.',
    ],
    'interrupted': [
      'Прервано',
      'Interrupted',
      'Interrumpido',
      'Unterbrochen',
      'Interrompu',
      'Interrotto',
      'Interrompido',
    ],
    'interrupted.d': [
      'Импорт остановлен. Ничего не записано — можно повторить попытку. Прежние данные сохранены.',
      'The import stopped. Nothing was written — you can try again. Your previous data is kept.',
      'La importación se detuvo. No se escribió nada: puedes reintentarlo. Tus datos se conservan.',
      'Der Import wurde gestoppt. Nichts wurde geschrieben — versuche es erneut. Deine Daten bleiben erhalten.',
      'L’import s’est arrêté. Rien n’a été écrit — vous pouvez réessayer. Vos données sont conservées.',
      'L’importazione si è interrotta. Nulla è stato scritto: puoi riprovare. I dati restano salvati.',
      'A importação parou. Nada foi escrito — pode tentar de novo. Os seus dados mantêm-se.',
    ],
    'retry': [
      'Повторить импорт',
      'Retry import',
      'Reintentar',
      'Erneut importieren',
      'Réessayer l’import',
      'Riprova',
      'Repetir importação',
    ],
    'conflict': [
      'На этом устройстве уже есть другой прогресс с теми же записями. Ничего не заменено — прежний прогресс сохранён.',
      'This device already has different progress for the same entries. Nothing was replaced — your existing progress is kept.',
      'Este dispositivo ya tiene otro progreso en las mismas entradas. No se reemplazó nada.',
      'Auf diesem Gerät gibt es schon anderen Fortschritt für dieselben Einträge. Nichts wurde ersetzt.',
      'Cet appareil a déjà d’autres progrès pour les mêmes entrées. Rien n’a été remplacé.',
      'Questo dispositivo ha già altri progressi per le stesse voci. Nulla è stato sostituito.',
      'Este dispositivo já tem outro progresso nas mesmas entradas. Nada foi substituído.',
    ],
    'done': [
      'Готово',
      'Done',
      'Hecho',
      'Fertig',
      'Terminé',
      'Fatto',
      'Concluído',
    ],
    'done.d': [
      'Прогресс перенесён. Продолжайте заниматься в новой версии.',
      'Progress moved. Keep practising in the new version.',
      'Progreso traspasado. Sigue practicando en la nueva versión.',
      'Fortschritt übernommen. Übe in der neuen Version weiter.',
      'Progrès transférés. Continuez dans la nouvelle version.',
      'Progressi trasferiti. Continua nella nuova versione.',
      'Progresso transferido. Continue a praticar na nova versão.',
    ],
    'again': [
      'Этот файл уже перенесён раньше — повторно ничего не добавлено.',
      'This file was already moved earlier — nothing was added twice.',
      'Este archivo ya se traspasó antes: no se añadió nada dos veces.',
      'Diese Datei wurde schon übernommen — nichts doppelt hinzugefügt.',
      'Ce fichier a déjà été transféré — rien n’a été ajouté deux fois.',
      'Questo file è già stato trasferito: nulla aggiunto due volte.',
      'Este ficheiro já foi transferido — nada foi adicionado duas vezes.',
    ],
    'safe': [
      'Исходные данные прежней версии не изменяются и остаются на устройстве.',
      'The previous version’s data is not changed and stays on the device.',
      'Los datos de la versión anterior no cambian y siguen en el dispositivo.',
      'Die Daten der vorigen Version bleiben unverändert auf dem Gerät.',
      'Les données de l’ancienne version ne changent pas et restent sur l’appareil.',
      'I dati della versione precedente non cambiano e restano sul dispositivo.',
      'Os dados da versão anterior não mudam e ficam no dispositivo.',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

/// «1 запись», «2 записи», «5 записей»; English singular; others plural.
String transferCount(int n, String language) {
  if (language == 'ru') {
    final d10 = n % 10, d100 = n % 100;
    final form = d100 >= 11 && d100 <= 14
        ? 'записей'
        : d10 == 1
        ? 'запись'
        : d10 >= 2 && d10 <= 4
        ? 'записи'
        : 'записей';
    return '$n $form';
  }
  if (language == 'en' && n == 1) return '1 entry';
  return '$n ${transferCopy(language, 'values')}';
}

enum _Step { waiting, ok, failed }

/// I5 (sheet 09): moving progress from the previous version as three steps —
/// the file is verified before anything is written, an interrupted write
/// commits nothing and can be retried, a conflict keeps existing progress.
class TransferPage extends StatefulWidget {
  const TransferPage({
    super.key,
    required this.language,
    required this.repository,
    this.pick = pickTransferFile,
  });
  final String language;
  final LocalRepository repository;
  final TransferFilePicker pick;
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  Map<String, dynamic>? file;
  HistoryImport? historyFile;
  int count = 0;
  var check = _Step.waiting, import = _Step.waiting;
  String? note;
  bool busy = false, repeated = false;

  String c(String k) => transferCopy(widget.language, k);

  Future<void> choose() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final picked = await widget.pick();
      if (picked == null) return;
      historyFile = picked['schema'] == 'typefree.history/1'
          ? await HistoryImport.verify(picked)
          : null;
      count = historyFile?.count ?? verifyTransfer(picked).length;
      file = picked;
      check = _Step.ok;
      note = null;
      await run();
    } on FormatException {
      file = null;
      historyFile = null;
      check = _Step.failed;
      import = _Step.waiting;
      note = c('bad');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> run() async {
    try {
      repeated = historyFile != null
          ? !await historyFile!.apply(widget.repository)
          : !await importTransfer(widget.repository, file!);
      import = _Step.ok;
      note = null;
    } on FormatException {
      import = _Step.failed;
      note = c('conflict');
    } catch (_) {
      // Storage write failed mid-way: the transaction committed nothing.
      import = _Step.failed;
      note = c('interrupted.d');
    }
  }

  Future<void> retry() async {
    if (busy || file == null) return;
    setState(() => busy = true);
    await run();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final interrupted = import == _Step.failed && note == c('interrupted.d');
    // Status chip right of the step title, as on sheet 09.
    Widget chip(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    Widget step(
      int n,
      String title,
      _Step state,
      Widget? body, {
      Widget? status,
    }) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: state == _Step.ok
              ? tokens['success']
              : state == _Step.failed
              ? tokens['danger']
              : tokens['border'],
          child: state == _Step.ok
              ? Icon(Icons.check, size: 16, color: tokens['canvas'])
              : Text('$n', style: TextStyle(color: tokens['text'])),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ?status,
                  ],
                ),
                ?body,
              ],
            ),
          ),
        ),
      ],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(c('title'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(c('intro'), style: TextStyle(color: muted)),
            const SizedBox(height: 16),
            step(
              1,
              c('step1'),
              check,
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: check == _Step.ok
                    ? Text(
                        transferCount(count, widget.language),
                        key: const ValueKey('transfer-checked'),
                        style: TextStyle(color: muted),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const ValueKey('transfer-choose'),
                          onPressed: busy ? null : choose,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(c('choose')),
                        ),
                      ),
              ),
              status: check == _Step.ok
                  ? chip(c('checked'), tokens['success'])
                  : null,
            ),
            step(
              2,
              c('step2'),
              import,
              import == _Step.failed
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note!, key: const ValueKey('transfer-note')),
                          if (interrupted) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              key: const ValueKey('transfer-retry'),
                              onPressed: busy ? null : retry,
                              icon: const Icon(Icons.refresh),
                              label: Text(c('retry')),
                            ),
                          ],
                        ],
                      ),
                    )
                  : null,
              status: interrupted
                  ? chip(c('interrupted'), tokens['danger'])
                  : null,
            ),
            step(
              3,
              c('step3'),
              import,
              import == _Step.ok
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        repeated
                            ? c('again')
                            : historyFile != null
                            ? c('historyDone')
                            : c('done.d'),
                        key: const ValueKey('transfer-done'),
                      ),
                    )
                  : null,
            ),
            if (check == _Step.failed)
              Text(
                note!,
                key: const ValueKey('transfer-bad'),
                style: TextStyle(color: tokens['danger']),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens['border']),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c('safe'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
