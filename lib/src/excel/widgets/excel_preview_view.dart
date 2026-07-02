import 'package:flutter/material.dart';

import '../../core/file_preview_kit_texts.dart';
import '../models/excel_workbook.dart';
import 'excel_grid_view.dart';

class ExcelPreviewView extends StatelessWidget {
  final ExcelWorkbook workbook;
  final FilePreviewKitTexts? texts;

  const ExcelPreviewView({super.key, required this.workbook, this.texts});

  @override
  Widget build(BuildContext context) {
    final resolvedTexts =
        texts ?? FilePreviewKitTexts.resolve(Localizations.localeOf(context));

    if (workbook.sheets.isEmpty) {
      return Center(child: Text(resolvedTexts.noSheetsFound));
    }

    return DefaultTabController(
      length: workbook.sheets.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                for (final sheet in workbook.sheets) Tab(text: sheet.name),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final sheet in workbook.sheets)
                  ExcelGridView(sheet: sheet, texts: resolvedTexts),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
