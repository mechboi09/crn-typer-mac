# CRN Typer for Mac

A small Mac app that types your CRNs into Banner with a keyboard shortcut.

**[Download the current Mac build](https://github.com/mechboi09/crn-typer-mac/actions/runs/42483791351/artifacts/13618541301)**

This Actions download requires GitHub sign-in. A public release download is being prepared.

macOS 12 or later · Apple Silicon and Intel · No developer tools needed

## Get started

1. Download and extract the ZIP.
2. Move **CRN Typer.app** from the `package` folder to **Applications** and open it.
3. Fill an option with up to six CRNs and choose **Normal** or **Fast**.
4. Click the first empty CRN box on the registration page, then press **F1–F4** for that option. Some Mac keyboards need **Fn/Globe + F1–F4**.
5. Review the result in **Summary**.

Start with **one empty CRN field**. The app finishes at **Add to Summary**; it does not press the separate registration **Submit** button.

## Pick your pace

| Mode | Behavior |
| --- | --- |
| **Normal** | Waits 300 ms for Banner to create and focus the next CRN field. |
| **Fast** | Activates Add Another CRN itself, with 1 ms requested pauses. Actual speed depends on macOS and the browser. |

Fast mode can outrun a busy browser. Try the app on a practice form first. There is a small Easter egg when you select Fast.

## Keyboard permission

Allow **CRN Typer** in **System Settings → Privacy & Security → Accessibility**, then quit and reopen the app. On macOS 12, use **System Preferences → Security & Privacy → Privacy**.

The app is locally signed, but is not Apple Developer ID signed or notarized. macOS may require explicit approval before opening it.

## Stay in control

- **Escape** cancels an active run.
- Switching applications stops the run. Keep the same browser tab and field focused; changes inside one browser are not detected.
- Clear partially entered text before trying again. The app does not undo typing.
- CRNs stay in memory until the app closes. No network calls, credentials, analytics, or saved CRN lists.

This is an unofficial utility. It cannot inspect the active field or confirm whether a class was accepted.

## For developers

The source is in [`src/`](src). See [Building the app](docs/BUILDING.md) for local and GitHub build instructions. Builds check both CPU architectures, the typing sequence, and the local app signature. Interactive registration behavior still needs a Mac test.
