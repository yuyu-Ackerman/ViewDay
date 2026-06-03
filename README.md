# ViewDay

ViewDay 是一款 iOS 日记与账本应用。它把每天的文字记录、情绪、地点、天气、图片、语音和收支流水放在同一个时间上下文里，方便回看一天发生了什么，也能按月查看账本统计。

## 功能

- 首页：展示所选日期的位置、天气、日记摘要和当日收支。
- 日记：支持日记列表、筛选、搜索、详情、编辑、收藏、草稿和标签。
- 记录：在同一入口中创建日记或账本流水，支持图片、语音、地点、天气和标签。
- 账本：支持收入/支出记录、月度汇总、分类占比、余额走势和流水详情。
- 附件：图片和音频保存到本地附件目录，并通过 Core Data 维护元数据。
- 位置与天气：支持自动定位、反地理编码、自动天气获取，也支持手动填写。

## 技术栈

- Swift
- UIKit
- Core Data
- SnapKit 5.7.1
- CoreLocation
- AVFoundation
- PhotosUI
- WeatherKit 可选兜底

## 运行方式

1. 使用 Xcode 打开 `ViewDay.xcodeproj`。
2. 等待 Swift Package Manager 拉取 SnapKit。
3. 选择 iOS Simulator 或真机运行 `ViewDay` scheme。

如果需要自动获取位置、天气或录音，请在系统弹窗中授权定位和麦克风权限。天气服务优先使用 Open-Meteo 和 wttr.in；当 `Info.plist` 中启用 WeatherKit 且系统支持时，会作为兜底来源。

## 目录结构

```text
ViewDay/
├── Features/          # 首页、日记、记录、账本和主 Tab
├── Models/            # 领域模型
├── Persistence/       # Core Data 栈、默认数据、字段映射
├── Repositories/      # 日记、账本、附件、标签、账户等仓储
├── Services/          # 定位、天气、附件存储、录音服务
├── Shared/            # 通用组件和主题
└── Assets.xcassets/   # App 图标和资源
```

## 数据设计

应用采用本地优先的数据策略。领域模型中保留了 `remoteId`、`syncStatus`、`deletedAt` 等字段，为后续接入云同步预留空间。删除操作使用软删除，避免未来同步前丢失删除语义。

## 测试

仓库包含 Core Data 仓储相关测试：

```text
ViewDayTests/Persistence/RepositoryTests.swift
```

可在 Xcode 中运行测试，或使用 `xcodebuild test` 指定模拟器执行。

## 注释规范

项目注释遵循工程级 Swift/UIKit 注释规范：注释解释意图、设计原因、复杂逻辑、使用方式和注意事项，避免重复简单代码本身。
