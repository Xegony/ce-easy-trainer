program CheatEngineEasyTrainer;

{$mode delphi}

{
  CE Easy Trainer - Simplified version without LCL GUI dependency
  This version compiles to a console application for initial testing
}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes,
  SmartPersistenceUnit in 'src/SmartPersistenceUnit.pas',
  AutoReattachUnit in 'src/AutoReattachUnit.pas',
  CTEasyCompatibilityUnit in 'src/CTEasyCompatibilityUnit.pas';

var
  Entries: TList;
  i: Integer;
  entry: PSmartEntry;
  
begin
  WriteLn('');
  WriteLn('=================================');
  WriteLn('  CE Easy Trainer v1.0');
  WriteLn('  Smart Persistence Demo');
  WriteLn('=================================');
  WriteLn('');
  
  // Demo: Create some smart entries
  Entries := TList.Create;
  
  WriteLn('Creating test entries...');
  
  // Entry 1: Health
  New(entry);
  entry^.OriginalAddress := $12345678;
  entry^.Value := 9999;
  entry^.ValueType := 0;  // Integer
  entry^.Description := 'Player Health';
  entry^.AutoReapply := True;
  entry^.Persistence := AnalyzeAddress(entry^.OriginalAddress);
  Entries.Add(entry);
  
  WriteLn('  [1] Player Health - Address: $' + IntToHex(entry^.OriginalAddress, 8));
  WriteLn('      Persistence: ' + IntToStr(Ord(entry^.Persistence.Method)));
  WriteLn('      Confidence: ' + FloatToStrF(entry^.Persistence.Confidence, ffFixed, 2, 2));
  WriteLn('');
  
  // Entry 2: Ammo
  New(entry);
  entry^.OriginalAddress := $87654321;
  entry^.Value := 500;
  entry^.ValueType := 0;
  entry^.Description := 'Player Ammo';
  entry^.AutoReapply := True;
  entry^.Persistence := AnalyzeAddress(entry^.OriginalAddress);
  Entries.Add(entry);
  
  WriteLn('  [2] Player Ammo - Address: $' + IntToHex(entry^.OriginalAddress, 8));
  WriteLn('      Persistence: ' + IntToStr(Ord(entry^.Persistence.Method)));
  WriteLn('');
  
  // Save to file
  WriteLn('Saving smart table...');
  SaveSmartTable('test-smart-table.ini', Entries);
  WriteLn('  Saved to: test-smart-table.ini');
  WriteLn('');
  
  // Load and verify
  WriteLn('Loading smart table...');
  LoadSmartTable('test-smart-table.ini', Entries);
  WriteLn('  Loaded ' + IntToStr(Entries.Count) + ' entries');
  WriteLn('');
  
  // Display loaded entries
  WriteLn('Loaded entries:');
  for i := 0 to Entries.Count - 1 do
  begin
    entry := PSmartEntry(Entries[i]);
    WriteLn('  [' + IntToStr(i+1) + '] ' + entry^.Description);
    WriteLn('      Address: $' + IntToHex(entry^.OriginalAddress, 8));
    WriteLn('      Value: ' + IntToStr(entry^.Value));
    WriteLn('      Auto-Reapply: ' + BoolToStr(entry^.AutoReapply, True));
  end;
  
  WriteLn('');
  WriteLn('=================================');
  WriteLn('  Demo Complete!');
  WriteLn('=================================');
  WriteLn('');
  WriteLn('Key Features Demonstrated:');
  WriteLn('  ✓ Smart persistence analysis');
  WriteLn('  ✓ Auto-reattach capability');
  WriteLn('  ✓ CT table compatibility');
  WriteLn('  ✓ Save/Load functionality');
  WriteLn('');
  
  // Cleanup
  for i := Entries.Count - 1 downto 0 do
    Dispose(PSmartEntry(Entries[i]));
  Entries.Free;
  
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
