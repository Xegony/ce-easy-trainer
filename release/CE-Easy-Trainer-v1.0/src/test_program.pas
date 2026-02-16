program test_SmartPersistence;

{$mode delphi}

uses
  Classes, SysUtils, test_SyntaxCheck;

var
  addr: ptrUint;
  result: TPersistenceResult;
  i: Integer;
begin
  WriteLn('=== Smart Persistence Engine Test ===');
  WriteLn('');
  
  // 测试不同地址
  for i := 1 to 5 do
  begin
    addr := $140000000 + (i * $10000);
    WriteLn('Test #', i, ': Address = 0x', IntToHex(addr, 8));
    
    result := BuildPersistence(addr);
    
    WriteLn('  Method: ');
    case result.Method of
      pmNone: WriteLn('    None');
      pmPointerChain: WriteLn('    Pointer Chain');
      pmAOB: WriteLn('    AOB Scan');
      pmModuleOffset: WriteLn('    Module Offset');
      pmHybrid: WriteLn('    Hybrid');
    end;
    
    WriteLn('  Confidence: ', result.Confidence:0:2);
    WriteLn('  Module: ', result.ModuleName);
    WriteLn('  ModuleOffset: 0x', IntToHex(result.ModuleOffset, 8));
    WriteLn('  AOB: ', result.AOBPattern);
    WriteLn('');
  end;
  
  WriteLn('=== Test Complete ===');
end.
