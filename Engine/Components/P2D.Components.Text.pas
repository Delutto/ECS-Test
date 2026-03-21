unit P2D.Components.Text;

{$mode objfpc}{$H+}

{ ─────────────────────────────────────────────────────────────────────────────
  TTextComponent2D — ECS component for rendering text in world or screen space.

  MOTIVATION
  ──────────
  THUDSystem renders text directly with DrawTextEx inside its Render method,
  hardcoding font, size and positions. There is no way to place a text label
  in the game world (e.g. floating "+100" score popup over a stomped Goomba,
  or a level name banner) without adding ad-hoc draw calls to existing systems.

  This component turns text into a first-class ECS entity. Combine with:
    • TTransformComponent  → world position / screen position
    • TLifetimeComponent2D → auto-despawn (score popups)
    • TTweenComponent2D    → animate Scale or alpha for bounce effects
  ───────────────────────────────────────────────────────────────────────────── }

interface

uses
   SysUtils, raylib,
   P2D.Core.Component, P2D.Core.ComponentRegistry;

type
  TTextAlignment = (taLeft, taCenter, taRight);

  TTextComponent2D = class(TComponent2D)
  public
    Text      : string;
    FontKey   : string;     // ResourceManager key ('' = default raylib font)
    FontSize  : Single;
    Spacing   : Single;     // letter spacing
    Color     : TColor;
    Alignment : TTextAlignment;
    ZOrder    : Integer;
    Shadow    : Boolean;    // draw a 1-px offset shadow for readability
    ShadowColor: TColor;

    constructor Create; override;
  end;

implementation

constructor TTextComponent2D.Create;
begin
  inherited Create;
  
  Text        := '';
  FontKey     := '';
  FontSize    := 16.0;
  Spacing     := 1.0;
  Color       := WHITE;
  Alignment   := taLeft;
  ZOrder      := 50;
  Shadow      := False;
  ShadowColor := ColorCreate(0, 0, 0, 180);
end;

initialization
   ComponentRegistry.Register(TTextComponent2D);

end.
