{*******************************************************}
{                                                       }
{               HCView V1.0  ���ߣ���ͨ                 }
{                                                       }
{      ��������ѭBSDЭ�飬����Լ���QQȺ 649023932      }
{            ����ȡ����ļ������� 2018-5-4              }
{                                                       }
{             �ĵ��ڸ������߼�������Ԫ                }
{                                                       }
{*******************************************************}

unit HCRichData;

interface

uses
  Windows, Classes, Controls, Graphics, SysUtils, HCCustomData, HCCustomRichData,
  HCItem, HCStyle, HCParaStyle, HCTextStyle, HCTextItem, HCRectItem, HCCommon,
  HCUndoRichData, HCList;

type
  TDomain = class
  strict private
    FBeginNo, FEndNo: Integer;
  public
    constructor Create;
    procedure Clear;
    function Contain(const AItemNo: Integer): Boolean;
    property BeginNo: Integer read FBeginNo write FBeginNo;
    property EndNo: Integer read FEndNo write FEndNo;
  end;

  TDrawItemPaintEvent = procedure (const AData: THCCustomData;
    const ADrawItemNo: Integer; const ADrawRect: TRect; const ADataDrawLeft,
    ADataDrawBottom, ADataScreenTop, ADataScreenBottom: Integer;
    const ACanvas: TCanvas; const APaintInfo: TPaintInfo) of object;

  TStyleItemEvent = function (const AStyleNo: Integer): THCCustomItem of object;

  THCRichData = class(THCUndoRichData)  // ���ı������࣬����Ϊ������ʾ���ı���Ļ���
  private
    FDomainStartDeletes: THCIntegerList;  // ������ѡ��ɾ��ʱ��������ʼ������ѡ��ʱ��ɾ���˽����������ʼ�Ŀ�ɾ��
    FHotDomain,  // ��ǰ������
    FActiveDomain  // ��ǰ������
      : TDomain;
    FHotDomainRGN, FActiveDomainRGN: HRGN;
    FDrawActiveDomainRegion, FDrawHotDomainRegion: Boolean;  // �Ƿ������߿�
    FOnDrawItemPaintAfter: TDrawItemPaintEvent;
    FOnCreateItemByStyle: TStyleItemEvent;
    procedure GetDomainFrom(const AItemNo, AOffset: Integer;
      const ADomain: TDomain);
    function GetActiveDomain: TDomain;
  protected
    function CreateItemByStyle(const AStyleNo: Integer): THCCustomItem; override;
    function CreateDefaultDomainItem: THCCustomItem; override;
    function CreateDefaultTextItem: THCCustomItem; override;
    procedure PaintData(const ADataDrawLeft, ADataDrawTop, ADataDrawBottom,
      ADataScreenTop, ADataScreenBottom, AVOffset: Integer;
      const ACanvas: TCanvas; const APaintInfo: TPaintInfo); override;
    procedure InitializeField; override;
    procedure GetCaretInfo(const AItemNo, AOffset: Integer; var ACaretInfo: TCaretInfo); override;
    function CanDeleteItem(const AItemNo: Integer): Boolean; override;
    function DeleteSelected: Boolean; override;

    /// <summary> ���ڴ���������Items�󣬼�鲻�ϸ��Item��ɾ�� </summary>
    function CheckInsertItemCount(const AStartNo, AEndNo: Integer): Integer; override;
    //
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;

    procedure DoDrawItemPaintBefor(const AData: THCCustomData; const ADrawItemNo: Integer;
      const ADrawRect: TRect; const ADataDrawLeft, ADataDrawBottom, ADataScreenTop,
      ADataScreenBottom: Integer; const ACanvas: TCanvas; const APaintInfo: TPaintInfo); override;

    procedure DoDrawItemPaintAfter(const AData: THCCustomData; const ADrawItemNo: Integer;
      const ADrawRect: TRect; const ADataDrawLeft, ADataDrawBottom, ADataScreenTop,
      ADataScreenBottom: Integer; const ACanvas: TCanvas; const APaintInfo: TPaintInfo); override;

    function InsertItem(const AItem: THCCustomItem): Boolean; override;
    function InsertItem(const AIndex: Integer; const AItem: THCCustomItem;
      const AOffsetBefor: Boolean = True): Boolean; override;
  public
    constructor Create(const AStyle: THCStyle); override;
    destructor Destroy; override;

    /// <summary> ����ѡ�з�Χ�������ⲿʹ���ڲ���ʹ�� </summary>
    procedure SetSelectBound(const AStartNo, AStartOffset, AEndNo, AEndOffset: Integer);

    /// <summary> ѡ��ָ��Item������� </summary>
    procedure SelectItemAfter(const AItemNo: Integer);

    /// <summary> ѡ�����һ��Item������� </summary>
    procedure SelectLastItemAfter;

    /// <summary> ��ȡDomainItem��Ե���һ��ItemNo </summary>
    function GetDomainAnother(const AItemNo: Integer): Integer;

    procedure GetCaretInfoCur(var ACaretInfo: TCaretInfo);
    procedure TraverseItem(const ATraverse: TItemTraverse);
    property HotDomain: TDomain read FHotDomain;
    property ActiveDomain: TDomain read GetActiveDomain;
    property OnDrawItemPaintAfter: TDrawItemPaintEvent read FOnDrawItemPaintAfter write FOnDrawItemPaintAfter;
    property OnCreateItemByStyle: TStyleItemEvent read FOnCreateItemByStyle write FOnCreateItemByStyle;
  end;

