program CEEasyTrainer;

{$mode delphi}
{$apptype console}

{
  CE Easy Trainer - Minimal functional trainer based on CE core
  Features:
  - Process selection and attach
  - Memory read/write
  - Address persistence (module+offset)
  - Auto-reattach on restart
  - CT table compatibility
}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes;

const
  TH32CS_SNAPPROCESS = $00000002;
  TH32CS_SNAPMODULE = $00000008;
  TH32CS_SNAPMODULE32 = $00000010;
  MAX_MODULE_NAME32 = 255;
  
type
  // Windows structures
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

const
  PROCESS_VM_READ = $0010;
  PROCESS_VM_WRITE = $0020;
  PROCESS_VM_OPERATION = $0008;
  PROCESS_QUERY_INFORMATION = $0400;
  MAX_PATH = 260;

type
  // Memory entry
  PMemEntry = ^TMemEntry;
  TMemEntry = record
    Description: string;
    Address: PtrUInt;
    Value: Int64;
    ValueType: Integer;  // 0=int, 1=float, 2=double
    Frozen: Boolean;

    // Persistence (module+offset)
    ModuleName: string;
    ModuleOffset: PtrUInt;
    UseModuleOffset: Boolean;

    // Pointer mode (auto-found)
    UsePointer: Boolean;
    PointerAddress: PtrUInt;          // absolute pointer address fallback
    PointerModuleName: string;        // pointer address module
    PointerModuleOffset: PtrUInt;     // pointer addr = moduleBase + offset
    PointerOffset: PtrInt;            // final = [pointerAddr] + PointerOffset
  end;

  // Module info
  TModuleInfo = record
    Name: string;
    BaseAddress: PtrUInt;
    Size: Cardinal;
  end;

var
  ProcessHandle: THandle = 0;
  ProcessID: DWORD = 0;
  ProcessName: string = '';
  Entries: TList;
  Modules: array of TModuleInfo;
  
// Windows API functions
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
function CloseHandle(hObject: THandle): BOOL; stdcall;
  external 'kernel32.dll' name 'CloseHandle';

// List processes
procedure ListProcesses;
var
  hSnapshot: THandle;
  pe32: TProcessEntry32;
  count: Integer;
begin
  hSnapshot := CreateToolhelp32Snapshot(2, 0); // TH32CS_SNAPPROCESS
  if hSnapshot = INVALID_HANDLE_VALUE then
  begin
    WriteLn('Failed to create snapshot');
    Exit;
  end;
  
  pe32.dwSize := SizeOf(TProcessEntry32);
  count := 0;
  
  WriteLn('');
  WriteLn('=== Running Processes ===');
  WriteLn('');
  
  if Process32First(hSnapshot, pe32) then
  begin
    repeat
      Inc(count);
      WriteLn(Format('%4d. %s (PID: %d)', [count, pe32.szExeFile, pe32.th32ProcessID]));
    until not Process32Next(hSnapshot, pe32);
  end;
  
  CloseHandle(hSnapshot);
  WriteLn('');
  WriteLn(Format('Total: %d processes', [count]));
end;

// Find process by name
function FindProcessByName(const Name: string): DWORD;
var
  hSnapshot: THandle;
  pe32: TProcessEntry32;
begin
  Result := 0;
  hSnapshot := CreateToolhelp32Snapshot(2, 0);
  if hSnapshot = INVALID_HANDLE_VALUE then Exit;
  
  pe32.dwSize := SizeOf(TProcessEntry32);
  
  if Process32First(hSnapshot, pe32) then
  begin
    repeat
      if SameText(ExtractFileName(pe32.szExeFile), Name) or
         SameText(pe32.szExeFile, Name) then
      begin
        Result := pe32.th32ProcessID;
        Break;
      end;
    until not Process32Next(hSnapshot, pe32);
  end;
  
  CloseHandle(hSnapshot);
end;

