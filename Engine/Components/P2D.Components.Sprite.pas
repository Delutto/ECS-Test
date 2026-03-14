unit P2D.Components.Sprite;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Component, P2D.Core.Types;

type
   TFlip = (flNone, flHorizontal, flVertical, flBoth);

   TSpriteComponent = class(TComponent2D)
   public
      Texture   : TTexture2D;
      SourceRect: TRectangle;  // raylib TRectangle (sub-region of texture)
      Origin    : TVector2;    // pivot point
      Tint      : TColor;
      Flip      : TFlip;
      ZOrder    : Integer;
      Visible   : Boolean;
    { Quando False, o destrutor NÃO chama UnloadTexture.
      Usar False para texturas compartilhadas (vindas de um atlas/cache gerenciado externamente, como as variáveis globais de Mario.Assets).
      Usar True apenas quando o sprite for o único dono da textura (ex: carregada via LoadFromFile para uso exclusivo). }
      OwnsTexture: Boolean;
      constructor Create; override;
      destructor  Destroy; override;
      procedure LoadFromFile(const APath: string);
      procedure SetSourceFull;
   end;

implementation

constructor TSpriteComponent.Create;
begin
   inherited Create;

   FillChar(Texture, SizeOf(Texture), 0);
   FillChar(SourceRect, SizeOf(SourceRect), 0);
   Origin  := Vector2Create(0, 0);
   Tint    := WHITE;
   Flip    := flNone;
   ZOrder  := 0;
   Visible := True;
   OwnsTexture := False; { Padrão seguro: não libera textura compartilhada }
end;

destructor TSpriteComponent.Destroy;
begin
   if OwnsTexture and (Texture.Id > 0) then
      UnloadTexture(Texture);

   inherited;
end;

procedure TSpriteComponent.LoadFromFile(const APath: string);
begin
   { LoadFromFile cria uma textura exclusiva — este sprite passa a ser dono. }
   if Texture.Id > 0 then
      UnloadTexture(Texture);
   Texture := LoadTexture(PChar(APath));
   OwnsTexture := True;
   SetSourceFull;
end;

procedure TSpriteComponent.SetSourceFull;
begin
   SourceRect.X      := 0;
   SourceRect.Y      := 0;
   SourceRect.Width  := Texture.Width;
   SourceRect.Height := Texture.Height;
end;

end.
