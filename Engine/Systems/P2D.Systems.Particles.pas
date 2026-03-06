unit P2D.Systems.Particles;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils, P2D.Core.System, P2D.Core.Entity,
   P2D.Components.ParticleEmitter, P2D.Components.Transform;

type
   { TP2DParticleSystem }
   TP2DParticleSystem = class(TP2DSystem)
   public
      procedure Update(DeltaTime: Double); override;
      procedure Render; override;
   end;

implementation

{ TP2DParticleSystem }
procedure TP2DParticleSystem.Update(DeltaTime: Double);
var
   Entities: TArray<TP2DEntity>;
   i: Integer;
   Emitter: TP2DParticleEmitter;
   Transform: TP2DTransform;
begin
   Entities := World.GetEntitiesWithComponent(TP2DParticleEmitter);

   for i := 0 to High(Entities) do
   begin
      if not Entities[i].Active then
         Continue;

      Emitter := Entities[i].GetComponent(TP2DParticleEmitter) as TP2DParticleEmitter;
      Transform := Entities[i].GetComponent(TP2DTransform) as TP2DTransform;

      if Assigned(Emitter) then
         Emitter.Update(DeltaTime);
   end;
end;

procedure TP2DParticleSystem.Render;
var
   Entities: TArray<TP2DEntity>;
   i: Integer;
   Emitter: TP2DParticleEmitter;
   Transform: TP2DTransform;
begin
   Entities := World.GetEntitiesWithComponent(TP2DParticleEmitter);

   for i := 0 to High(Entities) do
   begin
      if not Entities[i].Active then
         Continue;

      Emitter := Entities[i].GetComponent(TP2DParticleEmitter) as TP2DParticleEmitter;
      Transform := Entities[i].GetComponent(TP2DTransform) as TP2DTransform;

      if Assigned(Emitter) and Assigned(Transform) then
      begin
         // Aplica transformação da entidade
         // Renderiza partículas relativas à posição da entidade
         Emitter.Render;
      end;
   end;
end;

end.
