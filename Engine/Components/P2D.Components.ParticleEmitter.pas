unit P2D.Components.ParticleEmitter;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils, raylib, raymath,
   P2D.Core.Component, P2D.Core.Types;

type
   { TP2DParticle }
   TParticle2D = record
      Position: TVector2;
      Velocity: TVector2;
      Acceleration: TVector2;
      Color: TColor;
      Life: Single;
      MaxLife: Single;
      Size: Single;
      Rotation: Single;
      RotationSpeed: Single;
      Active: Boolean;
   end;

   { TEmitterShape2D }
   TEmitterShape2D = (esPoint, esCircle, esRectangle, esCone);

   { TParticleEmitterComponent }
   TParticleEmitterComponent = class(TComponent2D)
   private
      FParticles: array of TParticle2D;
      FMaxParticles: Integer;
      FEmissionRate: Single;
      FEmissionTimer: Single;
      FEmitterShape: TEmitterShape2D;
      FEmitterSize: TVector2;
      FEmitterAngle: Single;
      FEmitterSpread: Single;
      FParticleLifeMin: Single;
      FParticleLifeMax: Single;
      FParticleSpeedMin: Single;
      FParticleSpeedMax: Single;
      FParticleSizeMin: Single;
      FParticleSizeMax: Single;
      FParticleColorStart: TColor;
      FParticleColorEnd: TColor;
      FGravity: TVector2;
      FBurst: Boolean;
      FLoop: Boolean;
      FAutoStart: Boolean;
      FIsEmitting: Boolean;

      procedure EmitParticle;
      function FindInactiveParticle: Integer;
   public
      constructor Create; override;
      destructor Destroy; override;

      procedure Update(DeltaTime: Double);
      procedure RenderAt(const AWorldPos: TVector2);

      procedure Play;
      procedure Stop;
      procedure Pause;
      procedure Reset;
      procedure Emit(ACount: Integer);

      property MaxParticles: Integer read FMaxParticles write FMaxParticles;
      property EmissionRate: Single read FEmissionRate write FEmissionRate;
      property EmitterShape: TEmitterShape2D read FEmitterShape write FEmitterShape;
      property EmitterSize: TVector2 read FEmitterSize write FEmitterSize;
      property EmitterAngle: Single read FEmitterAngle write FEmitterAngle;
      property EmitterSpread: Single read FEmitterSpread write FEmitterSpread;
      property ParticleLifeMin: Single read FParticleLifeMin write FParticleLifeMin;
      property ParticleLifeMax: Single read FParticleLifeMax write FParticleLifeMax;
      property ParticleSpeedMin: Single read FParticleSpeedMin write FParticleSpeedMin;
      property ParticleSpeedMax: Single read FParticleSpeedMax write FParticleSpeedMax;
      property ParticleSizeMin: Single read FParticleSizeMin write FParticleSizeMin;
      property ParticleSizeMax: Single read FParticleSizeMax write FParticleSizeMax;
      property ParticleColorStart: TColor read FParticleColorStart write FParticleColorStart;
      property ParticleColorEnd: TColor read FParticleColorEnd write FParticleColorEnd;
      property Gravity: TVector2 read FGravity write FGravity;
      property Burst: Boolean read FBurst write FBurst;
      property Loop: Boolean read FLoop write FLoop;
      property AutoStart: Boolean read FAutoStart write FAutoStart;
      property IsEmitting: Boolean read FIsEmitting;
   end;

implementation

uses
   Math, P2D.Utils.Math, P2D.Core.ComponentRegistry;

{ TP2DParticleEmitter }

constructor TParticleEmitterComponent.Create;
begin
   inherited Create;

   FMaxParticles := 100;
   SetLength(FParticles, FMaxParticles);

   FEmissionRate := 10.0;
   FEmissionTimer := 0.0;
   FEmitterShape := esPoint;
   FEmitterSize := Vector2Create(0, 0);
   FEmitterAngle := 0.0;
   FEmitterSpread := 360.0;

   FParticleLifeMin := 1.0;
   FParticleLifeMax := 2.0;
   FParticleSpeedMin := 50.0;
   FParticleSpeedMax := 100.0;
   FParticleSizeMin := 2.0;
   FParticleSizeMax := 5.0;

   FParticleColorStart := WHITE;
   FParticleColorEnd := ColorCreate(255, 255, 255, 0);

   FGravity := Vector2Create(0, 98.0);

   FBurst := False;
   FLoop := True;
   FAutoStart := True;
   FIsEmitting := False;

   //if FAutoStart then
   //   Play;
end;

destructor TParticleEmitterComponent.Destroy;
begin
   SetLength(FParticles, 0);

   inherited;
end;

function TParticleEmitterComponent.FindInactiveParticle: Integer;
var
   i: Integer;
begin
   Result := -1;
   for i := 0 to High(FParticles) do
   begin
      if not FParticles[i].Active then
      begin
         Result := i;
         Exit;
      end;
   end;
