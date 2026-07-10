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
      child: _ExcelPreviewContent(workbook: workbook, texts: texts),
    );
  }
}

class _ExcelPreviewContent extends StatelessWidget {
  final ExcelWorkbook workbook;
  final FilePreviewKitTexts? texts;

  const _ExcelPreviewContent({required this.workbook, required this.texts});

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
    final animation = controller.animation ?? kAlwaysCompleteAnimation;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final selectedIndex = animation.value.round();

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTabDot(
          dotKey: dotKey,
          selected: selected,
          primaryColor: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _SheetTabLabel(
          label: label,
          selected: selected,
          normalStyle: normalStyle,
          selectedStyle: selectedStyle,
        ),
      ],
    );
  }
}

class _SheetTabDot extends StatelessWidget {
  final Key dotKey;
  final bool selected;
  final Color primaryColor;

  const _SheetTabDot({
    required this.dotKey,
    required this.selected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: dotKey,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: selected ? primaryColor : Colors.transparent,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SheetTabLabel extends StatefulWidget {
  final String label;
  final bool selected;
  final TextStyle normalStyle;
  final TextStyle selectedStyle;

  const _SheetTabLabel({
    required this.label,
    required this.selected,
    required this.normalStyle,
    required this.selectedStyle,
  });

  @override
  State<_SheetTabLabel> createState() => _SheetTabLabelState();
}

class _SheetTabLabelState extends State<_SheetTabLabel> {
  late double _labelWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _labelWidth = _measureLabelWidth();
  }

  @override
  void didUpdateWidget(covariant _SheetTabLabel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.label != widget.label ||
        oldWidget.selectedStyle != widget.selectedStyle) {
      _labelWidth = _measureLabelWidth();
    }
  }

  double _measureLabelWidth() {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.label, style: widget.selectedStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final width = textPainter.width;
    textPainter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _labelWidth,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        style: widget.selected ? widget.selectedStyle : widget.normalStyle,
        child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