implementation

{ THCRichData }

function THCRichData.CanDeleteItem(const AItemNo: Integer): Boolean;
var
  vItemNo: Integer;
begin
  Result := inherited CanDeleteItem(AItemNo);
  if Result then
  begin
    if Items[AItemNo].StyleNo = THCStyle.RsDomain then  // �����ʶ
    begin
      if (Items[AItemNo] as THCDomainItem).MarkType = TMarkType.cmtEnd then  // �������ʶ
      begin
        vItemNo := GetDomainAnother(AItemNo);  // ����ʼ
        Result := (vItemNo >= SelectInfo.StartItemNo) and (vItemNo <= SelectInfo.EndItemNo);
        if Result then  // ��ʼҲ��ѡ��ɾ����Χ��
          FDomainStartDeletes.Add(vItemNo);  // ��¼����
      end
      else  // ����ʼ���
        Result := FDomainStartDeletes.IndexOf(AItemNo) >= 0;  // ������ʶ�Ѿ�ɾ����
    end;
  end;
end;

function THCRichData.CheckInsertItemCount(const AStartNo,
  AEndNo: Integer): Integer;
var
  i, vDelCount: Integer;
begin
  Result := inherited CheckInsertItemCount(AStartNo, AEndNo);

  // �����ػ�ճ���ȴ�������Items��ƥ�������ʼ������ʶ��ɾ��
  vDelCount := 0;
  for i := AStartNo to AEndNo do  // ��ǰ������û�в�����ʼ��ʶ����ɾ���������������ʶ
  begin
    if Items[i] is THCDomainItem then  // ���ʶ
    begin
      if (Items[i] as THCDomainItem).MarkType = TMarkType.cmtEnd then  // �ǽ�����˵��û�в����Ӧ����ʼ
      begin
        if i < AEndNo then  // ������󣬺���̳������ʼ����
          Items[i + 1].ParaFirst := Items[i].ParaFirst;

        Items.Delete(i);
        Inc(vDelCount);

        if (i > AStartNo) and (i <= AEndNo - vDelCount) then  // ɾ�����м��
        begin
          if (not Items[i - 1].ParaFirst)
            and (not Items[i].ParaFirst)
            and MergeItemText(Items[i - 1], Items[i])  // ǰ�󶼲��Ƕ��ף����ܺϲ�
          then
          begin
            Items.Delete(i);
            Inc(vDelCount);
          end;
        end;

        Break;
      end
      else  // ����ʼ���ǣ����õ�����
        Break;
    end;
  end;

  for i := AEndNo - vDelCount downto AStartNo do  // �Ӻ���ǰ����û�в��������ʶ����
  begin
    if Items[i] is THCDomainItem then  // ���ʶ
    begin
      if (Items[i] as THCDomainItem).MarkType = TMarkType.cmtBeg then  // ����ʼ��˵��û�в����Ӧ�Ľ���
      begin
        if i < AEndNo - vDelCount then  // ������󣬺���̳������ʼ����
          Items[i + 1].ParaFirst := Items[i].ParaFirst;

        Items.Delete(i);
        Inc(vDelCount);

        if (i > AStartNo) and (i <= AEndNo - vDelCount) then  // ɾ�����м��
        begin
          if (not Items[i - 1].ParaFirst)
            and (not Items[i].ParaFirst)
            and MergeItemText(Items[i - 1], Items[i])  // ǰ�󶼲��Ƕ��ף����ܺϲ�
          then
          begin
            Items.Delete(i);
            Inc(vDelCount);
          end;
        end;

        Break;
      end
      else  // �ǽ������ǣ����õ�����
        Break;
    end;
  end;

  Result := Result - vDelCount;
