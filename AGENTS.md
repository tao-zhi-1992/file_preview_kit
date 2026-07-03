# Repository Guidelines

- Write all code comments in English.
- Write all test names, fixture data, assertions, and test documentation in English.
- Never use real, production, personal, customer, or otherwise identifiable data in tests or fixtures.
- Use clearly fictional and anonymized test data.

## Testing

- Any change to parsers, models, or UI behavior must include tests in the same task.
- Do not mark work complete until `flutter test` passes.
- See [docs/testing.md](docs/testing.md) for layout and examples.

## Versioning

- Published vs in-development versions are tracked in [docs/release.md](docs/release.md).
- Record unreleased changes under `CHANGELOG.md` → `Unreleased` only.
- Do not edit released version sections in `CHANGELOG.md`.
- Check the latest git tag (if any) before assuming a version is already published.
