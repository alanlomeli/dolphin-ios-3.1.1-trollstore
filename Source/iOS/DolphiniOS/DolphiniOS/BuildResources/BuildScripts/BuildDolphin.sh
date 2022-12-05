#!/bin/bash

set -e
export PATH="/Users/alanlomeli/CEdev/bin:/Users/alanlomeli/bin:/usr/local/opt/ncurses/bin:/Users/alanlomeli/.spicetify:/Library/Java/apache-maven-3.8.6/bin:/usr/local/share/dotnet/x64:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/TeX/texbin:/usr/local/share/dotnet:~/.dotnet/tools:/Library/Apple/usr/bin:/Applications/kitty.app/Contents/MacOS"

# Increment the build number
INFO_FILE=$PROJECT_DIR/DolphiniOS/Info.plist
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_FILE")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(($BUILD_NUMBER + 1))" "$INFO_FILE"

# Copy a dummy google service info plist if it doesn't exist (if we don't care about firebase)
if [ ! -f "$PROJECT_DIR/DolphiniOS/GoogleService-Info.plist" ]; then
  cp $PROJECT_DIR/DolphiniOS/GoogleService-Info-Placeholder.plist $PROJECT_DIR/DolphiniOS/GoogleService-Info.plist
fi

ROOT_DOLPHIN_DIR=$PROJECT_DIR/../../..

CMAKE_BUILD_DIR=$ROOT_DOLPHIN_DIR/build-$PLATFORM_NAME-$DOLPHIN_BUILD_TYPE
ADDITIONAL_CMAKE_SETTINGS=
echo $CMAKE_BUILD_DIR > CMAKE_BUILD_DIR
IOS_PLATFORM=OS64
if [ $PLATFORM_NAME == "iphonesimulator" ]; then
    IOS_PLATFORM=SIMULATOR64
fi

if [ $BUILD_FOR_JAILBROKEN_DEVICE == "YES" ]; then
  CMAKE_BUILD_DIR="$CMAKE_BUILD_DIR-jb"
  ADDITIONAL_CMAKE_SETTINGS="-DIOS_JAILBROKEN=1"
fi

if [ ! -d "$CMAKE_BUILD_DIR" ]; then
    mkdir $CMAKE_BUILD_DIR
    cd $CMAKE_BUILD_DIR
    
    cmake $ROOT_DOLPHIN_DIR -GNinja -DCMAKE_TOOLCHAIN_FILE=$ROOT_DOLPHIN_DIR/Source/iOS/ios.toolchain.cmake -DPLATFORM=$IOS_PLATFORM -DDEPLOYMENT_TARGET="12.0" -DCMAKE_BUILD_TYPE=$DOLPHIN_BUILD_TYPE -DENABLE_ANALYTICS=NO $ADDITIONAL_CMAKE_SETTINGS
fi

cd $CMAKE_BUILD_DIR

ninja

if [ ! -d "$CMAKE_BUILD_DIR/libs" ]; then
    mkdir $CMAKE_BUILD_DIR/libs
    mkdir $CMAKE_BUILD_DIR/libs/Dolphin
    mkdir $CMAKE_BUILD_DIR/libs/Externals
fi

rm -f $CMAKE_BUILD_DIR/libs/Dolphin/*.a
rm -f $CMAKE_BUILD_DIR/libs/Externals/*.a

find Source/ -name '*.a' -exec ln '{}' "$CMAKE_BUILD_DIR/libs/Dolphin/" ';'

find Externals/ -name '*.a' -exec ln '{}' "$CMAKE_BUILD_DIR/libs/Externals/" ';'

if [ -f "$CMAKE_BUILD_DIR/libs/Externals/libfmtd.a" ]; then
    rm $CMAKE_BUILD_DIR/libs/Externals/libfmt.a || true
    cp $CMAKE_BUILD_DIR/libs/Externals/libfmtd.a $CMAKE_BUILD_DIR/libs/Externals/libfmt.a
fi

rm $PROJECT_DIR/libMoltenVK.dylib || true
ln -s $ROOT_DOLPHIN_DIR/Externals/MoltenVK/libvulkan_iOS.dylib $PROJECT_DIR/libMoltenVK.dylib
