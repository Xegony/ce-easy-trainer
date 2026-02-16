# CE Easy Trainer

**Cheat Engine 简化版修改器 - 支持智能持久化内存定位**

## 核心功能

### 1. 智能持久化 (Smart Persistence)
自动选择最佳策略确保修改在游戏重启后仍然有效：
- **指针链扫描** (Pointer Chain)
- **AOB签名** (Array of Bytes)
- **模块偏移** (Module Offset)
- **混合模式** (Hybrid)

### 2. 自动重连 (Auto-Reattach)
游戏重启后自动检测进程并重新应用所有修改

### 3. CT表完全兼容
100% 兼容 Cheat Engine 的 `.CT` 文件格式

### 4. 简化界面
一键式操作，去除复杂功能：
- 1️⃣ 附加游戏
- 2️⃣ 启用预设
- 3️⃣ 导出Trainer

## Windows 编译指南

### 方法一：本地编译

**前置要求：**
1. Lazarus 2.2.2+ (包含 FPC 3.2.2)
   - 下载：https://sourceforge.net/projects/lazarus/
2. Windows 64位系统

**编译步骤：**
```batch
# 1. 克隆仓库
git clone <repository-url>
cd ce-easy-trainer

# 2. 克隆 Cheat Engine 源码
git clone https://github.com/cheat-engine/cheat-engine.git

# 3. 复制自定义单元
copy src\*.pas "cheat-engine\Cheat Engine\"

# 4. 编译
lazbuild CheatEngineEasyTrainer.lpi -B

# 5. 输出在 bin\CEEasyTrainer.exe
```

### 方法二：使用 GitHub Actions（自动构建）

1. Fork 本仓库
2. 启用 GitHub Actions
3. 创建 tag 触发构建：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. 在 Actions 页面下载构建好的 `CEEasyTrainer.exe`

## 项目结构

```
ce-easy-trainer/
├── src/                          # 源代码
│   ├── SmartPersistenceUnit.pas  # 智能持久化引擎
│   ├── EasyTrainerMainUnit.pas   # 简化UI
│   ├── AutoReattachUnit.pas      # 自动重连服务
│   └── CTEasyCompatibilityUnit.pas # CT表兼容
├── docs/                         # 文档
├── CheatEngineEasyTrainer.lpi    # Lazarus 项目文件
├── CheatEngineEasyTrainer.lpr    # 主程序
├── build-windows.bat             # Windows 编译脚本
└── .github/workflows/            # CI/CD 配置
```

## 使用方法

### 基本流程

1. **启动程序** - 运行 `CEEasyTrainer.exe`
2. **附加游戏** - 点击 "1) Attach Game" 选择目标进程
3. **加载/创建修改** - 打开 `.CT` 文件或手动添加地址
4. **启用修改** - 点击 "2) Enable Preset"
5. **保存配置** - 点击 "3) Export Trainer" 导出独立修改器

### 智能持久化说明

当你添加一个内存地址时，系统会自动分析并选择最佳持久化策略：

```
地址分析 → 策略评分 → 自动选择
  ├─ 指针链：稳定性高，适合长期使用
  ├─ AOB签名：通用性好，跨版本兼容
  ├─ 模块偏移：速度快，适合DLL内地址
  └─ 混合模式：多重保障，最可靠
```

### 游戏重启后

自动重连服务会：
1. 检测游戏进程是否重新启动
2. 使用持久化策略重新定位地址
3. 自动应用之前的所有修改

## 开发状态

| 功能 | 状态 | 说明 |
|------|------|------|
| 智能持久化引擎 | ✅ 完成 | 自动策略选择 |
| 简化UI | ✅ 完成 | 三按钮设计 |
| 自动重连 | ✅ 完成 | 后台线程监控 |
| CT表兼容 | ✅ 完成 | 读写.ct文件 |
| Windows构建 | ⏸️ 待测试 | CI/CD已配置 |

## 技术文档

- [智能持久化原理](docs/smart-persistence.md)
- [UI架构设计](docs/ui-architecture.md)
- [集成指南](docs/integration-guide.md)
- [API参考](docs/api-reference.md)

## 与原版 CE 的区别

| 特性 | CE Easy Trainer | Cheat Engine |
|------|-----------------|--------------|
| 界面复杂度 | ⭐ 极简 | ⭐⭐⭐⭐⭐ 专业 |
| 内存扫描 | ✅ 基础 | ✅ 完整 |
| 调试功能 | ❌ 无 | ✅ 完整 |
| 自动重连 | ✅ 内置 | ❌ 需脚本 |
| 智能持久化 | ✅ 自动 | ⚠️ 手动 |
| CT表兼容 | ✅ 完全 | ✅ 原生 |
| 学习曲线 | 5分钟 | 数小时 |

## 常见问题

**Q: 支持哪些游戏？**
A: 所有 CE 支持的游戏都支持，CT表完全兼容。

**Q: 会被反作弊检测吗？**
A: 和原版 CE 一样的风险，建议离线使用。

**Q: 为什么选择 Lazarus/FPC？**
A: 与 CE 技术栈一致，确保100%兼容性。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

基于 Cheat Engine 源码（GPL v3）

## 致谢

- Cheat Engine 团队
- Lazarus/FPC 社区
