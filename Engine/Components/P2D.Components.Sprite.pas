unit P2D.Components.Sprite;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   raylib,
   P2D.Core.Component,
   P2D.Core.Types;

type
   TFlip = (flNone, flHorizontal, flVertical, flBoth);

   TSpriteComponent = class(TComponent2D)
   public
      Texture: TTexture2D;
      SourceRect: TRectangle;  // raylib TRectangle (sub-region of texture)
      Origin: TVector2;    // pivot point
      Tint: TColor;
      Flip: TFlip;
      ZOrder: Integer;
      Visible: Boolean;
    { Quando False, o destrutor NÃO chama UnloadTexture.
      Usar False para texturas compartilhadas (vindas de um atlas/cache gerenciado externamente, como as variáveis globais de Mario.Assets).
      Usar True apenas quando o sprite for o único dono da textura (ex: carregada via LoadFromFile para uso exclusivo). }
      OwnsTexture: Boolean;
      constructor Create; override;
      destructor Destroy; override;
      procedure LoadFromFile(const APath: String);
      procedure SetSourceFull;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TSpriteComponent.Create;
begin
   inherited Create;

   FillChar(Texture, SizeOf(Texture), 0);
   FillChar(SourceRect, SizeOf(SourceRect), 0);
   Origin := Vector2Create(0, 0);
   Tint := WHITE;
   Flip := flNone;
   ZOrder := 0;
   Visible := True;
   OwnsTexture := False; { Padrão seguro: não libera textura compartilhada }
end;

destructor TSpriteComponent.Destroy;
begin
   if OwnsTexture And (Texture.Id > 0) then
   begin
      UnloadTexture(Texture)
   end;

   inherited;
end;

procedure TSpriteComponent.LoadFromFile(const APath: String);
begin
   { LoadFromFile cria uma textura exclusiva — este sprite passa a ser dono. }
   if Texture.Id > 0 then
   begin
      UnloadTexture(Texture)
   end;
   Texture := LoadTexture(Pchar(APath));
   OwnsTexture := True;
   SetSourceFull;
end;

procedure TSpriteComponent.SetSourceFull;
begin
   SourceRect.X := 0;
   SourceRect.Y := 0;
   SourceRect.Width := Texture.Width;
   SourceRect.Height := Texture.Height;
end;

initialization
   ComponentRegistry.Register(TSpriteComponent);

end.
