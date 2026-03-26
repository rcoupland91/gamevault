#!/bin/bash

# GameVault iOS - Xcode Project Setup Script
# Run this script to create a proper .xcodeproj from the Swift source files

echo "🎮 GameVault iOS - Xcode Project Setup"
echo "======================================="

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "✅ Found: $XCODE_VERSION"

# Check swift version
SWIFT_VERSION=$(swift --version 2>&1 | head -1)
echo "✅ Found: $SWIFT_VERSION"

echo ""
echo "📱 Creating Xcode project..."
echo ""

# Use xcodegen if available, otherwise provide instructions
if command -v xcodegen &> /dev/null; then
    # Generate project.yml for xcodegen
    cat > project.yml << 'YAML'
name: GameVaultApp
options:
  bundleIdPrefix: com.gamevault
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15"

settings:
  base:
    SWIFT_VERSION: 5.9
    DEVELOPMENT_TEAM: ""
    IPHONEOS_DEPLOYMENT_TARGET: 17.0

targets:
  GameVaultApp:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Sources/GameVaultApp
        excludes:
          - "**/*.md"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.gamevault.app
        PRODUCT_NAME: GameVault
        SWIFT_VERSION: 5.9
        TARGETED_DEVICE_FAMILY: "1,2"
        INFOPLIST_FILE: Sources/GameVaultApp/Resources/Info.plist
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    info:
      path: Sources/GameVaultApp/Resources/Info.plist
      properties:
        CFBundleDisplayName: GameVault
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
        LSRequiresIPhoneOS: true
        NSCameraUsageDescription: "Used for avatar photos"
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true
          NSAllowsArbitraryLoads: false
YAML
    xcodegen generate
    echo "✅ Xcode project generated successfully!"
    echo "   Open GameVaultApp.xcodeproj in Xcode"
else
    echo "ℹ️  xcodegen not found. Creating project manually..."
    echo ""
    echo "OPTION 1 - Recommended (install xcodegen):"
    echo "  brew install xcodegen"
    echo "  ./setup-xcode-project.sh"
    echo ""
    echo "OPTION 2 - Create manually in Xcode:"
    echo "  1. Open Xcode"
    echo "  2. File > New > Project"
    echo "  3. Choose iOS > App"
    echo "  4. Product Name: GameVaultApp"
    echo "  5. Bundle Identifier: com.gamevault.app"
    echo "  6. Interface: SwiftUI"
    echo "  7. Language: Swift"
    echo "  8. Minimum Deployments: iOS 17.0"
    echo "  9. Delete the generated ContentView.swift"
    echo " 10. Drag all files from Sources/GameVaultApp/ into your project"
    echo " 11. Make sure 'Copy items if needed' is checked"
    echo ""
    echo "OPTION 3 - Open as Swift Package (limited features):"
    echo "  open Package.swift"
fi

echo ""
echo "📝 Next Steps:"
echo "  1. Set your Development Team in Signing & Capabilities"
echo "  2. Build and run on your device or simulator"
echo "  3. Enter your GameVault server URL in the app"
