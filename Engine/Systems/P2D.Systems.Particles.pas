unit P2D.Systems.Particles;

{$mode ObjFPC}
{$H+}

interface

uses
   Classes,
   SysUtils,
   P2D.Core.ComponentRegistry,
   P2D.Core.System,
   P2D.Core.Entity,
   P2D.Components.ParticleEmitter,
   P2D.Components.Transform;

type
   { TParticleSystem }
   TParticleSystem = class(TSystem2D)
   private
      FParticleEmitterID: Integer;
      FTransformID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure FixedUpdate(AFixedDelta: Single); override;
      procedure Render; override;
   end;

implementation

constructor TParticleSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 60;
   Name := 'ParticleSystem';
end;

procedure TParticleSystem.Init;
begin
   inherited;

   RequireComponent(TParticleEmitterComponent);
   RequireComponent(TTransformComponent);

   FParticleEmitterID := ComponentRegistry.GetComponentID(TParticleEmitterComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
end;

{ TP2DParticleSystem }
procedure TParticleSystem.FixedUpdate(AFixedDelta: Single);
var
   E: TEntity;
   Emitter: TParticleEmitterComponent;
   Transform: TTransformComponent;
begin
   for E In GetMatchingEntities do
   begin
      Emitter := TParticleEmitterComponent(E.GetComponentByID(FParticleEmitterID));
      Transform := TTransformComponent(E.GetComponentByID(FTransformID));

      if Assigned(Emitter) then
      begin
         Emitter.Update(AFixedDelta)
      end;
   end;
end;

procedure TParticleSystem.Render;
var
   E: TEntity;
   Emitter: TParticleEmitterComponent;
   Transform: TTransformComponent;
begin
   for E In GetMatchingEntities do
   begin
      Emitter := TParticleEmitterComponent(E.GetComponentByID(FParticleEmitterID));
      Transform := TTransformComponent(E.GetComponentByID(FTransformID));

      if Assigned(Emitter) And Assigned(Transform) then
      begin
         Emitter.RenderAt(Transform.Position)
      end;
   end;
end;

end.
