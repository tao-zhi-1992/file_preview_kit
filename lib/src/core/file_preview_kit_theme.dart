import 'package:flutter/material.dart';

/// Built-in themes for preview widgets.
abstract final class FilePreviewKitTheme {
  /// Default light Material theme.
  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    ),
    useMaterial3: true,
  );
}
