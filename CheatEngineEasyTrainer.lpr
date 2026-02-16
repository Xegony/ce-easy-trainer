program CheatEngineEasyTrainer;

{$mode delphi}

{
  CE Easy Trainer - Console demo version
}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes,
  SmartPersistenceUnit in 'src/SmartPersistenceUnit.pas',
  AutoReattachUnit in 'src/AutoReattachUnit.pas',
  CTEasyCompatibilityUnit in 'src/CTEasyCompatibilityUnit.pas';

var
  Entries: TList;
  i: Integer;
  entry: PSmartEntry;
  input: string;
  
procedure Pause;
begin
  WriteLn('');
  Write('Press ENTER to exit...');
  ReadLn(input);
end;

begin
  try
    {$IFDEF WINDOWS}
    SetConsoleOutputCP(65001);  // UTF-8
    {$ENDIF}
    
    WriteLn('');
    WriteLn('=================================');
    WriteLn('  CE Easy Trainer v1.0');
    WriteLn('  Smart Persistence Demo');
    WriteLn('=================================');
    WriteLn('');
    
    // Demo: Create some smart entries
    Entries := TList.Create;
    try
      WriteLn('Creating test entries...');
      WriteLn('');
      
      // Entry 1: Health
      New(entry);
      entry^.OriginalAddress := $12345678;
      entry^.Value := 9999;
      entry^.ValueType := 0;
      entry^.Description := 'Player Health';
      entry^.AutoReapply := True;
      entry^.Persistence.Method := pmModuleOffset;
      entry^.Persistence.Confidence := 0.75;
      entry^.Persistence.LastAddress := entry^.OriginalAddress;
      Entries.Add(entry);
      
      WriteLn('  [1] Player Health');
      WriteLn('      Address: $' + IntToHex(entry^.OriginalAddress, 8));
      WriteLn('      Value: ' + IntToStr(entry^.Value));
      WriteLn('');
      
      // Entry 2: Ammo
      New(entry);
      entry^.OriginalAddress := $87654321;
      entry^.Value := 500;
      entry^.ValueType := 0;
      entry^.Description := 'Player Ammo';
      entry^.AutoReapply := True;
      entry^.Persistence.Method := pmAOB;
      entry^.Persistence.Confidence := 0.68;
      entry^.Persistence.LastAddress := entry^.OriginalAddress;
      Entries.Add(entry);
      
      WriteLn('  [2] Player Ammo');
      WriteLn('      Address: $' + IntToHex(entry^.OriginalAddress, 8));
      WriteLn('      Value: ' + IntToStr(entry^.Value));
      WriteLn('');
      
      // Save to file
      WriteLn('Saving smart table to: test-smart-table.ini');
      SaveSmartTable('test-smart-table.ini', Entries);
      WriteLn('  Done!');
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
      end;
      
      WriteLn('');
      WriteLn('=================================');
      WriteLn('  Demo Complete!');
      WriteLn('=================================');
      WriteLn('');
      WriteLn('Features:');
      WriteLn('  - Smart persistence (pointer/AOB/module)');
      WriteLn('  - Auto-reattach on game restart');
      WriteLn('  - CT table compatibility');
      WriteLn('  - Save/Load functionality');
      
    finally
      // Cleanup
      for i := Entries.Count - 1 downto 0 do
        Dispose(PSmartEntry(Entries[i]));
      Entries.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('ERROR: ' + E.Message);
      WriteLn('');
    end;
  end;
  
  Pause;
end.
