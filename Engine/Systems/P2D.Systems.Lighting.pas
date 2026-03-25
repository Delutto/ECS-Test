unit P2D.Systems.Lighting;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,raylib,
     P2D.Core.ComponentRegistry,P2D.Core.Types,P2D.Core.Entity,
     P2D.Core.System,P2D.Core.World,
     P2D.Components.Transform,P2D.Components.LightEmitter;
type
  TLightingSystem2D=class(TSystem2D)
  private
    FTransformID,FLightID:Integer;
    FScreenW,FScreenH:Integer;
    FAmbientR,FAmbientG,FAmbientB,FAmbientA:Byte;
  public
    constructor Create(AW:TWorldBase;W,H:Integer);reintroduce;
    procedure Init;override;
    procedure Render;override;
    property AmbientR:Byte read FAmbientR write FAmbientR;
    property AmbientG:Byte read FAmbientG write FAmbientG;
    property AmbientB:Byte read FAmbientB write FAmbientB;
    property AmbientA:Byte read FAmbientA write FAmbientA;
  end;
implementation
uses P2D.Common;
constructor TLightingSystem2D.Create(AW:TWorldBase;W,H:Integer);
begin inherited Create(AW);Priority:=150;Name:='LightingSystem';
  RenderLayer:=rlWorld;FScreenW:=W;FScreenH:=H;
  FAmbientR:=DEFAULT_AMBIENT_R;FAmbientG:=DEFAULT_AMBIENT_G;
  FAmbientB:=DEFAULT_AMBIENT_B;FAmbientA:=DEFAULT_AMBIENT_A;end;
procedure TLightingSystem2D.Init;
begin inherited Init;
  RequireComponent(TLightEmitterComponent2D);RequireComponent(TTransformComponent);
  FTransformID:=ComponentRegistry.GetComponentID(TTransformComponent);
  FLightID:=ComponentRegistry.GetComponentID(TLightEmitterComponent2D);end;
procedure TLightingSystem2D.Render;
var E:TEntity;LC:TLightEmitterComponent2D;Tr:TTransformComponent;
    CX,CY:Single;DA:Byte;LC2:TColor;
begin
  DrawRectangle(0,0,FScreenW,FScreenH,ColorCreate(FAmbientR,FAmbientG,FAmbientB,FAmbientA));
  BeginBlendMode(BLEND_ADDITIVE);
  for E in GetMatchingEntities do begin
    LC:=TLightEmitterComponent2D(E.GetComponentByID(FLightID));
    Tr:=TTransformComponent(E.GetComponentByID(FTransformID));
    if not Assigned(LC)or not Assigned(Tr)then Continue;
    if not LC.Enabled or not Tr.Enabled then Continue;
    CX:=Tr.Position.X+LC.OffsetX;CY:=Tr.Position.Y+LC.OffsetY;
    if LC.Flicker then begin
      LC.FlickerTimer:=LC.FlickerTimer+0.016;
      DA:=Round((LC.Intensity+Sin(LC.FlickerTimer*LC.FlickerSpeed*2*Pi)*LC.FlickerAmp)*FAmbientA);
    end else DA:=Round(LC.Intensity*FAmbientA);
    DA:=Min(255,DA);LC2:=ColorCreate(LC.Color.R,LC.Color.G,LC.Color.B,DA);
    case LC.Shape of
      lsCircle:DrawCircleGradient(Round(CX),Round(CY),LC.Radius,LC2,
                  ColorCreate(LC.Color.R,LC.Color.G,LC.Color.B,0));
      lsRect:DrawRectangle(Round(CX-LC.RectW*0.5),Round(CY-LC.RectH*0.5),
               Round(LC.RectW),Round(LC.RectH),LC2);
      lsCone:DrawCircleGradient(Round(CX),Round(CY),LC.Radius,LC2,
               ColorCreate(LC.Color.R,LC.Color.G,LC.Color.B,0));
    end;end;
  EndBlendMode;end;
end.
