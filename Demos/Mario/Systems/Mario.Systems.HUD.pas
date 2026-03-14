unit Mario.Systems.HUD;

{$mode objfpc}{$H+}

{ ══════════════════════════════════════════════════════════════════════════════
  Mario.Systems.HUD
  ──────────────────────────────────────────────────────────────────────────────
  Renders the score, coins, lives counter and a CRT vignette+scanline overlay.

  Two engine features are demonstrated here:
    1. FONT   — custom pixel font loaded through TResourceManager2D.LoadFont.
                Falls back to raylib's built-in font if the .ttf file is
                absent, so the game is always playable without external assets.
    2. SHADER — a CRT vignette / scanline effect compiled from GLSL source
                strings at runtime via TResourceManager2D.LoadShaderFromMemory.
                No external shader files are required.
  ══════════════════════════════════════════════════════════════════════════════ }

interface

uses
   SysUtils, raylib,
   P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Core.ResourceManager,
   P2D.Components.Tags,
   Mario.Common,
   Mario.Components.Player;

type
   THUDSystem = class(TSystem2D)
   private
      FScreenW            : Integer;
      FScreenH            : Integer;

      { ── Font ── }
      FFont               : TFont;
      FFontSize           : Single;   { draw size (may differ from load size)  }

      { ── CRT shader ── }
      FShader             : TShader;
      FShaderReady        : Boolean;
      FShaderLocScreenSize: Integer;

      FShaderActive       : Boolean;


      { Draws one line of text with the custom font (or default fallback). }
      procedure DrawHUDText(const AText: string; AX, AY: Integer; ASize: Single; AColor: TColor);

      { Returns the pixel width of AText at ASize. }
      function MeasureHUDText(const AText: string; ASize: Single): Single;
   public
      constructor Create(AWorld: TWorldBase; AW, AH: Integer); reintroduce;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
      procedure Shutdown; override;
   end;

implementation

{ ─────────────────────────────────────────────────────────────────────────────
  GLSL fragment shader — CRT vignette + scanline overlay.

  Compiled at runtime from this source string; no .glsl file is needed.
  We pass nil for the vertex shader so raylib uses its own default VS,
  which outputs fragTexCoord (vec2) and fragColor (vec4) to the FS.

  The fragment shader ignores fragColor and computes a screen-space vignette
  using gl_FragCoord and the "screenSize" uniform:
    • vignette : smooth dark border that fades to transparent in the centre.
    • scanlines : very subtle (4%) horizontal banding for a CRT feel.

  The result is a black rectangle drawn over the full screen whose alpha
  encodes the combined effect — transparent in the centre, dark at edges.
  ───────────────────────────────────────────────────────────────────────────── }

{ Construction }
constructor THUDSystem.Create(AWorld: TWorldBase; AW, AH: Integer);
begin
   inherited Create(AWorld);

   Priority    := 200;
   Name        := 'HUDSystem';
   RenderLayer := rlScreen;
   FScreenW    := AW;
   FScreenH    := AH;
   FFontSize   := 16.0;
   FShaderReady := False;
   FShaderLocScreenSize := -1;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  Init — called once after World.Init, with an active OpenGL context.
  This is the correct place to load GPU resources (fonts, shaders).
  ══════════════════════════════════════════════════════════════════════════════ }
procedure THUDSystem.Init;
begin
   inherited;

   RequireComponent(TPlayerComponent);

   { ── 1. Load custom pixel font ──────────────────────────────────────────
   TResourceManager2D.LoadFont returns GetFontDefault() automatically when
   the file is missing, so no special error handling is required here.    }
   FFont := TResourceManager2D.Instance.LoadFont(FONT_HUD, FONT_HUD_SIZE);

   { ── 2. Load CRT shader from external files ────────────────────────────────
   SHADER_VS_CRT is an empty string, so nil is passed to raylib for the
   vertex shader and raylib's own default VS is used.
   SHADER_FS_CRT is the path to  assets/shaders/crt_vignette.fs.
   If the file is absent, LoadShaderFromFile returns Default(TShader),
   IsShaderReady returns False, and the overlay is silently skipped.        }
   FShader := TResourceManager2D.Instance.LoadShaderFromFile(SHADER_KEY_CRT, SHADER_VS_CRT, SHADER_FS_CRT);

   FShaderReady := IsShaderValid(FShader);

   if FShaderReady then
   begin
      { Retrieve the location of the "screenSize" uniform once and cache it. }
      FShaderLocScreenSize := GetShaderLocation(FShader, 'screenSize');
      FShaderActive := True;
      {$IFDEF DEBUG}
      Logger.Info('HUDSystem: CRT shader ready (loc screenSize = ' + IntToStr(FShaderLocScreenSize) + ')');
      {$ENDIF}
   end;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  Update — no per-frame logic needed; everything is rendered in Render.
  ══════════════════════════════════════════════════════════════════════════════ }
