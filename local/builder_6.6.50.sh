#!/bin/bash
set -e

# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 设置自定义参数 =====
echo "===== 欧加真MT6991通用6.6.50 A15 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android15-8-g29d86c5fc9dd-abogki428889875-4k）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android15-8-g29d86c5fc9dd-abogki428889875-4k}
read -p "是否启用susfs？(y/n，默认：y): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}
read -p "是否启用 KPM？(y/n，默认：n): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
read -p "KSU分支版本(y=SukiSU Ultra, r=ReSukiSU, n=KernelSU Next, m=MKSU, k=KSU, l=lkm模式(无内置KSU), 默认：y): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-y}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否启用网络功能增强优化配置？(y/n，默认：n): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-n}
read -p "是否添加 BBR 等一系列拥塞控制算法？(y添加/n禁用/d默认，默认：n): " APPLY_BBR
APPLY_BBR=${APPLY_BBR:-n}
read -p "是否启用ADIOS调度器？(y/n，默认：y): " APPLY_ADIOS
APPLY_ADIOS=${APPLY_ADIOS:-y}
read -p "是否启用Re-Kernel？(y/n，默认：n): " APPLY_REKERNEL
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
read -p "是否启用内核级基带保护？(y/n，默认：y): " APPLY_BBG
APPLY_BBG=${APPLY_BBG:-y}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="ReSukiSU"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next"
elif [[ "$KSU_BRANCH" == "m" || "$KSU_BRANCH" == "M" ]]; then
  KSU_TYPE="MKSU"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
else
  KSU_TYPE="no KSU"
fi

echo
echo "===== 配置信息 ====="
echo "适用机型: $MANIFEST"
echo "自定义内核后缀: -$CUSTOM_SUFFIX"
echo "KSU分支版本: $KSU_TYPE"
echo "启用susfs: $APPLY_SUSFS"
echo "启用 KPM: $USE_PATCH_LINUX"
echo "应用 lz4&zstd 补丁: $APPLY_LZ4"
echo "应用 lz4kd 补丁: $APPLY_LZ4KD"
echo "应用网络功能增强优化配置: $APPLY_BETTERNET"
echo "应用 BBR 等算法: $APPLY_BBR"
echo "启用ADIOS调度器: $APPLY_ADIOS"
echo "启用Re-Kernel: $APPLY_REKERNEL"
echo "启用内核级基带保护: $APPLY_BBG"
echo "===================="
echo

# ===== 创建工作目录 =====
WORKDIR="$SCRIPT_DIR"
cd "$WORKDIR"

# ===== 安装构建依赖 =====
echo ">>> 安装构建依赖..."
# Function to run a command with sudo if not already root
SU() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

SU apt-mark hold firefox && apt-mark hold libc-bin && apt-mark hold man-db
SU rm -rf /var/lib/man-db/auto-update
SU apt-get update
SU apt-get install --no-install-recommends -y curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev cpio xz-utils tar unzip
SU rm -rf ./llvm.sh && wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh
SU ./llvm.sh 18 all

# ===== 初始化仓库 =====
echo ">>> 初始化仓库..."
rm -rf kernel_workspace
mkdir kernel_workspace
cd kernel_workspace
git clone --depth=1 https://github.com/cctv18/android_kernel_oneplus_mt6991 -b oneplus/mt6991_v_15.0.2_ace5_ultra common
echo ">>> 初始化仓库完成"

# ===== 清除 abi 文件、去除 -dirty 后缀 =====
echo ">>> 正在清除 ABI 文件及去除 dirty 后缀..."
rm common/android/abi_gki_protected_exports_* || true

for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "$f"
done
sudo sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-'${CUSTOM_SUFFIX}'"/' ./common/arch/arm64/configs/gki_defconfig
sed -i 's/${scm_version}//' ./common/scripts/setlocalversion
echo "CONFIG_LOCALVERSION_AUTO=n" >> ./common/arch/arm64/configs/gki_defconfig

