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

#构建libclc
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.0-rc2/libclc-19.1.0-rc2.src.tar.xz
tar xf libclc-19.1.0-rc2.src.tar.xz
cd libclc-19.1.0-rc2*
cmake_build () {
  ANDROID_ABI=$1
  mkdir -p build-$ANDROID_ABI
  cd build-$ANDROID_ABI
  cmake $GITHUB_WORKSPACE -DCMAKE_BUILD_TYPE=release -DANDROID_PLATFORM=24 -DANDROID_ABI=$ANDROID_ABI -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake
  cmake --build . --clean-first
  # | echo "Build exit code: $?"
  # --verbose
  cd ..
  cp build-$ANDROID_ABI/* /tmp/drm-static
}
cmake_build arm64-v8a

# 构建mesa
cd ..
envsubst <android-${BUILD_ARCH} >build-crossfile
git clone --depth 1 https://gitlab.freedesktop.org/mesa/mesa
cd mesa
#打补丁
git apply --reject --whitespace=fix ../patches/0001-mesa-zink-PojavTeam.diff || echo "git apply failed"
git apply --reject --whitespace=fix ../patches/0002-mesa-legacy.diff || echo "git apply failed"
git apply --reject --whitespace=fix ../patches/0003-mesa-termux-package.diff || echo "git apply failed"
#打补丁
meson setup "build-android" \
            --prefix=/tmp/mesa \
            --cross-file "../build-crossfile" \
            -Dcpp_rtti=false
            -Dplatforms=android \
            -Dplatform-sdk-version=24 \
            -Dandroid-stub=true \
            -Dandroid-libbacktrace=disabled \
            -Dandroid-strict=false \
            -Dxlib-lease=disabled \
            -Degl=disabled \
            -Dgbm=disabled \
            -Dglx=disabled \
            -Dllvm=disabled \
            -Dopengl=true \
            -Dosmesa=true \
            -Dvulkan-drivers= \
            -Dgallium-drivers=swrast,zink \
            # -Dfreedreno-kmds=kgsl,msm \
            -Dshared-glapi=false \
            -Dbuildtype=release
ninja -C "build-android" install
cp /tmp/mesa/lib/libOSMesa.so.8.0.0 /tmp/mesa/lib/libOSMesa_8.so
