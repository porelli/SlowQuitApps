# Release Process for SlowQuitApps

This document describes how to create a new release of SlowQuitApps using the automated GitHub Actions workflow.

## Automated Release Process

SlowQuitApps uses GitHub Actions to automate the build and release process. When you're ready to create a new release, follow these steps:

1. Update the version number in `SlowQuitApps/SlowQuitApps-Info.plist`:
   - Update `CFBundleShortVersionString` to the new version (e.g., "0.8.3")
   - Commit this change to the repository

2. Create and push a new tag with the version number:
   ```bash
   git tag v0.8.3  # Replace with your version number
   git push origin v0.8.3
   ```

3. The GitHub Actions workflow will automatically:
   - Build the application as a universal binary (Intel + Apple Silicon) with code signing disabled for CI
   - Create a GitHub release
   - Upload the built app as a release asset

   Note: The CI build has code signing disabled. Users will need to right-click the app and select "Open" the first time they run it.

## Local Development Builds

For local development and testing, you can use the provided `build-unsigned.sh` script to build the app without code signing:

```bash
# Make the script executable if needed
chmod +x build-unsigned.sh

# Run the build script
./build-unsigned.sh
```

This will create an unsigned universal app (compatible with both Intel and Apple Silicon Macs) at `build/Build/Products/Release/SlowQuitApps.app` and a zip archive at `build/Build/Products/Release/SlowQuitApps.zip`.

## Manual Release (if needed)

If you need to create a release manually:

1. Update the version number in `SlowQuitApps/SlowQuitApps-Info.plist`
2. Build the app using Xcode
3. Create a ZIP archive of the app
4. Create a new release on GitHub and upload the ZIP file

## Versioning Guidelines

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Increment PATCH for bug fixes
- Increment MINOR for new features
- Increment MAJOR for breaking changes

## Release Notes

When creating a new release, include:
- Summary of changes
- Bug fixes
- New features
- Any breaking changes
- Installation instructions