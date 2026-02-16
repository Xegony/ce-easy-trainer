unit CTEasyCompatibilityUnit;

{$mode DELPHI}

interface

uses
  SysUtils;

type
  TCEEasyMetadata = record
    Version: String;
    AutoReattach: Boolean;
    PreferredStrategy: String; // auto|pointer|aob|module|hybrid
    Notes: String;
  end;

function DefaultMetadata: TCEEasyMetadata;
function InjectOrUpdateMetadata(const CTXml: String; const Meta: TCEEasyMetadata): String;
function TryParseMetadata(const CTXml: String; out Meta: TCEEasyMetadata): Boolean;

implementation

function BoolToXml(const v: Boolean): String;
begin
  if v then Result := 'true' else Result := 'false';
end;

function XmlToBool(const v: String): Boolean;
var
  s: String;
begin
  s := LowerCase(Trim(v));
  Result := (s = '1') or (s = 'true') or (s = 'yes');
end;

function XmlEscape(const s: String): String;
begin
  Result := StringReplace(s, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function ExtractTagValue(const Xml, TagName: String): String;
var
  openTag, closeTag: String;
  p1, p2: SizeInt;
begin
  Result := '';
  openTag := '<' + TagName + '>';
  closeTag := '</' + TagName + '>';

  p1 := Pos(openTag, Xml);
  if p1 <= 0 then Exit;
  p1 := p1 + Length(openTag);

  p2 := Pos(closeTag, Xml);
  if (p2 <= 0) or (p2 < p1) then Exit;

  Result := Copy(Xml, p1, p2 - p1);
end;

function BuildMetaNode(const Meta: TCEEasyMetadata): String;
begin
  Result :=
    '<CEEasyTrainer>' +
      '<Version>' + XmlEscape(Meta.Version) + '</Version>' +
      '<AutoReattach>' + BoolToXml(Meta.AutoReattach) + '</AutoReattach>' +
      '<PreferredStrategy>' + XmlEscape(Meta.PreferredStrategy) + '</PreferredStrategy>' +
      '<Notes>' + XmlEscape(Meta.Notes) + '</Notes>' +
    '</CEEasyTrainer>';
end;

function DefaultMetadata: TCEEasyMetadata;
begin
  Result.Version := '1.0';
  Result.AutoReattach := True;
  Result.PreferredStrategy := 'auto';
  Result.Notes := '';
end;

function InjectOrUpdateMetadata(const CTXml: String; const Meta: TCEEasyMetadata): String;
const
  EXT_OPEN = '<Extensions>';
  EXT_CLOSE = '</Extensions>';
  NODE_OPEN = '<CEEasyTrainer>';
  NODE_CLOSE = '</CEEasyTrainer>';
var
  pExtOpen, pExtClose, pNodeOpen, pNodeClose: SizeInt;
  newNode: String;
begin
  Result := CTXml;
  newNode := BuildMetaNode(Meta);

  pNodeOpen := Pos(NODE_OPEN, Result);
  pNodeClose := Pos(NODE_CLOSE, Result);

  // Update existing metadata node
  if (pNodeOpen > 0) and (pNodeClose > pNodeOpen) then
  begin
    pNodeClose := pNodeClose + Length(NODE_CLOSE) - 1;
    Delete(Result, pNodeOpen, pNodeClose - pNodeOpen + 1);
    Insert(newNode, Result, pNodeOpen);
    Exit;
  end;

  // Insert into existing <Extensions>
  pExtOpen := Pos(EXT_OPEN, Result);
  pExtClose := Pos(EXT_CLOSE, Result);
  if (pExtOpen > 0) and (pExtClose > pExtOpen) then
  begin
    Insert(newNode, Result, pExtClose);
    Exit;
  end;

  // Fallback: append a fresh Extensions block at tail
  Result := Result + '<Extensions>' + newNode + '</Extensions>';
end;

function TryParseMetadata(const CTXml: String; out Meta: TCEEasyMetadata): Boolean;
var
  nodeStart, nodeEnd: SizeInt;
  nodeXml: String;
begin
  Result := False;
  Meta := DefaultMetadata;

  nodeStart := Pos('<CEEasyTrainer>', CTXml);
  nodeEnd := Pos('</CEEasyTrainer>', CTXml);
  if (nodeStart <= 0) or (nodeEnd <= nodeStart) then Exit;

  nodeEnd := nodeEnd + Length('</CEEasyTrainer>') - 1;
  nodeXml := Copy(CTXml, nodeStart, nodeEnd - nodeStart + 1);

  Meta.Version := ExtractTagValue(nodeXml, 'Version');
  Meta.AutoReattach := XmlToBool(ExtractTagValue(nodeXml, 'AutoReattach'));
  Meta.PreferredStrategy := ExtractTagValue(nodeXml, 'PreferredStrategy');
  Meta.Notes := ExtractTagValue(nodeXml, 'Notes');

  if Meta.Version = '' then Meta.Version := '1.0';
  if Meta.PreferredStrategy = '' then Meta.PreferredStrategy := 'auto';

  Result := True;
end;

end.
