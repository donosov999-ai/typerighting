import 'package:flutter/material.dart';

/// A host slot for the approved shared Synapse renderer; contains no pet engine,
/// reward rules, fabricated facts or copied assets from a private package.
class SynapseHeaderButton extends StatelessWidget {
  const SynapseHeaderButton({
    super.key,
    required this.portrait,
    required this.onOpen,
    required this.enabled,
    this.label = 'Синапс',
  });
  final Widget? portrait;
  final VoidCallback onOpen;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox(
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
