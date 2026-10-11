import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The signature flat, bordered card: Paper fill, 1px Hairline border,
/// radius 16, no shadow. Reused everywhere a bento grid needs a tile —
/// separation comes from the border and spacing, never elevation.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
