# op13 — 自编内核 + 自签 ReSukiSU 管理器(一键构建)

OnePlus 13 (PJZ110 / sun / SM8750, ColorOS15/A15)。基于 cctv18 源码,**全程用自己的签名**,
内核(susfs2.2.0)+ 自签 ReSukiSU 管理器(susfs2.2.0、去"非官方"提示、内置 ksud)。

## 一键构建(本地 221)

```bash
bash op13/build-all.sh
```
产物在 `op13/out/`:
- `kernel-op13-susfs220.zip` — boot-only AK3,Kernel Flasher 刷 / 或 PC magiskboot 换内核段刷 boot。
- `ReSukiSU-op13-susfs220.apk` — `adb install -r` 装。

## 目录

| 文件 | 作用 |
|---|---|
| `config.env` | 统一配置(证书 hash、上游分支、版本串)。**可提交,无私钥** |
| `build-kernel.sh` | 内核:预编译 clang18 + LLVM=1,删 protected_exports(route-②),bpf -Werror 修复,susfs2.2.0,ReSukiSU,注入 `KSU_EXPECTED_SIZE/HASH`(信任自签管理器),出 AK3 zip。Arch 与 ubuntu 都能跑 |
| `build-manager.sh` | 管理器(env 无关):fresh clone ReSukiSU+susfs4oki → 打 `patches/` → 放 susfs2.2.0 asset → gradle → 注入 `vendor/libksud.so` → RSA-2048 v2-only 重签 |
| `build-all.sh` | 本地编排:内核(host)+ 管理器(docker `op13-mgr-build:jdk21`) |
| `patches/resukisu-manager.patch` | 管理器源码改动(susfs2.2.0 CLI 对齐 + isOfficialSignature 认自签证书)。**上游变了会打补丁失败 → 更新此文件即可,不是 git 合并冲突** |
| `vendor/libksud.so` | ksud 二进制(注入进 apk;管理器一切 ksud 功能靠它)。ReSukiSU 大版本变了重新 vendor |
| `keys/` | keystore(**.gitignore,不进仓库,务必单独备份**) |

## 自签管理器"四件套"(缺一不可)

1. **证书 ≤1024 字节** → 用 **RSA-2048**(785B)。内核 `apk_sign.c` 写死 `CERT_MAX_LENGTH 1024`,RSA-4096(1297B)会被拒。
2. **内核信任该证书** → `KSU_EXPECTED_SIZE=785 / KSU_EXPECTED_HASH=3374a276…`(config.env)编进内核。
3. **去"非官方"提示** → patch 改 `isOfficialSignature()` 认自签证书。
4. **内置 ksud** → 注入 `lib/arm64-v8a/libksud.so`(gradle 直出不含,模块/susfs 等所有 ksud 功能都需要它)。

## 换 keystore 怎么办

重算 `KSU_EXPECTED_SIZE/HASH`(`keytool -exportcert … -file c.der; wc -c c.der; sha256sum c.der`),
改 `config.env`,重编内核重刷一次。之后该 key 签的任何管理器都被信任。

## 跟上游(零/可控冲突)

```bash
git remote add upstream https://github.com/cctv18/oppo_oplus_realme_sm8750   # 一次
git fetch upstream && git merge upstream/main
```
我们的东西都在独立 `op13/` 目录 + 构建期 fresh clone 上游 ReSukiSU/susfs/common,所以:
- cctv18 / ReSukiSU / susfs 更新 → 自动跟上。
- 唯一要盯的是 `patches/resukisu-manager.patch`:上游改到对应文件时构建会**当场报打补丁失败**(可见、好修),不是静默冲突。
- `patches/` 里 susfs2.2.0 那几处是**临时绕过版本错位**,上游 ReSukiSU 跟到 2.2.0 后可删。

## GitHub Actions(云端构建)

见 `.github/workflows/op13-build.yml`。keystore 走 GitHub Secrets:
- `KEYSTORE_B64` = `base64 -w0 op13_rsa2048.keystore`
- `KS_STOREPASS` / `KS_KEYPASS`

`gh workflow run op13-build.yml` 触发,产物在 workflow artifacts / release。
