CRN TYPER — GITHUB MAC BUILD

This folder is a GitHub project, not the finished Mac app.
GitHub Actions will compile a universal macOS app and provide its ZIP.
You do not need Xcode or Command Line Tools on your own Mac.

IF YOUR GITHUB ACCOUNT IS CONNECTED IN THIS CHAT

Ask the assistant to publish these files to a repository and run the workflow.
The assistant can then follow the build and fetch its download, subject to
the connected GitHub tools' available permissions.

MANUAL SETUP IF NEEDED

1. Create a GitHub repository named crn-typer-mac (private is fine).
2. Put the CONTENTS of this folder at the repository root, including .github.
   Do not upload the ZIP itself or nest this folder inside another folder.
3. Commit the files. The source upload triggers the first build automatically.
4. Open Actions > Build Mac App and select the latest run.
   For a later build, select Run workflow on the default branch.
5. After the build passes, open its Artifacts section and download
   CRN-Typer-Mac-Universal.
6. Extract the downloaded artifact, then extract the app ZIP inside it.
   The finished download contains CRN Typer.app and a separate README.

The .github folder is hidden on some computers. On a Mac use Command+Shift+.
to show hidden files. If uploading through GitHub's website does not include
it, create .github/workflows/build-mac.yml using GitHub's Add file command
and copy the included workflow text exactly. Keep src/ and build-mac.sh at
the repository root.

BUILD DETAILS

- macos-15 runner, maximum job time 15 minutes.
- One universal executable: arm64 (Apple Silicon) and x86_64 (Intel).
- macOS 12 minimum target.
- Automatic mode, fixed 300 ms pauses, F1–F4 options, Escape cancellation.
- Read-only repository permissions; no signing secrets or account tokens.
- Finished app ZIP preserved as an Actions artifact for 30 days.
- No public release is created by the workflow.
- Local ad-hoc signature only; not Apple Developer ID signed or notarized.

GitHub plan limits and runner availability apply. Private-repository Actions
usage can count against your included minutes; review your account's usage
settings before running. This workflow does not change billing settings.

CURRENT VERIFICATION LIMIT

The project was prepared on Windows. The app is not considered compiled or
tested on macOS until the GitHub workflow finishes successfully. The workflow
runs non-typing sequence checks; interactive browser behavior needs a Mac test.

Official GitHub references:
https://docs.github.com/en/actions/reference/runners/github-hosted-runners
https://docs.github.com/en/actions/tutorials/store-and-share-data
