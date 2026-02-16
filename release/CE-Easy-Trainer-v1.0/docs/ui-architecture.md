# T003 - Simplified UI Architecture (One-Click Trainer)

## 目标
- 保留CE底层能力
- 默认只暴露“一键附加/一键应用”路径
- 隐藏高级扫描器、调试器、脚本入口（高级模式可再开启）

## 分层设计
1. **Easy Shell层**
   - 新的轻量主界面承载核心按钮：
     - Attach Game
     - Apply Preset / Enable All
     - Save Trainer
2. **Compatibility Adapter层**
   - 复用`TMemoryRecord`和AddressList
   - 与`OpenSave`保持同一读写逻辑
3. **Engine层（沿用CE）**
   - 扫描、注入、符号解析、CT读写均复用原有实现

## UI状态流
1. 启动后自动提示附加进程
2. 加载CT后自动评估每条记录的持久化策略
3. 游戏重启后自动重连并重算地址
4. 用户只看到“已就绪/需重试”等状态

## 与原界面的兼容策略
- 不删除原MainUnit复杂功能代码
- 新增Easy入口及可选开关（默认Easy）
- 若检测到开发参数，可切回原UI
