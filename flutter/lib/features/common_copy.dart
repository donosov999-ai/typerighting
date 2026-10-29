/// Phrases shared by several screens that used to be hard-coded in Russian
/// and showed in every interface language (found 29.10 after the same-ID
/// update switched an English device to English).
String commonCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'typeHere': [
      'Печатайте здесь',
      'Type here',
      'Escribe aquí',
      'Hier tippen',
      'Tapez ici',
      'Digita qui',
      'Digite aqui',
    ],
    'typeLine': [
      'Печатайте строку',
      'Type the line',
      'Escribe la línea',
      'Zeile tippen',
      'Tapez la ligne',
      'Digita la riga',
      'Digite a linha',
    ],
    'keyboardInput': [
      'Ввод с клавиатуры',
      'Keyboard input',
      'Entrada de teclado',
      'Tastatureingabe',
      'Saisie au clavier',
      'Input da tastiera',
      'Entrada pelo teclado',
    ],
    'saving': [
      'Сохранение…',
      'Saving…',
      'Guardando…',
      'Wird gespeichert…',
      'Enregistrement…',
      'Salvataggio…',
      'A guardar…',
    ],
    'retrySave': [
      'Повторить сохранение',
      'Retry saving',
      'Reintentar guardar',
      'Erneut speichern',
      'Réessayer l’enregistrement',
      'Riprova a salvare',
      'Tentar guardar de novo',
    ],
    'resultNotSaved': [
      'Результат не сохранён. История осталась прежней. Повторите сохранение.',
      'The result was not saved. Your history is unchanged. Try saving again.',
      'El resultado no se guardó. Tu historial no cambió. Vuelve a guardar.',
      'Das Ergebnis wurde nicht gespeichert. Dein Verlauf ist unverändert. Erneut speichern.',
      'Le résultat n’a pas été enregistré. Votre historique est inchangé. Réessayez.',
      'Il risultato non è stato salvato. La cronologia è invariata. Riprova a salvare.',
      'O resultado não foi guardado. O histórico não mudou. Tente guardar de novo.',
    ],
    'settingsNotSaved': [
      'Настройки не сохранены. Проверьте свободное место.',
      'Settings were not saved. Check free storage space.',
      'No se guardaron los ajustes. Comprueba el espacio libre.',
      'Einstellungen nicht gespeichert. Prüfe den freien Speicher.',
      'Réglages non enregistrés. Vérifiez l’espace libre.',
      'Impostazioni non salvate. Controlla lo spazio libero.',
      'Definições não guardadas. Verifique o espaço livre.',
    ],
    'prev': [
      'Предыдущее',
      'Previous',
      'Anterior',
      'Vorherige',
      'Précédent',
      'Precedente',
      'Anterior',
    ],
    'next': [
      'Следующее',
      'Next',
      'Siguiente',
      'Nächste',
      'Suivant',
      'Successivo',
      'Seguinte',
    ],
    'keyboard': [
      'Клавиатура',
      'Keyboard',
      'Teclado',
      'Tastatur',
      'Clavier',
      'Tastiera',
      'Teclado',
    ],
    'nextChar': [
      'Следующий символ',
      'Next character',
      'Siguiente carácter',
      'Nächstes Zeichen',
      'Caractère suivant',
      'Carattere successivo',
      'Próximo carácter',
    ],
    'stars': [
      'Звёзд',
      'Stars',
      'Estrellas',
      'Sterne',
      'Étoiles',
      'Stelle',
      'Estrelas',
    ],
    'lastLineSpeed': [
      'скорость последней строки',
      'last line speed',
      'velocidad de la última línea',
      'Tempo der letzten Zeile',
      'vitesse de la dernière ligne',
      'velocità dell’ultima riga',
      'velocidade da última linha',
    ],
    'appTitle': [
      'TypeFree · пробная версия',
      'TypeFree · preview',
      'TypeFree · versión de prueba',
      'TypeFree · Vorschau',
      'TypeFree · aperçu',
      'TypeFree · anteprima',
      'TypeFree · pré-visualização',
    ],
    'candidateNote': [
      'Пробная версия Flutter. Данные хранятся отдельно от установленного приложения.',
      'Flutter preview. Data is kept separately from the installed app.',
      'Versión de prueba de Flutter. Los datos se guardan aparte de la app instalada.',
      'Flutter-Vorschau. Daten werden getrennt von der installierten App gespeichert.',
      'Aperçu Flutter. Les données sont séparées de l’application installée.',
      'Anteprima Flutter. I dati sono separati dall’app installata.',
      'Pré-visualização Flutter. Os dados ficam separados da app instalada.',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

/// Shown before any language is known (the saved data could not be read).
const startupFailedText =
    'Could not read local data. The original copy is kept — do not clear storage.\n'
    'Не удалось прочитать локальные данные. Исходная копия сохранена. Не очищайте хранилище.';
