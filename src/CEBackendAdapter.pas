unit CEBackendAdapter;

{$mode DELPHI}

interface

uses
  SysUtils, Classes, EasyTrainerMainUnit, AutoReattachUnit;

type
  TCEBackendAdapter = class(TInterfacedObject, ITrainerBackend)
  private
    FLastProcessId: THandle;
    FLastProcessHandle: THandle;
    FLastError: String;
  public
    // ITrainerBackend
    function AttachGame(const ProcessName: String; out Err: String): Boolean;
    function LoadCT(const FileName: String; out Err: String): Boolean;
    function EnablePreset(const PresetName: String; out Err: String): Boolean;
    function ExportTrainer(const OutputFile: String; out Err: String): Boolean;

    property LastProcessId: THandle read FLastProcessId;
    property LastProcessHandle: THandle read FLastProcessHandle;
  end;

  TCEProcessProbe = class(TInterfacedObject, IProcessProbe)
  public
    function IsProcessRunning(const ProcessName: String): Boolean;
  end;

implementation

uses
  {$IFDEF WINDOWS}
  jwaWindows, Windows,
  {$ENDIF}
  NewKernelHandler, CEFuncProc, MainUnit, addresslist, OpenSave, MemoryRecordUnit;

{ TCEBackendAdapter }

function TCEBackendAdapter.AttachGame(const ProcessName: String; out Err: String): Boolean;
var
  pid: THandle;
  ph: THandle;
begin
  Result := False;
  Err := '';
  FLastProcessId := 0;
  FLastProcessHandle := 0;

  {$IFDEF WINDOWS}
  // 实际 CE 实现
  pid := 0;
  ph := 0;

  // 调用 CE 的进程打开逻辑
  // 这里需要适配 CE 的 MainUnit 中的进程选择/打开流程
  // 简化版：直接尝试打开进程名
  // 实际实现需要：枚举进程 -> 匹配名称 -> OpenProcess

  // 伪代码骨架（真实实现需接 CE 的 ProcessHandlerUnit）
  {
  if OpenProcessByName(ProcessName, pid, ph) then
  begin
    FLastProcessId := pid;
    FLastProcessHandle := ph;
    processid := pid;
    processhandle := ph;
    Result := True;
  end
  else
  begin
    Err := 'Failed to open process: ' + ProcessName;
  end;
  }

  // 当前骨架版本：标记为需要接入
  Err := 'CEBackendAdapter.AttachGame: requires CE ProcessHandler integration';
  {$ELSE}
  Err := 'AttachGame only available on Windows with CE core';
  {$ENDIF}
end;

function TCEBackendAdapter.LoadCT(const FileName: String; out Err: String): Boolean;
begin
  Result := False;
  Err := '';

  if not FileExists(FileName) then
  begin
    Err := 'File not found: ' + FileName;
    Exit;
  end;

  try
    // 调用 CE 的 LoadTable
    LoadTable(FileName, False {merge});
    Result := True;
  except
    on E: Exception do
    begin
      Err := 'Load CT failed: ' + E.Message;
    end;
  end;
end;

function TCEBackendAdapter.EnablePreset(const PresetName: String; out Err: String): Boolean;
var
  i: Integer;
  memrec: TMemoryRecord;
  enabledCount: Integer;
begin
  Result := False;
  Err := '';
  enabledCount := 0;

  // 简化版：启用所有记录（实际应支持预设名过滤）
  try
    if MainForm = nil then
    begin
      Err := 'MainForm not available';
      Exit;
    end;

    if MainForm.addresslist1 = nil then
    begin
      Err := 'AddressList not available';
      Exit;
    end;

    for i := 0 to MainForm.addresslist1.Count - 1 do
    begin
      memrec := TMemoryRecord(MainForm.addresslist1[i]);
      if memrec <> nil then
      begin
        // 启用/冻结记录
        if not memrec.Active then
        begin
          memrec.Active := True;
          Inc(enabledCount);
        end;
      end;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      Err := 'EnablePreset failed: ' + E.Message;
    end;
  end;
end;

function TCEBackendAdapter.ExportTrainer(const OutputFile: String; out Err: String): Boolean;
begin
  Result := False;
  Err := '';

  // 实际实现需要调用 CE 的 trainer generator
  // 这里提供骨架

  {$IFDEF WINDOWS}
  // 伪代码骨架：
  {
  if GenerateTrainer(OutputFile, MainForm.addresslist1) then
    Result := True
  else
    Err := 'Trainer generation failed';
  }

  Err := 'CEBackendAdapter.ExportTrainer: requires CE trainer generator integration';
  {$ELSE}
  Err := 'ExportTrainer only available on Windows with CE core';
  {$ENDIF}
end;

{ TCEProcessProbe }

function TCEProcessProbe.IsProcessRunning(const ProcessName: String): Boolean;
{$IFDEF WINDOWS}
var
  snap: THandle;
  pe32: TProcessEntry32;
  nameLower: String;
{$ENDIF}
begin
  Result := False;

  {$IFDEF WINDOWS}
  nameLower := LowerCase(ProcessName);

  snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if snap = INVALID_HANDLE_VALUE then Exit;

  try
    pe32.dwSize := SizeOf(pe32);
    if Process32First(snap, pe32) then
    begin
      repeat
        if Pos(nameLower, LowerCase(pe32.szExeFile)) > 0 then
        begin
          Result := True;
          Break;
        end;
      until not Process32Next(snap, pe32);
    end;
  finally
    CloseHandle(snap);
  end;
  {$ENDIF}
end;

end.