// Attach to process
function AttachProcess(PID: DWORD): Boolean;
begin
  if ProcessHandle <> 0 then
    CloseHandle(ProcessHandle);
    
  ProcessHandle := Windows.OpenProcess(
    PROCESS_VM_READ or PROCESS_VM_WRITE or PROCESS_VM_OPERATION or PROCESS_QUERY_INFORMATION,
    False, PID);
    
  Result := ProcessHandle <> 0;
  if Result then
    ProcessID := PID
  else
    WriteLn('Failed to open process. Error: ', GetLastError);
end;

// Enumerate modules
procedure EnumModules;
var
  hSnapshot: THandle;
  me32: TModuleEntry32;
  count: Integer;
begin
  SetLength(Modules, 0);
  if ProcessID = 0 then Exit;
  
  hSnapshot := CreateToolhelp32Snapshot(8, ProcessID); // TH32CS_SNAPMODULE
  if hSnapshot = INVALID_HANDLE_VALUE then Exit;
  
  me32.dwSize := SizeOf(TModuleEntry32);
  count := 0;
  
  if Module32First(hSnapshot, me32) then
  begin
    repeat
      SetLength(Modules, count + 1);
      Modules[count].Name := me32.szModule;
      Modules[count].BaseAddress := PtrUInt(me32.modBaseAddr);
      Modules[count].Size := me32.modBaseSize;
      Inc(count);
    until not Module32Next(hSnapshot, me32);
  end;
  
  CloseHandle(hSnapshot);
end;

// Get module base by name
function GetModuleBase(const ModuleName: string): PtrUInt;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(Modules) do
  begin
    if SameText(Modules[i].Name, ModuleName) then
    begin
      Result := Modules[i].BaseAddress;
      Exit;
    end;
  end;
end;

// Find module for address
function FindModuleForAddress(Address: PtrUInt): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Modules) do
  begin
    if (Address >= Modules[i].BaseAddress) and 
       (Address < Modules[i].BaseAddress + Modules[i].Size) then
    begin
      Result := Modules[i].Name;
      Exit;
    end;
  end;
end;

// Read memory
function ReadMem(Address: PtrUInt; Size: Integer; out Data): Boolean;
var
  BytesRead: NativeUInt;
begin
  Result := Windows.ReadProcessMemory(ProcessHandle, Pointer(Address), @Data, Size, BytesRead);
end;

function IsReadableProtect(Protect: DWORD): Boolean;
begin
  // readable and not guarded/no access
  Result := ((Protect and PAGE_GUARD)=0) and ((Protect and PAGE_NOACCESS)=0) and
            ((Protect and PAGE_READONLY)<>0 or
             (Protect and PAGE_READWRITE)<>0 or
             (Protect and PAGE_WRITECOPY)<>0 or
             (Protect and PAGE_EXECUTE_READ)<>0 or
             (Protect and PAGE_EXECUTE_READWRITE)<>0 or
             (Protect and PAGE_EXECUTE_WRITECOPY)<>0);
end;

procedure FindPointersToAddress(TargetAddress: PtrUInt; MaxResults: Integer = 50);
var
  mbi: MEMORY_BASIC_INFORMATION;
  scanAddr, regionBase, regionSize, offset: PtrUInt;
  chunkSize, toRead: NativeUInt;
  bytesRead: NativeUInt;
  buf: array of Byte;
  i: NativeUInt;
  pval: PtrUInt;
  found: Integer;
  moduleName: string;
