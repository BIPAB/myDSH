# DSH Remote（fish-pocket 改造版）

原生 iOS 客户端，**连家里三台电脑上的 DSH**，不在手机上跑引擎。

> 基于 [imsai-sh/fish-pocket](https://github.com/imsai-sh/fish-pocket)（MIT）改造。
> 原项目是「把 Node 嵌进 App，DSH 跑在手机上」；这一版把引擎整个移除了，
> 只保留它的原生 SwiftUI 界面，改成连远程。

## 和原版的区别

| | 原版 fish-pocket | 这一版 |
|---|---|---|
| 引擎在哪 | 手机 App 内（nodejs-mobile）| **不用引擎**，连电脑上的 DSH |
| 依赖 | nodejs-mobile / libgit2 / native 绑定 | **纯 SwiftUI** |
| 构建 | 要下 XCFramework、编 C 库 | `xcodegen` + `xcodebuild` 就够 |
| 认证 | 本机 `?token=` 换 cookie | 反向代理 `?k=` 换 cookie（模型一致）|

## 目录改动

```
删掉：
  engine/     手机本机运行的 DSH 引擎
  native/     libgit2 / ImageIO / root 三个 N-API 绑定
  scripts/    构建引擎、nodejs-mobile、libgit2 的 6 个脚本
  .github/workflows/ios-build.yml   原引擎版 CI

改掉：
  app/DshIOS/NodeEngine.swift     → 桩（保留接口，不再 import NodeMobile）
  app/DshIOS/EnginePaths.swift    → 去掉 dsh_root_install 链接符号
  app/DshIOS/DshIOSApp.swift      → 远程优先入口
  app/project.yml                 → 去掉引擎依赖、改 Bundle ID 为 com.wsw.dsh-remote

新增：
  app/DshIOS/DeviceStore.swift    三台设备 + 持久化
  app/DshIOS/DeviceSwitcher.swift 设备面板 + 右边缘胶囊入口
  app/DshIOS/Views/StartupView.swift  补上游缺失的两个界面
  codemagic.yaml                  云端构建（未签名 ipa）
```

## 三台设备

| 设备 | 地址 |
|---|---|
| 沫雨 | `https://dsh.spqrbipab.site:8443` |
| DESKTOP-M1P9A8G | `https://dsh.spqrbipab.site:5173` |
| 云电脑 | `https://dsh.spqrbipab.site:8444` |

配对码三台统一：`9MJ52DQX`。

## 构建

Codemagic 上直接读 `codemagic.yaml`，产出未签名 `.ipa`：

```
xcodegen generate
xcodebuild CODE_SIGNING_ALLOWED=NO build
zip -r dsh-remote-unsigned.ipa Payload/
```

然后用 Sideloadly / AltStore 配合免费 Apple ID 签名装到 iPhone（7 天有效）。

## 状态

- [x] 架构研究、注入点定位
- [x] 引擎剥离、入口改造、设备管理
- [x] 补上游缺失的 `StartupView` / `EngineTrouble`
- [ ] **编译验证**（等 Codemagic 首次构建）
- [ ] 装机验证能否连上三台
