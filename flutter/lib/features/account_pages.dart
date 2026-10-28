import 'package:flutter/material.dart';

import '../data/artifact_export.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
import 'progress_page.dart' show exportHistory, progressCopy;
import 'transfer_page.dart' show transferCopy;

/// F5 «Аккаунт» and F6 «Данные и разрешения» as honest LOCAL states (sheet 06
/// draws them with «(план Flutter)»): practice works without an account;
/// sign-in, the shared account, restore and account deletion are not in this
/// build yet and say so instead of pretending. Export of history works.
String accountCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'account': [
      'Аккаунт',
      'Account',
      'Cuenta',
      'Konto',
      'Compte',
      'Account',
      'Conta',
    ],
    'account.d': [
      'Синхронизация между устройствами',
      'Sync between devices',
      'Sincronización entre dispositivos',
      'Synchronisierung zwischen Geräten',
      'Synchronisation entre appareils',
      'Sincronizzazione tra dispositivi',
      'Sincronização entre dispositivos',
    ],
    'data': [
      'Данные и разрешения',
      'Data and permissions',
      'Datos y permisos',
      'Daten und Berechtigungen',
      'Données et autorisations',
      'Dati e autorizzazioni',
      'Dados e permissões',
    ],
    'data.d': [
      'Где хранится прогресс, экспорт',
      'Where progress is kept, export',
      'Dónde se guarda el progreso, exportar',
      'Wo der Fortschritt liegt, Export',
      'Où sont les progrès, export',
      'Dove sono i progressi, esporta',
      'Onde fica o progresso, exportar',
    ],
    'noacc': [
      'Без аккаунта уже можно заниматься',
      'You can practise without an account',
      'Puedes practicar sin cuenta',
      'Üben geht auch ohne Konto',
      'Vous pouvez vous entraîner sans compte',
      'Puoi esercitarti senza account',
      'Pode praticar sem conta',
    ],
    'noacc.d': [
      'Все режимы работают на этом устройстве. Аккаунт нужен только для синхронизации между устройствами.',
      'Every mode works on this device. An account is only needed to sync between devices.',
      'Todos los modos funcionan en este dispositivo. La cuenta solo sirve para sincronizar.',
      'Alle Modi laufen auf diesem Gerät. Ein Konto braucht man nur zum Synchronisieren.',
      'Tous les modes fonctionnent sur cet appareil. Le compte ne sert qu’à synchroniser.',
      'Tutte le modalità funzionano su questo dispositivo. L’account serve solo a sincronizzare.',
      'Todos os modos funcionam neste dispositivo. A conta serve só para sincronizar.',
    ],
    'login': [
      'Вход по нику и PIN',
      'Sign in with nickname and PIN',
      'Entrar con apodo y PIN',
      'Anmelden mit Nick und PIN',
      'Connexion avec pseudo et PIN',
      'Accesso con nick e PIN',
      'Entrar com apelido e PIN',
    ],
    'login.d': [
      'Работает в установленном приложении TypeFree. В эту версию вход ещё не перенесён — прогресс здесь не теряется.',
      'Works in the installed TypeFree app. Not yet moved into this version — progress here is kept.',
      'Funciona en la app instalada de TypeFree. Aún no está en esta versión; el progreso se conserva.',
      'Funktioniert in der installierten TypeFree-App. In dieser Version noch nicht — der Fortschritt bleibt.',
      'Fonctionne dans l’app TypeFree installée. Pas encore dans cette version — les progrès sont conservés.',
      'Funziona nell’app TypeFree installata. Non ancora in questa versione: i progressi restano.',
      'Funciona na app TypeFree instalada. Ainda não nesta versão — o progresso fica guardado.',
    ],
    'shared': [
      'Общий аккаунт — кандидат',
      'Shared account — candidate',
      'Cuenta común — candidata',
      'Gemeinsames Konto — Kandidat',
      'Compte commun — candidat',
      'Account comune — candidato',
      'Conta comum — candidata',
    ],
    'shared.d': [
      'Синхронизация прогресса между устройствами — в будущих версиях.',
      'Syncing progress between devices — in future versions.',
      'Sincronizar el progreso entre dispositivos: en próximas versiones.',
      'Fortschritt zwischen Geräten synchronisieren — in künftigen Versionen.',
      'Synchroniser les progrès entre appareils — dans de prochaines versions.',
      'Sincronizzare i progressi tra dispositivi: nelle prossime versioni.',
      'Sincronizar o progresso entre dispositivos — em versões futuras.',
    ],
    'off': [
      'Сервис не подключён',
      'Service not connected',
      'Servicio no conectado',
      'Dienst nicht verbunden',
      'Service non connecté',
      'Servizio non collegato',
      'Serviço não ligado',
    ],
    'later': [
      'В следующей версии',
      'In a later version',
      'En una próxima versión',
      'In einer späteren Version',
      'Dans une prochaine version',
      'In una versione futura',
      'Numa versão futura',
    ],
    'local': [
      'Только локальные данные',
      'Local data only',
      'Solo datos locales',
      'Nur lokale Daten',
      'Données locales uniquement',
      'Solo dati locali',
      'Só dados locais',
    ],
    'local.d': [
      'Прогресс сохраняется на этом устройстве. Никакие данные не отправляются без вашего согласия.',
      'Progress is kept on this device. Nothing is sent without your consent.',
      'El progreso se guarda en este dispositivo. No se envía nada sin tu consentimiento.',
      'Der Fortschritt bleibt auf diesem Gerät. Ohne Zustimmung wird nichts gesendet.',
      'Les progrès restent sur cet appareil. Rien n’est envoyé sans votre accord.',
      'I progressi restano su questo dispositivo. Nulla viene inviato senza consenso.',
      'O progresso fica neste dispositivo. Nada é enviado sem o seu consentimento.',
    ],
    'perm': [
      'Разрешения',
      'Permissions',
      'Permisos',
      'Berechtigungen',
      'Autorisations',
      'Autorizzazioni',
      'Permissões',
    ],
    'cloud': [
      'История тренировок в облаке',
      'Practice history in the cloud',
      'Historial en la nube',
      'Verlauf in der Cloud',
      'Historique dans le cloud',
      'Cronologia nel cloud',
      'Histórico na nuvem',
    ],
    'coach': [
      'Доступ для тренера',
      'Access for a coach',
      'Acceso para un entrenador',
      'Zugriff für Trainer',
      'Accès pour un coach',
      'Accesso per un allenatore',
      'Acesso para treinador',
    ],
    'backup': [
      'Экспорт и восстановление',
      'Export and restore',
      'Exportar y restaurar',
      'Export und Wiederherstellung',
      'Export et restauration',
      'Esporta e ripristina',
      'Exportar e restaurar',
    ],
    'restore': [
      'Восстановить из файла',
      'Restore from a file',
      'Restaurar desde archivo',
      'Aus Datei wiederherstellen',
      'Restaurer depuis un fichier',
      'Ripristina da file',
      'Restaurar de ficheiro',
    ],
    'delete': [
      'Удалить аккаунт',
      'Delete account',
      'Eliminar cuenta',
      'Konto löschen',
      'Supprimer le compte',
      'Elimina account',
      'Eliminar conta',
    ],
    'delete.d': [
      'Аккаунта в этой версии нет — удалять нечего. Прогресс на устройстве остаётся вашим.',
      'There is no account in this version — nothing to delete. Progress on the device stays yours.',
      'No hay cuenta en esta versión: nada que eliminar. El progreso sigue siendo tuyo.',
      'In dieser Version gibt es kein Konto — nichts zu löschen. Der Fortschritt bleibt deiner.',
      'Pas de compte dans cette version — rien à supprimer. Vos progrès restent à vous.',
      'In questa versione non c’è account: niente da eliminare. I progressi restano tuoi.',
      'Não há conta nesta versão — nada a eliminar. O progresso continua seu.',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.border});
  final Widget child;
  final Color? border;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border ?? tokens['border']),
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
                if (trailing != null) ...[const SizedBox(height: 6), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// F5: account (honest LOCAL state).
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.language});
  final String language;
  @override
  Widget build(BuildContext context) {
    String c(String k) => accountCopy(language, k);
    final scheme = Theme.of(context).colorScheme;
    Widget badge(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.primary.withValues(alpha: .15),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: scheme.primary)),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Box(
              child: _Line(
                icon: Icons.person_outline,
                title: c('noacc'),
                subtitle: c('noacc.d'),
              ),
            ),
            _Box(
              child: _Line(
                icon: Icons.key_outlined,
                title: c('login'),
                subtitle: c('login.d'),
                trailing: badge(c('later')),
              ),
            ),
            _Box(
              child: _Line(
                icon: Icons.cloud_outlined,
                title: c('shared'),
                subtitle: c('shared.d'),
                trailing: badge(c('off')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// F6: where data lives, permissions (none granted — no service), export
/// that works, restore/delete that are not in this build.
class DataPage extends StatefulWidget {
  const DataPage({
    super.key,
    required this.language,
    required this.repository,
    this.exporter,
    this.clock,
    this.onTransfer,
  });
  final String language;
  final LocalRepository repository;
  final ArtifactExporter? exporter;
  final int Function()? clock;

  /// I5: opens «Переход на новую версию» (file from the previous version).
  final VoidCallback? onTransfer;
  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  String? status;
  bool busy = false;

  Future<void> export() async {
    if (busy) return;
    setState(() => busy = true);
    String p(String k) => progressCopy(widget.language, k);
    try {
      final r = await exportHistory(
        widget.repository,
        widget.exporter,
        widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch,
      );
      status = p(
        r == ArtifactExportOutcome.cancelled
            ? 'cancelled'
            : r == ArtifactExportOutcome.requested
            ? 'requested'
            : 'saved',
      );
    } catch (_) {
      status = p('failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String c(String k) => accountCopy(widget.language, k);
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final later = Text(
      c('later'),
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Box(
              border: tokens['success'],
              child: _Line(
                icon: Icons.verified_user_outlined,
                title: c('local'),
                subtitle: c('local.d'),
              ),
            ),
            Text(
              c('perm'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _Box(
              child: Column(
                children: [
                  for (final (icon, key) in [
                    (Icons.cloud_sync_outlined, 'cloud'),
                    (Icons.school_outlined, 'coach'),
                  ])
                    _Line(
                      icon: icon,
                      title: c(key),
                      subtitle: c('off'),
                      trailing: const Switch(value: false, onChanged: null),
                    ),
                ],
              ),
            ),
            Text(
              c('backup'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _Box(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('data-export'),
                    onPressed: busy ? null : export,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(progressCopy(widget.language, 'export')),
                  ),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(status!, key: const ValueKey('data-status')),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('data-transfer'),
                    onPressed: widget.onTransfer,
                    icon: const Icon(Icons.move_up_outlined),
                    label: Text(transferCopy(widget.language, 'entry')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.upload_outlined),
                    label: Text(c('restore')),
                  ),
                  Align(alignment: Alignment.centerRight, child: later),
                ],
              ),
            ),
            _Box(
              border: tokens['danger'],
              child: _Line(
                icon: Icons.delete_outline,
                title: c('delete'),
                subtitle: c('delete.d'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