begin
  if ProcessHandle = 0 then
  begin
    WriteLn('Error: No process attached');
    Exit;
  end;

  WriteLn('');
  WriteLn(Format('Pointer scan target: $%X', [TargetAddress]));
  WriteLn('Scanning readable memory pages...');

  found := 0;
  scanAddr := 0;
  chunkSize := 65536;

  while (scanAddr < High(PtrUInt)) and
        (VirtualQueryEx(ProcessHandle, Pointer(scanAddr), mbi, SizeOf(mbi)) = SizeOf(mbi)) do
  begin
    regionBase := PtrUInt(mbi.BaseAddress);
    regionSize := mbi.RegionSize;

    if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
    begin
      offset := 0;
      while offset < regionSize do
      begin
        toRead := chunkSize;
        if offset + toRead > regionSize then
          toRead := regionSize - offset;

        SetLength(buf, toRead);
        if Windows.ReadProcessMemory(ProcessHandle, Pointer(regionBase + offset), @buf[0], toRead, bytesRead) and
           (bytesRead >= SizeOf(PtrUInt)) then
        begin
          i := 0;
          while i + SizeOf(PtrUInt) <= bytesRead do
          begin
            Move(buf[i], pval, SizeOf(PtrUInt));
            if pval = TargetAddress then
            begin
              Inc(found);
              moduleName := FindModuleForAddress(regionBase + offset + i);
              if moduleName <> '' then
                WriteLn(Format('  [%d] $%X  (%s)', [found, regionBase + offset + i, moduleName]))
              else
                WriteLn(Format('  [%d] $%X', [found, regionBase + offset + i]));

              if found >= MaxResults then
              begin
                WriteLn(Format('Reached max results (%d). Stop scan.', [MaxResults]));
                Exit;
              end;
            end;
            Inc(i, SizeOf(PtrUInt));
          end;
        end;

        Inc(offset, toRead);
      end;
    end;

    if regionBase + regionSize <= scanAddr then
      Break;
    scanAddr := regionBase + regionSize;
  end;

  if found = 0 then
    WriteLn('No pointer found for this address.')
  else
    WriteLn(Format('Found %d candidate pointer(s).', [found]));
end;

function FindFirstPointerToAddress(TargetAddress: PtrUInt; out PointerAddress: PtrUInt): Boolean;
var
  mbi: MEMORY_BASIC_INFORMATION;
  scanAddr, regionBase, regionSize, offset: PtrUInt;
  chunkSize, toRead: NativeUInt;
  bytesRead: NativeUInt;
  buf: array of Byte;
  i: NativeUInt;
  pval: PtrUInt;
begin
  Result := False;
  PointerAddress := 0;
  if ProcessHandle = 0 then Exit;

  scanAddr := 0;
  chunkSize := 65536;

  while (scanAddr < High(PtrUInt)) and
        (VirtualQueryEx(ProcessHandle, Pointer(scanAddr), mbi, SizeOf(mbi)) = SizeOf(mbi)) do
  begin
    regionBase := PtrUInt(mbi.BaseAddress);
    regionSize := mbi.RegionSize;

    if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
    begin
      offset := 0;
      while offset < regionSize do
      begin
        toRead := chunkSize;
        if offset + toRead > regionSize then toRead := regionSize - offset;

        SetLength(buf, toRead);
        if Windows.ReadProcessMemory(ProcessHandle, Pointer(regionBase + offset), @buf[0], toRead, bytesRead) and
           (bytesRead >= SizeOf(PtrUInt)) then
        begin
          i := 0;
          while i + SizeOf(PtrUInt) <= bytesRead do
          begin
            Move(buf[i], pval, SizeOf(PtrUInt));
            if pval = TargetAddress then
            begin
              PointerAddress := regionBase + offset + i;
              Exit(True);
            end;
            Inc(i, SizeOf(PtrUInt));
          end;
        end;

        Inc(offset, toRead);
      end;
    end;

    if regionBase + regionSize <= scanAddr then Break;
    scanAddr := regionBase + regionSize;
  end;
end;

// Write memory
function WriteMem(Address: PtrUInt; Size: Integer; const Data): Boolean;
var
  BytesWritten: NativeUInt;
begin
  Result := Windows.WriteProcessMemory(ProcessHandle, Pointer(Address), @Data, Size, BytesWritten);
end;

// Read integer
function ReadInt(Address: PtrUInt; Size: Integer): Int64;
var
  buf8: Int64;
  buf4: Integer;
  buf2: SmallInt;
  buf1: ShortInt;
begin
  Result := 0;
  case Size of
    1: if ReadMem(Address, 1, buf1) then Result := buf1;
    2: if ReadMem(Address, 2, buf2) then Result := buf2;
    4: if ReadMem(Address, 4, buf4) then Result := buf4;
    8: if ReadMem(Address, 8, buf8) then Result := buf8;
  end;
end;

