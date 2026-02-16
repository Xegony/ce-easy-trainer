# T004 - 智能持久化引擎实现

已新增：`cheat-engine/Cheat Engine/SmartPersistenceUnit.pas`

## 提供能力
- `TPersistenceMethod = (pmPointerChain, pmAOB, pmModuleOffset, pmHybrid)`
- `FindBestPersistence(address)`：根据评分自动选择最优策略
- `BuildPersistence(address)`：返回方法与置信度及可用元数据
- `GenerateAOBPattern`：读取目标地址附近字节生成AOB
- `ResolveModuleOffset`：计算模块基址+偏移

## 选择策略（当前实现）
1. Pointer链评分（占位，后续可接CE Pointer Scanner结果）
2. AOB评分（可读取到稳定字节则加分）
3. 模块偏移评分（模块解析成功且偏移合理则高分）
4. 双高分触发`pmHybrid`

## 后续增强点
- 接入真实指针扫描结果缓存
- AOB唯一性验证（全内存段扫描冲突检测）
- 跨版本稳定性历史评分（多次启动统计）
