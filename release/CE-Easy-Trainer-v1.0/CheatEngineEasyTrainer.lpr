program CheatEngineEasyTrainer;

{$mode delphi}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL interface
  Forms,
  SmartPersistenceUnit,
  EasyTrainerMainUnit,
  AutoReattachUnit,
  CTEasyCompatibilityUnit;

{$R *.res}

begin
  Application.Title := 'CE Easy Trainer';
  Application.Initialize;
  Application.CreateForm(TfrmEasyTrainerMain, frmEasyTrainerMain);
  Application.Run;
end.
