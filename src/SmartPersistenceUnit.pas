unit SmartPersistenceUnit;

{$mode DELPHI}

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
  Classes, SysUtils, NewKernelHandler, symbolhandler, ProcessHandlerUnit;

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
    Confidence: Integer;  // 0-100, higher = more reliable
    
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

uses
  MainUnit, MemoryRecordUnit, CEFuncProc;

const
  MAX_POINTER_DEPTH = 8;
  MIN_AOB_LENGTH = 6;
  MAX_AOB_LENGTH = 64;

function AnalyzeAddress(Address: PtrUInt): TPersistenceInfo;
var
  i: Integer;
  moduleBase, offset: PtrUInt;
  moduleName: String;
  buf: array[0..MAX_AOB_LENGTH-1] of Byte;
  bytesRead: SIZE_T;
begin
  Result.Method := pmNone;
  Result.Success := False;
  Result.LastAddress := Address;
  Result.Confidence := 0;
  
  // Strategy 1: Try Module + Offset
  if GetModuleInfo(Address, moduleName, moduleBase) then
  begin
    offset := Address - moduleBase;
    if offset < $10000000 then  // Reasonable offset
    begin
      Result.Method := pmModuleOffset;
      Result.ModuleName := moduleName;
      Result.ModuleOffset := offset;
      Result.Confidence := 70;
      
      // Verify it's a consistent module
      if (Pos('.exe', LowerCase(moduleName)) > 0) or 
         (Pos('.dll', LowerCase(moduleName)) > 0) then
        Result.Confidence := 85;
    end;
  end;
  
  // Strategy 2: Try AOB Signature
  if ReadProcessMemory(processhandle, pointer(Address), @buf[0], MAX_AOB_LENGTH, bytesRead) then
  begin
    if bytesRead >= MIN_AOB_LENGTH then
    begin
      // Build signature with wildcards for non-deterministic bytes
      Result.AOBSignature := '';
      Result.AOBMask := '';
      for i := 0 to MIN_AOB_LENGTH - 1 do
      begin
        Result.AOBSignature := Result.AOBSignature + IntToHex(buf[i], 2) + ' ';
        Result.AOBMask := Result.AOBMask + 'xx ';  // All bytes significant
      end;
      Result.AOBSignature := Trim(Result.AOBSignature);
      Result.AOBMask := Trim(Result.AOBMask);
      
      // AOB as backup or primary if module method failed
      if Result.Method = pmNone then
      begin
        Result.Method := pmAOB;
        Result.Confidence := 60;
      end
      else
      begin
        // Hybrid mode - we have both module offset and AOB
        Result.Method := pmHybrid;
        Result.Confidence := 95;
      end;
    end;
  end;
  
  // Strategy 3: Pointer Chain (would need pointer scanning - expensive)
  // This would be done as background task
  
  Result.Success := (Result.Method <> pmNone);
  Result.LastVerified := Now;
end;

function ResolvePersistentAddress(var Info: TPersistenceInfo): PtrUInt;
var
  moduleBase: PtrUInt;
  foundAddr: PtrUInt;
begin
  Result := 0;
  
  case Info.Method of
    pmModuleOffset:
      begin
        // Find module base by name
        moduleBase := GetModuleBaseByName(Info.ModuleName);
        if moduleBase > 0 then
        begin
          Result := moduleBase + Info.ModuleOffset;
          Info.LastAddress := Result;
          Info.LastVerified := Now;
        end;
      end;
      
    pmAOB:
      begin
        // Scan for AOB signature
        foundAddr := ScanAOB(Info.AOBSignature, Info.AOBMask);
        if foundAddr > 0 then
        begin
          Result := foundAddr;
          Info.LastAddress := Result;
          Info.LastVerified := Now;
        end;
      end;
      
    pmHybrid:
      begin
        // Try module offset first (faster)
        Result := ResolvePersistentAddress(Info);
        if Result = 0 then
        begin
          // Fall back to AOB scan
          foundAddr := ScanAOB(Info.AOBSignature, Info.AOBMask);
          if foundAddr > 0 then
          begin
            Result := foundAddr;
            Info.LastAddress := Result;
            Info.LastVerified := Now;
          end;
        end;
      end;
      
    pmPointerChain:
      begin
        // Follow pointer chain
        Result := FollowPointerChain(Info.PointerBase, 
          Info.PointerOffsets, Length(Info.PointerOffsets));
        if Result > 0 then
        begin
          Info.LastAddress := Result;
          Info.LastVerified := Now;
        end;
      end;
  end;
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
  
  // Analyze and determine best persistence method
  Result^.Persistence := AnalyzeAddress(Address);
end;

procedure SaveSmartTable(Filename: String; Entries: TList);
var
  f: TextFile;
  i: Integer;
  entry: PSmartEntry;
