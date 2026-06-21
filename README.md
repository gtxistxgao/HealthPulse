# HealthPulse

一个 SwiftUI iOS 应用,读取 HealthKit 数据并在首页展示**恢复分(Recovery)**、**能量消耗(Energy, kcal)**以及一行生理指标(HRV / 静息心率 / 血氧 / 呼吸频率)。恢复分基于最近 60 天的 HRV、RHR 滚动基线做 z-score 评分;历史不足 14 天时显示「数据积累中」而非误导性的分数。

- 平台:iOS 17.0+
- 依赖:仅系统框架(HealthKit、SwiftUI),无第三方包
- Bundle ID:`com.healthpulse.HealthPulse`(免费账号签名时需改为唯一值,见下文)

> HealthKit 数据只有真机才有,**模拟器无法读取**,因此验证必须在真机上进行。

## 项目结构

```
project.yml                 # XcodeGen 工程定义(签名 team 故意留空)
HealthPulse.xcodeproj/      # 已提交的生成产物,供无 XcodeGen 的环境直接构建
Shared/                     # 跨端代码:Models / Services / ViewModels / Extensions
iPhone/                     # iPhone 端入口与视图
HealthPulse/Info.plist      # 含 NSHealthShareUsageDescription
HealthPulse/HealthPulse.entitlements  # 声明 com.apple.developer.healthkit
```

## 1. 生成 Xcode 工程

工程已提交在仓库中,可直接打开。若改动了 `project.yml` 或新增/移动了 `.swift` 文件,需要重新生成:

```bash
brew install xcodegen      # 如未安装
xcodegen generate          # 读取 project.yml,重写 HealthPulse.xcodeproj
open HealthPulse.xcodeproj
```

> 注意:`.swift` 文件的增删/移动必须通过 `xcodegen generate` 同步到 `project.pbxproj`,否则新文件不会进入编译。

## 2. 设置签名(免费 Apple ID)

`project.yml` 与工程里 `DEVELOPMENT_TEAM` 故意留空,需在 Xcode 中配置:

1. Xcode → Settings → Accounts,用你的 Apple ID 登录(免费个人账号即可)。
2. 选中 **HealthPulse** target → **Signing & Capabilities**。
3. 勾选 **Automatically manage signing**,在 **Team** 下拉里选你的「Personal Team」。
4. 免费账号下 `com.healthpulse.HealthPulse` 这个 Bundle ID 很可能已被占用,把 **Bundle Identifier** 改成全局唯一的值,例如 `com.<你的名字>.HealthPulse`,直到提示消失。
5. 确认 **HealthKit** capability 仍在(工程已带 entitlements;若被移除,点 **+ Capability** 重新加上 HealthKit)。

## 3. 真机 Build & Run

1. 用数据线连接 iPhone,在 Xcode 顶部目标设备里选中它。
2. iPhone 需开启**开发者模式**:首次会提示,或到 设置 → 隐私与安全性 → 开发者模式 打开并重启。
3. ⌘R 运行。首次安装后,免费账号的证书未受信任,需到 iPhone **设置 → 通用 → VPN与设备管理 → 开发者 App**,信任你的开发者证书,再次点开 App。
4. **首次启动会弹出 HealthKit 授权弹窗**,把需要的指标全部「允许」。
5. 授权后 Dashboard 应显示:
   - **恢复**卡片:彩色环 + 分数(历史满 14 天后);历史不足时显示「数据积累中」。
   - **能量**卡片:今日总消耗 kcal,以及「活动 / 静息」拆分。
   - **生理指标**行:HRV、静息心率、血氧、呼吸频率;暂无读数的指标显示「—」,不崩溃。
6. 下拉可刷新;若误拒授权,会显示引导页,可在 设置 → 健康 中重新授权后点「重新加载」。

## 4. 命令行构建(可选,用于 CI / 验收)

可在不签名的情况下验证工程能否编译:

```bash
xcodebuild -project HealthPulse.xcodeproj -scheme HealthPulse \
  -destination 'generic/platform=iOS' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

## 免费账号 7 天重签注意

用**免费 Apple ID** 签名的 App 有效期只有 **7 天**,到期后图标还在但点开会闪退/无法启动。这是 Apple 对免费开发者证书的限制,不是 Bug。应对方式:

- **重新连接 iPhone 用 Xcode ⌘R 重装**即可刷新 7 天有效期。
- 每台设备最多同时安装约 **3 个**免费签名的 App;Bundle ID 数量也有限制。
- 重签时如遇 Bundle ID 冲突或证书过期,在 Signing & Capabilities 里重新选 Team / 换唯一 Bundle ID 即可。
- 升级到**付费 Apple Developer Program**($99/年)后,证书有效期为 1 年,可免去频繁重签。
