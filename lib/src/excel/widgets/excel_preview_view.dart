import 'package:flutter/material.dart';

import '../../core/file_preview_kit_theme.dart';
import '../../core/file_preview_kit_texts.dart';
import '../models/excel_workbook.dart';
import 'excel_grid_view.dart';

/// Displays workbook sheets in an interactive spreadsheet grid.
class ExcelPreviewView extends StatelessWidget {
  /// Workbook to display.
  final ExcelWorkbook workbook;

  /// Optional user-facing text overrides.
  final FilePreviewKitTexts? texts;

  /// Optional theme applied within the preview.
  final ThemeData? theme;

  /// Creates a workbook preview.
  const ExcelPreviewView({
    super.key,
    required this.workbook,
    this.texts,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme ?? FilePreviewKitTheme.light,
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
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
            child: _SheetTabBar(
              labels: [for (final sheet in workbook.sheets) sheet.name],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
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

class _SheetTabBar extends StatelessWidget {
  final List<String> labels;

  const _SheetTabBar({required this.labels});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final selectedIndex = controller.animation!.value.round();

        return TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: const BoxDecoration(),
          tabs: [
            for (var index = 0; index < labels.length; index++)
              Tab(
                child: _SheetTab(
                  key: ValueKey('sheet-tab-$index'),
                  label: labels[index],
                  selected: index == selectedIndex,
                  dotKey: ValueKey('sheet-tab-dot-$index'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SheetTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Key dotKey;

  const _SheetTab({
    super.key,
    required this.label,
    required this.selected,
    required this.dotKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalStyle = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: theme.colorScheme.onSurfaceVariant);
    final selectedStyle = normalStyle.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: selectedStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelWidth = textPainter.width;
    textPainter.dispose();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          key: dotKey,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: labelWidth,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: selected ? selectedStyle : normalStyle,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}
