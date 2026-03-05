unit P2D.Systems.Collision;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Collider, P2D.Components.TileMap,
   P2D.Core.Events, P2D.Components.Tags;

type
   { TCollisionSystem }
   TCollisionSystem = class(TSystem2D)
   private
      FEntList: array of TEntity;
      procedure SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
      procedure SolveEntityCollisions;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

implementation

constructor TCollisionSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 20;
   Name     := 'CollisionSystem';
end;

procedure TCollisionSystem.Init;
begin
   inherited;

 { Cache cobre todas as entidades colidíveis (player, inimigos, moedas).
   O loop de tile collision filtra adicionalmente por TRigidBodyComponent. }
   RequireComponent(TColliderComponent);
   RequireComponent(TTransformComponent);
end;

procedure TCollisionSystem.SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
var
   R    : TRectF;
   ColL, ColR, RowT, RowB: Integer;
   C, Row: Integer;
   Tile : TTileData;
   TileR: TRectF;
   OverX, OverY: Single;
   IsInternalEdgeX: Boolean; // Flag para ignorar quinas internas
begin
   R := ACol.GetWorldRect(ATr.Position);

   ColL := Trunc((R.X - AMapTr.Position.X) / AMap.TileWidth);
   ColR := Trunc((R.Right - AMapTr.Position.X) / AMap.TileWidth); // Removido o - 1
   RowT := Trunc((R.Y - AMapTr.Position.Y) / AMap.TileHeight);
   RowB := Trunc((R.Bottom - AMapTr.Position.Y) / AMap.TileHeight); // Removido o - 1

   for Row := RowT to RowB do
   begin
      for C := ColL to ColR do
      begin
         Tile := AMap.GetTile(C, Row);
         if not Tile.Solid then
            Continue;

         TileR := AMap.GetTileWorldRect(C, Row);
         TileR.X := TileR.X + AMapTr.Position.X;
         TileR.Y := TileR.Y + AMapTr.Position.Y;

         if not R.Overlaps(TileR) then
            Continue;

         OverX := Min(R.Right, TileR.Right) - Max(R.X, TileR.X);
         OverY := Min(R.Bottom, TileR.Bottom) - Max(R.Y, TileR.Y);

         { Verifica se é uma colisão horizontal fantasma (borda interna) }
         IsInternalEdgeX := False;
         if OverX < OverY then
         begin
            if ATr.Position.X < TileR.X then
               IsInternalEdgeX := AMap.GetTile(C - 1, Row).Solid // Verifica tile da esquerda
            else
               IsInternalEdgeX := AMap.GetTile(C + 1, Row).Solid; // Verifica tile da direita
         end;

         { Só resolve no eixo X se NÃO for uma borda interna }
         if (OverX < OverY) and not IsInternalEdgeX then
         begin
            // Horizontal resolve
            if ATr.Position.X < TileR.X then
               ATr.Position.X := ATr.Position.X - OverX
            else
               ATr.Position.X := ATr.Position.X + OverX;

            ARB.Velocity.X := 0;
            ARB.OnWall     := True;
         end
         else
         begin
            // Vertical resolve (usado inclusive como fallback se for borda interna no X)
            if ATr.Position.Y < TileR.Y then
            begin
               ATr.Position.Y := ATr.Position.Y - OverY;
               ARB.Grounded   := True;
               if ARB.Velocity.Y > 0 then
                  ARB.Velocity.Y := 0;
            end
            else
            begin
               ATr.Position.Y := ATr.Position.Y + OverY;
               if ARB.Velocity.Y < 0 then
                  ARB.Velocity.Y := 0;
            end;
         end;

         // Update R after resolve (Atualiza a caixa de colisão para o próximo tile do loop)
         R := ACol.GetWorldRect(ATr.Position);
      end;
   end;
end;

procedure TCollisionSystem.SolveEntityCollisions;
var
   EA, EB        : TEntity;
   TA, TB        : TTransformComponent;
   CA, CB        : TColliderComponent;
   RA, RB_       : TRectF;
   RBA           : TRigidBodyComponent;
   PlayerComp    : TPlayerComponent;
   PlayerEntity  : TEntity;
   EnemyEntity   : TEntity;
   CoinEntity    : TEntity;
   I, J, Count   : Integer;
begin
   { Coleta entidades elegíveis para colisão }
   Count := 0;
   if Length(FEntList) < GetMatchingEntities.Count then
      SetLength(FEntList, GetMatchingEntities.Count);

   for EA in GetMatchingEntities do
      if EA.Alive then
      begin
         FEntList[Count] := EA;
         Inc(Count);
      end;

   { Testa todos os pares (I, J) }
   for I := 0 to Count - 2 do
   begin
      EA := FEntList[I];
      for J := I + 1 to Count - 1 do
      begin
         EB := FEntList[J];

         { Ignora pares onde alguma entidade já foi destruída durante esta mesma iteração (ex: moeda coletada em par anterior). }
         if not EA.Alive or not EB.Alive then
            Continue;

         TA := TTransformComponent(EA.GetComponent(TTransformComponent));
         TB := TTransformComponent(EB.GetComponent(TTransformComponent));
         CA := TColliderComponent(EA.GetComponent(TColliderComponent));
         CB := TColliderComponent(EB.GetComponent(TColliderComponent));

         RA  := CA.GetWorldRect(TA.Position);
         RB_ := CB.GetWorldRect(TB.Position);

         if not RA.Overlaps(RB_) then
            Continue;
         { ── Sobreposição detectada ───────────────────────────────────────────
           A engine publica o evento genérico e encerra sua responsabilidade.
           O jogo decide o que fazer: coletar moeda, aplicar dano, etc. }
         World.EventBus.Publish(TEntityOverlapEvent.Create(EA.ID, EB.ID, CA.Tag, CB.Tag, CA.IsTrigger, CB.IsTrigger));
      end;
   end;
end;

procedure TCollisionSystem.Update(ADelta: Single);
begin
   { Update é vazio: a detecção e resposta de colisão acontecem em FixedUpdate, no mesmo passo fixo que a física — garantindo consistência. }
end;

{ FixedUpdate: roda no mesmo passo fixo que TPhysicsSystem (prioridade 20 > 10). A ordem garante: Física integra posição → Colisão corrige posição. }
procedure TCollisionSystem.FixedUpdate(AFixedDelta: Single);
var
   E    : TEntity;
   Tr   : TTransformComponent;
   RB   : TRigidBodyComponent;
   Col  : TColliderComponent;
   MapE : TEntity;
   TileM: TTileMapComponent;
   MapTr: TTransformComponent;
begin
   // Find the tilemap entity
   TileM := nil;
   MapTr := nil;
   for MapE in World.Entities.GetAll do
      if MapE.Alive and MapE.HasComponent(TTileMapComponent) then
      begin
         TileM := TTileMapComponent(MapE.GetComponent(TTileMapComponent));
         MapTr := TTransformComponent(MapE.GetComponent(TTransformComponent));
         Break;
      end;

   // Solve tile collisions for all rigid bodies
   if Assigned(TileM) then
      for E in GetMatchingEntities do
      begin
         if not E.Alive then
            Continue;
         if not E.HasComponent(TRigidBodyComponent) then
            Continue;

         Tr  := TTransformComponent(E.GetComponent(TTransformComponent));
         RB  := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
         Col := TColliderComponent(E.GetComponent(TColliderComponent));

         if Tr.Enabled and RB.Enabled and Col.Enabled then
            SolveTileCollision(Tr, RB, Col, TileM, MapTr);
      end;

   // Resolves collisions between entities (triggers, pickups, damage)
   SolveEntityCollisions;
end;

end.