end;

procedure TParticleEmitterComponent.EmitParticle;
var
   Index: Integer;
   Angle: Single;
   Speed: Single;
   Dir: TVector2;
   Offset: TVector2;
begin
   Index := FindInactiveParticle;
   if Index < 0 then
      Exit;

   with FParticles[Index] do
   begin
      // Position based on emitter shape
      case FEmitterShape of
         esPoint: Offset := Vector2Create(0, 0);
         esCircle:
         begin
            Angle := Random * 2 * Pi;
            Offset := Vector2Create(Cos(Angle) * Random * FEmitterSize.X, Sin(Angle) * Random * FEmitterSize.Y);
         end;
         esRectangle: Offset := Vector2Create((Random - 0.5) * FEmitterSize.X, (Random - 0.5) * FEmitterSize.Y);
         esCone:
         begin
            Angle := FEmitterAngle + (Random - 0.5) * FEmitterSpread;
            Offset := Vector2Create(0, 0);
         end;
      end;

      Position := Offset;

      // Velocity
      if FEmitterShape = esCone then
         Angle := DegToRad(FEmitterAngle + (Random - 0.5) * FEmitterSpread)
      else
         Angle := Random * 2 * Pi;

      Speed := FParticleSpeedMin + Random * (FParticleSpeedMax - FParticleSpeedMin);
      Dir := Vector2Create(Cos(Angle), Sin(Angle));
      Velocity := Vector2Scale(Dir, Speed);

      Acceleration := Vector2Create(0, 0);

      // Life
      Life := 0.0;
      MaxLife := FParticleLifeMin + Random * (FParticleLifeMax - FParticleLifeMin);

      // Size
      Size := FParticleSizeMin + Random * (FParticleSizeMax - FParticleSizeMin);

      // Rotation
      Rotation := Random * 360.0;
      RotationSpeed := (Random - 0.5) * 360.0;

      // Color
      Color := FParticleColorStart;

      Active := True;
   end;
end;

procedure TParticleEmitterComponent.Update(DeltaTime: Double);
var
   i: Integer;
   LifeRatio: Single;
   EmitCount: Integer;
begin
   if not FIsEmitting then
      Exit;

   // Emission
   if FBurst then
   begin
      for i := 0 to FMaxParticles - 1 do
         EmitParticle;
      FIsEmitting := False;
   end
   else
   begin
      FEmissionTimer := FEmissionTimer + DeltaTime;
      EmitCount := Trunc(FEmissionTimer * FEmissionRate);

      if EmitCount > 0 then
      begin
         for i := 1 to EmitCount do
            EmitParticle;
         FEmissionTimer := FEmissionTimer - (EmitCount / FEmissionRate);
      end;
   end;

   // Update particles
   for i := 0 to High(FParticles) do
   begin
      if not FParticles[i].Active then
         Continue;

      with FParticles[i] do
      begin
         // Update life
         Life := Life + DeltaTime;

         if Life >= MaxLife then
         begin
         Active := False;
         Continue;
         end;

         // Update physics
         Velocity := Vector2Add(Velocity, Vector2Scale(FGravity, DeltaTime));
         Velocity := Vector2Add(Velocity, Vector2Scale(Acceleration, DeltaTime));
         Position := Vector2Add(Position, Vector2Scale(Velocity, DeltaTime));

         // Update rotation
         Rotation := Rotation + RotationSpeed * DeltaTime;

         // Update color (lerp from start to end)
         LifeRatio := Life / MaxLife;
         Color := ColorLerp(FParticleColorStart, FParticleColorEnd, LifeRatio);
      end;
   end;
end;

procedure TParticleEmitterComponent.RenderAt(const AWorldPos: TVector2);
var
   I: Integer;
   DrawPos: TVector2;
begin
   for I := 0 to FMaxParticles - 1 do
   begin
      if FParticles[I].Active then
      begin
         DrawPos.X := AWorldPos.X + FParticles[I].Position.X;
         DrawPos.Y := AWorldPos.Y + FParticles[I].Position.Y;
         DrawCircleV(DrawPos, FParticles[I].Size, FParticles[I].Color);
      end;
   end;
end;

procedure TParticleEmitterComponent.Play;
begin
   FIsEmitting := True;
end;

procedure TParticleEmitterComponent.Stop;
begin
   FIsEmitting := False;
   Reset;
end;

procedure TParticleEmitterComponent.Pause;
begin
   FIsEmitting := False;
end;

procedure TParticleEmitterComponent.Reset;
var
   I: Integer;
begin
   for I := 0 to High(FParticles) do
      FParticles[I].Active := False;
   FEmissionTimer := 0.0;
end;

procedure TParticleEmitterComponent.Emit(ACount: Integer);
var
   I: Integer;
begin
   for I := 1 to Min(ACount, FMaxParticles) do
      EmitParticle;
end;

initialization
   ComponentRegistry.Register(TParticleEmitterComponent);

end.
