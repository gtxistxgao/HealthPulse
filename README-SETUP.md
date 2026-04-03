# HealthPulse - 项目设置指南

## 一键设置（推荐）

打开 Mac 的终端（Terminal），运行以下命令：

```bash
cd ~/path/to/HealthPulse    # 替换成这个文件夹的实际路径
chmod +x setup.sh
./setup.sh
```

脚本会自动完成以下操作：
1. 安装 Homebrew（如果没有）
2. 安装 XcodeGen（项目生成工具）
3. 根据 `project.yml` 自动生成 `HealthPulse.xcodeproj`
4. 用 Xcode 打开项目

**生成完成后你只需要做一件事：** 在 Xcode 中设置你的开发者 Team：
- 点击左侧项目名 → 选择 HealthPulse target → Signing & Capabilities → Team 选择你的 Apple ID

然后连接 iPhone，按 Cmd+R 就能编译运行了。

---

## 项目结构

```
HealthPulse/
├── project.yml                ← XcodeGen 配置（定义 targets、权限等）
├── setup.sh                   ← 一键设置脚本
├── Shared/                    ← iPhone 和 Watch 共享代码
│   ├── Models/                  6 个数据模型
│   ├── Services/                5 个核心服务（HealthKit + 算法）
│   └── Extensions/              工具扩展
├── iPhone/                    ← iPhone App
│   ├── App/                     入口 + Info.plist + Entitlements
│   ├── ViewModels/              2 个 ViewModel
│   └── Views/                   5 个界面 + 共享组件
└── Watch/                     ← Apple Watch App
    ├── App/                     入口 + Info.plist + Entitlements
    └── Views/                   Watch 仪表盘
```

## 六大功能模块

| 模块 | 算法 | 文件 |
|------|------|------|
| **Recovery** | HRV(60%) + RHR(40%) vs 60天基线 → 0-100% | RecoveryCalculator.swift |
| **Sleep** | 时长/深度/REM/效率/中断/入睡 加权评分 → 0-100% | SleepAnalyzer.swift |
| **Exertion** | TRIMP: 心率区间×权重×时间 → 0-10 | ExertionCalculator.swift |
| **Energy** | HealthKit 直接读取 active + basal 卡路里 | HealthKitManager.swift |
| **Journal** | SwiftData 本地存储 + 影响分析 | JournalEntry.swift |
| **Health** | 各指标 vs 60天基线 ±2σ 异常检测 | HealthMonitor.swift |

## 系统要求

- macOS + Xcode 15+
- iPhone（iOS 17.0+）
- Apple Watch（watchOS 10.0+）— 用于采集健康数据
- 免费 Apple ID（自用测试不需要付费开发者账号）

## 注意事项

- 模拟器没有真实健康数据，界面会显示 "No Data"，需要真机测试
- 首次运行需要在 Health App 中允许 HealthPulse 读取数据
- Recovery 和 Exertion 算法需要积累 7-60 天的历史数据才能建立准确的个人基线
- 免费开发者账号安装的 App 每 7 天需要重新安装（付费 $99/年则不需要）
