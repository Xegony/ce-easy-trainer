unit MainGUIUnit;

{$mode delphi}

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes,
  Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Menus, Dialogs,
  LCLType, LCLIntf, Buttons, Grids;

type
  TMainForm = class(TForm)
    PanelTop: TPanel;
    PanelMain: TPanel;
    PanelBottom: TPanel;
    BtnAttach: TButton;
    BtnAdd: TButton;
    BtnApply: TButton;
    BtnSave: TButton;
    BtnLoad: TButton;
    BtnAutoPtr: TButton;
    BtnRefresh: TButton;
    StringGrid: TStringGrid;
    StatusBar: TStatusBar;
    GroupBox1: TGroupBox;
    LblProcess: TLabel;
    CmbProcess: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnAttachClick(Sender: TObject);
    procedure BtnAddClick(Sender: TObject);
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnLoadClick(Sender: TObject);
    procedure BtnAutoPtrClick(Sender: TObject);
  private
    ProcessHandle: THandle;
    ProcessID: DWORD;
    ProcessName: string;
    Entries: TList;
    procedure RefreshProcessList;
    procedure AddLog(const S: string);
    function AttachProcess: Boolean;
    procedure UpdateGrid;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  TH32CS_SNAPPROCESS = $00000002;
  TH32CS_SNAPMODULE = $00000008;
  MAX_PATH = 260;
  MAX_MODULE_NAME32 = 255;
  PROCESS_VM_READ = $0010;
  PROCESS_VM_WRITE = $0020;
  PROCESS_VM_OPERATION = $0008;
  PROCESS_QUERY_INFORMATION = $0400;
  PAGE_READONLY = $02;
  PAGE_READWRITE = $04;
  PAGE_WRITECOPY = $08;
  PAGE_EXECUTE_READ = $20;
  PAGE_EXECUTE_READWRITE = $40;
  PAGE_EXECUTE_WRITECOPY = $80;
  PAGE_GUARD = $100;
  PAGE_NOACCESS = $01;
  MEM_COMMIT = $1000;

type
  TProcessEntry32 = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: ULONG_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: LONG;
    dwFlags: DWORD;
    szExeFile: array [0..MAX_PATH - 1] of AnsiChar;
  end;

  TModuleEntry32 = record
    dwSize: DWORD;
    th32ModuleID: DWORD;
    th32ProcessID: DWORD;
    GlblcntUsage: DWORD;
    ProccntUsage: DWORD;
    modBaseAddr: PByte;
    modBaseSize: DWORD;
    hModule: HMODULE;
    szModule: array [0..MAX_MODULE_NAME32] of AnsiChar;
    szExePath: array [0..MAX_PATH - 1] of AnsiChar;
  end;

  TModuleInfo = record
    Name: string;
    BaseAddress: PtrUInt;
    Size: Cardinal;
  end;

  PMemEntry = ^TMemEntry;
  TMemEntry = record
    Description: string;
    Address: PtrUInt;
    Value: Int64;
    ValueType: Integer;
    Frozen: Boolean;
    ModuleName: string;
    ModuleOffset: PtrUInt;
    UseModuleOffset: Boolean;
    UsePointer: Boolean;
    PointerAddress: PtrUInt;
    PointerModuleName: string;
    PointerModuleOffset: PtrUInt;
    PointerOffset: PtrInt;
  end;

var
  Modules: array of TModuleInfo;

function CreateToolhelp32Snapshot(dwFlags: DWORD; th32ProcessID: DWORD): THandle; stdcall;
  external 'kernel32.dll' name 'CreateToolhelp32Snapshot';
function Process32First(hSnapshot: THandle; var lppe: TProcessEntry32): BOOL; stdcall;
  external 'kernel32.dll' name 'Process32First';
function Process32Next(hSnapshot: THandle; var lppe: TProcessEntry32): BOOL; stdcall;
  external 'kernel32.dll' name 'Process32Next';
function Module32First(hSnapshot: THandle; var lpme: TModuleEntry32): BOOL; stdcall;
  external 'kernel32.dll' name 'Module32First';
function Module32Next(hSnapshot: THandle; var lpme: TModuleEntry32): BOOL; stdcall;
  external 'kernel32.dll' name 'Module32Next';
function VirtualQueryEx(hProcess: THandle; lpAddress: Pointer; var lpBuffer: MEMORY_BASIC_INFORMATION; dwLength: SIZE_T): SIZE_T; stdcall;
  external 'kernel32.dll' name 'VirtualQueryEx';

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  ProcessHandle := 0;
  ProcessID := 0;
  ProcessName := '';
  Entries := TList.Create;
  
  // 设置Grid
  StringGrid.ColCount := 5;
  StringGrid.RowCount := 2;
  StringGrid.FixedRows := 1;
  StringGrid.Cells[0, 0] := '描述';
  StringGrid.Cells[1, 0] := '地址';
  StringGrid.Cells[2, 0] := '值';
  StringGrid.Cells[3, 0] := '冻结';
  StringGrid.Cells[4, 0] := '类型';
  
  // 设置窗口
  Caption := 'CE Easy Trainer - GUI版';
  Width := 800;
  Height := 500;
  Position := poScreenCenter;
  
  RefreshProcessList;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  if ProcessHandle <> 0 then
    CloseHandle(ProcessHandle);
  for i := Entries.Count - 1 downto 0 do
    Dispose(PMemEntry(Entries[i]));
  Entries.Free;
end;

