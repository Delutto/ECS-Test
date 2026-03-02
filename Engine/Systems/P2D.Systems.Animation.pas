unit P2D.Systems.Animation;

{$mode objfpc}{$H+}

interface
uses
	P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
     P2D.Components.Sprite, P2D.Components.Animation;
type
  TAnimationSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;
  
implementation

constructor TAnimationSystem.Create(AWorld: TWorld);
begin
	inherited Create(AWorld);
	Priority := 5;
	Name := 'AnimationSystem';
end;

procedure TAnimationSystem.Update(ADelta: Single);
var
	E: TEntity;
	Anim: TAnimationComponent;
	Spr: TSpriteComponent;
	Rect: TRectangle;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then
		Continue;
    if not E.HasComponent(TAnimationComponent) then
		Continue;
    if not E.HasComponent(TSpriteComponent) then
		Continue;
    Anim := TAnimationComponent(E.GetComponent(TAnimationComponent));
    Spr := TSpriteComponent(E.GetComponent(TSpriteComponent));
    if Anim.Enabled and Spr.Enabled then
	begin
		Anim.Tick(ADelta,Rect);
		Spr.SourceRect := Rect;
	end;
  end;
end;
end.