# ===== 拉取 KSU 并设置版本号 =====
if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  echo ">>> 拉取 SukiSU-Ultra 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin
  cd KernelSU
  GIT_COMMIT_HASH=$(git rev-parse --short=8 HEAD)
  echo "当前提交哈希: $GIT_COMMIT_HASH"
  echo ">>> 正在获取上游 API 版本信息..."
  for i in {1..3}; do
      KSU_API_VERSION=$(curl -s "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/builtin/kernel/Kbuild" | \
          grep -m1 "KSU_VERSION_API :=" | \
          awk -F'= ' '{print $2}' | \
          tr -d '[:space:]')
      if [ -n "$KSU_API_VERSION" ]; then
          echo "成功获取 API 版本: $KSU_API_VERSION"
          break
      else
          echo "获取失败，重试中 ($i/3)..."
          sleep 1
      fi
  done
  if [ -z "$KSU_API_VERSION" ]; then
      echo -e "无法获取 API 版本，使用默认值 3.1.7..."
      KSU_API_VERSION="3.1.7"
  fi
  export KSU_API_VERSION=$KSU_API_VERSION

  VERSION_DEFINITIONS=$'define get_ksu_version_full\nv\\$1-'"$GIT_COMMIT_HASH"$'@cctv18\nendef\n\nKSU_VERSION_API := '"$KSU_API_VERSION"$'\nKSU_VERSION_FULL := v'"$KSU_API_VERSION"$'-'"$GIT_COMMIT_HASH"$'@cctv18'

  echo ">>> 正在修改 kernel/Kbuild 文件..."
  sed -i '/define get_ksu_version_full/,/endef/d' kernel/Kbuild
  sed -i '/KSU_VERSION_API :=/d' kernel/Kbuild
  sed -i '/KSU_VERSION_FULL :=/d' kernel/Kbuild
  awk -v def="$VERSION_DEFINITIONS" '
      /REPO_OWNER :=/ {print; print def; inserted=1; next}
      1
      END {if (!inserted) print def}
  ' kernel/Kbuild > kernel/Kbuild.tmp && mv kernel/Kbuild.tmp kernel/Kbuild

  KSU_VERSION_CODE=$(expr $(git rev-list --count main 2>/dev/null) + 37185 2>/dev/null || echo 114514)
  echo ">>> 修改完成！验证结果："
  echo "------------------------------------------------"
  grep -A10 "REPO_OWNER" kernel/Kbuild | head -n 10
  echo "------------------------------------------------"
  grep "KSU_VERSION_FULL" kernel/Kbuild
  echo ">>> 最终版本字符串: v${KSU_API_VERSION}-${GIT_COMMIT_HASH}@cctv18"
  echo ">>> Version Code: ${KSU_VERSION_CODE}"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  echo ">>> 拉取 ReSukiSU 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s builtin
  cd KernelSU
  GIT_COMMIT_HASH=$(git rev-parse --short=8 HEAD)
  echo "当前提交哈希: $GIT_COMMIT_HASH"
  echo ">>> 正在获取上游 API 版本信息..."
  for i in {1..3}; do
      KSU_API_VERSION=$(curl -s "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/builtin/kernel/Kbuild" | \
          grep -m1 "KSU_VERSION_API :=" | \
          awk -F'= ' '{print $2}' | \
          tr -d '[:space:]')
      if [ -n "$KSU_API_VERSION" ]; then
          echo "成功获取 API 版本: $KSU_API_VERSION"
          break
      else
          echo "获取失败，重试中 ($i/3)..."
          sleep 1
      fi
  done
  if [ -z "$KSU_API_VERSION" ]; then
      echo -e "无法获取 API 版本，使用默认值 3.1.7..."
      KSU_API_VERSION="3.1.7"
  fi
  export KSU_API_VERSION=$KSU_API_VERSION

  VERSION_DEFINITIONS=$'define get_ksu_version_full\nv\\$1-'"$GIT_COMMIT_HASH"$'@cctv18\nendef\n\nKSU_VERSION_API := '"$KSU_API_VERSION"$'\nKSU_VERSION_FULL := v'"$KSU_API_VERSION"$'-'"$GIT_COMMIT_HASH"$'@cctv18'

  echo ">>> 正在修改 kernel/Kbuild 文件..."
  sed -i '/define get_ksu_version_full/,/endef/d' kernel/Kbuild
  sed -i '/KSU_VERSION_API :=/d' kernel/Kbuild
  sed -i '/KSU_VERSION_FULL :=/d' kernel/Kbuild
  awk -v def="$VERSION_DEFINITIONS" '
      /REPO_OWNER :=/ {print; print def; inserted=1; next}
      1
      END {if (!inserted) print def}
  ' kernel/Kbuild > kernel/Kbuild.tmp && mv kernel/Kbuild.tmp kernel/Kbuild

  KSU_VERSION_CODE=$(expr $(git rev-list --count main 2>/dev/null) + 30700 2>/dev/null || echo 114514)
  echo ">>> 修改完成！验证结果："
  echo "------------------------------------------------"
  grep -A10 "REPO_OWNER" kernel/Kbuild | head -n 10
  echo "------------------------------------------------"
  grep "KSU_VERSION_FULL" kernel/Kbuild
  echo ">>> 最终版本字符串: v${KSU_API_VERSION}-${GIT_COMMIT_HASH}@cctv18"
  echo ">>> Version Code: ${KSU_VERSION_CODE}"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  echo ">>> 拉取 KernelSU Next 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  cd KernelSU-Next
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_GIT_TAG/g" kernel/Kbuild
  #为KernelSU Next添加WildKSU管理器支持
  cd ../common/drivers/kernelsu
  wget https://github.com/WildKernels/kernel_patches/raw/refs/heads/main/next/susfs_fix_patches/v1.5.12/fix_apk_sign.c.patch
  patch -p2 -N -F 3 < fix_apk_sign.c.patch || true
