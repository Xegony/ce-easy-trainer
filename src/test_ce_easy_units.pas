program test_ce_easy_units;

{$mode DELPHI}

uses
  SysUtils,
  EasyTrainerMainUnit,
  AutoReattachUnit,
  CTEasyCompatibilityUnit;

type
  TMockBackend = class(TInterfacedObject, ITrainerBackend)
  public
    function AttachGame(const ProcessName: String; out Err: String): Boolean;
    function LoadCT(const FileName: String; out Err: String): Boolean;
    function EnablePreset(const PresetName: String; out Err: String): Boolean;
    function ExportTrainer(const OutputFile: String; out Err: String): Boolean;
  end;

  TMockProbe = class(TInterfacedObject, IProcessProbe)
  private
    FTick: Integer;
  public
    function IsProcessRunning(const ProcessName: String): Boolean;
  end;

  TReattachSink = class
  public
    Triggered: Integer;
    procedure OnReattach;
    procedure OnLog(const Msg: String);
  end;

function TMockBackend.AttachGame(const ProcessName: String; out Err: String): Boolean;
begin
  Err := '';
  Result := ProcessName <> '';
end;

function TMockBackend.LoadCT(const FileName: String; out Err: String): Boolean;
begin
  Err := '';
  Result := LowerCase(ExtractFileExt(FileName)) = '.ct';
end;

function TMockBackend.EnablePreset(const PresetName: String; out Err: String): Boolean;
begin
  Err := '';
  Result := PresetName <> '';
end;

function TMockBackend.ExportTrainer(const OutputFile: String; out Err: String): Boolean;
begin
  Err := '';
  Result := OutputFile <> '';
end;

function TMockProbe.IsProcessRunning(const ProcessName: String): Boolean;
begin
  Inc(FTick);
  // First 2 ticks not running, then running
  Result := FTick >= 3;
end;

procedure TReattachSink.OnReattach;
begin
  Inc(Triggered);
  WriteLn('[Reattach] callback triggered');
end;

procedure TReattachSink.OnLog(const Msg: String);
begin
  WriteLn('[AutoReattach] ', Msg);
end;

var
  backend: ITrainerBackend;
  ctl: TEasyTrainerController;
  probe: IProcessProbe;
  svc: TAutoReattachService;
  sink: TReattachSink;
  meta, parsed: TCEEasyMetadata;
  xml, xml2: String;
  ok: Boolean;
  i: Integer;
begin
  WriteLn('=== CE Easy Units Smoke Test ===');

  backend := TMockBackend.Create;
  ctl := TEasyTrainerController.Create(backend);
  try
    if not ctl.Attach('game.exe') then raise Exception.Create(ctl.LastError);
    if not ctl.LoadTable('demo.ct') then raise Exception.Create(ctl.LastError);
    if not ctl.ApplyPreset('default') then raise Exception.Create(ctl.LastError);
    if not ctl.Export('trainer.exe') then raise Exception.Create(ctl.LastError);
    WriteLn('Controller state OK. Final state=', Ord(ctl.State));
  finally
    ctl.Free;
  end;

  meta := DefaultMetadata;
  meta.Notes := 'hello';
  xml := '<CheatTable><CheatEntries/></CheatTable>';
  xml2 := InjectOrUpdateMetadata(xml, meta);
  ok := TryParseMetadata(xml2, parsed);
  if (not ok) or (parsed.Notes <> 'hello') then
    raise Exception.Create('CT metadata parse failed');
  WriteLn('CT compatibility metadata OK.');

  probe := TMockProbe.Create;
  sink := TReattachSink.Create;
  svc := TAutoReattachService.Create('game.exe', probe);
  try
    svc.MinReattachIntervalTicks := 1;
    svc.OnReattach := sink.OnReattach;
    svc.OnLog := sink.OnLog;
    svc.Start;
    for i := 1 to 5 do svc.Tick;
    svc.Stop;

    if sink.Triggered < 1 then
      raise Exception.Create('AutoReattach did not trigger');
    WriteLn('AutoReattach OK. Triggered=', sink.Triggered);
  finally
    svc.Free;
    sink.Free;
  end;

  WriteLn('=== ALL PASS ===');
end.