end;

constructor THCRichData.Create(const AStyle: THCStyle);
begin
  FDomainStartDeletes := THCIntegerList.Create;
  FHotDomain := TDomain.Create;
  FActiveDomain := TDomain.Create;
  inherited Create(AStyle);
end;

function THCRichData.CreateDefaultDomainItem: THCCustomItem;
begin
  Result := HCDefaultDomainItemClass.Create(Self);
end;

function THCRichData.CreateDefaultTextItem: THCCustomItem;
begin
  Result := HCDefaultTextItemClass.CreateByText('');  // �����в��������ܵ������Դ���
  if Style.CurStyleNo < THCStyle.RsNull then
    Result.StyleNo := 0
  else
    Result.StyleNo := Style.CurStyleNo;

  Result.ParaNo := Style.CurParaNo;
  if Assigned(OnCreateItem) then
    OnCreateItem(Result);
end;

function THCRichData.CreateItemByStyle(const AStyleNo: Integer): THCCustomItem;
begin
  Result := nil;

  if Assigned(FOnCreateItemByStyle) then  // �Զ���������ڴ˴�����
    Result := FOnCreateItemByStyle(AStyleNo);

  if not Assigned(Result) then
    Result := inherited CreateItemByStyle(AStyleNo);
end;

function THCRichData.DeleteSelected: Boolean;
begin
  FDomainStartDeletes.Clear;
  Result := inherited DeleteSelected;
end;

destructor THCRichData.Destroy;
begin
  FHotDomain.Free;
  FActiveDomain.Free;
  FDomainStartDeletes.Free;
  inherited Destroy;
end;

procedure THCRichData.DoDrawItemPaintAfter(const AData: THCCustomData;
  const ADrawItemNo: Integer; const ADrawRect: TRect; const ADataDrawLeft,
  ADataDrawBottom, ADataScreenTop, ADataScreenBottom: Integer;
  const ACanvas: TCanvas; const APaintInfo: TPaintInfo);

  {$REGION ' DrawLineLastMrak ��β�Ļ��з� '}
  procedure DrawLineLastMrak(const ADrawRect: TRect);
  var
    vPt: TPoint;
  begin
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Color := clActiveBorder;

    SetViewportExtEx(ACanvas.Handle, APaintInfo.WindowWidth, APaintInfo.WindowHeight, @vPt);
    try
      ACanvas.MoveTo(APaintInfo.GetScaleX(ADrawRect.Right) + 4,
        APaintInfo.GetScaleY(ADrawRect.Bottom) - 8);
      ACanvas.LineTo(APaintInfo.GetScaleX(ADrawRect.Right) + 6, APaintInfo.GetScaleY(ADrawRect.Bottom) - 8);
      ACanvas.LineTo(APaintInfo.GetScaleX(ADrawRect.Right) + 6, APaintInfo.GetScaleY(ADrawRect.Bottom) - 3);

      ACanvas.MoveTo(APaintInfo.GetScaleX(ADrawRect.Right),     APaintInfo.GetScaleY(ADrawRect.Bottom) - 3);
      ACanvas.LineTo(APaintInfo.GetScaleX(ADrawRect.Right) + 6, APaintInfo.GetScaleY(ADrawRect.Bottom) - 3);

      ACanvas.MoveTo(APaintInfo.GetScaleX(ADrawRect.Right) + 1, APaintInfo.GetScaleY(ADrawRect.Bottom) - 4);
      ACanvas.LineTo(APaintInfo.GetScaleX(ADrawRect.Right) + 1, APaintInfo.GetScaleY(ADrawRect.Bottom) - 1);

      ACanvas.MoveTo(APaintInfo.GetScaleX(ADrawRect.Right) + 2, APaintInfo.GetScaleY(ADrawRect.Bottom) - 5);
      ACanvas.LineTo(APaintInfo.GetScaleX(ADrawRect.Right) + 2, APaintInfo.GetScaleY(ADrawRect.Bottom));
    finally
      SetViewportExtEx(ACanvas.Handle, APaintInfo.GetScaleX(APaintInfo.WindowWidth),
        APaintInfo.GetScaleY(APaintInfo.WindowHeight), @vPt);
    end;
  end;
  {$ENDREGION}

