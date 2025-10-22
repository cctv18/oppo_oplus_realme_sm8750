# 欧加真 SM8750/MT6991 系列通用6.6内核自动化编译脚本
[![STAR](https://img.shields.io/github/stars/cctv18/oppo_oplus_realme_sm8750?style=flat&logo=github)](https://github.com/cctv18/oppo_oplus_realme_sm8750/stargazers)
[![FORK](https://img.shields.io/github/forks/cctv18/oppo_oplus_realme_sm8750?style=flat&logo=greasyfork&color=%2394E61A)](https://github.com/cctv18/oppo_oplus_realme_sm8750/forks)
[![COOLAPK](https://img.shields.io/badge/cctv18_2-cctv18_2?style=flat&logo=android&logoColor=FF4500&label=%E9%85%B7%E5%AE%89&color=FF4500)](http://www.coolapk.com/u/22650293)
[![DISCUSSION](https://img.shields.io/badge/%E8%AE%A8%E8%AE%BA%E5%8C%BA-discussions?logo=livechat&logoColor=FFBBFF&color=3399ff)](https://github.com/cctv18/oppo_oplus_realme_sm8750/discussions)
##### 
一个更方便、快捷的自动化OPPO/一加/真我系列骁龙8Elite(SM8750)/天玑9400+(MT6991)机型的通用内核编译脚本。
##### 
这个项目的初衷是解决以下问题：
- 绿厂官方摆烂，代码开源开一半，导致部分内核代码无法通过已有的配置xml正常编译，甚至没有编译配置xml；
- 官方使用的 Bazel 编译器过于不稳定且低效，容易出现各种各样莫名其妙的错误，且全网几乎找不到任何有效解决方法，对于新手极不友好；
- 由于绿厂魔改内核f2fs代码，导致欧加真机型刷入GKI内核后不清空data分区就无法正常开机。
## 本项目的主要内容(及计划)
- 提供 OKI（官方源码）/ GKI（谷歌通用内核源码）双编译模式，OKI保留官方驱动/调度，GKI兼容性更强（无需相同内核小版本即可刷入）；
- 为 GKI 移植官方内核的f2fs源码，使 GKI 内核可以和官方 OKI 内核一样，刷入后可保留数据正常开机，不需要清空data ~~（新建文件夹）~~；
- 改用 LLVM/Clang 18 进行编译，并排除了官方源码中不必要的 vendor 源码参与，大幅优化编译流程，对比原 bazel 编译器缩短了近2/3的编译时间（原版官方编译器每次约需要超过1h才能完成编译），提高了编译过程的稳定性，输出日志更便于维护调试；
- 修复官方代码部分bug/未及时更新的补丁，并引入风驰内核驱动支持；
- 提供 Github Action 在线编译/shell本地编译双版本脚本。
## 已实现：
- [x] 欧加真 SM8750 通用OKI内核（基于一加13/13t 6.6.30/6.6.66 ，一加Pad2Pro 6.6.57 及一加13t 6.6.56 官方内核源码，其他同内核版本非SM8750机型可自行测试，部分机型可完全兼容）
- [x] 欧加真 MT6991 通用OKI内核（基于一加Ace5至尊版 6.6.50 官方内核源码，其他同内核版本非MT6989机型可自行测试，部分机型可完全兼容）
- [x] SukiSU Ultra/KernelSU Next双版本KSU可选
- [x] 引入ccache缓存，优化工具链及编译流程，二次编译时间可缩短至约6min (注：首次使用ccache由于需要创建缓存速度会比较慢(约20-24min)，从第二次开始ccache才会生效加速编译，加速后单次编译时间约6~11min，具体时间随服务器负载情况而浮动；之后除非缓存出现问题，如无法加速等，可无需再清理ccache缓存)
- [x] 引入O2编译优化，改善内核运行性能
- [x] 可选manual/kprobes钩子模式：kprobes钩子模式下支持切换至sus su模式（类似面具的su实现，用于兼容一些程序的运行）
- [x] lz4 1.10.0 & zstd 1.5.7 算法更新&优化补丁(来自[@ferstar](https://github.com/ferstar), 移植by [@Xiaomichael](https://github.com/Xiaomichael))
- [x] 可选加入 BBR/Brutal 及一系列 tcp 拥塞控制算法
- [x] 三星SSG IO调度器移植（目前已知仅在一加12上会导致无法正常启动，原因尚不明确，待进一步研究修复）
- [x] 加入一些网络连接性能优化配置选项
- [x] 加入Re:Kernel支持，与Freezer，NoActive等软件配合降低功耗
- [x] 欧加真 SM8750 通用GKI内核（移植一加f2fs源码，实现免清data刷入）
## 待实现：
- [ ] zram内置化，无需外置zram.ko挂载 ~~（有了新版 lz4&zstd 补丁真的还有必要吗）~~
- [ ] LXC/Docker 功能支持
- [ ] Nethunter 驱动移植
- [ ] Adios 调度器移植
- [ ] 一加系列新版调度器移植（schedhorizon等）
- ~~整合多版本内核编译脚本（出于操作便捷性及GitHub Action的选项数量限制，暂不进行多脚本整合）~~
- 更多优化与特性移植……
##### 
##### 
##### 
## 鸣谢
- Sukisu Ultra：[SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- susfs4ksu：[ShirkNeko/susfs4ksu](https://github.com/ShirkNeko/susfs4ksu)
- SukiSU内核补丁：[SukiSU-Ultra/SukiSU_patch](https://github.com/SukiSU-Ultra/SukiSU_patch)
- pershoot维护的KernelSU Next分支：[pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next)
- KernelSU Next内核补丁：[WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches)
- GKI 内核构建脚本：(待定)
- ~~本地化内核构建脚本（已失效）：[Suxiaoqinx/kernel_manifest_OnePlus_Sukisu_Ultra](https://github.com/Suxiaoqinx/kernel_manifest_OnePlus_Sukisu_Ultra)~~
- ~~风驰内核源码（不完整，修改中）：[HanKuCha/sched_ext](https://github.com/HanKuCha/sched_ext)~~
