#!/bin/sh
set -eu

CEF_SOURCE="${PROJECT_DIR}/Frameworks/Chromium Embedded Framework.framework"
CEF_DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Chromium Embedded Framework.framework"

rm -rf "${CEF_DEST}"
mkdir -p "${CEF_DEST}/Versions/A/Resources"

cp "${CEF_SOURCE}/Chromium Embedded Framework" "${CEF_DEST}/Versions/A/Chromium Embedded Framework"
rsync -a "${CEF_SOURCE}/Resources/" "${CEF_DEST}/Versions/A/Resources/"
if [ -d "${CEF_SOURCE}/Libraries" ]; then
    rsync -a "${CEF_SOURCE}/Libraries/" "${CEF_DEST}/Versions/A/Libraries/"
fi
cp "${CEF_SOURCE}/Resources/Info.plist" "${CEF_DEST}/Versions/A/Resources/Info.plist"

ln -sf A "${CEF_DEST}/Versions/Current"
ln -sf "Versions/Current/Chromium Embedded Framework" "${CEF_DEST}/Chromium Embedded Framework"
ln -sf Versions/Current/Resources "${CEF_DEST}/Resources"
if [ -d "${CEF_DEST}/Versions/A/Libraries" ]; then
    ln -sf Versions/Current/Libraries "${CEF_DEST}/Libraries"
fi

# Wrap the Helper binary into a proper .app bundle
HELPER_SRC="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/helios-browser Helper"
HELPER_APP="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/helios-browser Helper.app"
if [ -f "${HELPER_SRC}" ]; then
    rm -rf "${HELPER_APP}"
    mkdir -p "${HELPER_APP}/Contents/MacOS"
    mv "${HELPER_SRC}" "${HELPER_APP}/Contents/MacOS/helios-browser Helper"
    cp "${PROJECT_DIR}/helios-browser Helper/HelperInfo.plist" "${HELPER_APP}/Contents/Info.plist"

    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable 'helios-browser Helper'" "${HELPER_APP}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.dmendoza.helios-browser.helper" "${HELPER_APP}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName 'helios-browser Helper'" "${HELPER_APP}/Contents/Info.plist"
fi

# CEF on macOS expects helper variants for specific process roles.
# Build variant bundles from the base Helper app.
make_helper_variant() {
    VARIANT_SUFFIX="$1"   # e.g. "Renderer", "GPU", "Plugin"
    VARIANT_SUFFIX_LC="$(printf "%s" "${VARIANT_SUFFIX}" | tr '[:upper:]' '[:lower:]')"
    VARIANT_NAME="helios-browser Helper (${VARIANT_SUFFIX})"
    VARIANT_APP="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/${VARIANT_NAME}.app"
    VARIANT_EXE="${VARIANT_APP}/Contents/MacOS/${VARIANT_NAME}"
    BASE_EXE="${HELPER_APP}/Contents/MacOS/helios-browser Helper"

    rm -rf "${VARIANT_APP}"
    cp -R "${HELPER_APP}" "${VARIANT_APP}"
    cp "${BASE_EXE}" "${VARIANT_EXE}"

    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable '${VARIANT_NAME}'" "${VARIANT_APP}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.dmendoza.helios-browser.helper.${VARIANT_SUFFIX_LC}" "${VARIANT_APP}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName '${VARIANT_NAME}'" "${VARIANT_APP}/Contents/Info.plist"
}

if [ -d "${HELPER_APP}" ]; then
    make_helper_variant "Renderer"
    make_helper_variant "GPU"
    make_helper_variant "Plugin"
fi

SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "${SIGN_IDENTITY}" ]; then
    SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
fi
if [ -z "${SIGN_IDENTITY}" ]; then
    SIGN_IDENTITY="-"
fi

if [ -d "${CEF_DEST}/Versions/A/Libraries" ]; then
    find "${CEF_DEST}/Versions/A/Libraries" -type f \( -name "*.dylib" -o -name "*.so" \) -print0 | while IFS= read -r -d '' lib; do
        codesign --force --timestamp=none --sign "${SIGN_IDENTITY}" "${lib}"
    done
fi

if [ -f "${CEF_DEST}/Versions/A/Chromium Embedded Framework" ]; then
    codesign --force --timestamp=none --sign "${SIGN_IDENTITY}" "${CEF_DEST}/Versions/A/Chromium Embedded Framework"
fi
codesign --force --deep --timestamp=none --sign "${SIGN_IDENTITY}" "${CEF_DEST}"
if [ -d "${HELPER_APP}" ]; then
    codesign --force --deep --timestamp=none --sign "${SIGN_IDENTITY}" "${HELPER_APP}"
    codesign --force --deep --timestamp=none --sign "${SIGN_IDENTITY}" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/helios-browser Helper (Renderer).app"
    codesign --force --deep --timestamp=none --sign "${SIGN_IDENTITY}" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/helios-browser Helper (GPU).app"
    codesign --force --deep --timestamp=none --sign "${SIGN_IDENTITY}" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/helios-browser Helper (Plugin).app"
fi
