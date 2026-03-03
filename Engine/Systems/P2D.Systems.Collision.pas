unit P2D.Systems.Collision;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Collider, P2D.Components.TileMap,
   P2D.Components.Tags;

type
   { TCollisionSystem }

   TCollisionSystem = class(TSystem2D)
   private
      procedure SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
      procedure SolveEntityCollisions;
   public
      constructor Create(AWorld: TWorldBase); override;
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

procedure TCollisionSystem.SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
var
   R    : TRectF;
   ColL, ColR, RowT, RowB: Integer;
   C, Row: Integer;
   Tile : TTileData;
   TileR: TRectF;
   OverX, OverY: Single;
begin
   R := ACol.GetWorldRect(ATr.Position);

   ColL := Trunc((R.X - AMapTr.Position.X) / AMap.TileWidth);
   ColR := Trunc((R.Right - AMapTr.Position.X - 1) / AMap.TileWidth);
   RowT := Trunc((R.Y - AMapTr.Position.Y) / AMap.TileHeight);
   RowB := Trunc((R.Bottom - AMapTr.Position.Y - 1) / AMap.TileHeight);

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

         if OverX < OverY then
         begin
            // Horizontal resolve
            if ATr.Position.X < TileR.X then
               ATr.Position.X := ATr.Position.X - OverX
            else
               ATr.Position.X := ATr.Position.X + OverX;
            ARB.Velocity.X := 0;
         end
         else
         begin
            // Vertical resolve
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

         // Update R after resolve
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
   EntList       : array of TEntity;
   I, J, Count   : Integer;
begin
   // Coleta entidades elegíveis para colisão
   Count := 0;
   SetLength(EntList, World.Entities.GetAll.Count);

   for EA in World.Entities.GetAll do
      if EA.Alive and EA.HasComponent(TColliderComponent) and EA.HasComponent(TTransformComponent) then
      begin
         EntList[Count] := EA;
         Inc(Count);
      end;

   { ── Testa todos os pares (I, J) ─────────────────────────────────────── }
   for I := 0 to Count - 2 do
   begin
      EA := EntList[I];

      for J := I + 1 to Count - 1 do
      begin
         EB := EntList[J];

         { CORREÇÃO 4: Ignora pares onde alguma entidade já foi destruída
         durante esta mesma iteração (ex: moeda coletada em par anterior). }
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

         { ── Coleta de moeda ────────────────────────────────────────────── }
         { Verifica os dois sentidos do par para garantir independência de ordem. }

         if (CA.Tag = ctPlayer) and (CB.Tag = ctCoin) then
         begin
            PlayerComp := TPlayerComponent(EA.GetComponent(TPlayerComponent));
            if Assigned(PlayerComp) then
            begin
               Inc(PlayerComp.Coins);
               PlayerComp.Score := PlayerComp.Score + 200;
            end;
            World.DestroyEntity(EB.ID);
            Continue; { par processado — avança para o próximo J }
         end;

         if (CA.Tag = ctCoin) and (CB.Tag = ctPlayer) then
         begin
            PlayerComp := TPlayerComponent(EB.GetComponent(TPlayerComponent));
            if Assigned(PlayerComp) then
            begin
               Inc(PlayerComp.Coins);
               PlayerComp.Score := PlayerComp.Score + 200;
            end;
            World.DestroyEntity(EA.ID);
            Continue;
         end;

         { ── Colisão Jogador × Inimigo ─────────────────────────────────────
           Identifica quem é o jogador e quem é o inimigo, independente da ordem do par (EA/EB). Corrige PROBLEMA 1 e PROBLEMA 3. }

         PlayerEntity := nil;
         EnemyEntity  := nil;

         if (CA.Tag = ctPlayer) and (CB.Tag = ctEnemy) then
         begin
            PlayerEntity := EA; { CORREÇÃO 1: EA é o jogador, não EB }
            EnemyEntity  := EB;
         end
         else
            if (CA.Tag = ctEnemy) and (CB.Tag = ctPlayer) then
            begin
               PlayerEntity := EB; { CORREÇÃO 3: caso simétrico — EB é o jogador }
               EnemyEntity  := EA;
            end;

         if Assigned(PlayerEntity) and Assigned(EnemyEntity) then
         begin
            PlayerComp := TPlayerComponent(PlayerEntity.GetComponent(TPlayerComponent));

            if not Assigned(PlayerComp) then
               Continue;

            { Jogador invulnerável — ignora colisão. }
            if PlayerComp.InvFrames > 0 then
               Continue;

            { Verifica se o jogador está caindo e pisando em cima do inimigo.
            Condição: jogador desce (Velocity.Y > 0) e a borda inferior do
            jogador está dentro da metade superior do sprite do inimigo. }
            RBA := TRigidBodyComponent(PlayerEntity.GetComponent(TRigidBodyComponent));

            if Assigned(RBA) and (RBA.Velocity.Y > 0) and (RA.Bottom <= RB_.Y + RB_.H * 0.5) then
            begin
               { ── Jogador pisou no inimigo: inimigo morre, jogador quica ── }
               PlayerComp.Score := PlayerComp.Score + 100;
               RBA.Velocity.Y   := -350.0; { quique de ricochete }
               World.DestroyEntity(EnemyEntity.ID);
            end
            else
            begin
               { ── Inimigo atinge o jogador lateralmente / por baixo ──────── }
               { CORREÇÃO 2: decrementa Lives em vez de subtrair Score. }
               Dec(PlayerComp.Lives);
               PlayerComp.InvFrames := 2.0; { 2 s de invulnerabilidade }

               if PlayerComp.Lives <= 0 then
                  PlayerComp.State := psDead;
            end;
         end;
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
      for E in World.Entities.GetAll do
      begin
         if not E.Alive then
            Continue;
         if not E.HasComponent(TTransformComponent) then
            Continue;
         if not E.HasComponent(TRigidBodyComponent) then
            Continue;
         if not E.HasComponent(TColliderComponent) then
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
