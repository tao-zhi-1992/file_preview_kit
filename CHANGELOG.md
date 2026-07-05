## Unreleased

- XLSX cell styles including fonts, fills, borders, alignment, wrap text, underline, and strikethrough.
- XLSX number and date formatting via `numFmt`.
- XLSX column widths loaded from workbook metadata.
- XLSX merged cell rendering in the grid.
- Added `FilePreviewLoader` and `PreviewContent` for type detection and parsing outside widgets.
- Changed: internal readability refactor across Excel grid, preview tabs, file preview loader, DOCX views, and parsers (no breaking API changes).

## 0.0.1

- Initial release of file_preview_kit.
- XLSX preview with multiple sheets, cell selection, and resizable rows and columns.
- UTF-8 CSV preview using the spreadsheet grid.
- Continuous DOCX preview with paragraphs, headings, lists, text styles, tables,
  images, links, bookmarks, checkboxes, tracked insertions, notes, comments, and
  text boxes.
- Unified byte-based preview widget with file name and MIME type detection.
- Loading, error, and unsupported-file states.
- Customizable themes and localized UI text.
