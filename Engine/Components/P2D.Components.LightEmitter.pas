unit P2D.Components.LightEmitter;
{$mode objfpc}{$H+}
interface
uses SysUtils,raylib,P2D.Core.Component,P2D.Core.Types;
type
  TLightShape2D=(lsCircle,lsCone,lsRect);
  TLightEmitterComponent2D=class(TComponent2D)
  public
    Color:TColor;
    Intensity,Radius,InnerRadius:Single;
    Shape:TLightShape2D;
    ConeAngle,ConeDirection:Single;
    RectW,RectH:Single;
    Flicker:Boolean;
    FlickerSpeed,FlickerAmp,FlickerTimer:Single;
    OffsetX,OffsetY:Single;
    ZOrder:Integer;
    constructor Create;override;
  end;
implementation
uses P2D.Core.ComponentRegistry;
constructor TLightEmitterComponent2D.Create;
begin inherited Create;
  Color:=ColorCreate(255,220,140,255);Intensity:=1;Radius:=96;InnerRadius:=0;
  Shape:=lsCircle;ConeAngle:=30;ConeDirection:=0;RectW:=64;RectH:=64;
  Flicker:=False;FlickerSpeed:=8;FlickerAmp:=0.15;FlickerTimer:=0;
  OffsetX:=0;OffsetY:=0;ZOrder:=0;end;
initialization ComponentRegistry.Register(TLightEmitterComponent2D);
end.
