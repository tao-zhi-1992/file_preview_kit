import 'package:flutter/material.dart';

import '../models/excel_workbook.dart';
import 'excel_grid_view.dart';

class ExcelPreviewView extends StatelessWidget {
  final ExcelWorkbook workbook;

  const ExcelPreviewView({super.key, required this.workbook});

  @override
  Widget build(BuildContext context) {
    if (workbook.sheets.isEmpty) {
      return const Center(child: Text('No sheets found'));
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
                  ExcelGridView(sheet: sheet),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
