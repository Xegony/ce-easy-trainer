unit EasyTrainerMainUnit;

{$mode DELPHI}

interface

uses
  SysUtils;

type
  TEasyTrainerState = (
    etsIdle,
    etsAttaching,
    etsAttached,
    etsTableLoaded,
    etsPresetEnabled,
    etsExported,
    etsError
  );

  ITrainerBackend = interface
    ['{A405A4AE-352A-466C-B3DD-B24968B347CC}']
    function AttachGame(const ProcessName: String; out Err: String): Boolean;
    function LoadCT(const FileName: String; out Err: String): Boolean;
    function EnablePreset(const PresetName: String; out Err: String): Boolean;
    function ExportTrainer(const OutputFile: String; out Err: String): Boolean;
  end;

  TEasyTrainerController = class
  private
    FBackend: ITrainerBackend;
    FState: TEasyTrainerState;
    FLastError: String;
    procedure SetError(const Err: String);
  public
    constructor Create(const ABackend: ITrainerBackend);

    function Attach(const ProcessName: String): Boolean;
    function LoadTable(const FileName: String): Boolean;
    function ApplyPreset(const PresetName: String): Boolean;
    function Export(const OutputFile: String): Boolean;

    property State: TEasyTrainerState read FState;
    property LastError: String read FLastError;
  end;

implementation

constructor TEasyTrainerController.Create(const ABackend: ITrainerBackend);
begin
  inherited Create;
  FBackend := ABackend;
  FState := etsIdle;
  FLastError := '';
end;

procedure TEasyTrainerController.SetError(const Err: String);
begin
  FLastError := Err;
  FState := etsError;
end;

function TEasyTrainerController.Attach(const ProcessName: String): Boolean;
var
  err: String;
begin
  Result := False;
  if FBackend = nil then
  begin
    SetError('Backend not assigned');
    Exit;
  end;

  FState := etsAttaching;
  err := '';
  if not FBackend.AttachGame(ProcessName, err) then
  begin
    SetError('Attach failed: ' + err);
    Exit;
  end;

  FState := etsAttached;
  FLastError := '';
  Result := True;
end;

function TEasyTrainerController.LoadTable(const FileName: String): Boolean;
var
  err: String;
begin
  Result := False;
  if FState <> etsAttached then
  begin
    SetError('LoadTable requires attached state');
    Exit;
  end;

  err := '';
  if not FBackend.LoadCT(FileName, err) then
  begin
    SetError('Load CT failed: ' + err);
    Exit;
  end;

  FState := etsTableLoaded;
  FLastError := '';
  Result := True;
end;

function TEasyTrainerController.ApplyPreset(const PresetName: String): Boolean;
var
  err: String;
begin
  Result := False;
  if not (FState in [etsTableLoaded, etsPresetEnabled]) then
  begin
    SetError('ApplyPreset requires table loaded');
    Exit;
  end;

  err := '';
  if not FBackend.EnablePreset(PresetName, err) then
  begin
    SetError('Enable preset failed: ' + err);
    Exit;
  end;

  FState := etsPresetEnabled;
  FLastError := '';
  Result := True;
end;

function TEasyTrainerController.Export(const OutputFile: String): Boolean;
var
  err: String;
begin
  Result := False;
  if not (FState in [etsPresetEnabled, etsTableLoaded]) then
  begin
    SetError('Export requires loaded table/preset');
    Exit;
  end;

  err := '';
  if not FBackend.ExportTrainer(OutputFile, err) then
  begin
    SetError('Export failed: ' + err);
    Exit;
  end;

  FState := etsExported;
  FLastError := '';
  Result := True;
end;

end.
