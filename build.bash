#!/bin/bash
set -e

# NDK r27 太多bug，使用NDK r26d
export ANDROID_NDK_ROOT="/usr/local/lib/android/sdk/ndk/26.3.11579264"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk-bundle"

# 构建 drm
envsubst <android-drm-${BUILD_ARCH} >build-crossfile-drm
git clone --depth 1 https://gitlab.freedesktop.org/mesa/drm.git
cd drm
meson setup "build-android" \
            --prefix=/tmp/drm-static \
            --cross-file "../build-crossfile-drm" \
            -Ddefault_library=static \
            -Dintel=disabled \
            -Dradeon=disabled \
            -Damdgpu=disabled \
            -Dnouveau=disabled \
            -Dvmwgfx=disabled \
            -Dfreedreno=disabled \
            -Detnaviv=disabled \
            -Dvc4=disabled \
            -Dfreedreno-kgsl=false
ninja -C "build-android" install

# 构建mesa
cd ..
envsubst <android-${BUILD_ARCH} >build-crossfile
git clone --depth 1 https://gitlab.freedesktop.org/mesa/mesa
cd mesa
#打补丁
git reset --hard
git apply --reject --whitespace=fix ../patches/0001-mesa-zink-PojavTeam.diff || echo "git apply failed"
git apply --reject --whitespace=fix ../patches/0002-mesa-legacy.diff || echo "git apply failed"
git apply --reject --whitespace=fix ../patches/0003-mesa-termux-package.diff || echo "git apply failed"
git apply --reject --whitespace=fix ../patches/0004-mesa-梓之果冻.diff || echo "git apply failed"
git apply --reject --whitespace=fix ../patches/0005-mesa-ap.diff || echo "git apply failed"
#打补丁
meson setup "build-android" \
            --prefix=/tmp/mesa \
            --cross-file "../build-crossfile" \
            -Dplatforms=android \
            -Dplatform-sdk-version=24 \
            -Dcpp_rtti=false \
            -Dxmlconfig=disabled \
            -Dandroid-stub=true \
            -Dandroid-libbacktrace=enabled \
            -Dandroid-strict=true \
            -Dxlib-lease=disabled \
            -Degl=disabled \
            -Dgbm=disabled \
            -Dglx=disabled \
            -Dllvm=disabled \
            -Dopengl=true \
            -Dosmesa=true \
            -Dvulkan-drivers= \
            -Dgallium-drivers=zink \
            -Dshared-glapi=true \
            -Dbuildtype=release
            # -Dfreedreno-kmds=kgsl,msm \
ninja -C "build-android" install
cp /tmp/mesa/lib/libOSMesa.so.8.0.0 /tmp/mesa/lib/libOSMesa_8.so

#clean elf
git clone --depth 1 https://github.com/termux/termux-elf-cleaner || true
cd termux-elf-cleaner
mkdir build
cd build
export CFLAGS=-D__ANDROID_API__=24
cmake ..
make -j4
unset CFLAGS
cd ../..

findexec() { find $1 -type f -name "*" -not -name "*.o" -exec sh -c '
    case "$(head -n 1 "$1")" in
      ?ELF*) exit 0;;
      MZ*) exit 0;;
      #!*/ocamlrun*)exit0;;
    esac
exit 1
' sh {} \; -print
}

findexec /tmp/mesa/lib | xargs -- ./termux-elf-cleaner/build/termux-elf-cleaner
