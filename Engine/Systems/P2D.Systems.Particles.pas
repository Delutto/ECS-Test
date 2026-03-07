unit P2D.Systems.Particles;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils,
   P2D.Core.System, P2D.Core.Entity,
   P2D.Components.ParticleEmitter, P2D.Components.Transform;

type
   { TParticleSystem }
   TParticleSystem = class(TSystem2D)
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


end;

procedure TParticleSystem.Init;
begin
   inherited Init;
end;

{ TP2DParticleSystem }
procedure TParticleSystem.FixedUpdate(AFixedDelta: Single);
var
   E: TEntity;
   Emitter: TParticleEmitterComponent;
   Transform: TTransformComponent;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then
         Continue;

      Emitter := TParticleEmitterComponent(E.GetComponent(TParticleEmitterComponent));
      Transform := TTransformComponent(E.GetComponent(TTransformComponent));

      if Assigned(Emitter) then
         Emitter.Update(AFixedDelta);
   end;
end;

procedure TParticleSystem.Render;
var
   E: TEntity;
   Emitter: TParticleEmitterComponent;
   Transform: TTransformComponent;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then
         Continue;

      Emitter := TParticleEmitterComponent(E.GetComponent(TParticleEmitterComponent));
      Transform := TTransformComponent(E.GetComponent(TTransformComponent));

      if Assigned(Emitter) and Assigned(Transform) then
      begin
         // Aplica transformação da entidade e renderiza partículas relativas à posição da entidade
         Emitter.Render;
      end;
   end;
end;

end.
