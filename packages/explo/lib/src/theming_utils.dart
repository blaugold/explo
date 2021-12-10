import 'package:flutter/material.dart';

class HasAnyState implements MaterialStateProperty<bool> {
  const HasAnyState(this.states);

  final Set<MaterialState> states;

  @override
  bool resolve(Set<MaterialState> states) =>
      this.states.intersection(states).isNotEmpty;
}
