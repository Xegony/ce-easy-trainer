program CEEasyTrainerGUI;

{$mode delphi}

{完整的GUI版本 - 基于CE核心功能}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  Interfaces,
  Forms,
  SysUtils, Classes,
  MainGUIUnit;

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'CE Easy Trainer';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
