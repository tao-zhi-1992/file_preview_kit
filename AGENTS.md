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

## Flutter/Dart Readability Constraints (agent-focused)

### Common Pitfalls

- **No deep nesting in build()**: more than 3 levels (e.g. Padding→Column→Row→Container) must be extracted into a separate Widget class — not a private method. Only a separate class can use a `const` constructor and benefit from localized rebuilds.
- **No business logic inside build()**: network calls, data processing, and complex computation belong in the state management layer (Provider/Riverpod/BLoC/Controller). build() should only render.
- **No "god widgets"**: a widget that handles layout + state + business logic + networking all at once must be split up.
- **Use named parameters when a constructor has more than 2-3 params**; mark required fields explicitly with `required`. No stacking positional parameters.
- **No unannotated `!` (null assertion)**: unexplained force-unwraps hide potential null bugs and leave readers unable to tell if it's a verified guarantee or just laziness.
- **No bare `dynamic`**: use concrete types or generics, except for genuine cases like parsing unknown JSON structures.
- **Use `const` constructors wherever possible**: this is both a performance constraint and a readability signal — it tells the reader this part of the UI is static and doesn't need to be reasoned about as changeable.

### Tooling Enforcement (to reduce manual review burden)

- Use `flutter_lints`; enforce formatting with `dart format` instead of relitigating style in review.
