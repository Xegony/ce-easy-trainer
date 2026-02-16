# T009 - CE Easy Trainer Quick Start

## 1) 准备
- 使用Windows + Lazarus/FPC环境
- 打开CE工程并包含新增单元：
  - SmartPersistenceUnit
  - EasyTrainerMainUnit
  - CTEasyCompatibilityUnit
  - AutoReattachUnit

## 2) 使用流程
1. 启动Easy Trainer UI
2. 点击 `Attach Game`
3. 加载`.CT`表并点击 `Enable Preset`
4. 系统自动选择持久化策略（指针/AOB/模块偏移）
5. 点击 `Export Trainer` 生成trainer

## 3) 兼容性说明
- 继续兼容原`.CT`结构
- 扩展信息写在`Extensions/CEEasyTrainer`节点，旧版可忽略

## 4) 自动重连
- 可配置目标进程名
- 游戏重启后后台线程轮询并触发重新附加
