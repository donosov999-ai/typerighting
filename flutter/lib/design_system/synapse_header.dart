import 'package:flutter/material.dart';

/// The companion's name: «Синапс» in Russian, «Synapse» elsewhere (as on the
/// result card).
String synapseName(String language) => language == 'ru' ? 'Синапс' : 'Synapse';

/// A host slot for the approved shared Synapse renderer; contains no pet engine,
/// reward rules, fabricated facts or copied assets from a private package.
class SynapseHeaderButton extends StatelessWidget {
  const SynapseHeaderButton({
    super.key,
    required this.portrait,
    required this.onOpen,
    required this.enabled,
    this.label = 'Синапс',
    this.showLabel = false,
  });
  final Widget? portrait;
  final VoidCallback onOpen;
  final bool enabled;
  final String label;

  /// M1: on wide screens the name is written next to the face.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Semantics(
      button: true,
      onTap: portrait == null ? null : onOpen,
      excludeSemantics: true,
      label: label,
      child: Tooltip(
        message: label,
        child: showLabel
            ? TextButton.icon(
                onPressed: portrait == null ? null : onOpen,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                ),
                icon: ExcludeSemantics(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: portrait ?? const Icon(Icons.info_outline),
                  ),
                ),
                label: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: portrait == null ? null : onOpen,
                  padding: const EdgeInsets.all(4),
                  icon: ExcludeSemantics(
                    child: portrait ?? const Icon(Icons.info_outline),
                  ),
                ),
              ),
      ),
    );
  }
}