begin
  inherited DoDrawItemPaintAfter(AData, ADrawItemNo, ADrawRect, ADataDrawLeft,
    ADataDrawBottom, ADataScreenTop, ADataScreenBottom, ACanvas, APaintInfo);

  if not APaintInfo.Print then
  begin
    if AData.Style.ShowLineLastMark then
    begin
      if (ADrawItemNo < DrawItems.Count - 1) and DrawItems[ADrawItemNo + 1].ParaFirst then
        DrawLineLastMrak(ADrawRect)  // ��β�Ļ��з�
      else
      if ADrawItemNo = DrawItems.Count - 1 then
        DrawLineLastMrak(ADrawRect);  // ��β�Ļ��з�
    end;
  end;

  if Assigned(FOnDrawItemPaintAfter) then
  begin
    FOnDrawItemPaintAfter(AData, ADrawItemNo, ADrawRect, ADataDrawLeft,
      ADataDrawBottom, ADataScreenTop, ADataScreenBottom, ACanvas, APaintInfo);
  end;
end;

procedure THCRichData.DoDrawItemPaintBefor(const AData: THCCustomData;
  const ADrawItemNo: Integer; const ADrawRect: TRect; const ADataDrawLeft,
  ADataDrawBottom, ADataScreenTop, ADataScreenBottom: Integer;
  const ACanvas: TCanvas; const APaintInfo: TPaintInfo);
var
  vDrawHotDomainBorde, vDrawActiveDomainBorde: Boolean;
  vItemNo: Integer;
  vDliRGN: HRGN;
begin
  inherited DoDrawItemPaintBefor(AData, ADrawItemNo, ADrawRect, ADataDrawLeft,
    ADataDrawBottom, ADataScreenTop, ADataScreenBottom, ACanvas, APaintInfo);;
  if not APaintInfo.Print then
  begin
    vDrawHotDomainBorde := False;
    vDrawActiveDomainBorde := False;
    vItemNo := DrawItems[ADrawItemNo].ItemNo;

    if FHotDomain.BeginNo >= 0 then
      vDrawHotDomainBorde := FHotDomain.Contain(vItemNo);

    if FActiveDomain.BeginNo >= 0 then
      vDrawActiveDomainBorde := FActiveDomain.Contain(vItemNo);

    if vDrawHotDomainBorde or vDrawActiveDomainBorde then
    begin
      vDliRGN := CreateRectRgn(ADrawRect.Left, ADrawRect.Top, ADrawRect.Right, ADrawRect.Bottom);
      try
        if (FHotDomain.BeginNo >= 0) and vDrawHotDomainBorde then
          CombineRgn(FHotDomainRGN, FHotDomainRGN, vDliRGN, RGN_OR);
        if (FActiveDomain.BeginNo >= 0) and vDrawActiveDomainBorde then
          CombineRgn(FActiveDomainRGN, FActiveDomainRGN, vDliRGN, RGN_OR);
      finally
        DeleteObject(vDliRGN);
      end;
    end;
  end;
end;

function THCRichData.GetDomainAnother(const AItemNo: Integer): Integer;
var
  vDomain: THCDomainItem;
  i, vIgnore: Integer;
