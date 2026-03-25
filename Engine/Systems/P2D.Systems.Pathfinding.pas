unit P2D.Systems.Pathfinding;
{$mode objfpc}{$H+}
interface

uses
   SysUtils, Math,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Entity,
   P2D.Core.System, P2D.Core.World, P2D.Core.Pathfinding,
   P2D.Components.Transform, P2D.Components.RigidBody, P2D.Components.Pathfinder;

type
   TPathfindingSystem2D = class(TSystem2D)
   private
      FTransformID, FRigidBodyID, FPathfinderID: integer;
   public
      constructor Create(AW: TWorldBase); override;
      procedure Init; override;
      procedure Update(DT: single); override;
   end;

implementation

constructor TPathfindingSystem2D.Create(AW: TWorldBase);
begin
   inherited Create(AW);
   Priority := 5;
   Name := 'PathfindingSystem';
end;

procedure TPathfindingSystem2D.Init;
begin
   inherited Init;
   RequireComponent(TPathfinderComponent2D);
   RequireComponent(TTransformComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FPathfinderID := ComponentRegistry.GetComponentID(TPathfinderComponent2D);
end;

procedure TPathfindingSystem2D.Update(DT: single);
var
   E, TC: TEntity;
   PF: TPathfinderComponent2D;
   Tr, TTr: TTransformComponent;
   RB: TRigidBodyComponent;
   GX, GY, SX, SY, Len: single;
   SC, SR, GC, GR: integer;
   Pt: TPathPoint2D;
begin
   for E in GetMatchingEntities do
   begin
      PF := TPathfinderComponent2D(E.GetComponentByID(FPathfinderID));
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));
      if not Assigned(PF) or not Assigned(Tr) or PF.Stopped then
         Continue;
      if not Assigned(PF.GridRef) then
         Continue;
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      GX := PF.TargetX;
      GY := PF.TargetY;
      if PF.TargetID <> 0 then
      begin
         TC := World.GetEntity(PF.TargetID);
         if Assigned(TC) and TC.Alive then
         begin
            TTr := TTransformComponent(TC.GetComponentByID(FTransformID));
            if Assigned(TTr) then
            begin
               GX := TTr.Position.X;
               GY := TTr.Position.Y;
            end;
         end;
      end;
      if PF.FollowMode = pfmChase then
      begin
         PF.RepathTimer := PF.RepathTimer + DT;
         if PF.RepathTimer >= PF.RepathInterval then
         begin
            PF.RepathTimer := 0;
            PF.PathDirty := True;
         end;
      end;
      if PF.PathDirty then
      begin
         PF.WorldToGrid(Tr.Position.X, Tr.Position.Y, SC, SR);
         PF.WorldToGrid(GX, GY, GC, GR);
         PF.PathDirty := False;
         PF.PathIndex := 0;
         if not PF.GridRef.FindPath(SC, SR, GC, GR, PF.Path) then
         begin
            PF.PathLength := 0;
            PF.Stopped := True;
            Continue;
         end;
         PF.PathLength := Length(PF.Path);
      end;
      if PF.PathIndex >= PF.PathLength then
      begin
         PF.Arrived := True;
         if PF.FollowMode <> pfmChase then
            PF.Stopped := True;
         if Assigned(RB) then
         begin
            RB.Velocity.X := 0;
            RB.Velocity.Y := 0;
         end;
         Continue;
      end;
      Pt := PF.Path[PF.PathIndex];
      PF.GridToWorld(Pt.Col, Pt.Row, SX, SY);
      SX := SX - Tr.Position.X;
      SY := SY - Tr.Position.Y;
      Len := Sqrt(SX * SX + SY * SY);
      if Len < 4 then
      begin
         Inc(PF.PathIndex);
         Continue;
      end;
      if Assigned(RB) then
      begin
         RB.Velocity.X := (SX / Len) * PF.MoveSpeed;
         RB.Velocity.Y := (SY / Len) * PF.MoveSpeed;
      end
      else
      begin
         Tr.Position.X := Tr.Position.X + (SX / Len) * PF.MoveSpeed * DT;
         Tr.Position.Y := Tr.Position.Y + (SY / Len) * PF.MoveSpeed * DT;
      end;
   end;
end;

end.
