# Building CRN Typer

The app uses Swift, AppKit, Carbon hotkeys, and Quartz keyboard events. It has no third-party dependencies.

## On a Mac

Install Apple's Command Line Tools if needed, then run:

```sh
bash build-mac.sh
```

The script compiles Apple Silicon and Intel executables, combines them into one universal app, runs the non-typing self-test, applies a local ad-hoc signature, and packages the app with its README.

Output: `dist/CRN-Typer-Mac-Universal.zip`.

## GitHub Actions

Use **Actions → Build Mac App → Run workflow**. Changes to the app, packaging, instructions, or workflow also trigger a build.

Each build uploads a downloadable artifact for 30 days. Publishing a release is a separate action.

The workflow uses read-only repository contents permission. It requires no personal tokens or Apple signing credentials. The finished app is not Apple notarized.