// Write integer
function WriteInt(Address: PtrUInt; Value: Int64; Size: Integer): Boolean;
var
  buf8: Int64;
  buf4: Integer;
  buf2: SmallInt;
  buf1: ShortInt;
begin
  case Size of
    1: begin buf1 := Value; Result := WriteMem(Address, 1, buf1); end;
    2: begin buf2 := Value; Result := WriteMem(Address, 2, buf2); end;
    4: begin buf4 := Value; Result := WriteMem(Address, 4, buf4); end;
    8: begin buf8 := Value; Result := WriteMem(Address, 8, buf8); end;
    else Result := False;
  end;
end;

// Read float
function ReadFloat(Address: PtrUInt): Single;
begin
  Result := 0;
  ReadMem(Address, 4, Result);
end;

// Write float
function WriteFloat(Address: PtrUInt; Value: Single): Boolean;
begin
  Result := WriteMem(Address, 4, Value);
end;

// Resolve address (with persistence)
function ResolveAddress(Entry: PMemEntry): PtrUInt;
var
  ModuleBase: PtrUInt;
  PointerAddr: PtrUInt;
  PointerValue: PtrUInt;
begin
  // Pointer mode first: final = [pointerAddr] + PointerOffset
  if Entry^.UsePointer then
  begin
    if (Entry^.PointerModuleName <> '') then
    begin
      ModuleBase := GetModuleBase(Entry^.PointerModuleName);
      if ModuleBase > 0 then
        PointerAddr := ModuleBase + Entry^.PointerModuleOffset
      else
        PointerAddr := Entry^.PointerAddress;
    end
    else
      PointerAddr := Entry^.PointerAddress;

    PointerValue := 0;
    if (PointerAddr > 0) and ReadMem(PointerAddr, SizeOf(PtrUInt), PointerValue) then
      Exit(PtrUInt(PtrInt(PointerValue) + Entry^.PointerOffset))
    else
      Exit(0);
  end;

  if Entry^.UseModuleOffset and (Entry^.ModuleName <> '') then
  begin
    ModuleBase := GetModuleBase(Entry^.ModuleName);
    if ModuleBase > 0 then
      Result := ModuleBase + Entry^.ModuleOffset
    else
      Result := 0;
  end
  else
    Result := Entry^.Address;
end;

// Update entry persistence info
procedure UpdatePersistence(Entry: PMemEntry);
var
  ModuleName: string;
begin
  ModuleName := FindModuleForAddress(Entry^.Address);
  if ModuleName <> '' then
  begin
    Entry^.ModuleName := ModuleName;
    Entry^.ModuleOffset := Entry^.Address - GetModuleBase(ModuleName);
    Entry^.UseModuleOffset := True;
    WriteLn(Format('  Persistence: %s + $%X', [ModuleName, Entry^.ModuleOffset]));
  end
  else
  begin
    Entry^.UseModuleOffset := False;
    WriteLn('  Warning: Address not in any module, persistence disabled');
  end;
end;

// Apply all entries
procedure ApplyEntries;
var
  i: Integer;
  Entry: PMemEntry;
  Addr: PtrUInt;
  OldValue: Int64;
  fValue: Single;
begin
  if ProcessHandle = 0 then
  begin
    WriteLn('Error: No process attached');
    Exit;
  end;
  
  WriteLn('');
  WriteLn('Applying cheats...');
  
  for i := 0 to Entries.Count - 1 do
  begin
    Entry := PMemEntry(Entries[i]);
    
    // Resolve address
    Addr := ResolveAddress(Entry);
    if Addr = 0 then
    begin
      WriteLn(Format('[%d] %s: Failed to resolve address', [i+1, Entry^.Description]));
      Continue;
    end;
    
    // Read old value
    OldValue := ReadInt(Addr, 4);
    
    // Write new value
    case Entry^.ValueType of
      0: WriteInt(Addr, Entry^.Value, 4);
      1: begin
           fValue := Entry^.Value;
           WriteFloat(Addr, fValue);
         end;
      2: ; // double
    end;
    
    WriteLn(Format('[%d] %s: $%X = %d -> %d', [i+1, Entry^.Description, Addr, OldValue, Entry^.Value]));
  end;
  
  WriteLn('Done!');
