import 'package:flutter/material.dart';

class ThemingConstants {
  static const spacing = 16.0;
  static const spacingPadding = EdgeInsets.all(spacing);
  static const spacer = SizedBox(height: spacing, width: spacing);
}

class HasAnyState implements MaterialStateProperty<bool> {
  const HasAnyState(this.states);

  final Set<MaterialState> states;

  @override
  bool resolve(Set<MaterialState> states) =>
      this.states.intersection(states).isNotEmpty;
}
