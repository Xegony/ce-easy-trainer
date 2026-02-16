# T005-T007 实现说明

## T005 简化主界面
- 新增 `EasyTrainerMainUnit.pas`
- 提供三按钮流程：Attach / Enable Preset / Export Trainer
- 设计为“委托式”：复用原MainUnit和生成器逻辑，减少破坏

## T006 CT表兼容
- 新增 `CTEasyCompatibilityUnit.pas`
- 在`MemoryRecord`节点下新增可选`Extensions/CEEasyTrainer`元数据
- 不修改原字段语义，旧版CE读取时可忽略扩展节点

## T007 游戏重启后自动重连
- 新增 `AutoReattachUnit.pas`
- 后台线程轮询进程名，命中后触发重连回调
- 当前为可接入骨架，方便后续接入CE真实attach流程
