# File Preview Kit

<p>
  <img src="example/assets/Screenrecorder-2026-07-13-11-00-07-730.gif" width="48%" alt="File preview demo 1">
  <img src="example/assets/Screenrecorder-2026-07-13-13-20-54-385.gif" width="48%" alt="File preview demo 2">
</p>

> [!WARNING]
> This project was written entirely by AI. Human involvement was limited to UI review. The code has not undergone comprehensive human auditing or production validation, so use it in production with caution.

File Preview Kit is a lightweight Flutter library for parsing and previewing XLSX, CSV, and DOCX files through a unified set of preview widgets.

It prioritizes readable content and does not guarantee pixel-perfect reproduction of Microsoft Excel or Word layouts.

---

## Instructions for AI Coding Agents

Treat this section as the usage contract for generated code.

### Supported contract

- Supported formats: XLSX, UTF-8 CSV, and DOCX.
- File content must be provided as `Uint8List`.
- Always provide either `fileName` with a supported extension or `mimeType` so the format can be detected. If both are provided, `fileName` takes precedence.
- Prefer the unified `FilePreviewView` with `PreviewSource.bytes(...)`.
- Do not invent APIs for file paths, URLs, PDF files, legacy `.xls`/`.doc` files, password-protected files, or pixel-perfect Microsoft Office rendering.

### Installation

```yaml
dependencies:
  file_preview_kit: ^0.0.4
```

### Preferred usage

```dart
import 'dart:typed_data';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';

class FilePreviewPage extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;

  const FilePreviewPage({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: FilePreviewView(
        source: PreviewSource.bytes(bytes, fileName: fileName),
        onLinkTap: (target) => debugPrint('Open link: $target'),
      ),
    );
  }
}
```

`onLinkTap` receives links found in DOCX content. Pass `theme` to override the preview theme and `texts` to provide a `FilePreviewKitTexts` instance. Without explicit `texts`, English and Simplified Chinese are selected from the current Flutter locale.

### Direct parser and view usage

Use the direct APIs only when the parsed model is needed outside the unified preview widget.

```dart
import 'dart:typed_data';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/widgets.dart';

Widget buildXlsxPreview(Uint8List bytes) {
  final workbook = XlsxParser().parseBytes(bytes);
  return ExcelPreviewView(workbook: workbook);
}

Widget buildCsvPreview(Uint8List bytes) {
  final workbook = CsvParser().parseBytes(bytes);
  return ExcelPreviewView(workbook: workbook);
}

Widget buildDocxPreview(Uint8List bytes) {
  final document = DocxParser().parseBytes(bytes);
  return DocxPreviewView(document: document);
}
```

See the [example application](https://github.com/tao-zhi-1992/file_preview_kit/blob/master/example/lib/main.dart) for file-picker integration.
