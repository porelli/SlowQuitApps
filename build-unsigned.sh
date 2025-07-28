#!/bin/bash

# build-unsigned.sh
# Script to build SlowQuitApps without code signing
# This is useful for development and testing

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Building SlowQuitApps without code signing...${NC}"

# Create build directory if it doesn't exist
mkdir -p build

# Build the app
echo -e "${GREEN}Running xcodebuild...${NC}"
xcodebuild -project SlowQuitApps.xcodeproj \
           -scheme SlowQuitApps \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build successful!${NC}"
    
    # Create a zip archive of the app
    echo -e "${GREEN}Creating zip archive...${NC}"
    cd build/Build/Products/Release
    zip -r SlowQuitApps.zip SlowQuitApps.app
    
    echo -e "${GREEN}Done!${NC}"
    echo -e "${YELLOW}The unsigned app is available at:${NC}"
    echo -e "build/Build/Products/Release/SlowQuitApps.app"
    echo -e "${YELLOW}A zip archive is available at:${NC}"
    echo -e "build/Build/Products/Release/SlowQuitApps.zip"
    echo -e "${YELLOW}Note: Since the app is unsigned, you'll need to right-click and select 'Open' the first time you run it.${NC}"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi