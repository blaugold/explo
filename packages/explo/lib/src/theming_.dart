import 'package:flutter/material.dart';

class ThemingUtils {
  static const spacing = 16.0;
  static const spacingPadding = EdgeInsets.all(spacing);
  static EdgeInsets spacingPaddingX(double n) => EdgeInsets.all(n * spacing);
  static const spacer = SizedBox(height: spacing, width: spacing);
  static Widget spacerX(double n) =>
      SizedBox(height: n * spacing, width: n * spacing);
}

final typography = Typography.material2018();

const _primaryColor = Color(0xFF36a964);
const _primaryVariantColor = Color(0xFF196538);
const _secondaryColor = Color(0xFF42a936);
const _secondaryVariantColor = Color(0xFF1f7818);

final lightTheme = ThemeData.from(
  colorScheme: const ColorScheme.light(
    primary: _primaryColor,
    primaryVariant: _primaryVariantColor,
    secondary: _secondaryColor,
    secondaryVariant: _secondaryVariantColor,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
  ),
).copyWith(
  typography: typography,
  toggleableActiveColor: _secondaryColor,
);

final darkTheme = ThemeData.from(
  colorScheme: const ColorScheme.dark(
    primary: _primaryColor,
    primaryVariant: _primaryVariantColor,
    secondary: _secondaryColor,
    secondaryVariant: _secondaryVariantColor,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
  ),
).copyWith(
  typography: typography,
  toggleableActiveColor: _secondaryColor,
);

class ExploTheme extends StatelessWidget {
  const ExploTheme({Key? key, this.themeMode, required this.child})
      : super(key: key);

  final ThemeMode? themeMode;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context)
        : themeMode == ThemeMode.dark
            ? Brightness.dark
            : Brightness.light;
    final themeData = brightness == Brightness.light ? lightTheme : darkTheme;

    return Theme(
      child: child,
      data: themeData,
    );
  }
}
