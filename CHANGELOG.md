## 0.0.1

- Initial release of file_preview_kit.
- Preview view for multiple file types (Excel, Word, PDF, etc.).
- Excel support: parse .xlsx files, display sheets in a scrollable table with cell selection and column/row resizing.
- CSV support: parse UTF-8 .csv files with the same table preview.
- Customizable texts and theming via `FilePreviewKitTexts` and `FilePreviewKitTheme`.
- Error and loading states for previews.
- Support for previewing from local file, bytes, or URL via `PreviewSource`.
- Expanded DOCX parsing based on Mammoth semantics, including relationship-based
  part discovery, inline links, bookmarks, checkboxes, notes, comments, text
  boxes, tracked changes, richer styles, numbering, and legacy images.
- Corrected DOCX point-to-pixel font sizing and style inheritance, restored
  first-line/list indentation, and ignored unresolved numbering definitions.
