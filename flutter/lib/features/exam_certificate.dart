import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/exam.dart';

String examCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const values = {
    'input': [
      'Печатайте здесь',
      'Type here',
      'Escribe aquí',
      'Hier tippen',
      'Tapez ici',
      'Digita qui',
      'Digite aqui',
    ],
    'actual': [
      'Фактическое время',
      'Actual time',
      'Tiempo real',
      'Tatsächliche Zeit',
      'Temps réel',
      'Tempo effettivo',
      'Tempo real',
    ],
    'early': [
      'Завершено досрочно',
      'Finished early',
      'Finalizado antes de tiempo',
      'Vorzeitig beendet',
      'Terminé plus tôt',
      'Terminato in anticipo',
      'Finalizado antecipadamente',
    ],
    'settingsError': [
      'Выберите 1, 5 или 10 минут и цель от 5 до 120 WPM.',
      'Choose 1, 5 or 10 minutes and a target of 5–120 WPM.',
      'Elige 1, 5 o 10 minutos y un objetivo de 5–120 WPM.',
      'Wähle 1, 5 oder 10 Minuten und ein Ziel von 5–120 WPM.',
      'Choisissez 1, 5 ou 10 minutes et un objectif de 5–120 WPM.',
      'Scegli 1, 5 o 10 minuti e un obiettivo di 5–120 WPM.',
      'Escolha 1, 5 ou 10 minutos e uma meta de 5–120 WPM.',
    ],
    'nameTooLong': [
      'Сократите имя сертификата.',
      'Please shorten the certificate name.',
      'Acorta el nombre del certificado.',
      'Bitte den Zertifikatsnamen kürzen.',
      'Veuillez raccourcir le nom du certificat.',
      'Accorcia il nome del certificato.',
      'Encurte o nome do certificado.',
    ],
    'noTexts': [
      'Тексты теста недоступны.',
      'Test texts are unavailable.',
      'Textos de prueba no disponibles.',
      'Testtexte nicht verfügbar.',
      'Textes de test indisponibles.',
      'Testi non disponibili.',
      'Textos de teste indisponíveis.',
    ],
    'saveError': [
      'Не удалось сохранить. Повторите перед выходом.',
      'Could not save. Retry before leaving.',
      'No se pudo guardar. Reintenta antes de salir.',
      'Speichern fehlgeschlagen. Vor dem Verlassen erneut versuchen.',
      'Échec de l’enregistrement. Réessayez avant de quitter.',
      'Salvataggio non riuscito. Riprova prima di uscire.',
      'Falha ao salvar. Tente novamente antes de sair.',
    ],
    'saved': [
      'Результат сохранён на устройстве',
      'Result saved on this device',
      'Resultado guardado en este dispositivo',
      'Ergebnis auf diesem Gerät gespeichert',
      'Résultat enregistré sur cet appareil',
      'Risultato salvato sul dispositivo',
      'Resultado salvo neste dispositivo',
    ],
    'fileRequested': [
      'Файл передан для сохранения',
      'File sent for saving',
      'Archivo enviado para guardar',
      'Datei zum Speichern übergeben',
      'Fichier transmis pour enregistrement',
      'File inviato per il salvataggio',
      'Arquivo enviado para salvar',
    ],
    'cancelled': [
      'Сохранение файла отменено',
      'File save cancelled',
      'Guardado cancelado',
      'Speichern abgebrochen',
      'Enregistrement annulé',
      'Salvataggio annullato',
      'Salvamento cancelado',
    ],
    'exportError': [
      'Не удалось сохранить сертификат. Можно повторить.',
      'Could not save the certificate. You can retry.',
      'No se pudo guardar el certificado. Puedes reintentar.',
      'Zertifikat konnte nicht gespeichert werden. Erneut versuchen.',
      'Impossible d’enregistrer le certificat. Réessayez.',
      'Impossibile salvare il certificato. Puoi riprovare.',
      'Não foi possível salvar o certificado. Tente novamente.',
    ],
    'local': [
      'Сертификат сохраняется файлом. Публичная ссылка в этой сборке пока недоступна.',
      'The certificate is saved as a file. Public links are not available in this build yet.',
      'El certificado se guarda como archivo. Los enlaces públicos aún no están disponibles.',
      'Das Zertifikat wird als Datei gespeichert. Öffentliche Links sind noch nicht verfügbar.',
      'Le certificat est enregistré dans un fichier. Les liens publics ne sont pas encore disponibles.',
      'Il certificato viene salvato come file. I link pubblici non sono ancora disponibili.',
      'O certificado é salvo como arquivo. Links públicos ainda não estão disponíveis.',
    ],
  };
  final index = langs.indexOf(language);
  return values[key]![index < 0 ? 1 : index];
}