begin
  Result := -1;
  vIgnore := 0;

  // ���ⲿ��֤AItemNo��Ӧ����THCDomainItem
  vDomain := Self.Items[AItemNo] as THCDomainItem;
  if vDomain.MarkType = TMarkType.cmtEnd then  // �ǽ�����ʶ
  begin
    for i := AItemNo - 1 downto 0 do  // ����ʼ��ʶ
    begin
      if Items[i].StyleNo = THCStyle.RsDomain then
      begin
        if (Items[i] as THCDomainItem).MarkType = TMarkType.cmtBeg then  // ����ʼ��ʶ
        begin
          if vIgnore = 0 then
          begin
            Result := i;
            Break;
          end
          else
            Dec(vIgnore);
        end
        else
          Inc(vIgnore);
      end;
    end;
  end
  else  // ����ʼ��ʶ
  begin
    for i := AItemNo + 1 to Self.Items.Count - 1 do  // �ҽ�����ʶ
    begin
      if Items[i].StyleNo = THCStyle.RsDomain then
      begin
        if (Items[i] as THCDomainItem).MarkType = TMarkType.cmtEnd then  // �ǽ�����ʶ
        begin
          if vIgnore = 0 then
          begin
            Result := i;
            Break;
          end
          else
            Dec(vIgnore);
        end
        else
          Inc(vIgnore);
      end;
    end;
  end;
end;

procedure THCRichData.GetDomainFrom(const AItemNo, AOffset: Integer;
  const ADomain: TDomain);
var
  i, vStartNo, vEndNo, vCount: Integer;
begin
  ADomain.Clear;

  if (AItemNo < 0) or (AOffset < 0) then Exit;

  { ����ʼ��ʶ }
  vCount := 0;
  // ȷ����ǰ�ҵ���ʼλ��
  vStartNo := AItemNo;
  vEndNo := AItemNo;
  if Items[AItemNo] is THCDomainItem then  // ��ʼλ�þ���Group
  begin
    if (Items[AItemNo] as THCDomainItem).MarkType = TMarkType.cmtBeg then  // ����λ������ʼ���
    begin
      if AOffset = OffsetAfter then  // ����ں���
      begin
        ADomain.BeginNo := AItemNo;  // ��ǰ��Ϊ��ʼ��ʶ
        vEndNo := AItemNo + 1;
      enD
      else  // �����ǰ��
      begin
        if AItemNo > 0 then  // ���ǵ�һ��
          vStartNo := AItemNo - 1  // ��ǰһ����ǰ
        else  // ���ڵ�һ��ǰ��
          Exit;  // ��������
      end;
    end
    else  // ����λ���ǽ������
    begin
      if AOffset = OffsetAfter then  // ����ں���
      begin
        if AItemNo < Items.Count - 1 then  // �������һ��
          vEndNo := AItemNo + 1
        else  // �����һ������
          Exit;  // ��������
      end
      else  // �����ǰ��
      begin
        ADomain.EndNo := AItemNo;
        vStartNo := AItemNo - 1;
      end;
    end;
  end;

  if ADomain.BeginNo < 0 then
  begin
    for i := vStartNo downto 0 do  // ��
    begin
      if Items[i] is THCDomainItem then
      begin
        if (Items[i] as THCDomainItem).MarkType = TMarkType.cmtBeg then  // ��ʼ���
        begin
          if vCount <> 0 then  // ��Ƕ��
            Dec(vCount)
          else
          begin
            ADomain.BeginNo := i;
            Break;
          end;
        end
        else  // �������
          Inc(vCount);  // ��Ƕ��
      end;
    end;
  end;

  { �ҽ�����ʶ }
  if (ADomain.BeginNo >= 0) and (ADomain.EndNo < 0) then
  begin
    vCount := 0;
    for i := vEndNo to Items.Count - 1 do
    begin
      if Items[i] is THCDomainItem then
      begin
        if (Items[i] as THCDomainItem).MarkType = TMarkType.cmtEnd then  // �ǽ�β
        begin
          if vCount <> 0 then
            Dec(vCount)
          else
          begin
            ADomain.EndNo := i;
            Break;
          end;
        end
        else  // ����ʼ���
          Inc(vCount);  // ��Ƕ��
      end;
    end;

    if ADomain.EndNo < 0 then
      raise Exception.Create('�쳣����ȡ���������������');
  end;
end;

function THCRichData.GetActiveDomain: TDomain;
begin
  Result := nil;
  if FActiveDomain.BeginNo >= 0 then
    Result := FActiveDomain;
end;

procedure THCRichData.GetCaretInfo(const AItemNo, AOffset: Integer;
  var ACaretInfo: TCaretInfo);
var
  vTopData: THCCustomRichData;