begin
  AssignFile(f, Filename);
  Rewrite(f);
  
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
    WriteLn(f, 'Confidence=', entry^.Persistence.Confidence);
    
    case entry^.Persistence.Method of
      pmModuleOffset:
        begin
          WriteLn(f, 'ModuleName=', entry^.Persistence.ModuleName);
          WriteLn(f, 'ModuleOffset=', IntToHex(entry^.Persistence.ModuleOffset, 8));
        end;
      pmAOB, pmHybrid:
        begin
          WriteLn(f, 'AOBSignature=', entry^.Persistence.AOBSignature);
          WriteLn(f, 'AOBMask=', entry^.Persistence.AOBMask);
          if entry^.Persistence.Method = pmHybrid then
          begin
            WriteLn(f, 'ModuleName=', entry^.Persistence.ModuleName);
            WriteLn(f, 'ModuleOffset=', IntToHex(entry^.Persistence.ModuleOffset, 8));
          end;
        end;
      pmPointerChain:
        begin
          WriteLn(f, 'PointerBase=', IntToHex(entry^.Persistence.PointerBase, 8));
          // Write offsets...
        end;
    end;
    WriteLn(f, '');
  end;
  
  CloseFile(f);
end;

procedure LoadSmartTable(Filename: String; Entries: TList);
var
  f: TextFile;
  line, section, key, value: String;
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
  
  if not FileExists(Filename) then Exit;
  
  AssignFile(f, Filename);
  Reset(f);
  
  entry := nil;
  while not EOF(f) do
  begin
    ReadLn(f, line);
    line := Trim(line);
    
    if (line = '') or (line[1] = ';') or (line[1] = '#') then Continue;
    
    if (line[1] = '[') then
    begin
      // New section
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
      else if key = 'OriginalAddress' then entry^.OriginalAddress := StrToIntDef('$' + value, 0)
      else if key = 'Value' then entry^.Value := StrToInt64Def(value, 0)
      else if key = 'ValueType' then entry^.ValueType := StrToIntDef(value, 0)
      else if key = 'AutoReapply' then entry^.AutoReapply := (LowerCase(value) = 'true')
      else if key = 'PersistenceMethod' then entry^.Persistence.Method := TPersistenceMethod(StrToIntDef(value, 0))
      else if key = 'Confidence' then entry^.Persistence.Confidence := StrToIntDef(value, 0)
      else if key = 'ModuleName' then entry^.Persistence.ModuleName := value
      else if key = 'ModuleOffset' then entry^.Persistence.ModuleOffset := StrToInt64Def('$' + value, 0)
      else if key = 'AOBSignature' then entry^.Persistence.AOBSignature := value
      else if key = 'AOBMask' then entry^.Persistence.AOBMask := value;
    end;
  end;
  
  CloseFile(f);
end;

procedure AutoReapplyEntries(Entries: TList; ProcessName: String);
var
  i: Integer;
  entry: PSmartEntry;
  newAddr: PtrUInt;
  written: SIZE_T;
begin
  // Wait for process
  if not WaitForProcess(ProcessName, 5000) then Exit;
  
  // Reapply each entry
  for i := 0 to Entries.Count - 1 do
  begin
    entry := PSmartEntry(Entries[i]);
    if not entry^.AutoReapply then Continue;
    
    // Resolve address using persistence method
    newAddr := ResolvePersistentAddress(entry^.Persistence);
    
    if newAddr > 0 then
    begin
      // Write value
      case entry^.ValueType of
        0: WriteProcessMemory(processhandle, pointer(newAddr), 
              @entry^.Value, 4, written);  // int
        1: WriteProcessMemory(processhandle, pointer(newAddr), 
              @entry^.Value, 4, written);  // float
        2: WriteProcessMemory(processhandle, pointer(newAddr), 
              @entry^.Value, 8, written);  // double
      end;
      
      entry^.OriginalAddress := newAddr;
      entry^.LastError := '';
    end
    else
    begin
      entry^.LastError := 'Failed to resolve address';
    end;
  end;
end;

// Helper stubs (would call existing CE functions)
function GetModuleInfo(Address: PtrUInt; out Name: String; out Base: PtrUInt): Boolean;
begin
  // Would call CE's module enumeration
  Result := False;
end;

function GetModuleBaseByName(Name: String): PtrUInt;
begin
  // Would call CE's module lookup
  Result := 0;
end;

function ScanAOB(Signature, Mask: String): PtrUInt;
begin
  // Would call CE's AOB scanner
  Result := 0;
end;

function FollowPointerChain(Base: PtrUInt; Offsets: array of Integer; Depth: Integer): PtrUInt;
begin
  // Would call CE's pointer resolution
  Result := 0;
end;

function WaitForProcess(Name: String; TimeoutMs: Integer): Boolean;
begin
  // Would poll for process
  Result := False;
end;

end.