elif [[ "$KSU_BRANCH" == "m" || "$KSU_BRANCH" == "M" ]]; then
  echo "正在配置 MKSU (5ec1cff/KernelSU)..."
  curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/5ec1cff/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo "正在配置原版 KernelSU (tiann/KernelSU)..."
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
else
  echo "已选择无内置KernelSU模式，跳过配置..."
fi

# ===== 克隆补丁仓库&应用 SUSFS 补丁 =====
echo ">>> 克隆补丁仓库..."
cd "$WORKDIR/kernel_workspace"
echo ">>> 应用 SUSFS&hook 补丁..."
if [[ "$KSU_BRANCH" == [yYrR] && "$APPLY_SUSFS" == [yY] ]]; then
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./common
  patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || true
  #临时修复 undeclared identifier 'vma' 编译错误：把vma = find_vma(...)替换为struct vm_area_struct *vma = find_vma(...)，解决部分版本源码中vma定义缺失的问题
  sed -i 's|vma = find_vma(mm|struct vm_area_struct *&|' ./fs/proc/task_mmu.c
  patch -p1 -F 3 < 69_hide_stuff.patch || true
elif [[ "$KSU_BRANCH" == [nN] && "$APPLY_SUSFS" == [yY] ]]; then
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./common
  patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || true
  #临时修复 undeclared identifier 'vma' 编译错误：把vma = find_vma(...)替换为struct vm_area_struct *vma = find_vma(...)，解决部分版本源码中vma定义缺失的问题
  sed -i 's|vma = find_vma(mm|struct vm_area_struct *&|' ./fs/proc/task_mmu.c
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
elif [[ "$KSU_BRANCH" == [mM] && "$APPLY_SUSFS" == [yY] ]]; then
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  # 临时修复：修复susfs补丁日志输出（由于上游KSU把部分Makefile代码移至Kbuild中，而susfs补丁未同步修改，故需修复susfs补丁修补位点）
  PATCH_FILE="./KernelSU/10_enable_susfs_for_ksu.patch"
  if [ -f "$PATCH_FILE" ]; then
    if grep -q "a/kernel/Makefile" "$PATCH_FILE"; then
      echo "检测到旧版 Makefile 补丁代码，正在执行修复..."
      sed -i 's|kernel/Makefile|kernel/Kbuild|g' "$PATCH_FILE"
      sed -i 's|^@@ .* format:.*|@@ -94,4 +94,13 @@|' "$PATCH_FILE"
      sed -i 's|.*check-format:.*| ccflags-y += -Wno-strict-prototypes -Wno-int-conversion -Wno-gcc-compat -Wno-missing-prototypes|' "$PATCH_FILE"
      sed -i 's|.*clang-format --dry-run.*| ccflags-y += -Wno-declaration-after-statement -Wno-unused-function -Wno-unused-variable|' "$PATCH_FILE"
      echo "补丁修复完成！"
    else
      echo "补丁代码已修复至 Kbuild 或不匹配，跳过修改..."
    fi
  else
    echo "未找到KSU补丁！"
    exit 1
  fi
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./KernelSU
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
  #为MKSU修正susfs 2.0.0补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/mksu_supercalls.patch
  patch -p1 < mksu_supercalls.patch || true
  cd ../common
  patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || true
  #临时修复 undeclared identifier 'vma' 编译错误：把vma = find_vma(...)替换为struct vm_area_struct *vma = find_vma(...)，解决部分版本源码中vma定义缺失的问题
  sed -i 's|vma = find_vma(mm|struct vm_area_struct *&|' ./fs/proc/task_mmu.c
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
elif [[ "$KSU_BRANCH" == [kK] && "$APPLY_SUSFS" == [yY] ]]; then
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  # 临时修复：修复susfs补丁日志输出（由于上游KSU把部分Makefile代码移至Kbuild中，而susfs补丁未同步修改，故需修复susfs补丁修补位点）
  PATCH_FILE="./KernelSU/10_enable_susfs_for_ksu.patch"
  if [ -f "$PATCH_FILE" ]; then
    if grep -q "a/kernel/Makefile" "$PATCH_FILE"; then
      echo "检测到旧版 Makefile 补丁代码，正在执行修复..."
      sed -i 's|kernel/Makefile|kernel/Kbuild|g' "$PATCH_FILE"
      sed -i 's|^@@ .* format:.*|@@ -94,4 +94,13 @@|' "$PATCH_FILE"
      sed -i 's|.*check-format:.*| ccflags-y += -Wno-strict-prototypes -Wno-int-conversion -Wno-gcc-compat -Wno-missing-prototypes|' "$PATCH_FILE"
      sed -i 's|.*clang-format --dry-run.*| ccflags-y += -Wno-declaration-after-statement -Wno-unused-function -Wno-unused-variable|' "$PATCH_FILE"
      echo "补丁修复完成！"
    else
      echo "补丁代码已修复至 Kbuild 或不匹配，跳过修改..."
    fi
  else
    echo "未找到KSU补丁！"
    exit 1
  fi
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./KernelSU
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
  cd ../common
  patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || true
  #临时修复 undeclared identifier 'vma' 编译错误：把vma = find_vma(...)替换为struct vm_area_struct *vma = find_vma(...)，解决部分版本源码中vma定义缺失的问题
  sed -i 's|vma = find_vma(mm|struct vm_area_struct *&|' ./fs/proc/task_mmu.c
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
else
  echo ">>> 未开启susfs，跳过susfs补丁配置..."
