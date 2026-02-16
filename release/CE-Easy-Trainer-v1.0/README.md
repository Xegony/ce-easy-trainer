# CE Easy Trainer

> Cheat Engine 简化修改器框架 - 自动持久化地址，一键应用预设

## 概述

CE Easy Trainer 是一个为 Cheat Engine 设计的扩展框架，提供：

- **智能持久化**：自动选择最佳地址持久化策略（指针链/AOB/模块偏移/混合）
- **简化 UI**：一键附加、一键应用、一键导出
- **CT 兼容**：完全兼容现有 `.CT` 表格格式
- **自动重连**：游戏重启后自动重新附加并重应用修改

## 快速开始

### 核心单元（无 CE 依赖）

```bash
# Linux 测试
fpc src/test_ce_easy_units.pas
./src/test_ce_easy_units
```

### Windows 完整构建

```cmd
# 编译所有组件
build-all.bat

# 运行测试
build-all.bat test

# 清理
build-all.bat clean
```

## 集成到 CE

详见 [集成指南](docs/integration-guide.md)

### 最小集成步骤

1. 将 `src/*.pas` 添加到 CE 工程
2. 在 `MainUnit.pas` 中初始化：
```pascal
uses
  EasyTrainerMainUnit, AutoReattachUnit, CEBackendAdapter;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FEasyTrainerController := TEasyTrainerController.Create(TCEBackendAdapter.Create);
  FAutoReattachService := TAutoReattachService.Create(ProcessName, TCEProcessProbe.Create);
end;
```

## 功能

### 智能持久化

自动为每条地址记录选择最佳持久化策略：

| 策略 | 描述 | 置信度 |
|------|------|--------|
| 指针链 | 静态基址 + 偏移链 | 70-85% |
| AOB 签名 | 字节特征码扫描 | 60-75% |
| 模块偏移 | DLL/EXE 基址 + 相对偏移 | 85-95% |
| 混合 | 多策略组合 | 95%+ |

### 自动重连

- 轮询检测进程状态
- 游戏重启后自动附加
- 重应用所有启用的修改

### CT 扩展

```xml
<CheatTable>
  <CheatEntries>...</CheatEntries>
  <Extensions>
    <CEEasyTrainer>
      <Version>1.0</Version>
      <AutoReattach>true</AutoReattach>
      <PreferredStrategy>hybrid</PreferredStrategy>
    </CEEasyTrainer>
  </Extensions>
</CheatTable>
```

## 文档

- [集成指南](docs/integration-guide.md) - 详细集成步骤
- [快速开始](docs/quick-start.md) - 使用说明
- [智能持久化](docs/smart-persistence.md) - 策略说明
- [UI 架构](docs/ui-architecture.md) - 设计文档
- [发布清单](docs/release-checklist.md) - 版本状态

## 状态

| 组件 | 状态 |
|------|------|
| 核心单元 | ✅ 完成 |
| 适配器 | ✅ 完成 |
| 测试 | ✅ 通过 |
| 文档 | ✅ 完成 |
| Windows 集成 | ⏳ 待验证 |

## 要求

- **核心单元**：FPC 3.2.2+
- **完整集成**：Windows 7+ + Lazarus 2.2.6+ + CE 7.5+ 源码

## 许可证

MIT License

## 相关项目

- [Cheat Engine](https://github.com/cheat-engine/cheat-engine)