begin
  inherited GetCaretInfo(AItemNo, AOffset, ACaretInfo);

  // ��ֵ����Group��Ϣ������� MouseDown
  if Self.SelectInfo.StartItemNo >= 0 then
  begin
    vTopData := GetTopLevelData;
    if vTopData = Self then
    begin
      if FActiveDomain.BeginNo >= 0 then  // ԭ������Ϣ(����δͨ��������ƶ����ʱû�����)
      begin
        FActiveDomain.Clear;
        FDrawActiveDomainRegion := False;
        Style.UpdateInfoRePaint;
      end;
      // ��ȡ��ǰ��괦ActiveDeGroup��Ϣ
      Self.GetDomainFrom(Self.SelectInfo.StartItemNo, Self.SelectInfo.StartItemOffset, FActiveDomain);
      if FActiveDomain.BeginNo >= 0 then
      begin
        FDrawActiveDomainRegion := True;
        Style.UpdateInfoRePaint;
      end;
    end;
  end;
end;

procedure THCRichData.GetCaretInfoCur(var ACaretInfo: TCaretInfo);
begin
  if Style.UpdateInfo.Draging then
    Self.GetCaretInfo(Self.MouseMoveItemNo, Self.MouseMoveItemOffset, ACaretInfo)
  else
    Self.GetCaretInfo(SelectInfo.StartItemNo, SelectInfo.StartItemOffset, ACaretInfo);
end;

function THCRichData.InsertItem(const AItem: THCCustomItem): Boolean;
begin
  Result := inherited InsertItem(AItem);
  if Result then
  begin
    Style.UpdateInfoRePaint;
    Style.UpdateInfoReCaret;
    Style.UpdateInfoReScroll;
  end;
end;

procedure THCRichData.InitializeField;
begin
  inherited InitializeField;
  FActiveDomain.Clear;
  FHotDomain.Clear;
end;

function THCRichData.InsertItem(const AIndex: Integer;
  const AItem: THCCustomItem; const AOffsetBefor: Boolean = True): Boolean;
begin
  Result := inherited InsertItem(AIndex, AItem, AOffsetBefor);
  if Result then
  begin
    Style.UpdateInfoRePaint;
    Style.UpdateInfoReCaret;
    Style.UpdateInfoReScroll;
  end;
end;

procedure THCRichData.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  // ��������Group��Ϣ����ֵ�� GetCaretInfo
  if FActiveDomain.BeginNo >= 0 then
    Style.UpdateInfoRePaint;
  FActiveDomain.Clear;
  FDrawActiveDomainRegion := False;

  inherited MouseDown(Button, Shift, X, Y);

  if Button = TMouseButton.mbRight then  // �Ҽ��˵�ʱ������ȡ��괦FActiveDomain
    Style.UpdateInfoReCaret;
end;

procedure THCRichData.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  vTopData: THCRichData;
begin
  // ��� FHotDeGroup ��Ϣ
  if FHotDomain.BeginNo >= 0 then
    Style.UpdateInfoRePaint;
  FHotDomain.Clear;
  FDrawHotDomainRegion := False;

  inherited MouseMove(Shift, X, Y);

  if not Self.MouseMoveRestrain then  // ��Item��
  begin
    Self.GetDomainFrom(Self.MouseMoveItemNo, Self.MouseMoveItemOffset, FHotDomain);  // ȡHotDeGroup
    vTopData := Self.GetTopLevelDataAt(X, Y) as THCRichData;
    if (vTopData = Self) or (not vTopData.FDrawHotDomainRegion) then  // �������� �� ���㲻�����Ҷ���û��HotDeGroup  201711281352
    begin
      if FHotDomain.BeginNo >= 0 then  // ��FHotDeGroup
      begin
        FDrawHotDomainRegion := True;
        Style.UpdateInfoRePaint;
      end;
    end;
  end;
end;

procedure THCRichData.PaintData(const ADataDrawLeft, ADataDrawTop,
  ADataDrawBottom, ADataScreenTop, ADataScreenBottom, AVOffset: Integer;
  const ACanvas: TCanvas; const APaintInfo: TPaintInfo);
var
  vOldColor: TColor;
