unit P2D.Systems.Animation;

{$mode objfpc}{$H+}

interface

uses
   raylib,
   P2D.Core.ComponentRegistry, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Sprite, P2D.Components.Animation;

type
   { TAnimationSystem }
   TAnimationSystem = class(TSystem2D)
   private
      FAnimationID: Integer;
      FSpriteID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

constructor TAnimationSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 5;
   Name     := 'AnimationSystem';
end;

procedure TAnimationSystem.Init;
begin
   inherited;

   RequireComponent(TAnimationComponent);
   RequireComponent(TSpriteComponent);

   FAnimationID := ComponentRegistry.GetComponentID(TAnimationComponent);
   FSpriteID := ComponentRegistry.GetComponentID(TSpriteComponent);
end;

procedure TAnimationSystem.Update(ADelta: Single);
var
   E   : TEntity;
   Anim: TAnimationComponent;
   Spr : TSpriteComponent;
   Rect: TRectangle;
begin
   for E in GetMatchingEntities do
   begin
      Anim := TAnimationComponent(E.GetComponentByID(FAnimationID));
      Spr  := TSpriteComponent(E.GetComponentByID(FSpriteID));

      if Anim.Enabled and Spr.Enabled then
      begin
         Anim.Tick(ADelta, Rect);
         Spr.SourceRect := Rect;
      end;
   end;
end;

end.