procedure THUDSystem.Update(ADelta: Single);
begin
  { intentionally empty }
end;

{ ══════════════════════════════════════════════════════════════════════════════
  Render
  ══════════════════════════════════════════════════════════════════════════════ }
procedure THUDSystem.Render;
var
   E        : TEntity;
   PC       : TPlayerComponent;
   HUD      : string;
   TextW    : Single;
   SizeVec  : array[0..1] of Single;
begin
   { ── Find the player component ── }
   PC := nil;
   for E in GetMatchingEntities do
      if E.Alive then
      begin
         PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
         Break;
      end;
      if not Assigned(PC) then
         Exit;

   { ── Top HUD bar ── }
   DrawRectangle(0, 0, FScreenW, 34, ColorCreate(0, 0, 0, 180));

   { Score }
   HUD := Format('SCORE %07d', [PC.Score]);
   DrawHUDText(HUD, 12, 10, FFontSize, YELLOW);

   { Coins — centred }
   HUD   := Format('x%02d', [PC.Coins]);
   TextW := MeasureHUDText('COINS ' + HUD, FFontSize);
   DrawHUDText('COINS ' + HUD, (FScreenW div 2) - Trunc(TextW * 0.5), 10, FFontSize, WHITE);

   { Lives — right-aligned }
   HUD   := Format('LIVES %d', [PC.Lives]);
   TextW := MeasureHUDText(HUD, FFontSize);
   DrawHUDText(HUD, FScreenW - Trunc(TextW) - 12, 10, FFontSize, WHITE);

   { ── Bottom control hint ── }
   DrawRectangle(0, FScreenH - 20, FScreenW, 20, ColorCreate(0, 0, 0, 140));
   DrawText('Arrows: Move  |  Shift: Run  |  Space: Jump  |  Ctrl: Spin  |  G: Shader On/Off', 8, FScreenH - 15, 10, ColorCreate(200, 200, 200, 180));

   if IsKeyPressed(KEY_G) then
      FShaderActive := not FShaderActive;
   { ── CRT vignette + scanline overlay ──────────────────────────────────
   A full-screen black rectangle is rendered with the shader active. The shader ignores the rectangle colour and computes its own
   per-pixel alpha from gl_FragCoord, producing a vignette that darkens the edges while remaining transparent in the centre. }
   if FShaderReady and (FShaderLocScreenSize >= 0) and(FShaderActive) then
   begin
      SizeVec[0] := FScreenW;
      SizeVec[1] := FScreenH;
      { SHADER_UNIFORM_VEC2 = 1 (raylib constant) }
      SetShaderValue(FShader, FShaderLocScreenSize, @SizeVec[0], 1);

      BeginShaderMode(FShader);
      { Any drawable will trigger the shader; colour is irrelevant because the FS computes its own output using gl_FragCoord + screenSize.    }
      DrawRectangle(0, 0, FScreenW, FScreenH, WHITE);
      EndShaderMode;
   end;

   { ── Game-over overlay (drawn last, on top of the vignette) ── }
   if PC.State = psDead then
   begin
      DrawRectangle(0, 0, FScreenW, FScreenH, ColorCreate(0, 0, 0, 160));

      HUD   := 'GAME OVER';
      TextW := MeasureHUDText(HUD, 32.0);
      DrawHUDText(HUD, (FScreenW div 2) - Trunc(TextW * 0.5), (FScreenH div 2) - 24, 32.0, RED);

      HUD   := 'Press R to restart';
      TextW := MeasureHUDText(HUD, FFontSize);
      DrawHUDText(HUD, (FScreenW div 2) - Trunc(TextW * 0.5), (FScreenH div 2) + 20, FFontSize, WHITE);
   end;
end;

{ Shutdown — release resources acquired in Init.
  Both calls are safe no-ops when the resource was not stored by the manager (e.g., the default font fallback or a failed shader compilation). }
procedure THUDSystem.Shutdown;
begin
   TResourceManager2D.Instance.UnloadFont(FONT_HUD, FONT_HUD_SIZE);
   TResourceManager2D.Instance.UnloadShader(SHADER_KEY_CRT);
   FShaderReady := False;

   inherited;
end;

{ Private helpers }

procedure THUDSystem.DrawHUDText(const AText: string; AX, AY: Integer; ASize: Single; AColor: TColor);
var
   Pos    : TVector2;
   Spacing: Single;
begin
   Pos.X   := AX;
   Pos.Y   := AY;
   Spacing := ASize * 0.05;  { 5% of font size — compact but readable }
   DrawTextEx(FFont, PChar(AText), Pos, ASize, Spacing, AColor);
end;

function THUDSystem.MeasureHUDText(const AText: string; ASize: Single): Single;
var
   Sz     : TVector2;
   Spacing: Single;
begin
   Spacing := ASize * 0.05;
   Sz      := MeasureTextEx(FFont, PChar(AText), ASize, Spacing);
   Result  := Sz.X;
end;

end.
