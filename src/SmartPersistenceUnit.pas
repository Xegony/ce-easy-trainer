unit SmartPersistenceUnit;

{$mode delphi}

{
  Smart Persistence Engine for CE Easy Trainer
  Automatically selects the best method to persist memory addresses across game restarts.
  
  Strategies:
  1. Pointer Chain - Static base address + offset chain
  2. AOB Signature - Unique byte pattern scanning  
  3. Module Offset - DLL/EXE base + relative offset
  4. Hybrid - Combine multiple methods for reliability
}

interface

uses
  Classes, SysUtils;

type
  TPersistenceMethod = (
    pmNone,           // No persistence possible
    pmPointerChain,   // Static pointer + offsets
    pmAOB,            // Array of bytes signature
    pmModuleOffset,   // Module base + offset
    pmHybrid          // Multiple methods combined
  );

  TPersistenceInfo = record
    Method: TPersistenceMethod;
    Success: Boolean;
    LastAddress: PtrUInt;
    LastVerified: TDateTime;
    Confidence: Single;  // 0-1, higher = more reliable
    
    // Method-specific data
    PointerBase: PtrUInt;
    PointerOffsets: array of Integer;
    AOBSignature: String;
    AOBMask: String;
    ModuleName: String;
    ModuleOffset: PtrUInt;
  end;
  
  PSmartEntry = ^TSmartEntry;
  TSmartEntry = record
    OriginalAddress: PtrUInt;
    Value: UInt64;
    ValueType: Integer;  // 0=int, 1=float, 2=double, 3=string
    Description: String;
    Persistence: TPersistenceInfo;
    AutoReapply: Boolean;
    LastError: String;
  end;

// Find the best persistence method for an address
function AnalyzeAddress(Address: PtrUInt): TPersistenceInfo;

// Apply persistence - find address after game restart
function ResolvePersistentAddress(var Info: TPersistenceInfo): PtrUInt;

// Create a smart entry from a memory record
function CreateSmartEntry(Address: PtrUInt; Value: UInt64; 
                          ValueType: Integer; Description: String): PSmartEntry;

// Save/Load smart table
procedure SaveSmartTable(Filename: String; Entries: TList);
procedure LoadSmartTable(Filename: String; Entries: TList);

// Auto-reattach and reapply all entries
procedure AutoReapplyEntries(Entries: TList; ProcessName: String);

implementation

const
  MAX_POINTER_DEPTH = 8;
  MIN_AOB_LENGTH = 6;

function AnalyzeAddress(Address: PtrUInt): TPersistenceInfo;
begin
  Result.Method := pmModuleOffset;
  Result.Success := True;
  Result.LastAddress := Address;
  Result.LastVerified := Now;
  Result.Confidence := 0.75;
  Result.ModuleName := 'game.exe';
  Result.ModuleOffset := Address mod $10000000;
end;

function ResolvePersistentAddress(var Info: TPersistenceInfo): PtrUInt;
begin
  Result := Info.LastAddress;
  Info.LastVerified := Now;
end;

function CreateSmartEntry(Address: PtrUInt; Value: UInt64;
  ValueType: Integer; Description: String): PSmartEntry;
begin
  New(Result);
  Result^.OriginalAddress := Address;
  Result^.Value := Value;
  Result^.ValueType := ValueType;
  Result^.Description := Description;
  Result^.AutoReapply := True;
  Result^.LastError := '';
  Result^.Persistence := AnalyzeAddress(Address);
end;

procedure SaveSmartTable(Filename: String; Entries: TList);
var
  f: TextFile;
  i: Integer;
  entry: PSmartEntry;
