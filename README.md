<p align="center">
  <img src="AppIcon-256.png" width="128" alt="PDF Equalizer icon">
</p>
<h1 align="center">PDF Equalizer</h1>
<p align="center">
  <strong>A lightweight macOS app that equalizes all pages of a PDF to the same width.</strong><br>
  Lossless media box adjustment &middot; Drag &amp; drop &middot; Universal Binary (arm64 + x86_64)
</p>
<p align="center">
  <img src="https://img.shields.io/badge/macOS-12%2B-blue" alt="macOS 12+">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

Pages are adjusted by modifying the page media box — no re-rendering or quality loss. Useful when scanned documents or merged PDFs have inconsistent page sizes.

<p align="center">
  <img src="Screenshot.png" width="720" alt="PDF Equalizer main window">
</p>

## Features

- **Drag & drop** a PDF onto the window or the Dock icon
- **Equalizes all pages** to match the widest page in the document
- **Replace original file** option to overwrite the source PDF directly
- Outputs a new file with `_equalized` suffix by default

## Download

Download the latest universal binary (Apple Silicon + Intel) from the [Releases](../../releases) page.

### Opening the app (unsigned)

Since the app is not signed with an Apple Developer certificate, macOS will block it on first launch. To open it:

1. **Right-click** (or Control-click) on `PDF Equalizer.app`
2. Select **Open** from the context menu
3. Click **Open** in the dialog that appears

You only need to do this once. After that, the app will open normally.

Alternatively, you can remove the quarantine attribute via Terminal:

```bash
xattr -d com.apple.quarantine "PDF Equalizer.app"
```

## Build from source

Requires **Xcode Command Line Tools** on macOS 12.0 or later.

```bash
# Debug build (current architecture)
./build.sh

# Universal binary (Apple Silicon + Intel)
./build-universal.sh
```

The built app will be in `build/` or `build-universal/universal/`.

## License

MIT