begin
  if not APaintInfo.Print then  // �Ǵ�ӡ���Ƽ���������
  begin
    if FDrawHotDomainRegion then
      FHotDomainRGN := CreateRectRgn(0, 0, 0, 0);

    if FDrawActiveDomainRegion then
      FActiveDomainRGN := CreateRectRgn(0, 0, 0, 0);
  end;

  inherited PaintData(ADataDrawLeft, ADataDrawTop, ADataDrawBottom,
    ADataScreenTop, ADataScreenBottom, AVOffset, ACanvas, APaintInfo);

  if not APaintInfo.Print then  // �Ǵ�ӡ���Ƽ���������
  begin
    vOldColor := ACanvas.Brush.Color;  // ��Ϊʹ��Brush���Ʊ߿�������Ҫ����ԭ��ɫ
    try
      if FDrawHotDomainRegion then
      begin
        ACanvas.Brush.Color := clActiveBorder;
        FrameRgn(ACanvas.Handle, FHotDomainRGN, ACanvas.Brush.Handle, 1, 1);
        DeleteObject(FHotDomainRGN);
      end;

      if FDrawActiveDomainRegion then
      begin
        ACanvas.Brush.Color := clBlue;
        FrameRgn(ACanvas.Handle, FActiveDomainRGN, ACanvas.Brush.Handle, 1, 1);
        DeleteObject(FActiveDomainRGN);
      end;
    finally
      ACanvas.Brush.Color := vOldColor;
    end;
  end;
end;

procedure THCRichData.SelectItemAfter(const AItemNo: Integer);
begin
  ReSetSelectAndCaret(AItemNo);
end;

procedure THCRichData.SelectLastItemAfter;
begin
  SelectItemAfter(Items.Count - 1);
end;

procedure THCRichData.SetSelectBound(const AStartNo, AStartOffset, AEndNo,
  AEndOffset: Integer);
var
  vStartNo, vEndNo, vStartOffset, vEndOffset: Integer;
begin
  if AEndNo < 0 then  // ѡ��һ����
  begin
    vStartNo := AStartNo;
    vStartOffset := AStartOffset;
    vEndNo := -1;
    vEndOffset := -1;
  end
  else
  if AEndNo >= AStartNo then  // ��ǰ����ѡ��
  begin
    vStartNo := AStartNo;
    vEndNo := AEndNo;

    if AEndNo = AStartNo then  // ͬһ��Item
    begin
      if AEndOffset >= AStartOffset then  // ����λ������ʼ����
      begin
        vStartOffset := AStartOffset;
        vEndOffset := AEndOffset;
      end
      else  // ����λ������ʼǰ��
      begin
        vStartOffset := AEndOffset;
        vEndOffset := AStartOffset;
      end;
    end
    else  // ����ͬһ��Item
    begin
      vStartOffset := AStartOffset;
      vEndOffset := AEndOffset;
    end;
  end
  else  // AEndNo < AStartNo �Ӻ���ǰѡ��
  begin
    vStartNo := AEndNo;
    vStartOffset := AEndOffset;

    vEndNo := AStartNo;
    vEndOffset := vStartOffset;
  end;

  SelectInfo.StartItemNo := AStartNo;
  SelectInfo.StartItemOffset := AStartOffset;

  if (vEndNo < 0)
    or ((vEndNo = vStartNo) and (vEndOffset = vStartOffset))
  then
  begin
    SelectInfo.EndItemNo := -1;
    SelectInfo.EndItemOffset := -1;
  end
  else
  begin
    SelectInfo.EndItemNo := vEndNo;
    SelectInfo.EndItemOffset := vEndOffset;
  end;

  //FSelectSeekNo  �����Ҫȷ�� FSelectSeekNo���˷������ƶ���CustomRichData
end;

procedure THCRichData.TraverseItem(const ATraverse: TItemTraverse);
var
  i: Integer;
begin
  if ATraverse <> nil then
  begin
    for i := 0 to Items.Count - 1 do
    begin
      if ATraverse.Stop then Break;

      ATraverse.Process(Self, i, ATraverse.Tag, ATraverse.Stop);
      if Items[i].StyleNo < THCStyle.RsNull then
        (Items[i] as THCCustomRectItem).TraverseItem(ATraverse);
    end;
  end;
end;

{ TDomain }

procedure TDomain.Clear;
begin
  FBeginNo := -1;
  FEndNo := -1;
end;

function TDomain.Contain(const AItemNo: Integer): Boolean;
begin
  Result := (AItemNo >= FBeginNo) and (AItemNo <= FEndNo);
end;

constructor TDomain.Create;
begin
  Clear;
end;

end.