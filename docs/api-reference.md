# CE Easy Trainer API 参考

## 核心单元

### SmartPersistenceUnit

智能持久化引擎，自动选择最佳地址持久化策略。

#### 类型

##### TPersistenceMethod

```pascal
type
  TPersistenceMethod = (
    pmNone,           // 无持久化方法
    pmPointerChain,   // 指针链：静态基址 + 偏移链
    pmAOB,            // AOB 签名：字节特征码扫描
    pmModuleOffset,   // 模块偏移：DLL/EXE 基址 + 相对偏移
    pmHybrid          // 混合：多策略组合
  );
```

##### TPersistenceInfo

```pascal
type
  TPersistenceInfo = record
    Method: TPersistenceMethod;       // 使用的持久化方法
    Success: Boolean;                 // 是否成功分析
    LastAddress: PtrUInt;             // 最后解析的地址
    LastVerified: TDateTime;          // 最后验证时间
    Confidence: Integer;              // 置信度 (0-100)

    // 方法特定数据
    PointerBase: PtrUInt;             // 指针链基址
    PointerOffsets: array of Integer; // 指针偏移数组
    AOBSignature: String;             // AOB 签名字符串
    AOBMask: String;                  // AOB 掩码
    ModuleName: String;               // 模块名称
    ModuleOffset: PtrUInt;            // 模块偏移
  end;
```

##### TSmartEntry

```pascal
type
  PSmartEntry = ^TSmartEntry;
  TSmartEntry = record
    OriginalAddress: PtrUInt;         // 原始地址
    Value: UInt64;                    // 当前值
    ValueType: Integer;               // 值类型 (0=int, 1=float, 2=double, 3=string)
    Description: String;              // 描述
    Persistence: TPersistenceInfo;    // 持久化信息
    AutoReapply: Boolean;             // 是否自动重应用
    LastError: String;                // 最后错误
  end;
```

#### 函数

##### AnalyzeAddress

```pascal
function AnalyzeAddress(Address: PtrUInt): TPersistenceInfo;
```

分析地址并返回最佳持久化方法。

**参数:**
- `Address`: 要分析的内存地址

**返回:**
- `TPersistenceInfo`: 包含持久化方法和置信度的信息

**示例:**
```pascal
var
  info: TPersistenceInfo;
begin
  info := AnalyzeAddress($140001000);
  WriteLn('Method: ', Ord(info.Method));
  WriteLn('Confidence: ', info.Confidence);
end;
```

##### ResolvePersistentAddress

```pascal
function ResolvePersistentAddress(var Info: TPersistenceInfo): PtrUInt;
```

使用持久化信息解析当前地址。

**参数:**
- `Info`: 持久化信息（in/out）

**返回:**
- `PtrUInt`: 解析后的地址，失败返回 0

**示例:**
```pascal
var
  addr: PtrUInt;
begin
  addr := ResolvePersistentAddress(info);
  if addr > 0 then
    WriteLn('Resolved address: ', IntToHex(addr, 8));
end;
```

##### CreateSmartEntry

```pascal
function CreateSmartEntry(Address: PtrUInt; Value: UInt64;
  ValueType: Integer; Description: String): PSmartEntry;
```

创建智能条目并自动分析持久化方法。

**参数:**
- `Address`: 内存地址
- `Value`: 当前值
- `ValueType`: 值类型
- `Description`: 描述

**返回:**
- `PSmartEntry`: 智能条目指针

##### SaveSmartTable / LoadSmartTable

```pascal
procedure SaveSmartTable(Filename: String; Entries: TList);
procedure LoadSmartTable(Filename: String; Entries: TList);
```

保存/加载智能表到文件。

**文件格式:** INI 格式
```ini
[SmartTable v1.0]
Count=2

[Entry0]
Description=Health
OriginalAddress=140001000
Value=100
ValueType=0
AutoReapply=true
PersistenceMethod=3
Confidence=85
ModuleName=game.exe
ModuleOffset=00001000

[Entry1]
Description=Ammo
...
```

---

### EasyTrainerMainUnit

简化主流程状态机控制器。

#### 类型

##### TEasyTrainerState

```pascal
type
  TEasyTrainerState = (
    etsIdle,          // 空闲
    etsAttaching,     // 正在附加
    etsAttached,      // 已附加
    etsTableLoaded,   // 表已加载
    etsPresetEnabled, // 预设已启用
    etsExported,      // 已导出
    etsError          // 错误
  );
```

##### ITrainerBackend

```pascal
type
  ITrainerBackend = interface
    ['{A405A4AE-352A-466C-B3DD-B24968B347CC}']
    function AttachGame(const ProcessName: String; out Err: String): Boolean;
    function LoadCT(const FileName: String; out Err: String): Boolean;
    function EnablePreset(const PresetName: String; out Err: String): Boolean;
    function ExportTrainer(const OutputFile: String; out Err: String): Boolean;
  end;
```

##### TEasyTrainerController

```pascal
type
  TEasyTrainerController = class
  public
    constructor Create(const ABackend: ITrainerBackend);

    function Attach(const ProcessName: String): Boolean;
    function LoadTable(const FileName: String): Boolean;
    function ApplyPreset(const PresetName: String): Boolean;
    function Export(const OutputFile: String): Boolean;

    property State: TEasyTrainerState read FState;
    property LastError: String read FLastError;
  end;
```

#### 使用示例

```pascal
var
  backend: ITrainerBackend;
  controller: TEasyTrainerController;
begin
  backend := TCEBackendAdapter.Create;
  controller := TEasyTrainerController.Create(backend);

  try
    if not controller.Attach('game.exe') then
      raise Exception.Create(controller.LastError);

    if not controller.LoadTable('cheats.ct') then
      raise Exception.Create(controller.LastError);

    if not controller.ApplyPreset('default') then
      raise Exception.Create(controller.LastError);

    if not controller.Export('trainer.exe') then
      raise Exception.Create(controller.LastError);
  finally
    controller.Free;
  end;
end;
```