String examTime(int milliseconds) {
  final seconds = (milliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String examElapsedTime(int milliseconds) {
  final tenths = (milliseconds / 100).round();
  return '${tenths ~/ 600}:${((tenths % 600) / 10).toStringAsFixed(1).padLeft(4, '0')}';
}

Future<Uint8List> renderExamCertificate({
  required ExamMetrics metrics,
  required num target,
  required int durationMinutes,
  required int finishedAt,
  required String name,
  required String language,
  required String Function(String) tr,
}) async {
  final recorder = ui.PictureRecorder();
  // Use one recorder for the actual export, independent of viewport/theme.
  final drawing = Canvas(recorder);
  drawing.drawRect(
    const Rect.fromLTWH(0, 0, 1200, 850),
    Paint()..color = const Color(0xfffaf7f0),
  );
  final frame = Paint()
    ..color = const Color(0xffb9962e)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;
  drawing.drawRect(const Rect.fromLTWH(30, 30, 1140, 790), frame);
  frame.strokeWidth = 1.5;
  drawing.drawRect(const Rect.fromLTWH(44, 44, 1112, 762), frame);
  void line(
    String text,
    double y,
    double size,
    Color color, {
    bool bold = false,
    int maxLines = 1,
    double height = 70,
  }) {
    TextPainter? painter;
    var current = size;
    do {
      painter?.dispose();
      painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: current,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: 1060);
      if (!painter.didExceedMaxLines && painter.height <= height ||
          current <= 14) {
        break;
      }
      current *= .9;
    } while (true);
    painter.paint(drawing, Offset((1200 - painter.width) / 2, y));
    painter.dispose();
  }

  const ink = Color(0xff2a2a33),
      gold = Color(0xffb9962e),
      muted = Color(0xff555555);
  final verdict = metrics.net >= target
      ? const Color(0xff2f7d4f)
      : const Color(0xffb3443a);
  line('TypeFree', 76, 30, ink, bold: true);
  line(tr('ex.cert.title'), 150, 60, gold, bold: true);
  line(tr('ex.cert.sub'), 225, 27, muted);
  line(
    name.isEmpty ? '—' : name,
    292,
    48,
    ink,
    bold: true,
    maxLines: 2,
    height: 100,
  );
  line(
    '${metrics.net} ${tr('ex.net')}',
    410,
    98,
    verdict,
    bold: true,
    height: 118,
  );
  line(
    '${tr('ex.gross')}: ${metrics.gross} · ${tr('st.accuracy')}: ${metrics.accuracy}%',
    535,
    30,
    muted,
  );
  line(
    '${examCopy(language, 'actual')}: ${examElapsedTime(metrics.elapsedMs)} · ${tr('ex.duration')}: $durationMinutes ${tr('ex.min')}',
    585,
    25,
    muted,
  );
  line(
    tr(metrics.net >= target ? 'ex.pass' : 'ex.fail'),
    645,
    34,
    verdict,
    bold: true,
  );
  if (metrics.elapsedMs < durationMinutes * 60000) {
    line(examCopy(language, 'early'), 700, 22, muted);
  }
  final date = DateTime.fromMillisecondsSinceEpoch(finishedAt);
  final iso =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  line('${tr('ex.cert.date')}: $iso', 750, 21, muted);
  final picture = recorder.endRecording(),
      image = await picture.toImage(1200, 850);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  // Keeps the renderer entirely local; no external font/image service.
  if (bytes == null) throw StateError('PNG encoding failed');
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}
