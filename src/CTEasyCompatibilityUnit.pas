unit CTEasyCompatibilityUnit;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TCTEasyMeta = record
    Method: Integer;  // 0=pointer, 1=AOB, 2=module, 3=hybrid
    AOBPattern: string;
    ModuleName: string;
    ModuleOffset: PtrUInt;
  end;

procedure SaveEasyMetaToIni(Filename: string; const meta: TCTEasyMeta);
function LoadEasyMetaFromIni(Filename: string; out meta: TCTEasyMeta): boolean;

implementation

procedure SaveEasyMetaToIni(Filename: string; const meta: TCTEasyMeta);
var
  f: TextFile;
begin
  AssignFile(f, Filename);
  Rewrite(f);
  WriteLn(f, '[CEEasyMeta]');
  WriteLn(f, 'Method=', meta.Method);
  WriteLn(f, 'AOB=', meta.AOBPattern);
  WriteLn(f, 'Module=', meta.ModuleName);
  WriteLn(f, 'ModuleOffset=', IntToHex(meta.ModuleOffset, 8));
  CloseFile(f);
end;

function LoadEasyMetaFromIni(Filename: string; out meta: TCTEasyMeta): boolean;
var
  f: TextFile;
  line, key, value: string;
  p: Integer;
begin
  Result := False;
  if not FileExists(Filename) then Exit;
  
  FillChar(meta, SizeOf(meta), 0);
  
  AssignFile(f, Filename);
  Reset(f);
  
  while not EOF(f) do
  begin
    ReadLn(f, line);
    line := Trim(line);
    p := Pos('=', line);
    if p > 0 then
    begin
      key := Copy(line, 1, p-1);
      value := Copy(line, p+1, MaxInt);
      
      if key = 'Method' then meta.Method := StrToIntDef(value, 0)
      else if key = 'AOB' then meta.AOBPattern := value
      else if key = 'Module' then meta.ModuleName := value
      else if key = 'ModuleOffset' then meta.ModuleOffset := StrToInt64Def('$' + value, 0);
    end;
  end;
  
  CloseFile(f);
  Result := True;
end;

end.
