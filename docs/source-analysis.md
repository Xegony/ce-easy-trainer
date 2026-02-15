# T001/T002 - Cheat Engine源码与关键模块分析

## 源码结构结论
- 主工程位于 `cheat-engine/Cheat Engine/`
- 关键入口：`MainUnit.pas`
- 表格式读写：`OpenSave.pas`
- 地址记录与激活逻辑：`MemoryRecordUnit.pas`
- Trainer生成：`frmExeTrainerGeneratorUnit.pas`

## 与CE Easy Trainer相关的核心模块
1. **UI与交互**
   - `MainUnit.pas`
   - `addresslist*.pas`
2. **内存记录模型**
   - `MemoryRecordUnit.pas`
   - `memrecDataStructures.pas`
3. **CT兼容读写**
   - `OpenSave.pas`
4. **扫描与定位能力**
   - `memscan.pas`
   - `simpleaobscanner.pas`
   - `symbolhandler.pas`
5. **Trainer导出**
   - `frmExeTrainerGeneratorUnit.pas`

## 二次开发落点
- 在不破坏原有`.CT`结构的前提下，新增“智能持久化”元数据
- 新增轻量入口单元，保留原有复杂界面代码以保证兼容
- 通过可选功能开关注入，不改变旧表行为