---

### AutoReattachUnit

进程自动重连服务。

#### 类型

##### IProcessProbe

```pascal
type
  IProcessProbe = interface
    ['{755A2444-B5E9-4A92-9D5A-8E8FB8C9D6F4}']
    function IsProcessRunning(const ProcessName: String): Boolean;
  end;
```

##### TReattachLogProc / TOnReattachProc

```pascal
type
  TReattachLogProc = procedure(const Msg: String) of object;
  TOnReattachProc = procedure of object;
```

##### TAutoReattachService

```pascal
type
  TAutoReattachService = class
  public
    constructor Create(const AProcessName: String; const AProbe: IProcessProbe);

    procedure Tick;
    procedure Start;
    procedure Stop;

    property Enabled: Boolean read FEnabled;
    property OnReattach: TOnReattachProc read FOnReattach write FOnReattach;
    property OnLog: TReattachLogProc read FOnLog write FOnLog;
    property MinReattachIntervalTicks: QWord read FMinReattachIntervalTicks write FMinReattachIntervalTicks;
  end;
```

#### 使用示例

```pascal
type
  TMyForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FService: TAutoReattachService;
    procedure OnReattachCallback;
    procedure OnLogCallback(const Msg: String);
  end;

procedure TMyForm.FormCreate(Sender: TObject);
begin
  FService := TAutoReattachService.Create('game.exe', TCEProcessProbe.Create);
  FService.OnReattach := @OnReattachCallback;
  FService.OnLog := @OnLogCallback;
  FService.MinReattachIntervalTicks := 10;
  FService.Start;
end;

procedure TMyForm.Timer1Timer(Sender: TObject);
begin
  if Assigned(FService) then
    FService.Tick;
end;
```

---

### CTEasyCompatibilityUnit

CT 表扩展兼容层。

#### 类型

##### TCEEasyMetadata

```pascal
type
  TCEEasyMetadata = record
    Version: String;              // 版本号
    AutoReattach: Boolean;        // 是否自动重连
    PreferredStrategy: String;    // 首选策略 (auto|pointer|aob|module|hybrid)
    Notes: String;                // 备注
  end;
```

#### 函数

##### DefaultMetadata

```pascal
function DefaultMetadata: TCEEasyMetadata;
```

返回默认元数据。

##### InjectOrUpdateMetadata

```pascal
function InjectOrUpdateMetadata(const CTXml: String; const Meta: TCEEasyMetadata): String;
```

在 CT XML 中注入或更新元数据。

**参数:**
- `CTXml`: 原始 CT XML 字符串
- `Meta`: 要注入的元数据

**返回:**
- `String`: 包含元数据的新 XML

##### TryParseMetadata

```pascal
function TryParseMetadata(const CTXml: String; out Meta: TCEEasyMetadata): Boolean;
```

尝试从 CT XML 中解析元数据。

**参数:**
- `CTXml`: CT XML 字符串
- `Meta`: 输出元数据

**返回:**
- `Boolean`: 是否成功解析

#### 使用示例

```pascal
var
  xml, newXml: String;
  meta, parsed: TCEEasyMetadata;
  success: Boolean;
begin
  // 设置元数据
  meta := DefaultMetadata;
  meta.AutoReattach := True;
  meta.PreferredStrategy := 'hybrid';
  meta.Notes := 'Generated by CE Easy Trainer';

  // 注入到 CT
  newXml := InjectOrUpdateMetadata(xml, meta);

  // 解析元数据
  success := TryParseMetadata(newXml, parsed);
  if success then
    WriteLn('Strategy: ', parsed.PreferredStrategy);
end;
```

---

### CEBackendAdapter

CE 后端适配器（仅 Windows）。

#### 类型

##### TCEBackendAdapter

```pascal
type
  TCEBackendAdapter = class(TInterfacedObject, ITrainerBackend)
  public
    function AttachGame(const ProcessName: String; out Err: String): Boolean;
    function LoadCT(const FileName: String; out Err: String): Boolean;
    function EnablePreset(const PresetName: String; out Err: String): Boolean;
    function ExportTrainer(const OutputFile: String; out Err: String): Boolean;

    property LastProcessId: THandle read FLastProcessId;
    property LastProcessHandle: THandle read FLastProcessHandle;
  end;
```

##### TCEProcessProbe

```pascal
type
  TCEProcessProbe = class(TInterfacedObject, IProcessProbe)
  public
    function IsProcessRunning(const ProcessName: String): Boolean;
  end;
```

---

## 错误处理

所有函数都通过返回值和 `out Err` 参数报告错误。

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `Backend not assigned` | 未设置后端 | 调用 `Create(backend)` 时传入有效后端 |
| `AttachGame requires Windows with CE core` | 在非 Windows 环境调用 | 仅在 Windows 上使用 CE 适配器 |
| `Load CT failed: File not found` | 文件不存在 | 检查文件路径 |
| `EnablePreset requires table loaded` | 状态不正确 | 先调用 `LoadTable` |

---

## 版本兼容性

| 组件 | FPC | Lazarus | CE |
|------|-----|---------|-----|
| 核心单元 | 3.2.2+ | - | - |
| CE 适配器 | 3.2.2+ | 2.2.6+ | 7.5+ |

---

## 性能建议

1. **持久化分析**: `AnalyzeAddress` 可能耗时，建议后台线程执行
2. **自动重连**: 使用适当的 `MinReattachIntervalTicks` 避免高频检测
3. **大表加载**: `LoadSmartTable` 对于大型表（1000+ 条目）建议分批处理
