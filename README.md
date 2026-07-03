# File Preview Kit

!!Work in Progress ...

file_preview_kit is a lightweight Flutter file preview toolkit.

V1 focuses on XLSX, CSV, and DOCX preview:

- Parse .xlsx files
- Parse UTF-8 .csv files
- Parse .docx paragraphs, headings, lists, direct text formatting, alignment,
  tables, and inline PNG/JPEG images
- Restore readable DOCX styles including title hierarchy, font size and color,
  highlighting, paragraph spacing, nested lists, table widths, and merged cells
- Read sheets, rows and cells
- Preview spreadsheet data in Flutter
- Preview DOCX files as a continuous document without page layout
- Not intended to fully reproduce Microsoft Excel or Word layout

DOCX preview prioritizes complete, readable content over matching Word layout.
It does not currently support full style inheritance, headers, footers,
comments, footnotes, tracked changes, floating layout, or pagination.
