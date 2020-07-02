#! /bin/sh
#
#  Step 1.
#  Configure for base system so simulator is covered
#  
#  Step 2.
#  Make for iOS and iOS simulator
#
#  Step 3.
#  Merge libs into final version for xcode import

export PREFIX="$(pwd)/libsodium-simulator"
export SIMULATOR32_PREFIX="$PREFIX/tmp/simulator32"
export SIMULATOR64_PREFIX="$PREFIX/tmp/simulator64"
export XCODEDIR=$(xcode-select -p)

export IOS_SIMULATOR_VERSION_MIN=${IOS_SIMULATOR_VERSION_MIN-"9.0.0"}

echo
echo "Warnings related to headers being present but not usable are due to functions"
echo "that didn't exist in the specified minimum iOS version level."
echo "They can be safely ignored."
echo

mkdir -p $SIMULATOR32_PREFIX $SIMULATOR64_PREFIX || exit 1

# Build for the simulator
export BASEDIR="${XCODEDIR}/Platforms/iPhoneSimulator.platform/Developer"
export PATH="${BASEDIR}/usr/bin:$BASEDIR/usr/sbin:$PATH"
export SDK="${BASEDIR}/SDKs/iPhoneSimulator.sdk"

## i386 simulator
export CFLAGS="-O2 -arch i386 -isysroot ${SDK} -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"
export LDFLAGS="-arch i386 -isysroot ${SDK} -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"

make distclean > /dev/null

if [ -z "$LIBSODIUM_FULL_BUILD" ]; then
  export LIBSODIUM_ENABLE_MINIMAL_FLAG="--enable-minimal"
else
  export LIBSODIUM_ENABLE_MINIMAL_FLAG=""
fi

./configure --host=i686-apple-darwin10 \
            ${LIBSODIUM_ENABLE_MINIMAL_FLAG} \
            --prefix="$SIMULATOR32_PREFIX" || exit 1


NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)
PROCESSORS=${NPROCESSORS:-3}

make -j${PROCESSORS} install || exit 1

## x86_64 simulator
export CFLAGS="-O2 -arch x86_64 -isysroot ${SDK} -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"
export LDFLAGS="-arch x86_64 -isysroot ${SDK} -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"

make distclean > /dev/null

./configure --host=x86_64-apple-darwin10 \
            ${LIBSODIUM_ENABLE_MINIMAL_FLAG} \
            --prefix="$SIMULATOR64_PREFIX"

make -j${PROCESSORS} install || exit 1

# Create universal binary and include folder
rm -fr -- "$PREFIX/include" "$PREFIX/libsodium.a" 2> /dev/null
mkdir -p -- "$PREFIX/lib"
lipo -create \
  "$SIMULATOR32_PREFIX/lib/libsodium.a" \
  "$SIMULATOR64_PREFIX/lib/libsodium.a" \
  -output "$PREFIX/lib/libsodium.a"
lipo -create \
  "$SIMULATOR32_PREFIX/lib/libsodium.dylib" \
  "$SIMULATOR64_PREFIX/lib/libsodium.dylib" \
  -output "$PREFIX/lib/libsodium.dylib"
install_name_tool -id "@rpath/SODIUM.framework/libsodium.dylib" "$PREFIX/lib/libsodium.dylib"

echo
echo "libsodium has been installed into $PREFIX"
echo
file -- "$PREFIX/lib/libsodium.a"
file -- "$PREFIX/lib/libsodium.dylib"

# Cleanup
rm -rf -- "$PREFIX/tmp"
make distclean > /dev/null