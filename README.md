# PDF Pair Viewer

A native, offline macOS app for reviewing a folder of single-page PDFs two at a time. Built with SwiftUI, AppKit, and PDFKit; no third-party packages, network access, or Git repository.

## Open and run

Open `PDFPairViewer.xcodeproj`, select the **PDFPairViewer** scheme, and run. Requires **macOS 26 or newer**. The project uses Swift 6 and an Xcode filesystem-synchronized project; use **Xcode 26 or newer**. Developed and tested with **Xcode 27.0 (27A266a), Swift 6.4**.

The default signing identity is **Sign to Run Locally** (`-`), with App Sandbox and user-selected read-only file access enabled. For distribution, choose your own bundle identifier, development team, and signing identity in Xcode. No team is required for the local build.

```sh
xcodebuild build -scheme PDFPairViewer -destination 'platform=macOS' -derivedDataPath build
xcodebuild test -scheme PDFPairViewer -destination 'platform=macOS' -derivedDataPath build
open build/Build/Products/Debug/PDFPairViewer.app
```

## Use

- **About PDF Pair Viewer** includes Support and Privacy Policy links beneath the version. The **Help** menu provides the same destinations. Links open in your default browser; the app itself remains offline.

- Click the toolbar folder button (⌘O), use **Choose Folder…** in the empty state, or drop exactly one folder anywhere on the window.
- Use **File → Open Folder by Path…** (⇧⌘O), or right-click the folder button, to enter an absolute path (including `~/…`). Press Return or **Open** to load it; **Browse…** opens the native picker instead.
- If a typed/dropped folder needs authorization, the system picker opens there. Select that same folder to grant access. Canceling keeps the existing folder unchanged.
- Only immediate regular files with a `.pdf` extension, ignoring case, are considered. Symbolic links, subfolders, unreadable/invalid PDFs, locked PDFs, and documents with anything other than one page are excluded.
- Filenames use macOS localized natural sorting, then literal full-filename comparison to resolve ties.
- Use the toolbar **Down** control for the next disjoint pair and **Up** to go back, or press the corresponding arrow keys. The folder name and pair count appear beside the native window controls. Navigation clamps at either end. Held-key repeats are ignored. Arrow keys retain normal behavior while editing a path or using the picker.
- The **Go** menu also provides **Previous Pair** (↑) and **Next Pair** (↓), disabled at the corresponding ends of the folder.
- The viewer follows macOS light/dark appearance, with a light gray or charcoal canvas and native macOS 26 Liquid Glass toolbar controls and filename badges. PDF page colors are unchanged. The badges float over the PDFs without reserving a header strip; the viewer adds no page padding or shadows. Whole-page fitting preserves page proportions, so unused canvas may remain when pane and page aspect ratios differ. Whitespace inside the PDF is unchanged. Hover over a PDF pane or folder title for its full path. An information/warning button appears when files were skipped or folder access could not be saved; click it for details. Selection and scan errors remain visible above the documents.
- Both pages fit their panes on resize. Zooming out stops at the whole-page fitted size (100% of the pane's fit); zooming in remains available. An odd final document leaves the right pane empty. If a file becomes unavailable after scanning, its pane reports an error and navigation still works.
- Zooming or scrolling either PDF also updates the other pane. Zoom is relative to each pane's whole-page fit, and the visible center is matched by its relative position on the page; page edges can limit scrolling when document proportions differ.
- Use the zoom toolbar group before the Up/Down controls, or **View → Zoom Out / Default Zoom / Zoom In**. Shortcuts are **⌘−**, **⌘0**, and **⌘+**. Default Zoom restores both panes to whole-page fit.
- The last successfully loaded folder is saved as an app-scoped security-scoped bookmark. Relaunch rescans it at the first pair. Bookmark failures do not prevent viewing; use Browse to reauthorize lost access.
- Selecting a different folder resets to its first pair. Rescanning the same folder preserves the pair when possible and clamps after deletions. A failed scan preserves the currently loaded folder.

## Structure

Source files are grouped by responsibility under `PDFPairViewer/`:

- `Views/`: SwiftUI screens and shared viewer colors; `Views/PDFKit/` contains the PDFKit bridge, fitting view, and viewport synchronization.
- `ViewModels/`: observable pair selection and loading state.
- `Models/`: PDF entries, catalog results, displayed documents, folder access sessions, and selection errors.
- `Services/`: folder authorization/persistence and PDF catalog scanning.
- `Commands/`: File, View, and Go menu commands and their scene-focused actions.

The app entry point and signing entitlements remain at the source root. Xcode's filesystem-synchronized group discovers the nested source files automatically.

Three main SwiftUI views (`ContentView`, `FolderPickerView`, `PDFPairView`), a scene-focused folder-path command, and one PDFKit bridge (`PDFKitViewRepresentable`). The bridge owns the window-scoped keyboard route and clears PDFKit references before releasing access. Its AppKit subclass keeps pages fitted. Path-sheet dismissal completes before launching a picker or authorization request.

`PDFPairViewModel` is main-actor isolated. Catalog validation runs sequentially in a cancellable detached task, inside per-document autorelease pools. Only the visible pair has main-actor display documents. Access sessions are retained independently by scans and display documents; replacement or closing the window cannot revoke access underneath an outstanding reader. Request IDs prevent obsolete scans from updating the UI.

`FolderAccessService` manages authorization, bookmark restoration/refresh, and balanced security-scope access. `PDFCatalog` returns only lightweight URLs and skip counts across the actor boundary. Comparison, image diff, and OCR are deliberately not implemented.

## Verification

The XCTest target generates local PDF fixtures. It covers natural ordering and literal ties, mixed/empty folders, uppercase extensions, invalid/locked/multipage PDFs, ignored nested files and links, enumeration failure, pair bounds, odd/single/empty catalogs, missing display files, folder replacement, bookmark round-trip and invalid bookmark recovery, late scans, and window-close cancellation.

System UI and actual permission grants need these **manual checks on a signed, sandboxed build**; automated tests are not a substitute:

- Open **About PDF Pair Viewer** and check the centered Support and Privacy Policy links in Light and Dark appearances. Verify both open the correct pages in the default browser. Check Help-menu links, including with all viewer windows closed, keyboard navigation, and VoiceOver.

- Browse, typed path outside the sandbox, and Finder folder drop all load the intended folder. Mismatched authorization and a dropped file show feedback; picker cancellation preserves the old pair.
- Click each PDF pane, then use Up/Down. Try holding Down, modified arrows, editing a path, and arrow navigation within the picker.
- Resize the window with differently sized/oriented pages and navigate from a full pair to an odd last pair.
- Switch macOS between Light and Dark while PDFs are zoomed and scrolled. Confirm both canvas backgrounds and the toolbar update without resetting zoom, scrolling, or the selected pair. Check empty, loading, missing-PDF, and error states, sheets, popovers, and filename badges in both appearances, including with Increase Contrast enabled.
- Relaunch with a saved external folder; then move/delete/revoke that folder and check reselection feedback. Exercise a stale but resolvable bookmark and confirm refresh.
- Change folders rapidly during a large scan and close the window during a scan. Confirm no obsolete results appear and reopen works.
- Check toolbar focus followed by Up/Down, ⇧⌘O path entry and cancellation, and status popovers. Confirm glass filename badges overlay the PDFs without reserving space and allow selection/scrolling through them. Verify whole-page fitting for portrait and landscape pages, including after zooming and changing pairs. Check fullscreen, inactive windows, Reduce Transparency, Increase Contrast, and VoiceOver labels.

Build output goes in `build/`. No Git initialization is performed.

Verification on Xcode 27.0: **11 XCTest tests passed** and the local signed Debug build succeeded. The normal app's signing entitlements were checked: sandbox, user-selected read-only access, and app-scoped bookmarks, with no network or broad file-access entitlement. Xcode temporarily adds test-runner access exceptions to its test host; run the regular build command again after tests before manual sandbox verification. The interactive checklist above remains to be verified manually.
