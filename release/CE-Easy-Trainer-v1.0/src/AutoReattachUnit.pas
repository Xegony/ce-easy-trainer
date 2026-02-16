unit AutoReattachUnit;

{$mode DELPHI}

interface

uses
  Classes, SysUtils;

type
  TReattachLogProc = procedure(const Msg: String) of object;
  TOnReattachProc = procedure of object;

  IProcessProbe = interface
    ['{755A2444-B5E9-4A92-9D5A-8E8FB8C9D6F4}']
    function IsProcessRunning(const ProcessName: String): Boolean;
  end;

  TAutoReattachService = class
  private
    FProcessName: String;
    FProbe: IProcessProbe;
    FOnReattach: TOnReattachProc;
    FOnLog: TReattachLogProc;
    FWasRunning: Boolean;
    FEnabled: Boolean;
    FTickCount: QWord;
    FLastReattachTick: QWord;
    FMinReattachIntervalTicks: QWord;
    procedure Log(const Msg: String);
  public
    constructor Create(const AProcessName: String; const AProbe: IProcessProbe);
    procedure Tick;
    procedure Start;
    procedure Stop;

    property Enabled: Boolean read FEnabled;
    property OnReattach: TOnReattachProc read FOnReattach write FOnReattach;
    property OnLog: TReattachLogProc read FOnLog write FOnLog;
    property MinReattachIntervalTicks: QWord read FMinReattachIntervalTicks write FMinReattachIntervalTicks;
  end;

implementation

constructor TAutoReattachService.Create(const AProcessName: String; const AProbe: IProcessProbe);
begin
  inherited Create;
  FProcessName := AProcessName;
  FProbe := AProbe;
  FWasRunning := False;
  FEnabled := False;
  FTickCount := 0;
  FLastReattachTick := 0;
  FMinReattachIntervalTicks := 3;
end;

procedure TAutoReattachService.Log(const Msg: String);
begin
  if Assigned(FOnLog) then
    FOnLog(Msg);
end;

procedure TAutoReattachService.Start;
begin
  if FEnabled then Exit;
  FEnabled := True;
  FWasRunning := False;
  FTickCount := 0;
  FLastReattachTick := 0;
  Log('AutoReattach started for process: ' + FProcessName);
end;

procedure TAutoReattachService.Stop;
begin
  if not FEnabled then Exit;
  FEnabled := False;
  Log('AutoReattach stopped');
end;

procedure TAutoReattachService.Tick;
var
  isRunning: Boolean;
begin
  if not FEnabled then Exit;
  if FProbe = nil then Exit;

  Inc(FTickCount);
  isRunning := FProbe.IsProcessRunning(FProcessName);

  if (not FWasRunning) and isRunning then
  begin
    if (FTickCount - FLastReattachTick) >= FMinReattachIntervalTicks then
    begin
      FLastReattachTick := FTickCount;
      Log('Process detected, triggering reattach: ' + FProcessName);
      if Assigned(FOnReattach) then
        FOnReattach;
    end;
  end;

  FWasRunning := isRunning;
end;

end.
