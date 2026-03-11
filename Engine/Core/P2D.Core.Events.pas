unit P2D.Core.Events;

{$mode objfpc}{$H+}

{ ── Eventos genéricos da engine Pascal2D ────────────────────────────────────
  Este unit define apenas eventos do DOMÍNIO DA ENGINE:
  física, colisão, ciclo de vida de entidades, etc.
  ─────────────────────────────────────────────────────────────────────────── }

interface

uses
   P2D.Core.Event,  { TEvent2D }
   P2D.Core.Types;  { TEntityID, TColliderTag }

type
   { -------------------------------------------------------------------------
    TEntityOverlapEvent — dois colisores se sobrepuseram.

    Publicado por TCollisionSystem sempre que dois colisores de entidades
    diferentes se intersectam. Não carrega lógica de jogo — apenas os fatos
    brutos da colisão: quem colidiu com quem, com quais tags e se são triggers.

    O handler recupera as entidades via World.GetEntity(EntityAID/EntityBID)
    e acessa os componentes necessários para implementar a resposta de jogo.

    Campos:
      EntityAID  — ID da primeira entidade
      EntityBID  — ID da segunda entidade
      TagA/TagB  — tags dos respectivos TColliderComponent
      IsTriggerA — se o colider A é trigger (sem resolução física)
      IsTriggerB — se o colider B é trigger (sem resolução física)
    ------------------------------------------------------------------------- }
   TEntityOverlapEvent = class(TEvent2D)
   public
      EntityAID : TEntityID;
      EntityBID : TEntityID;
      TagA      : TColliderTag;
      TagB      : TColliderTag;
      IsTriggerA: Boolean;
      IsTriggerB: Boolean;

      constructor Create(AEntityAID: TEntityID; AEntityBID: TEntityID; ATagA: TColliderTag; ATagB: TColliderTag; AIsTriggerA: Boolean; AIsTriggerB: Boolean);
   end;

implementation

constructor TEntityOverlapEvent.Create(AEntityAID: TEntityID; AEntityBID: TEntityID; ATagA: TColliderTag; ATagB: TColliderTag; AIsTriggerA: Boolean; AIsTriggerB: Boolean);
begin
   inherited Create;

   EntityAID  := AEntityAID;
   EntityBID  := AEntityBID;
   TagA       := ATagA;
   TagB       := ATagB;
   IsTriggerA := AIsTriggerA;
   IsTriggerB := AIsTriggerB;
end;

end.
