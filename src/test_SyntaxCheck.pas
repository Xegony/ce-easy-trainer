unit test_SyntaxCheck;

{$mode delphi}

// 独立语法检查版本 - 不依赖CE单元

interface

uses
  Classes, SysUtils;

type
  // 模拟CE类型
  ptrUint = QWord;
  SIZE_T = QWord;
  
  TPersistenceMethod = (pmNone, pmPointerChain, pmAOB, pmModuleOffset, pmHybrid);

  TPersistenceResult = record
    Method: TPersistenceMethod;
    Confidence: Single;
    PointerBase: ptrUint;
    PointerOffsets: array of integer;
    ModuleName: string;
    ModuleOffset: ptrUint;
    AOBPattern: string;
  end;

function FindBestPersistence(address: ptrUint): TPersistenceMethod;
function BuildPersistence(address: ptrUint): TPersistenceResult;

implementation

function Clamp01(v: Single): Single;
begin
  if v < 0 then Exit(0);
  if v > 1 then Exit(1);
  Result := v;
end;

function ScorePointerChain(address: ptrUint): Single;
begin
  Result := 0;
  if address <> 0 then
    Result := 0.55;
  if (address and $F) = 0 then
    Result := Result + 0.1;
  Result := Clamp01(Result);
end;

function ScoreAOB(address: ptrUint): Single;
begin
  // 简化版 - 实际需要读取内存
  if address <> 0 then
    Result := 0.68
  else
    Result := 0;
end;

function ScoreModuleOffset(address: ptrUint): Single;
begin
  // 简化版 - 实际需要模块枚举
  if address <> 0 then
    Result := 0.75
  else
    Result := 0;
  Result := Clamp01(Result);
end;

function FindBestPersistence(address: ptrUint): TPersistenceMethod;
var
  pScore, aScore, mScore: Single;
begin
  pScore := ScorePointerChain(address);
  aScore := ScoreAOB(address);
  mScore := ScoreModuleOffset(address);

  // Hybrid when two strategies are both strong
  if ((pScore >= 0.65) and (aScore >= 0.65)) or
     ((mScore >= 0.70) and (aScore >= 0.65)) then
    Exit(pmHybrid);

  if (pScore >= aScore) and (pScore >= mScore) then
    Result := pmPointerChain
  else if (aScore >= mScore) then
    Result := pmAOB
  else
    Result := pmModuleOffset;
end;

function BuildPersistence(address: ptrUint): TPersistenceResult;
var
  pScore, aScore, mScore: Single;
begin
  // 初始化所有字段，包括managed types
  Result.Method := pmNone;
  Result.Confidence := 0;
  Result.PointerBase := 0;
  SetLength(Result.PointerOffsets, 0);
  Result.ModuleName := '';
  Result.ModuleOffset := 0;
  Result.AOBPattern := '';

  pScore := ScorePointerChain(address);
  aScore := ScoreAOB(address);
  mScore := ScoreModuleOffset(address);

  Result.Method := FindBestPersistence(address);

  case Result.Method of
    pmPointerChain: Result.Confidence := pScore;
    pmAOB: Result.Confidence := aScore;
    pmModuleOffset: Result.Confidence := mScore;
    pmHybrid: Result.Confidence := Clamp01((aScore + mScore + pScore) / 3 + 0.1);
  end;
  
  // 简化版AOB pattern（实际需要读取内存）
  Result.AOBPattern := '48 89 5C 24 08 48 89 6C 24 10';
  Result.ModuleName := 'game.exe';
  Result.ModuleOffset := address mod $10000000;
end;

end.
