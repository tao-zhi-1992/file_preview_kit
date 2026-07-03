# Release status

| | Version |
|---|---|
| Published (pub.dev / release branch) | 0.0.1 |
| In development (`pubspec.yaml`) | 0.0.2 |

Last published: 2026-07-03 (`af8c0cb` — chore: prepare package for initial publishing)

No git release tag yet. After publishing, run `git tag v0.0.1` (or the matching version) on the release commit.

## Release checklist

1. Move [CHANGELOG.md](../CHANGELOG.md) `Unreleased` entries into a dated version section (for example `## 0.0.2 - 2026-07-03`).
2. Confirm [pubspec.yaml](../pubspec.yaml) `version` matches the release.
3. Run `flutter test`.
4. Commit, tag (`git tag v0.0.2`), and push including tags.
5. Publish to pub.dev.
6. Add a new empty `## Unreleased` section at the top of CHANGELOG.
7. Update the table in this file and bump `pubspec.yaml` to the next development version if needed.