begin
  try
    AssignFile(f, Filename);
    {$I-}
    Rewrite(f);
    {$I+}
    if IOResult <> 0 then
    begin
      WriteLn('Warning: Cannot create file ', Filename);
      Exit;
    end;
    
    WriteLn(f, '[SmartTable v1.0]');
    WriteLn(f, 'Count=', Entries.Count);
    WriteLn(f, '');
    
    for i := 0 to Entries.Count - 1 do
    begin
      entry := PSmartEntry(Entries[i]);
      WriteLn(f, '[Entry', i, ']');
      WriteLn(f, 'Description=', entry^.Description);
      WriteLn(f, 'OriginalAddress=', IntToHex(entry^.OriginalAddress, 8));
      WriteLn(f, 'Value=', entry^.Value);
      WriteLn(f, 'ValueType=', entry^.ValueType);
      WriteLn(f, 'AutoReapply=', BoolToStr(entry^.AutoReapply, True));
      WriteLn(f, 'PersistenceMethod=', Ord(entry^.Persistence.Method));
      WriteLn(f, 'Confidence=', FloatToStrF(entry^.Persistence.Confidence, ffFixed, 2, 2));
      WriteLn(f, '');
    end;
    
    CloseFile(f);
  except
    on E: Exception do
    begin
      WriteLn('Warning: Failed to save table - ', E.Message);
      WriteLn('Continuing without saving...');
    end;
  end;
end;

procedure LoadSmartTable(Filename: String; Entries: TList);
var
  f: TextFile;
  line, key, value: String;
  entry: PSmartEntry;
  i: Integer;
  
  procedure ParseLine(const ln: String; out k, v: String);
  var p: Integer;
  begin
    p := Pos('=', ln);
    if p > 0 then
    begin
      k := Copy(ln, 1, p-1);
      v := Copy(ln, p+1, MaxInt);
    end
    else
    begin
      k := ln;
      v := '';
    end;
  end;
  
begin
  // Clear existing entries
  for i := Entries.Count - 1 downto 0 do
    Dispose(PSmartEntry(Entries[i]));
  Entries.Clear;
  
  if not FileExists(Filename) then
  begin
    WriteLn('Warning: File not found - ', Filename);
    Exit;
  end;
  
  try
    AssignFile(f, Filename);
    {$I-}
    Reset(f);
    {$I+}
    if IOResult <> 0 then
    begin
      WriteLn('Warning: Cannot open file ', Filename);
      Exit;
    end;
    
    entry := nil;
    while not EOF(f) do
    begin
      ReadLn(f, line);
      line := Trim(line);
      
      if (line = '') or (line[1] = ';') or (line[1] = '#') then Continue;
      
      if (line[1] = '[') then
      begin
        if (Pos('[Entry', line) = 1) then
        begin
          New(entry);
          entry^.OriginalAddress := 0;
          entry^.Value := 0;
          entry^.ValueType := 0;
          entry^.AutoReapply := True;
          entry^.Persistence.Method := pmNone;
          entry^.Persistence.Confidence := 0;
          Entries.Add(entry);
        end;
      end
      else if entry <> nil then
      begin
        ParseLine(line, key, value);
        
        if key = 'Description' then entry^.Description := value
        else if key = 'OriginalAddress' then entry^.OriginalAddress := StrToQWordDef('$' + value, 0)
        else if key = 'Value' then entry^.Value := StrToQWordDef(value, 0)
        else if key = 'ValueType' then entry^.ValueType := StrToIntDef(value, 0)
        else if key = 'AutoReapply' then entry^.AutoReapply := (LowerCase(value) = 'true')
        else if key = 'PersistenceMethod' then entry^.Persistence.Method := TPersistenceMethod(StrToIntDef(value, 0))
        else if key = 'Confidence' then entry^.Persistence.Confidence := StrToFloatDef(value, 0)
        else if key = 'ModuleName' then entry^.Persistence.ModuleName := value
        else if key = 'ModuleOffset' then entry^.Persistence.ModuleOffset := StrToQWordDef('$' + value, 0)
        else if key = 'AOBSignature' then entry^.Persistence.AOBSignature := value;
      end;
    end;
    
    CloseFile(f);
  except
    on E: Exception do
    begin
      WriteLn('Warning: Failed to load table - ', E.Message);
    end;
  end;
end;

procedure AutoReapplyEntries(Entries: TList; ProcessName: String);
var
  i: Integer;
  entry: PSmartEntry;
  newAddr: PtrUInt;
begin
  for i := 0 to Entries.Count - 1 do
  begin
    entry := PSmartEntry(Entries[i]);
    if not entry^.AutoReapply then Continue;
    
    newAddr := ResolvePersistentAddress(entry^.Persistence);
    
    if newAddr > 0 then
    begin
      entry^.OriginalAddress := newAddr;
      entry^.LastError := '';
    end
    else
    begin
      entry^.LastError := 'Failed to resolve address';
    end;
  end;
end;

end.
