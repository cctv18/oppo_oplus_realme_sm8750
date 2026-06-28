#!/usr/bin/env bash
# ===== 构建自签 ReSukiSU 管理器(susfs2.2.0 + 去官方警告 + 内置 ksud) =====
# 环境无关:本地在 docker(op13-mgr-build:jdk21)里跑,CI 在 ubuntu 里跑。
# 需要环境提供: java(JDK21)、ANDROID_SDK_ROOT(含 build-tools)、git/zip/unzip。
# 入参(环境变量):
#   ROOT      op13 目录(含 patches/ vendor/ config.env)
#   WORK      构建临时目录
#   OUT       产物输出目录
#   KEYSTORE  keystore 文件路径
#   KS_ALIAS/KS_STOREPASS/KS_KEYPASS  签名参数
set -euo pipefail

: "${ROOT:?need ROOT}"; : "${WORK:?need WORK}"; : "${OUT:?need OUT}"; : "${KEYSTORE:?need KEYSTORE}"
: "${ANDROID_SDK_ROOT:?need ANDROID_SDK_ROOT}"
# shellcheck disable=SC1091
source "$ROOT/config.env"
KS_ALIAS="${KS_ALIAS:?}"; KS_STOREPASS="${KS_STOREPASS:?}"; KS_KEYPASS="${KS_KEYPASS:?}"

# 确保工具齐(docker 精简镜像可能缺 zip)
for t in zip unzip git; do command -v "$t" >/dev/null 2>&1 || MISS="${MISS:-} $t"; done
if [ -n "${MISS:-}" ] && command -v apt-get >/dev/null 2>&1; then apt-get update -qq && apt-get install -y -qq $MISS; fi

APKSIGNER="$(ls "$ANDROID_SDK_ROOT"/build-tools/*/apksigner | sort -V | tail -1)"
ZIPALIGN="$(ls "$ANDROID_SDK_ROOT"/build-tools/*/zipalign | sort -V | tail -1)"
echo ">>> apksigner=$APKSIGNER"

rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"; cd "$WORK"

echo ">>> [1/6] clone ReSukiSU ($RESUKISU_BRANCH) + susfs4oki ($SUSFS_BRANCH)"
git clone --depth=1 -b "$RESUKISU_BRANCH" "$RESUKISU_REPO" ReSukiSU
git clone --depth=1 -b "$SUSFS_BRANCH" "$SUSFS_REPO" susfs4oki

echo ">>> [2/6] 应用管理器补丁(susfs2.2.0 + 去官方警告)"
git -C ReSukiSU apply --reject "$ROOT/patches/resukisu-manager.patch" || {
  echo "!! patch 不完全适用(上游可能已变),用 patch -p1 尝试; 失败请更新 op13/patches/resukisu-manager.patch";
  ( cd ReSukiSU && patch -p1 < "$ROOT/patches/resukisu-manager.patch" ); }

echo ">>> [3/6] 放入 susfs2.2.0 用户态 asset"
cp susfs4oki/ksu_module_susfs/tools/ksu_susfs_arm64 ReSukiSU/manager/app/src/main/assets/ksu_susfs_2.2.0
chmod 644 ReSukiSU/manager/app/src/main/assets/ksu_susfs_2.2.0

echo ">>> [4/6] 写签名配置 + gradle assembleRelease"
cat >> ReSukiSU/manager/gradle.properties <<EOF
KEYSTORE_FILE=$KEYSTORE
KEYSTORE_PASSWORD=$KS_STOREPASS
KEY_ALIAS=$KS_ALIAS
KEY_PASSWORD=$KS_KEYPASS
EOF
git config --global --add safe.directory "$WORK/ReSukiSU" || true
( cd ReSukiSU/manager && ./gradlew --no-daemon assembleRelease -Pcommit="$(git -C .. rev-parse --short HEAD)" )
GAPK="$(ls "$WORK"/ReSukiSU/manager/app/build/outputs/apk/release/ReSukiSU_*_*-arm64-v8a-release.apk | head -1)"
echo ">>> gradle 产物: $GAPK"

echo ">>> [5/6] 注入 libksud.so(内置 ksud) + zipalign"
cp "$GAPK" work.apk
mkdir -p lib/arm64-v8a && cp "$ROOT/vendor/libksud.so" lib/arm64-v8a/libksud.so
zip -g work.apk lib/arm64-v8a/libksud.so >/dev/null
"$ZIPALIGN" -f 4 work.apk aligned.apk

echo ">>> [6/6] RSA-2048 v2-only 重签"
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass "pass:$KS_STOREPASS" --ks-key-alias "$KS_ALIAS" --key-pass "pass:$KS_KEYPASS" \
  --v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled false --v4-signing-enabled false \
  --out "$OUT/ReSukiSU-op13-susfs220.apk" aligned.apk

echo "=== 验证 ==="
"$APKSIGNER" verify --print-certs "$OUT/ReSukiSU-op13-susfs220.apk" 2>&1 | grep -iE "Verified using v[1234]|certificate SHA-256 digest"
echo -n "[libksud.so 内置] "; unzip -l "$OUT/ReSukiSU-op13-susfs220.apk" | grep -c "lib/arm64-v8a/libksud.so"
echo ">>> 管理器产物: $OUT/ReSukiSU-op13-susfs220.apk"
