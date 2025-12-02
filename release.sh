#!/bin/bash

# Tunes4R Release Script

echo "🚀 Starting Tunes4R Release Build..."

# Clean everything
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Generate app icons
echo "🎨 Generating app icons..."
flutter pub run flutter_launcher_icons:main

# Build for Android
echo "📱 Building Android APK..."
flutter build apk --release

# Get version from pubspec.yaml
VERSION=$(grep -E '^version:' pubspec.yaml | sed 's/version: *//;s/\+.*//')
echo "📋 Release version: $VERSION"

# Create release directory
RELEASE_DIR="tunes4r-release-$VERSION"
mkdir -p "$RELEASE_DIR"

# Copy Android build
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "$RELEASE_DIR/tunes4r-android-$VERSION.apk"
    echo "✅ Android APK: $RELEASE_DIR/tunes4r-android-$VERSION.apk"
fi

# Build for iOS, macOS and Windows (if on macOS)
if [ "$(uname)" == "Darwin" ]; then
    # Build for iOS
    echo "🍎 Building iOS..."
    flutter build ios --release --no-codesign
    if [ -d "build/ios/iphoneos" ]; then
        zip -r "$RELEASE_DIR/tunes4r-ios-$VERSION.app.zip" "build/ios/iphoneos/Runner.app"
        echo "✅ iOS App: $RELEASE_DIR/tunes4r-ios-$VERSION.app.zip"
    fi

    # Build for macOS
    echo "🍎 Building macOS app..."
    flutter build macos --release

    # Create DMG
    echo "📦 Creating macOS DMG..."
    if [ -d "build/macos/Build/Products/Release/tunes4r.app" ]; then
        create-dmg "tunes4r.dmg" "build/macos/Build/Products/Release/tunes4r.app"
        mv "tunes4r.dmg" "$RELEASE_DIR/tunes4r-macos-$VERSION.dmg"
        echo "✅ macOS DMG: $RELEASE_DIR/tunes4r-macos-$VERSION.dmg"
    fi

    # Build for Windows
    echo "🪟 Building Windows app..."
    flutter build windows --release
    if [ -d "build/windows/x64/runner/Release" ]; then
        zip -r "$RELEASE_DIR/tunes4r-windows-$VERSION.zip" "build/windows/x64/runner/Release"
        echo "✅ Windows App: $RELEASE_DIR/tunes4r-windows-$VERSION.zip"
    fi
else
    echo "⚠️  Not on macOS - skipping macOS, iOS and Windows builds"
fi

# Create release notes
echo "📝 Creating release notes..."
cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOL
# Tunes4R Release $VERSION

## What's New

- Bug fixes and improvements
- Cross-platform support for Windows, macOS, and Android

## Installation

### Android
Install the APK file on your device

### iOS
Use Xcode to install the app on device - extract the .app from the ZIP and follow deployment instructions

### macOS
- Download the DMG file
- Open the DMG and drag tunes4r.app to Applications folder

### Windows
- Download the ZIP file
- Extract and run tunes4r.exe

## Checksum

$(cd "$RELEASE_DIR" && find . -type f -exec shasum -a 256 {} \; | sort)
EOL

# Create GitHub release if gh CLI is available
if command -v gh &> /dev/null; then
    echo "🐙 Creating GitHub release..."
    TAG="v$VERSION"

    # Check if release already exists
    if gh release view "$TAG" &> /dev/null; then
        echo "⚠️  Release $TAG already exists, skipping GitHub release creation"
    else
        gh release create "$TAG" \
            --title "Tunes4R $VERSION" \
            --notes-file "$RELEASE_DIR/RELEASE_NOTES.md" \
            "$RELEASE_DIR"/*
        echo "✅ GitHub release created: $TAG"
    fi
else
    echo "⚠️  GitHub CLI not found, skip release deployment"
    echo "📋 To manually create release, upload files from: $RELEASE_DIR"
    echo "💡 Install GitHub CLI: brew install gh"
fi

echo "🏆 Release build complete!"
echo "📂 Release files are in: $RELEASE_DIR"
ls -la "$RELEASE_DIR"