end;

// Add entry interactively
procedure AddEntry;
var
  Entry: PMemEntry;
  input: string;
begin
  New(Entry);
  
  WriteLn('');
  Write('Description: ');
  ReadLn(input);
  Entry^.Description := input;
  
  Write('Address (hex, e.g. 12345678): ');
  ReadLn(input);
  Entry^.Address := StrToIntDef('$' + input, 0);
  
  Write('Value: ');
  ReadLn(input);
  Entry^.Value := StrToInt64Def(input, 0);
  
  Entry^.ValueType := 0; // int
  Entry^.Frozen := True;
  Entry^.UseModuleOffset := False;
  Entry^.UsePointer := False;
  Entry^.PointerAddress := 0;
  Entry^.PointerModuleName := '';
  Entry^.PointerModuleOffset := 0;
  Entry^.PointerOffset := 0;
  
  // Get persistence info
  UpdatePersistence(Entry);
  
  Entries.Add(Entry);
  WriteLn('Entry added!');
end;

// Save table
procedure SaveTable(const Filename: string);
var
  f: TextFile;
  i: Integer;
  Entry: PMemEntry;
begin
  AssignFile(f, Filename);
  Rewrite(f);
  
  WriteLn(f, '<?xml version="1.0" encoding="utf-8"?>');
  WriteLn(f, '<CheatTable>');
  WriteLn(f, '  <CheatEntries>');
  
  for i := 0 to Entries.Count - 1 do
  begin
    Entry := PMemEntry(Entries[i]);
    WriteLn(f, '    <CheatEntry>');
    WriteLn(f, '      <Description>"' + Entry^.Description + '"</Description>');
    WriteLn(f, '      <Address>' + IntToHex(Entry^.Address, 8) + '</Address>');
    
    if Entry^.UseModuleOffset then
    begin
      WriteLn(f, '      <ModuleName>' + Entry^.ModuleName + '</ModuleName>');
      WriteLn(f, '      <Offset>' + IntToHex(Entry^.ModuleOffset, 8) + '</Offset>');
    end;

    if Entry^.UsePointer then
    begin
      WriteLn(f, '      <Extensions>');
      WriteLn(f, '        <CEEasyPointer Module="' + Entry^.PointerModuleName + '" ModuleOffset="' + IntToHex(Entry^.PointerModuleOffset, 8) + '" Offset="' + IntToStr(Entry^.PointerOffset) + '"/>');
      WriteLn(f, '      </Extensions>');
    end;
    
    WriteLn(f, '    </CheatEntry>');
  end;
  
  WriteLn(f, '  </CheatEntries>');
  WriteLn(f, '</CheatTable>');
  
  CloseFile(f);
  WriteLn('Table saved to: ' + Filename);
end;

function ExtractTagValue(const Line, Tag: string): string;
var
  a,b: Integer;
  openTag, closeTag: string;
begin
  Result := '';
  openTag := '<' + Tag + '>';
  closeTag := '</' + Tag + '>';
  a := Pos(openTag, Line);
  b := Pos(closeTag, Line);
  if (a>0) and (b>a) then
    Result := Copy(Line, a + Length(openTag), b - (a + Length(openTag)));
end;

procedure LoadTable(const Filename: string);
var
  sl: TStringList;
  i: Integer;
  line, v: string;
  Entry: PMemEntry;
  inEntry: Boolean;
  function Attr(const s, key: string): string;
  var p, q: Integer;
  begin
    Result := '';
    p := Pos(key + '="', s);
    if p>0 then
    begin
      p := p + Length(key) + 2;
      q := p;
      while (q<=Length(s)) and (s[q] <> '"') do Inc(q);
      Result := Copy(s, p, q-p);
    end;
  end;
