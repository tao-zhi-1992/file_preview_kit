import 'package:flutter/material.dart';

abstract final class FilePreviewKitTheme {
  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    ),
    useMaterial3: true,
  );
}
