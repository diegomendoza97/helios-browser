# CEF (Chromium Embedded Framework) Integration

This guide walks you through adding Chromium’s engine to Helios so the browser uses CEF instead of WebKit.

**Without CEF:** The app builds and runs using WebKit (Safari’s engine). You do not need to do anything for that.

**With CEF:** Follow the steps below, then add the **USE_CEF** compilation condition and link the CEF framework. The same UI will then use Chromium under the hood.

---

## Why you need the CEF build (and how shipping works)

**You need the CEF build only to *develop and build* the app.** It is not something end users install.

- **What the “CEF build” is:** A pre-compiled Chromium engine (framework + resources + Helper app). Building Chromium from source is huge (hours, hundreds of GB), so CEF provides these binaries so you can link against them.
- **What you do with it:** You add the CEF framework and Helper app to your Xcode project and **embed them inside your app bundle**. When you build “helios-browser.app”, that single `.app` contains:
  - Your code
  - `Chromium Embedded Framework.framework`
  - `helios-browser Helper.app` (CEF’s subprocess)
  - All CEF resources (e.g. `.pak` files) that the framework needs

**Shipping to users:**

- You ship **one app** (e.g. helios-browser.app in a .dmg or via the Mac App Store). Users download and run it like any other Mac app.
- They **do not** install CEF or Chromium separately. Everything is inside your app bundle; the app is self-contained.
- **Downside:** The app is much larger (often **200–400+ MB** or more) because it includes a full Chromium build. That’s the tradeoff for using Chrome’s engine instead of WebKit.
- **Code signing & notarization:** Sign and notarize your app (and the embedded framework + Helper) as you would for any Mac app. Apple’s docs and CEF’s distribution notes cover signing the Helper and nested bundles.

So: you “install” the CEF build once on your dev machine to build the app; when you ship, users only get your single app with Chromium embedded inside it.

---

## 1. Download CEF binaries

1. Open **[CEF Automated Builds](https://cef-builds.spotifycdn.com/index.html)**.
2. Pick a **macOS** build:
   - **Apple Silicon (M1/M2/M3):** choose a build with `macosarm64` in the name.
   - **Intel:** choose `macosx64`.
3. Download the **Standard Distribution** (e.g. `cef_binary_xxx_macosarm64.tar.bz2`).
4. Extract the archive. You should get a folder like `cef_binary_132.3.1+g64b6a2e+chromium-132.0.0.0_macosarm64`.

## 2. Place CEF in the project

1. In the repo root, create a folder for CEF (e.g. `ThirdParty`).
2. Move the extracted folder into it and rename it to something simple, e.g.:
   - `helios-browser/ThirdParty/cef/`
3. Inside that folder you should see:
   - `Release/` (or `Debug/`) – contains `Chromium Embedded Framework.framework`
   - `Resources/` – CEF resources
   - Helper app (e.g. in `Release/` or a dedicated folder) – **required for subprocess**

Check the CEF `README.txt` in the distribution for the exact layout and the Helper app name/location.

## 3. Xcode project setup

### 3.1 Link the CEF framework

1. Select the **helios-browser** target → **General** → **Frameworks, Libraries, and Embedded Content**.
2. Click **+** → **Add Other…** → **Add Files…**.
3. Navigate to `ThirdParty/cef/Release/` and select **Chromium Embedded Framework.framework** (or the path from your build).
4. Set it to **Embed & Sign** (or **Embed Without Signing** for local dev).

### 3.2 Framework search path

1. Target → **Build Settings** → search for **Framework Search Paths**.
2. Add:
   - `$(PROJECT_DIR)/ThirdParty/cef/Release`  
   (or your actual path to the folder that contains `Chromium Embedded Framework.framework`).

### 3.3 Header search path (for CEF C++ bridge)

1. **Build Settings** → **Header Search Paths**.
2. Add:
   - `$(PROJECT_DIR)/ThirdParty/cef/Release/Chromium Embedded Framework.framework/Headers`  
   so that `#include "include/cef_*.h"` resolves.

### 3.4 Embed the Helper app (required on macOS)

CEF uses a separate Helper process. You must ship it inside your app bundle.

1. In the CEF distribution, locate the **Helper app** (e.g. `cefsimple Helper.app` or similar; see CEF `README.txt`).
2. Copy it into your app’s **Frameworks** folder in the bundle.
3. Rename it so the main app’s name matches. For **helios-browser** the Helper should be:
   - `helios-browser.app/Contents/Frameworks/helios-browser Helper.app`
4. In Xcode, add the Helper app to the target and add a **Copy Files** build phase:
   - **Destination:** Frameworks
   - Add the Helper app so it ends up at `Contents/Frameworks/helios-browser Helper.app`.

(Exact Helper name and paths are in the CEF distribution docs; adjust if your build layout differs.)

### 3.5 Enable CEF in the app

1. **Build Settings** → **Swift Compiler - Custom Flags** → **Active Compilation Conditions** (or **Other Swift Flags**).
2. Add: `USE_CEF`  
   So the app uses the CEF UI path and the CEF bridge code.

### 3.6 Bridging header

1. The project includes **helios-browser/helios-browser-Bridging-Header.h** (it imports `CEF/CEFBridge.h`).
2. In **Build Settings** → **Objective-C Bridging Header**, set:
   - `helios-browser/helios-browser-Bridging-Header.h`

## 4. Build and run

1. Clean build folder (Product → Clean Build Folder).
2. Build and run.

If you see crashes or “Helper”/subprocess errors, double-check:

- Framework search path and that the CEF framework is embedded.
- Helper app is present at `Contents/Frameworks/helios-browser Helper.app` (or the name CEF expects).
- CEF initialization runs once at app launch (see `HeliosCEFAppDelegate` and `HeliosCEFInitialize()`).

## 5. Switching back to WebKit

To use WebKit again:

1. Remove the **USE_CEF** compilation condition.
2. Rebuild; the app will use the existing WKWebView-based UI.

## References

- [CEF Project](https://github.com/chromiumembedded/cef-project) – sample project and build instructions
- [CEF Tutorial](https://chromiumembedded.github.io/cef/tutorial) – minimal app structure
- [CEF Automated Builds](https://cef-builds.spotifycdn.com/index.html) – prebuilt binaries