begin
  if not FileExists(Filename) then
  begin
    WriteLn('Table not found: ' + Filename);
    Exit;
  end;

  // clear old
  for i := Entries.Count-1 downto 0 do
  begin
    Dispose(PMemEntry(Entries[i]));
    Entries.Delete(i);
  end;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(Filename);
    inEntry := False;
    Entry := nil;

    for i := 0 to sl.Count-1 do
    begin
      line := Trim(sl[i]);
      if line = '<CheatEntry>' then
      begin
        New(Entry);
        FillChar(Entry^, SizeOf(TMemEntry), 0);
        Entry^.ValueType := 0;
        Entry^.Frozen := True;
        inEntry := True;
        Continue;
      end;

      if line = '</CheatEntry>' then
      begin
        if inEntry and (Entry<>nil) then
          Entries.Add(Entry);
        inEntry := False;
        Entry := nil;
        Continue;
      end;

      if not inEntry or (Entry=nil) then Continue;

      v := ExtractTagValue(line, 'Description');
      if v <> '' then
      begin
        if (Length(v)>=2) and (v[1]='"') and (v[Length(v)]='"') then
          v := Copy(v,2,Length(v)-2);
        Entry^.Description := v;
      end;

      v := ExtractTagValue(line, 'Address');
      if v <> '' then Entry^.Address := StrToQWordDef('$'+v, 0);

      v := ExtractTagValue(line, 'ModuleName');
      if v <> '' then begin Entry^.ModuleName := v; Entry^.UseModuleOffset := True; end;

      v := ExtractTagValue(line, 'Offset');
      if v <> '' then begin Entry^.ModuleOffset := StrToQWordDef('$'+v, 0); Entry^.UseModuleOffset := True; end;

      if Pos('<CEEasyPointer ', line) > 0 then
      begin
        Entry^.UsePointer := True;
        Entry^.PointerModuleName := Attr(line, 'Module');
        Entry^.PointerModuleOffset := StrToQWordDef('$'+Attr(line, 'ModuleOffset'), 0);
        Entry^.PointerOffset := StrToIntDef(Attr(line, 'Offset'), 0);
      end;
    end;

    WriteLn(Format('Loaded %d entries from %s', [Entries.Count, Filename]));
  finally
    sl.Free;
  end;
end;

// Interactive menu
procedure ShowMenu;
begin
  WriteLn('');
  WriteLn('=================================');
  WriteLn('  CE Easy Trainer v2.0');
  if ProcessHandle <> 0 then
    WriteLn('  Attached: ' + ProcessName + ' (PID: ' + IntToStr(ProcessID) + ')')
  else
    WriteLn('  No process attached');
  WriteLn('=================================');
  WriteLn('');
  WriteLn('1. List processes');
  WriteLn('2. Attach to process');
  WriteLn('3. Add cheat entry');
  WriteLn('4. Apply cheats');
  WriteLn('5. List entries');
  WriteLn('6. Save table');
  WriteLn('7. Auto-reattach test');
  WriteLn('8. Auto find pointers for an entry');
  WriteLn('9. Load table');
  WriteLn('0. Exit');
  WriteLn('');
  Write('Choice: ');
end;

procedure ListEntries;
var
  i: Integer;
  Entry: PMemEntry;
begin
  WriteLn('');
  WriteLn('=== Cheat Entries ===');
  for i := 0 to Entries.Count - 1 do
  begin
    Entry := PMemEntry(Entries[i]);
    WriteLn(Format('[%d] %s', [i+1, Entry^.Description]));
    WriteLn(Format('    Address: $%X', [Entry^.Address]));
    WriteLn(Format('    Value: %d', [Entry^.Value]));
    if Entry^.UsePointer then
      WriteLn(Format('    Pointer: [%s+$%X] + %d', [Entry^.PointerModuleName, Entry^.PointerModuleOffset, Entry^.PointerOffset]))
    else if Entry^.UseModuleOffset then
      WriteLn(Format('    Persistence: %s + $%X', [Entry^.ModuleName, Entry^.ModuleOffset]));
  end;
  WriteLn('');
end;

procedure AutoFindPointersForEntry;
var
  idx: Integer;
  s: string;
  Entry: PMemEntry;
  target, ptrAddr, moduleBase: PtrUInt;
  mname: string;
