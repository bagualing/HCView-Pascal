{*******************************************************}
{                                                       }
{               HCView V1.1  作者：荆通                 }
{                                                       }
{      本代码遵循BSD协议，你可以加入QQ群 649023932      }
{            来获取更多的技术交流 2018-12-14            }
{                                                       }
{                     xml格式处理                       }
{                                                       }
{*******************************************************}

unit HCXml;

interface

uses
  Classes, Windows, Graphics, XMLDoc, XMLIntf, SysUtils;

type
  IHCXMLDocument = IXMLDocument;

  IHCXMLNode = IXMLNode;

  THCXMLDocument = class(TXMLDocument)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  function GetEncodingName(const AEncoding: TEncoding): string;
  function GetColorXmlRGB(const AColor: TColor): string;
  function GetXmlRGBColor(const AColorStr: string): TColor;
  //function GetColorHtmlRGB(const AColor: TColor): string;
  function GetXmlRN(const AText: string): string;

  /// <summary> Bitmap转为Base64字符 </summary>
  function GraphicToBase64(const AGraphic: TGraphic): string;
  procedure Base64ToGraphic(const ABase64: string; const AGraphic: TGraphic);

implementation

uses
  EncdDecd, HCCommon;

function GetEncodingName(const AEncoding: TEncoding): string;
begin
  if AEncoding = TEncoding.UTF8 then
    Result := 'UTF-8'
  else
    Result := 'Unicode';
end;

function StreamToBase64(const AStream: TStream): string;
var
  vSs:TStringStream;
begin
  vSs := TStringStream.Create('');
  try
    AStream.Position := 0;
    EncodeStream(AStream, vSs);  // 将内存流编码为base64字符流
    Result := vSs.DataString;
  finally
    FreeAndNil(vSs);
  end;
end;

procedure Base64ToStream(const ABase64: string; var AStream: TStream);
var
  vSs:TStringStream;
begin
  vSs := TStringStream.Create(ABase64);
  try
    DecodeStream(vSs, AStream);//将base64字符流还原为内存流
  finally
    FreeAndNil(vSs);
  end;
end;

function GraphicToBase64(const AGraphic: TGraphic): string;
var
  vMs: TMemoryStream;
begin
  vMs := TMemoryStream.Create;
  try
    AGraphic.SaveToStream(vMs);
    Result := StreamToBase64(vMs);  // 将base64字符流还原为内存流
  finally
    FreeAndNil(vMs);
  end;
end;

procedure Base64ToGraphic(const ABase64: string; const AGraphic: TGraphic);
var
  vMs: TStream;
begin
  vMs := TMemoryStream.Create;
  try
    Base64ToStream(ABase64, vMs);
    vMs.Position := 0;
    AGraphic.LoadFromStream(vMs);
  finally
    FreeAndNil(vMs);
  end;
end;

function GetColorXmlRGB(const AColor: TColor): string;
var
  vR, vG, vB: Byte;
begin
  if AColor = HCTransparentColor then
    Result := '0,255,255,255'
  else
  begin
    vR := Byte(AColor);
    vG := Byte(AColor shr 8);
    vB := Byte(AColor shr 16);
    Result := Format('255,%d,%d,%d', [vR, vG, vB]);
  end;
end;

function GetXmlRGBColor(const AColorStr: string): TColor;
var
  vsRGB: TStringList;
begin
  vsRGB := TStringList.Create;
  try
    vsRGB.Delimiter := ',';
    vsRGB.DelimitedText := AColorStr;

    if vsRGB.Count > 3 then
    begin
      if vsRGB[0] = '0' then
        Result := HCTransparentColor
      else
        Result := RGB(StrToInt(vsRGB[1]), StrToInt(vsRGB[2]), StrToInt(vsRGB[3]));
    end
    else
      Result := RGB(StrToInt(vsRGB[0]), StrToInt(vsRGB[1]), StrToInt(vsRGB[2]));
  finally
    FreeAndNil(vsRGB);
  end;
end;

function GetXmlRN(const AText: string): string;
begin
  Result := StringReplace(AText, #10, #13#10, [rfReplaceAll]);
end;

//function GetColorHtmlRGB(const AColor: TColor): string;
//begin
//  Result := 'rgb(' + GetColorXmlRGB(AColor) + ')';
//end;

{ THCXMLDocument }

constructor THCXMLDocument.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ParseOptions := ParseOptions + [poPreserveWhiteSpace];
end;

end.
