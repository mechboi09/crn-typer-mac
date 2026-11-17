# CRN typer for Mac

**Mac update not yet available:** GitHub could not assign a Mac runner to build the latest source. The new download will be linked once the app is built.

The finished download contains only **CRN typer.app** in a ZIP; all instructions are here. macOS apps are bundles, so a ZIP is needed to distribute the app correctly. An EXE is Windows-only.

## Use

1. Download and extract **CRN typer.zip**, move **CRN typer.app** to Applications, then open it.
2. Enter up to **seven CRNs per option**. F1–F4 select the four columns; some keyboards need **Fn/Globe + F1–F4**.
3. Focus the first empty CRN box in your browser, then press the corresponding shortcut and release it.
4. Review Summary. The app ends at **Add to Summary**, with a final Tab, Tab, Enter; the separate Submit button remains manual.

## Editing and speed

- Compact four-column layout, digits only, with leading zeros preserved.
- Paste a list into a box to distribute it downward in that option. Commas and whitespace separate CRNs. Invalid or duplicate pasted lists are rejected.
- **Command+A** (or **Control+A**) once selects the current CRN; twice within 0.7 seconds selects that column's numbers.
- Copy/Cut/Paste and Delete/Backspace apply to the selected column. Clearing returns to its first box.
- No autosave or settings files. Closing the app discards the CRNs.
- The black **Normal/Fast toggle** starts in Fast. Normal uses **200 ms** between entries; Fast uses **1 ms** and activates Add Another CRN using Tab + Enter. Actual timing varies. **Tips** opens the notes.

## First-time Mac setup

The app is locally signed, but is not Apple Developer ID signed or notarized. macOS may say Apple cannot verify it is free of malicious software. Proceed only if you trust your downloaded file.

1. Move the app to Applications and try opening it once.
2. Open **System Settings → Privacy & Security**, find the blocked-app notice under Security, and choose **Open Anyway**.
3. Confirm Open and enter your Mac login password on the Mac if prompted. [Apple's instructions](https://support.apple.com/en-us/102445)
4. In **Privacy & Security → Accessibility**, enable **CRN typer**. Add it using **+** if needed, then quit and reopen the app. On macOS 12 use System Preferences → Security & Privacy → Privacy → Accessibility.

Close older typer apps before running this one. Escape cancels; switching applications stops a run. Changes of browser tab or field are not detected. The app cannot verify page results. 

## Building

The [build script](build-mac.sh) compiles **Intel and Apple Silicon**, runs non-typing sequence checks, verifies both architectures and a local signature, then packages the app without a README. The workflow uses the standard Intel Mac runner to avoid the Apple Silicon capacity failure encountered by earlier builds. Repository permissions remain read-only.

[Windows direct EXE](https://github.com/mechboi09/crn-typer-windows/raw/refs/heads/main/download/CRN%20typer.exe)