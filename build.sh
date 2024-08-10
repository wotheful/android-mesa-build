#!/bin/bash
set -e

# 安装依赖库
sudo apt update
sudo apt install -y libxrandr-dev libxxf86vm-dev libxcb-*-dev libx11-xcb-dev libxfixes-dev libdrm-dev libx11-dev
pip3 install mako meson ninja

# NDK r27 太多bug，使用ndk r26d
export ANDROID_SDK_ROOT="/usr/local/lib/android/sdk/ndk/26.3.11579264"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk-bundle"

# 构建 drm
envsubst <android-${{matrix.arch}} >build-crossfile-drm
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
            -Dvc4=disabled \
            -Detnaviv=disabled \
            -Dfreedreno-kgsl=true
ninja -C "build-android" install

# 构建mesa
cd ..
envsubst <android-${{matrix.arch}} >build-crossfile
git clone --depth 1 https://gitlab.freedesktop.org/mesa/mesa
cd mesa
meson setup "build-android" \
            --prefix=/tmp/mesa \
            --cross-file "../build-crossfile" \
            -Dplatforms=android \
            -Dplatform-sdk-version=24 \
            -Dandroid-stub=true \
            -Dandroid-libbacktrace=disabled \
            -Dandroid-strict=false \
            -Dxlib-lease=disabled \
            -Degl=disabled \
            -Dgbm=disabled \
            -Dglx=disabled \
            -Dllvm=enabled \
            -Dopengl=true \
            -Dosmesa=true \
            -Dvulkan-drivers= \
            -Dgallium-drivers=zink \
            -Dfreedreno-kmds=kgsl,msm \
            -Dshared-glapi=false \
            -Dbuildtype=release
ninja -C "build-android" install
cp /tmp/mesa/lib/libOSMesa.so.8.0.0 /tmp/mesa/lib/libOSMesa_8.so