procedure TMainForm.AddLog(const S: string);
begin
  StatusBar.SimpleText := S;
  Application.ProcessMessages;
end;

procedure TMainForm.RefreshProcessList;
var
  hSnapshot: THandle;
  pe32: TProcessEntry32;
begin
  CmbProcess.Items.Clear;
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hSnapshot = INVALID_HANDLE_VALUE then
  begin
    AddLog('无法获取进程列表');
    Exit;
  end;
  
  pe32.dwSize := SizeOf(TProcessEntry32);
  if Process32First(hSnapshot, pe32) then
  begin
    repeat
      CmbProcess.Items.Add(Format('%s (PID: %d)', [pe32.szExeFile, pe32.th32ProcessID]));
    until not Process32Next(hSnapshot, pe32);
  end;
  
  CloseHandle(hSnapshot);
  AddLog(Format('找到 %d 个进程', [CmbProcess.Items.Count]));
end;

procedure TMainForm.BtnRefreshClick(Sender: TObject);
begin
  RefreshProcessList;
end;

function TMainForm.AttachProcess: Boolean;
var
  s: string;
  p: Integer;
  PID: DWORD;
begin
  Result := False;
  if CmbProcess.ItemIndex < 0 then
  begin
    ShowMessage('请先选择一个进程');
    Exit;
  end;
  
  s := CmbProcess.Items[CmbProcess.ItemIndex];
  p := Pos('(PID: ', s);
  if p <= 0 then Exit;
  
  PID := StrToIntDef(Copy(s, p + 6, Length(s) - p - 6), 0);
  if PID = 0 then Exit;
  
  if ProcessHandle <> 0 then
    CloseHandle(ProcessHandle);
  
  ProcessHandle := OpenProcess(
    PROCESS_VM_READ or PROCESS_VM_WRITE or PROCESS_VM_OPERATION or PROCESS_QUERY_INFORMATION,
    False, PID);
  
  if ProcessHandle = 0 then
  begin
    ShowMessage('无法附加到进程');
    Exit;
  end;
  
  ProcessID := PID;
  ProcessName := Trim(Copy(s, 1, p - 1));
  Result := True;
  AddLog(Format('已附加: %s (PID: %d)', [ProcessName, ProcessID]));
end;

procedure TMainForm.BtnAttachClick(Sender: TObject);
begin
  if AttachProcess then
    BtnAttach.Caption := '已附加'
  else
    BtnAttach.Caption := '附加进程';
end;

procedure TMainForm.BtnAddClick(Sender: TObject);
var
  Entry: PMemEntry;
  Desc, AddrStr, ValStr: string;
begin
  if ProcessHandle = 0 then
  begin
    ShowMessage('请先附加到进程');
    Exit;
  end;
  
  Desc := InputBox('添加地址', '描述:', '新地址');
  AddrStr := InputBox('添加地址', '地址 (十六进制):', '0');
  ValStr := InputBox('添加地址', '值:', '0');
  
  New(Entry);
  Entry^.Description := Desc;
  Entry^.Address := StrToInt64Def('$' + AddrStr, 0);
  Entry^.Value := StrToInt64Def(ValStr, 0);
  Entry^.ValueType := 0;
  Entry^.Frozen := False;
  Entry^.UseModuleOffset := False;
  Entry^.UsePointer := False;
  
  Entries.Add(Entry);
  UpdateGrid;
  AddLog(Format('已添加: %s', [Desc]));
end;

procedure TMainForm.UpdateGrid;
var
  i: Integer;
  Entry: PMemEntry;
begin
  StringGrid.RowCount := Entries.Count + 1;
  for i := 0 to Entries.Count - 1 do
  begin
    Entry := PMemEntry(Entries[i]);
    StringGrid.Cells[0, i + 1] := Entry^.Description;
    StringGrid.Cells[1, i + 1] := IntToHex(Entry^.Address, 8);
    StringGrid.Cells[2, i + 1] := IntToStr(Entry^.Value);
    StringGrid.Cells[3, i + 1] := IfThen(Entry^.Frozen, '是', '否');
    StringGrid.Cells[4, i + 1] := IfThen(Entry^.UsePointer, '指针', IfThen(Entry^.UseModuleOffset, '模块', '绝对'));
  end;
end;

function IfThen(AValue: Boolean; const ATrue, AFalse: string): string;
begin
  if AValue then Result := ATrue else Result := AFalse;
end;

procedure TMainForm.BtnApplyClick(Sender: TObject);
begin
  if ProcessHandle = 0 then
  begin
    ShowMessage('请先附加到进程');
    Exit;
  end;
  
  ShowMessage('应用功能 - 需要实现内存写入');
  AddLog('应用修改');
end;

procedure TMainForm.BtnSaveClick(Sender: TObject);
begin
  ShowMessage('保存功能 - 需要实现文件保存');
  AddLog('保存表');
end;

procedure TMainForm.BtnLoadClick(Sender: TObject);
begin
  ShowMessage('加载功能 - 需要实现文件加载');
  AddLog('加载表');
end;

procedure TMainForm.BtnAutoPtrClick(Sender: TObject);
begin
  if ProcessHandle = 0 then
  begin
    ShowMessage('请先附加到进程');
    Exit;
  end;
  
  if Entries.Count = 0 then
  begin
    ShowMessage('请先添加地址');
    Exit;
  end;
  
  ShowMessage('自动指针功能 - 需要实现指针扫描');
  AddLog('自动查找指针');
end;

end.
