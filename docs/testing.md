# Testing

Behavior changes under `lib/` need tests in the same change. Run `flutter test` before finishing.

## Where to put tests

| Change | Test file |
|--------|-----------|
| Parser / reader | `test/*_parser_test.dart` or `test/*_reader_test.dart` |
| Model | `test/*_models_test.dart` or the matching domain test |
| Widget | `test/*_test.dart` with `testWidgets` |

## Fixtures

- Use fictional data only.
- Prefer inline XML / zip builders when a binary fixture is not needed.
- Follow patterns in `test/xlsx_parser_error_test.dart` and `test/docx_parser_test.dart`.

## Examples in this repo

- `test/styles_reader_test.dart` — unit test for a parser helper
- `test/xlsx_styles_parser_test.dart` — parser integration test
- `test/excel_grid_style_test.dart` — widget rendering test

## Done checklist

- [ ] Tests added or updated for the behavior change
- [ ] `flutter test` passes
