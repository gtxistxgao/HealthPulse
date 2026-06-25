# T107 — Dashboard 接入设置入口 · 运行验证

**任务**：在 DashboardView 的 NavigationStack 顶部工具栏加齿轮按钮,导航/弹出到 SettingsView。

**验证方式**：实际构建并运行 App,在已启动的 iOS 模拟器上端到端走完齿轮入口 + 语言切换流程,逐步截图。
**复现脚本**：[`verify.sh`](./verify.sh)(`bash evidence/T107/verify.sh`)

| 项 | 值 |
|----|----|
| 运行时间 | 2026-06-25 12:16:56 PDT |
| 设备 | iPhone 17 Pro Max · iOS 26.5 (UDID 3E86C1BB-3159-4A85-8BB1-43B2501BCBE3) |
| App | com.healthpulse.HealthPulse (Debug, iphonesimulator) |
| 构建 | `xcodebuild ... build` → **BUILD SUCCEEDED** |
| UI 驱动 | idb(`idb ui tap` / `swipe` 直接向模拟器注入触摸;沙箱内 AppleScript/辅助功能不可用) |

## 实现位置

- `iPhone/Views/Dashboard/DashboardView.swift` — `.toolbar` 内 `.topBarTrailing` 放置 `Image(systemName: "gearshape")` 按钮,点击置 `isShowingSettings = true`;`.sheet(isPresented:)` 弹出 `SettingsView()`。
- `iPhone/Views/Settings/SettingsView.swift` — 语言选择列表,行点击调用 `LocalizationManager.setLanguage(...)`。
- `Shared/Services/LocalizationManager.swift` — 选择持久化于 `UserDefaults.standard` 键 `HealthPulse.selectedLanguage`,republish 后 Dashboard(观察 `@EnvironmentObject`)实时重渲染。

## 步骤与凭证

| # | 步骤 | 截图 | 观察 |
|---|------|------|------|
| 0 | 启动,系统 HealthKit 授权弹窗 | [`01-healthkit-auth.png`](./01-healthkit-auth.png) | 授权 sheet 出现 |
| 1 | 处理授权(Turn On All → Allow)进入首页 | [`02-dashboard-en.png`](./02-dashboard-en.png) | **Rubric ①**:英文 "Today" 首页,**右上角齿轮按钮可见**(idb 实测 frame x≈382 y≈66) |
| 2 | 点击齿轮 | [`03-settings-en.png`](./03-settings-en.png) | **Rubric ②**:弹出 **SettingsView**("Settings / Language",Follow System 勾选) |
| 3 | 在 Settings 选择 "简体中文" | [`04-settings-zh.png`](./04-settings-zh.png) | Settings 即时变中文("设置 / 语言 / 跟随系统"),勾选移到简体中文 |
| 4 | 下滑关闭 sheet 返回首页 | [`05-dashboard-zh.png`](./05-dashboard-zh.png) | **Rubric ③**:首页文案全面变中文 |

## Rubric ③ 前后对比(同一 Dashboard,仅切换语言)

| 英文 (02) | 中文 (05) |
|-----------|-----------|
| Today | 今日 |
| Recovery / Energy / Sleep / Load | 恢复 / 能量 / 睡眠 / 消耗负荷 |
| Collecting data | 数据积累中 |
| kcal · Active 0 · Resting 0 | 千卡 · 活动 0 · 静息 0 |
| Coming soon | 即将上线 |
| Vitals | 生理指标 |
| Heart Rate Variability / Resting Heart Rate / Blood Oxygen / Respiratory Rate | 心率变异性 / 静息心率 / 血氧 / 呼吸频率 |
| ms / bpm / % / br/min | ms / 次/分 / % / 次/分 |

三项 Rubric 均在运行的真实 App 中得到验证。
