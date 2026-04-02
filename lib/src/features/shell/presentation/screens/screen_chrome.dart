import 'package:flutter/material.dart';

import '../game_theme.dart';

BoxDecoration screenBackgroundDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF071521), Color(0xFF0B2436)],
    ),
  );
}

BoxDecoration solidScreenCardDecoration() {
  return BoxDecoration(
    color: const Color(0xFF11293F),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: const Color(0xFF2A5474)),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x7A000000),
        blurRadius: 28,
        offset: Offset(0, 18),
      ),
    ],
  );
}

Widget screenActionButton({
  required bool compact,
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
  bool primary = false,
}) {
  final Color background = primary
      ? const Color(0xFF79B9FF)
      : const Color(0xFF1A3E5B);
  final Color foreground = primary ? const Color(0xFF072033) : Colors.white;

  return SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        alignment: Alignment.center,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 13 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(primary ? 18 : 16),
        ),
        backgroundColor: background,
        foregroundColor: foreground,
        textStyle: TextStyle(
          fontSize: compact ? 12 : 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 18 : 22),
      label: Text(label),
    ),
  );
}

Widget screenDropdownField<T>({
  required String label,
  required T initialValue,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(
          color: GameColors.muted,
          fontSize: 11,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        initialValue: initialValue,
        items: items,
        onChanged: onChanged,
        decoration: const InputDecoration(isDense: true),
      ),
    ],
  );
}
