#!/usr/bin/env bash
# ===== OP13 一键构建: 自编内核(susfs2.2.0) + 自签 ReSukiSU 管理器 =====
# 在 221(Arch)上跑: bash op13/build-all.sh
# 产物输出到 op13/out/
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"     # .../op13
# shellcheck disable=SC1091
source "$HERE/config.env"
OUT="$HERE/out"; mkdir -p "$OUT"

# 221 上已就绪的管理器构建环境(docker 镜像 + Android SDK + gradle 缓存)
SDK="${OP13_SDK:-/root/op13_mgr/android-sdk}"
GHOME="${OP13_GRADLE_HOME:-/root/op13_mgr/gradle-home}"
DOCKER_IMG="${OP13_DOCKER_IMG:-op13-mgr-build:jdk21}"
KEYSTORE="$HERE/keys/op13_rsa2048.keystore"

echo "######################## [A] 内核 (host/Arch, 预编译clang18 + LLVM=1) ########################"
bash "$HERE/build-kernel.sh"
KZIP="$(ls -t "$HERE"/kernel_workspace/Anykernel3-*.zip 2>/dev/null | head -1 || true)"
if [ -n "$KZIP" ]; then cp -f "$KZIP" "$OUT/kernel-op13-susfs220.zip"; echo ">>> 内核 -> $OUT/kernel-op13-susfs220.zip"; else echo "!! 没找到内核 zip"; exit 1; fi

echo "######################## [B] 管理器 (docker: $DOCKER_IMG) ########################"
[ -f "$KEYSTORE" ] || { echo "!! 缺 keystore: $KEYSTORE (放你的 op13_rsa2048.keystore)"; exit 1; }
mkdir -p "$GHOME"
docker run --rm \
  -v "$HERE":/op13 -v "$SDK":/sdk -v "$GHOME":/gradle-home \
  -e ROOT=/op13 -e WORK=/op13/workdir -e OUT=/op13/out \
  -e ANDROID_SDK_ROOT=/sdk -e GRADLE_USER_HOME=/gradle-home \
  -e KEYSTORE=/op13/keys/op13_rsa2048.keystore \
  -e KS_ALIAS="$KS_ALIAS" -e KS_STOREPASS="$KS_STOREPASS" -e KS_KEYPASS="$KS_KEYPASS" \
  "$DOCKER_IMG" bash -lc "bash /op13/build-manager.sh"

echo "######################## 完成 ########################"
ls -la "$OUT"
echo
echo "内核:   $OUT/kernel-op13-susfs220.zip   (Kernel Flasher 刷 / 或 magiskboot 换段刷 boot)"
echo "管理器: $OUT/ReSukiSU-op13-susfs220.apk (adb install -r)"
