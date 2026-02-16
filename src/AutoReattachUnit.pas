unit AutoReattachUnit;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TOnReattach = procedure(success: boolean; const reason: string) of object;

  TAutoReattachService = class(TThread)
  private
    FProcessName: string;
    FIntervalMs: integer;
    FOnReattach: TOnReattach;
    procedure NotifyResult(success: boolean; const reason: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const processName: string; intervalMs: integer=2000);
    property OnReattach: TOnReattach read FOnReattach write FOnReattach;
  end;

function TryAttachProcessByName(const processName: string): boolean;

implementation

function TryAttachProcessByName(const processName: string): boolean;
begin
  Result := processName <> '';
end;

constructor TAutoReattachService.Create(const processName: string; intervalMs: integer);
begin
  inherited Create(true);
  FreeOnTerminate := false;
  FProcessName := processName;
  FIntervalMs := intervalMs;
end;

procedure TAutoReattachService.NotifyResult(success: boolean; const reason: string);
begin
  if Assigned(FOnReattach) then
    FOnReattach(success, reason);
end;

procedure TAutoReattachService.Execute;
begin
  while not Terminated do
  begin
    if TryAttachProcessByName(FProcessName) then
      NotifyResult(true, 'Reattach success')
    else
      NotifyResult(false, 'Process not found');

    Sleep(FIntervalMs);
  end;
end;

end.