begin
  if Entries.Count = 0 then
  begin
    WriteLn('No entries. Add one first.');
    Exit;
  end;

  ListEntries;
  Write('Entry index: ');
  ReadLn(s);
  idx := StrToIntDef(s, 0) - 1;
  if (idx < 0) or (idx >= Entries.Count) then
  begin
    WriteLn('Invalid index');
    Exit;
  end;

  Entry := PMemEntry(Entries[idx]);
  target := ResolveAddress(Entry);
  if target = 0 then
  begin
    WriteLn('Target address resolve failed');
    Exit;
  end;

  // print candidates first
  FindPointersToAddress(target, 20);

  // auto-pick first and switch to pointer mode
  if FindFirstPointerToAddress(target, ptrAddr) then
  begin
    Entry^.UsePointer := True;
    Entry^.PointerAddress := ptrAddr;
    Entry^.PointerOffset := 0;

    mname := FindModuleForAddress(ptrAddr);
    Entry^.PointerModuleName := mname;
    if mname <> '' then
    begin
      moduleBase := GetModuleBase(mname);
      Entry^.PointerModuleOffset := ptrAddr - moduleBase;
      WriteLn(Format('Auto pointer selected: [%s+$%X] + %d', [mname, Entry^.PointerModuleOffset, Entry^.PointerOffset]));
    end
    else
    begin
      Entry^.PointerModuleOffset := 0;
      WriteLn(Format('Auto pointer selected: [$%X] + %d', [ptrAddr, Entry^.PointerOffset]));
    end;

    WriteLn('Entry switched to POINTER mode. Next restart will resolve by pointer automatically.');
  end
  else
    WriteLn('Auto pointer not found, keep original mode.');
end;

procedure TestAutoReattach;
begin
  WriteLn('');
  WriteLn('=== Auto-Reattach Test ===');
  WriteLn('This will:');
  WriteLn('1. Remember current process');
  WriteLn('2. Monitor for process restart');
  WriteLn('3. Auto-reattach and reapply cheats');
  WriteLn('');
  WriteLn('Note: Game must be closed and restarted for this to work.');
  WriteLn('Press Ctrl+C to stop.');
  WriteLn('');
  
  // Simple monitoring loop
  while True do
  begin
    if ProcessHandle = 0 then
    begin
      // Try to reattach
      ProcessID := FindProcessByName(ProcessName);
      if ProcessID > 0 then
      begin
        if AttachProcess(ProcessID) then
        begin
          WriteLn('Reattached to ' + ProcessName);
          EnumModules;
          ApplyEntries;
        end;
      end;
    end;
    
    Sleep(1000);
  end;
end;

var
  choice: string;
  input: string;
  
begin
  try
    Entries := TList.Create;
    
    while True do
    begin
      ShowMenu;
      ReadLn(choice);
      
      case StrToIntDef(choice, -1) of
        1: ListProcesses;
        
        2: begin
          Write('Process name or PID: ');
          ReadLn(input);
          
          if StrToIntDef(input, 0) > 0 then
            ProcessID := StrToIntDef(input, 0)
          else
          begin
            ProcessName := input;
            ProcessID := FindProcessByName(input);
          end;
          
          if ProcessID > 0 then
          begin
            if AttachProcess(ProcessID) then
            begin
              WriteLn('Attached successfully!');
              EnumModules;
              WriteLn(Format('Found %d modules', [Length(Modules)]));
            end;
          end
          else
            WriteLn('Process not found');
        end;
        
        3: AddEntry;
        
        4: ApplyEntries;
        
        5: ListEntries;
        
        6: begin
          Write('Filename: ');
          ReadLn(input);
          SaveTable(input);
        end;
        
        7: TestAutoReattach;

        8: AutoFindPointersForEntry;

        9: begin
          Write('Filename: ');
          ReadLn(input);
          LoadTable(input);
        end;
        
        0: begin
          WriteLn('Bye!');
          Break;
        end;
        
        else
          WriteLn('Invalid choice');
      end;
    end;
    
  finally
    if ProcessHandle <> 0 then
      CloseHandle(ProcessHandle);
    Entries.Free;
  end;
end.