fi
cd ../

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8750.git
  cp ./oppo_oplus_realme_sm8750/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8750/zram_patch/001-lz4-clearMake.patch ./common/
  cp ./oppo_oplus_realme_sm8750/zram_patch/lz4armv8.S ./common/lib
  cp ./oppo_oplus_realme_sm8750/zram_patch/002-zstd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  git apply -p1 < 001-lz4.patch || true
  git apply -p1 < 001-lz4-clearMake.patch || true
  patch -p1 < 002-zstd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4&ZSTD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 应用 LZ4KD 补丁 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  echo ">>> 应用 LZ4KD 补丁..."
  if [ ! -d "SukiSU_patch" ]; then
    git clone --depth=1 https://github.com/ShirkNeko/SukiSU_patch.git
  fi
  cp -r ./SukiSU_patch/other/zram/lz4k/include/linux/* ./common/include/linux/
  cp -r ./SukiSU_patch/other/zram/lz4k/lib/* ./common/lib
  cp -r ./SukiSU_patch/other/zram/lz4k/crypto/* ./common/crypto
  cp ./SukiSU_patch/other/zram/zram_patch/6.6/lz4kd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  patch -p1 -F 3 < lz4kd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 添加 defconfig 配置项 =====
echo ">>> 添加 defconfig 配置项..."
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig

# 写入通用 SUSFS/KSU 配置
echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> "$DEFCONFIG_FILE"
else
  echo "CONFIG_KSU_SUSFS=n" >> "$DEFCONFIG_FILE"
fi
#添加对 Mountify (backslashxx/mountify) 模块的支持
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"

# 开启O2编译优化配置
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
#跳过将uapi标准头安装到 usr/include 目录的不必要操作，节省编译时间
echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"

# 仅在启用了 KPM 时添加 KPM 支持
if [[ "$USE_PATCH_LINUX" == "y" || "$USE_PATCH_LINUX" == "Y" ]]; then
  echo "CONFIG_KPM=y" >> "$DEFCONFIG_FILE"
fi

# 仅在启用了 LZ4KD 补丁时添加相关算法支持
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
EOF

fi

# ===== 启用网络功能增强优化配置 =====
if [[ "$APPLY_BETTERNET" == "y" || "$APPLY_BETTERNET" == "Y" ]]; then
  echo ">>> 正在启用网络功能增强优化配置..."
  echo "CONFIG_BPF_STREAM_PARSER=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"
  #由于部分机型的vintf兼容性检测规则，在开启CONFIG_IP6_NF_NAT后开机会出现"您的设备内部出现了问题。请联系您的设备制造商了解详情。"的提示，故添加一个配置修复补丁，在编译内核时隐藏CONFIG_IP6_NF_NAT=y但不影响对应功能编译
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8750/raw/refs/heads/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

# ===== 添加 BBR 等一系列拥塞控制算法 =====
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
  echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
  else
    echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
  fi
fi

# ===== 启用ADIOS调度器 =====
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  echo ">>> 正在启用ADIOS调度器..."
  echo "CONFIG_MQ_IOSCHED_ADIOS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用Re-Kernel =====
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  echo ">>> 正在启用Re-Kernel..."
  echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用内核级基带保护 =====
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  echo ">>> 正在启用内核级基带保护..."
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd ./common/security
  wget https://github.com/cctv18/Baseband-guard/archive/refs/heads/master.zip
  unzip -q master.zip
  mv "Baseband-guard-master" baseband-guard
  printf '\nobj-$(CONFIG_BBG) += baseband-guard/\n' >> ./Makefile
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/lockdown/lockdown,baseband_guard/ } }' ./Kconfig
  awk '
  /endmenu/ { last_endmenu_line = NR }
  { lines[NR] = $0 }
  END {
    for (i=1; i<=NR; i++) {
      if (i == last_endmenu_line) {
        sub(/endmenu/, "", lines[i]);
        print lines[i] "source \"security/baseband-guard/Kconfig\""
        print ""
        print "endmenu"
      } else {
          print lines[i]
      }
    }
  }
  ' ./Kconfig > Kconfig.tmp && mv Kconfig.tmp ./Kconfig
  sed -i 's/selinuxfs.o //g' "./selinux/Makefile"
  sed -i 's/hooks.o //g' "./selinux/Makefile"
  cat "./baseband-guard/sepatch.txt" >> "./selinux/Makefile"
  cd ../../
fi

# ===== 禁用 defconfig 检查 =====
echo ">>> 禁用 defconfig 检查..."
sed -i 's/check_defconfig//' ./common/build.config.gki

# ===== 编译内核 =====
echo ">>> 开始编译内核..."
cd common
make -j$(nproc --all) LLVM=-18 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnuabeihf- CC=clang LD=ld.lld HOSTCC=clang HOSTLD=ld.lld O=out KCFLAGS+=-O2 KCFLAGS+=-Wno-error gki_defconfig all
echo ">>> 内核编译成功！"

# ===== 选择使用 patch_linux (KPM补丁)=====
OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == "y" || "$USE_PATCH_LINUX" == "Y" ]]; then
  echo ">>> 使用 patch_linux 工具处理输出..."
  cd "$OUT_DIR"
  wget https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.2/patch_linux
  chmod +x patch_linux
  ./patch_linux
  rm -f Image
  mv oImage Image
  echo ">>> 已成功打上KPM补丁"
else
  echo ">>> 跳过 patch_linux 操作"
fi

# ===== 克隆并打包 AnyKernel3 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 克隆 AnyKernel3 项目..."
git clone https://github.com/cctv18/AnyKernel3 --depth=1

echo ">>> 清理 AnyKernel3 Git 信息..."
rm -rf ./AnyKernel3/.git

echo ">>> 拷贝内核镜像到 AnyKernel3 目录..."
cp "$OUT_DIR/Image" ./AnyKernel3/

echo ">>> 进入 AnyKernel3 目录并打包 zip..."
cd "$WORKDIR/kernel_workspace/AnyKernel3"

# ===== 如果启用 lz4kd，则下载 zram.zip 并放入当前目录 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  wget https://raw.githubusercontent.com/cctv18/oppo_oplus_realme_sm8750/refs/heads/main/zram.zip
fi

# ===== 生成 ZIP 文件名 =====
ZIP_NAME="Anykernel3-${MANIFEST}"

if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-susfs"
fi
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4kd"
fi
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4-zstd"
fi
if [[ "$USE_PATCH_LINUX" == "y" || "$USE_PATCH_LINUX" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-kpm"
fi
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbr"
fi
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-adios"
fi
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-rek"
fi
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbg"
fi

ZIP_NAME="${ZIP_NAME}-v$(date +%Y%m%d).zip"

# ===== 打包 ZIP 文件，包括 zram.zip（如果存在） =====
echo ">>> 打包文件: $ZIP_NAME"
zip -r "../$ZIP_NAME" ./*

ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> 打包完成 文件所在目录: $ZIP_PATH"
