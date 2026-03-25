unit P2D.Components.Tag;
{$mode objfpc}{$H+}
interface
uses SysUtils,P2D.Core.Component;
type
  TTagComponent2D=class(TComponent2D)
  private FTags:array of String; FCount:Integer;
  public
    constructor Create;override;
    procedure AddTag(const T:String);
    procedure RemoveTag(const T:String);
    function  HasTag(const T:String):Boolean;
    procedure ClearTags;
    function  GetTag(I:Integer):String;
    property  Count:Integer read FCount;
  end;
implementation
uses P2D.Core.ComponentRegistry;
constructor TTagComponent2D.Create;
begin inherited Create;FCount:=0;SetLength(FTags,8);end;
procedure TTagComponent2D.AddTag(const T:String);
var I:Integer;
begin for I:=0 to FCount-1 do if SameText(FTags[I],T)then Exit;
  if FCount>=Length(FTags)then SetLength(FTags,Length(FTags)*2);
  FTags[FCount]:=T;Inc(FCount);end;
procedure TTagComponent2D.RemoveTag(const T:String);
var I:Integer;
begin for I:=0 to FCount-1 do if SameText(FTags[I],T)then
  begin FTags[I]:=FTags[FCount-1];Dec(FCount);Exit;end;end;
function TTagComponent2D.HasTag(const T:String):Boolean;
var I:Integer;
begin for I:=0 to FCount-1 do if SameText(FTags[I],T)then begin Result:=True;Exit;end;
  Result:=False;end;
procedure TTagComponent2D.ClearTags;begin FCount:=0;end;
function TTagComponent2D.GetTag(I:Integer):String;
begin if(I>=0)and(I<FCount)then Result:=FTags[I]else Result:='';end;
initialization ComponentRegistry.Register(TTagComponent2D);
end.
