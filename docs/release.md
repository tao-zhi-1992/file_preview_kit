# Release status

| | Version |
|---|---|
| Published (pub.dev / release branch) | 0.0.2 |
| In development (`pubspec.yaml`) | 0.0.4 |

Last published: 2026-07-10 (0.0.2)

No git release tag yet for 0.0.4. After publishing, run `git tag v0.0.4` on the release commit.

## Release checklist

1. Move any draft notes into a version section in [CHANGELOG.md](../CHANGELOG.md) (for example `## 0.0.4`). Do not leave an empty `## Unreleased` heading — pub.dev surfaces it.
2. Confirm [pubspec.yaml](../pubspec.yaml) `version` matches the release.
3. Run `flutter test`.
4. Commit, tag (`git tag v0.0.4`), and push including tags.
5. Publish to pub.dev.
6. Update the table in this file and bump `pubspec.yaml` to the next development version if needed.
