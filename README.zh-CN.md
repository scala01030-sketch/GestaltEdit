> **安全复核分支，不是 Siri AI 正式兼容版。** 已识别 RC `24A435` 和正式版 `24A437`，但在私有 API 调用前阻止系统访问。不要安装旧 fork 产物绕过此限制。下方原作者的下载链接不代表经过本次复核的构建。详见[最终安全复核](docs/FINAL_SAFETY_REVIEW.md)。

> 另有独立的[安装／启动自检版](docs/INSTALL_CHECK.md)，从编译阶段排除系统缓存访问。它不启用 Siri AI，不代表正式版功能适配成功；签名产物仍须另行审核。

<div align="center">

<img src="docs/icon.png" alt="GestaltEdit 应用图标" width="128" height="128">

# GestaltEdit

**直接在 iPhone 和 iPad 上运行的 MobileGestalt 工具**

<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/daily?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>
<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/weekly?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>

<p>
  <a href="https://github.com/frs0n/GestaltEdit/releases/latest"><img src="https://img.shields.io/github/v/release/frs0n/GestaltEdit?style=flat-square&label=release&color=6E56CF" alt="最新版本"></a>
  <a href="https://github.com/frs0n/GestaltEdit/releases"><img src="https://img.shields.io/github/downloads/frs0n/GestaltEdit/total?style=flat-square&label=downloads&color=6E56CF" alt="下载量"></a>
  <a href="https://github.com/frs0n/GestaltEdit/stargazers"><img src="https://img.shields.io/github/stars/frs0n/GestaltEdit?style=flat-square&color=6E56CF" alt="Stars"></a>
  <img src="https://img.shields.io/badge/iOS%20%7C%20iPadOS-27-000000?style=flat-square&logo=apple&logoColor=white" alt="支持平台">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Noncommercial-6E56CF?style=flat-square" alt="PolyForm 非商业许可证"></a>
</p>

<a href="https://github.com/frs0n/GestaltEdit/releases/latest"><b>下载 IPA</b></a> ·
<a href="#系统要求">系统要求</a> ·
<a href="#安装">安装</a> ·
<a href="README.md">English</a>

</div>

在设备上直接编辑 `com.apple.MobileGestalt.plist`，提供功能预设、完整字段编辑器与备份 / 恢复。

> [!WARNING]
> 本项目使用私有 API 并修改系统缓存数据。错误的取值可能破坏系统功能，严重时需要刷机恢复。请仅在你本人拥有的设备上使用。

> [!IMPORTANT]
> 本项目免费、源码公开；未经授权，不得以任何形式出售本 App。

## 功能

**预设** —— 灵动岛、设备型号名称、开关机铃声、充电限制、轻点唤醒、相机控制、Apple Pencil、操作按钮、车祸检测、息屏显示、壁纸视差、台前调度、iPad 应用兼容性、Siri AI 美区等。勾选需要的，点「应用」。

**字段编辑器** —— 预设没覆盖到的，可以自己搜索并编辑任意 MobileGestalt 键值。

**备份** —— 每次写入都会自动备份，也可随时手动备份、导入、导出与恢复。

## 系统要求

- iOS / iPadOS 27 beta 1–4
- iOS / iPadOS 27.0 RC（24A435）已识别，系统访问被阻止
- iOS / iPadOS 27.0 正式版（24A437）已识别，系统访问被阻止
- 设备已开启开发者模式
- 一种签名安装方式，例如 [iLoader](https://github.com/nab138/iloader)

源码默认是只读探测版（`GESTALT_READ_ONLY_PROBE=1`、`GESTALT_ENABLE_WRITES=0`）。仅原 beta 白名单允许手动触发一次快照；本次进程内失败不重试，导出复用第一次读取的原始字节，尝试结束即释放租约。`O_RDONLY` 只约束文件操作，不表示私有沙盒租约本身是只读权限。复核构建不编译 MobileGestalt 写入实现或 WebKit 注销负载。探测备份使用文件保护并排除系统备份，请在卸载前私下导出；它是诊断副本，不是已验证的系统恢复机制。

## 安装

**当前 RC／正式版目标停止安装。** 以下是原作者安装说明，不是本次设备操作的许可。复核构建使用独立标识 `me.ssus.gestaltedit.readonlyprobe`，签名时不得改回已安装应用的标识。

1. 从 [Releases](https://github.com/frs0n/GestaltEdit/releases/latest) 下载 `GestaltEdit.ipa`。
2. 使用可信的本地签名方式；不要向未经验证的第三方签名服务提交主 Apple ID 密码或双重认证验证码。
3. 导入 IPA 完成签名安装，然后在「设置」→「通用」→「VPN 与设备管理」中信任证书。

## 致谢

- [Nugget](https://github.com/leminlimez/Nugget) —— 预设与 iPadOS 支持
- [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop)、[bad_query](https://github.com/forcequitOS/bad_query)、[0xJohnny](https://x.com/0xjohnny) —— 文件访问研究
- [neospring](https://github.com/rooootdev/neospring) —— 注销实现

与 Apple 及上述项目均无隶属关系。

## 许可证

[PolyForm Noncommercial License 1.0.0](LICENSE) —— 非商业用途免费；不得用于商业目的。
