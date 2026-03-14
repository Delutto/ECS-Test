unit Mario.Systems.HUD;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Tags,
   Mario.Components.Player;

type
   THUDSystem = class(TSystem2D)
   private
      FScreenW: Integer;
      FScreenH: Integer;
   public
    { reintroduce: construtor com parâmetros extras (AW, AH).
      Parâmetro AWorld usa TWorldBase — padrão de todos os sistemas. }
      constructor Create(AWorld: TWorldBase; AW, AH: Integer); reintroduce;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

constructor THUDSystem.Create(AWorld: TWorldBase; AW, AH: Integer);
begin
  inherited Create(AWorld);
  Priority := 200;
  Name     := 'HUDSystem';
  RenderLayer := rlScreen;  { HUD sempre em coordenadas de tela }
  FScreenW := AW;
  FScreenH := AH;
end;

procedure THUDSystem.Init;
begin
   inherited;

   RequireComponent(TPlayerComponent);
end;

procedure THUDSystem.Update(ADelta: Single);
begin

end;

procedure THUDSystem.Render;
var
   E  : TEntity;
   PC : TPlayerComponent;
   HUD: string;
begin
   PC := nil;
   for E in GetMatchingEntities do
      if E.Alive then
      begin
         PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
         Break;
      end;

   if not Assigned(PC) then
      Exit;

   // Painel superior
   DrawRectangle(0, 0, FScreenW, 32, ColorCreate(0, 0, 0, 160));

   // Pontuação
   HUD := Format('SCORE  %07d', [PC.Score]);
   DrawText(PChar(HUD), 20, 8, 18, YELLOW);

   // Moedas
   DrawText('COINS', FScreenW div 2 - 100, 8, 18, WHITE);
   HUD := Format('x%02d', [PC.Coins]);
   DrawText(PChar(HUD), FScreenW div 2 - 40, 8, 18, YELLOW);

   // Vidas
   HUD := Format('LIVES  %d', [PC.Lives]);
   DrawText(PChar(HUD), FScreenW - 200, 8, 18, WHITE);

   // Dica de controles
   DrawText('Arrows: Move   Shift: Run   Space: Jump   CTRL: Spin Jump', 10, FScreenH - 22, 12, ColorCreate(220, 220, 220, 200));

   // Game over
   if PC.State = psDead then
   begin
      DrawRectangle(0, 0, FScreenW, FScreenH, ColorCreate(0, 0, 0, 160));
      DrawText('GAME OVER', FScreenW div 2 - 90, FScreenH div 2 - 20, 40, RED);
      DrawText('Press R to restart', FScreenW div 2 - 110, FScreenH div 2 + 30, 22, WHITE);
   end;
end;

end.
