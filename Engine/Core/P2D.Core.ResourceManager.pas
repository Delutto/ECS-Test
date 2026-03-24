unit P2D.Core.ResourceManager;

{$mode ObjFPC}
{$H+}

interface

uses
   Classes,
   SysUtils,
   fgl,
   raylib;

type
   { TResourceType2D }
   TResourceType2D = (rtTexture, rtSound, rtMusic, rtFont, rtShader);

   { TResource2D — reference-counted base wrapper for any engine resource }
   TResource2D = class
   private
      FName: String;
      FRefCount: Integer;
      FResourceType: TResourceType2D;
   public
      constructor Create(const AName: String; AType: TResourceType2D);
      procedure AddRef;
      function Release: Integer;
      property Name: String read FName;
      property RefCount: Integer read FRefCount;
      property ResourceType: TResourceType2D read FResourceType;
   end;

   { TTextureResource2D }
   TTextureResource2D = class(TResource2D)
   private
      FTexture: TTexture2D;
   public
      constructor Create(const AName: String; const ATexture: TTexture2D);
      destructor Destroy; override;
      property Texture: TTexture2D read FTexture;
   end;

   { TSoundResource2D }
   TSoundResource2D = class(TResource2D)
   private
      FSound: TSound;
   public
      constructor Create(const AName: String; const ASound: TSound);
      destructor Destroy; override;
      property Sound: TSound read FSound;
   end;

   { TMusicResource2D }
   TMusicResource2D = class(TResource2D)
   private
      FMusic: TMusic;
   public
      constructor Create(const AName: String; const AMusic: TMusic);
      destructor Destroy; override;
      property Music: TMusic read FMusic;
   end;

   { TFontResource2D
   Wraps a raylib TFont loaded either from a file or via LoadFontFromMemory.
   The map key is  <filename>#<size>  (e.g. "assets/fonts/pixel.ttf#16"). }
   TFontResource2D = class(TResource2D)
   private
      FFont: TFont;
   public
      constructor Create(const AName: String; const AFont: TFont);
      destructor Destroy; override;
      property Font: TFont read FFont;
   end;

   { TShaderResource2D
   Wraps a raylib TShader loaded either from files or from GLSL source strings.
   The map key is a caller-defined identifier (e.g. 'crt_overlay'). }
   TShaderResource2D = class(TResource2D)
   private
      FShader: TShader;
   public
      constructor Create(const AName: String; const AShader: TShader);
      destructor Destroy; override;
      property Shader: TShader read FShader;
   end;

   { TResourceMap2D }
   TResourceMap2D = specialize TFPGMap<String, TResource2D>;

   { TResourceManager2D — singleton resource cache with reference counting }
   TResourceManager2D = class
   private
      FResources: TResourceMap2D;
      class var FInstance: TResourceManager2D;
      constructor Create;
   public
      destructor Destroy; override;

      class function Instance: TResourceManager2D;
      class procedure FreeInstance;

      { ── Texture ─────────────────────────────────────────────────────────── }
      function LoadTexture(const AFileName: String): TTexture2D;
      procedure UnloadTexture(const AFileName: String);

      { ── Sound ───────────────────────────────────────────────────────────── }
      function LoadSound(const AFileName: String): TSound;
      procedure UnloadSound(const AFileName: String);

      { ── Music ───────────────────────────────────────────────────────────── }
      function LoadMusic(const AFileName: String): TMusic;
      procedure UnloadMusic(const AFileName: String);

      { ── Font ─────────────────────────────────────────────────────────────
      Key format: <AFileName>#<AFontSize>

      If AFileName is empty, or the file does not exist, or raylib fails to
      load it, GetFontDefault() is returned WITHOUT being stored in the cache
      (the engine does not own the default font and must not unload it).

      Calling UnloadFont for a font that was not stored (e.g. the fallback)
      is a safe no-op.

      AFontSize controls the rasterisation resolution; the same file at
      different sizes produces distinct cached resources.               }
      function LoadFont(const AFileName: String; AFontSize: Integer = 32): TFont;
      procedure UnloadFont(const AFileName: String; AFontSize: Integer = 32);

      { ── Shader (from files) ──────────────────────────────────────────────
      AKey     : caller-defined cache identifier.
      AVsFile  : path to the vertex shader  (empty = use raylib default VS).
      AFsFile  : path to the fragment shader (empty = use raylib default FS).
      If both paths are empty the result is raylib's default pass-through
      shader.  A failed load returns Default(TShader) (id = 0).          }
      function LoadShaderFromFile(const AKey, AVsFile, AFsFile: String): TShader;

      { ── Shader (from GLSL source strings) ───────────────────────────────
      AKey    : caller-defined cache identifier.
      AVsCode : GLSL vertex shader source   (empty = use raylib default VS).
      AFsCode : GLSL fragment shader source (empty = use raylib default FS).
      Returns Default(TShader) if compilation fails.                       }
      function LoadShaderFromMemory(const AKey, AVsCode, AFsCode: String): TShader;

      { Decrement the reference count for a shader identified by AKey.
      The shader is unloaded from GPU when the count reaches zero.         }
      procedure UnloadShader(const AKey: String);

      { ── Generic helpers ─────────────────────────────────────────────────── }
      procedure AddResource(AResource: TResource2D);
      function GetResource(const AName: String): TResource2D;
      procedure Clear;

      { ── Debug & stats ───────────────────────────────────────────────────── }
      function GetResourceCount: Integer;
      function GetMemoryUsage: Int64;
      procedure PrintResourceStats;
   end;

implementation

uses
   P2D.Utils.Logger;

{ ══════════════════════════════════════════════════════════════════════════════
  Internal helper: human-readable name for each resource type.
  ══════════════════════════════════════════════════════════════════════════════ }
function ResourceTypeName(AType: TResourceType2D): String;
begin
   case AType of
      rtTexture:
      begin
         Result := 'Texture'
      end;
      rtSound:
      begin
         Result := 'Sound'
      end;
      rtMusic:
      begin
         Result := 'Music'
      end;
      rtFont:
      begin
         Result := 'Font'
      end;
      rtShader:
      begin
         Result := 'Shader'
      end;
      else
      begin
         Result := 'Unknown'
      end;
   end;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  TResource2D
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TResource2D.Create(const AName: String; AType: TResourceType2D);
begin
   inherited Create;

   FName := AName;
   FResourceType := AType;
   FRefCount := 1;
end;

procedure TResource2D.AddRef;
begin
   Inc(FRefCount);
end;

function TResource2D.Release: Integer;
begin
   Dec(FRefCount);
   Result := FRefCount;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  TTextureResource2D
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TTextureResource2D.Create(const AName: String; const ATexture: TTexture2D);
begin
   inherited Create(AName, rtTexture);

   FTexture := ATexture;
end;

destructor TTextureResource2D.Destroy;
begin
   raylib.UnloadTexture(FTexture);
   {$IFDEF DEBUG}
   Logger.Info('Texture unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  TSoundResource2D
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TSoundResource2D.Create(const AName: String; const ASound: TSound);
begin
   inherited Create(AName, rtSound);

   FSound := ASound;
end;

destructor TSoundResource2D.Destroy;
begin
   raylib.UnloadSound(FSound);
   {$IFDEF DEBUG}
   Logger.Info('Sound unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  TMusicResource2D
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TMusicResource2D.Create(const AName: String; const AMusic: TMusic);
begin
   inherited Create(AName, rtMusic);

   FMusic := AMusic;
end;

destructor TMusicResource2D.Destroy;
begin
   raylib.UnloadMusicStream(FMusic);
   {$IFDEF DEBUG}
   Logger.Info('Music unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  TFontResource2D
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TFontResource2D.Create(const AName: String; const AFont: TFont);
begin
   inherited Create(AName, rtFont);

   FFont := AFont;
end;

destructor TFontResource2D.Destroy;
begin
   raylib.UnloadFont(FFont);
   {$IFDEF DEBUG}
   Logger.Info('Font unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  TShaderResource2D
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TShaderResource2D.Create(const AName: String; const AShader: TShader);
begin
   inherited Create(AName, rtShader);

   FShader := AShader;
end;

destructor TShaderResource2D.Destroy;
begin
   raylib.UnloadShader(FShader);
   {$IFDEF DEBUG}
   Logger.Info('Shader unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ TResourceManager2D }
constructor TResourceManager2D.Create;
begin
   inherited Create;

   FResources := TResourceMap2D.Create;
   FResources.Sorted := True;
   {$IFDEF DEBUG}
   Logger.Info('ResourceManager initialized');
   {$ENDIF}
end;

destructor TResourceManager2D.Destroy;
begin
   Clear;
   FResources.Free;
   {$IFDEF DEBUG}
   Logger.Info('ResourceManager destroyed');
   {$ENDIF}

   inherited;
end;

class function TResourceManager2D.Instance: TResourceManager2D;
begin
   if FInstance = nil then
   begin
      FInstance := TResourceManager2D.Create
   end;
   Result := FInstance;
end;

class procedure TResourceManager2D.FreeInstance;
begin
   FreeAndNil(FInstance);
end;

{ ── Internal ref-count helpers ─────────────────────────────────────────────── }

{ Tries to find AKey in the map.
  If found: increments RefCount and returns True (ARes is set).
  If not found: returns False (ARes = nil).                        }
function TResourceManager2D.GetResource(const AName: String): TResource2D;
var
   Idx: Integer;
begin
   Idx := FResources.IndexOf(AName);
   if Idx >= 0 then
   begin
      Result := FResources.Data[Idx]
   end
   else
   begin
      Result := nil
   end;
end;

procedure TResourceManager2D.AddResource(AResource: TResource2D);
begin
   FResources.Add(AResource.Name, AResource);
end;

{ Shared unload logic: decrement refcount; free + remove when it hits zero. }
procedure UnloadByKey(FResources: TResourceMap2D; const AKey: String);
var
   Idx: Integer;
   Res: TResource2D;
begin
   Idx := FResources.IndexOf(AKey);
   if Idx < 0 then
   begin
      Exit
   end;
   Res := FResources.Data[Idx];
   if Res.Release <= 0 then
   begin
      FResources.Delete(Idx);
      Res.Free;
   end;
end;

{ ── Texture ─────────────────────────────────────────────────────────────── }

function TResourceManager2D.LoadTexture(const AFileName: String): TTexture2D;
var
   Idx: Integer;
   Res: TResource2D;
begin
   Idx := FResources.IndexOf(AFileName);
   if Idx >= 0 then
   begin
      Res := FResources.Data[Idx];
      Res.AddRef;
      Result := TTextureResource2D(Res).Texture;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Texture reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
      {$ENDIF}
      Exit;
   end;

   if FileExists(Pchar(AFileName)) then
   begin
      Result := raylib.LoadTexture(Pchar(AFileName));
      AddResource(TTextureResource2D.Create(AFileName, Result));
      {$IFDEF DEBUG}
      Logger.Info('Texture loaded: ' + AFileName);
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Error('Texture file not found: ' + AFileName);
      {$ENDIF}
      Result := Default(TTexture2D);
   end;
end;

procedure TResourceManager2D.UnloadTexture(const AFileName: String);
begin
   UnloadByKey(FResources, AFileName);
   {$IFDEF DEBUG}
   Logger.Debug('Texture unref: ' + AFileName);
   {$ENDIF}
end;

{ ── Sound ───────────────────────────────────────────────────────────────── }

function TResourceManager2D.LoadSound(const AFileName: String): TSound;
var
   Idx: Integer;
   Res: TResource2D;
begin
   Idx := FResources.IndexOf(AFileName);
   if Idx >= 0 then
   begin
      Res := FResources.Data[Idx];
      Res.AddRef;
      Result := TSoundResource2D(Res).Sound;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Sound reused: %s (RefCount: %d)',
         [AFileName, Res.RefCount]));
      {$ENDIF}
      Exit;
   end;

   if FileExists(Pchar(AFileName)) then
   begin
      Result := raylib.LoadSound(Pchar(AFileName));
      AddResource(TSoundResource2D.Create(AFileName, Result));
      {$IFDEF DEBUG}
      Logger.Info('Sound loaded: ' + AFileName);
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Error('Sound file not found: ' + AFileName);
      {$ENDIF}
      Result := Default(TSound);
   end;
end;

procedure TResourceManager2D.UnloadSound(const AFileName: String);
begin
   UnloadByKey(FResources, AFileName);
end;

{ ── Music ───────────────────────────────────────────────────────────────── }

function TResourceManager2D.LoadMusic(const AFileName: String): TMusic;
var
   Idx: Integer;
   Res: TResource2D;
begin
   Idx := FResources.IndexOf(AFileName);
   if Idx >= 0 then
   begin
      Res := FResources.Data[Idx];
      Res.AddRef;
      Result := TMusicResource2D(Res).Music;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Music reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
      {$ENDIF}
      Exit;
   end;

   if FileExists(Pchar(AFileName)) then
   begin
      Result := raylib.LoadMusicStream(Pchar(AFileName));
      AddResource(TMusicResource2D.Create(AFileName, Result));
      {$IFDEF DEBUG}
      Logger.Info('Music loaded: ' + AFileName);
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Error('Music file not found: ' + AFileName);
      {$ENDIF}
      Result := Default(TMusic);
   end;
end;

procedure TResourceManager2D.UnloadMusic(const AFileName: String);
begin
   UnloadByKey(FResources, AFileName);
end;

{ ── Font ─────────────────────────────────────────────────────────────────── }

function TResourceManager2D.LoadFont(const AFileName: String; AFontSize: Integer): TFont;
var
   Key: String;
   Idx: Integer;
   Res: TResource2D;
   Fnt: TFont;
begin
   { Build unique cache key: path + rasterisation size }
   Key := AFileName + '#' + IntToStr(AFontSize);

   { ── Cache hit ── }
   Idx := FResources.IndexOf(Key);
   if Idx >= 0 then
   begin
      Res := FResources.Data[Idx];
      Res.AddRef;
      Result := TFontResource2D(Res).Font;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Font reused: %s (RefCount: %d)', [Key, Res.RefCount]));
      {$ENDIF}
      Exit;
   end;

   { ── Cache miss: attempt to load from file ── }
   if (AFileName <> '') And FileExists(Pchar(AFileName)) then
   begin
      { LoadFontEx: nil codepoints = load the full default charset }
      Fnt := raylib.LoadFontEx(Pchar(AFileName), AFontSize, nil, 0);
      if IsFontValid(Fnt) then
      begin
         AddResource(TFontResource2D.Create(Key, Fnt));
         Result := Fnt;
         {$IFDEF DEBUG}
         Logger.Info(Format('Font loaded: %s at %dpx', [AFileName, AFontSize]));
         {$ENDIF}
         Exit;
      end;
   end;

   { ── Graceful fallback: return raylib built-in font.
   We do NOT store it — the engine does not own it. ── }
   {$IFDEF DEBUG}
   if AFileName = '' then
   begin
      Logger.Warn('LoadFont: empty filename, using raylib default font')
   end
   else
   begin
      Logger.Warn('Font file not found or failed to load: ' + AFileName + ' — using raylib default font')
   end;
   {$ENDIF}
   Result := GetFontDefault;
end;

procedure TResourceManager2D.UnloadFont(const AFileName: String; AFontSize: Integer);
var
   Key: String;
begin
   Key := AFileName + '#' + IntToStr(AFontSize);
   UnloadByKey(FResources, Key);
end;

{ ── Shader (from files) ──────────────────────────────────────────────────── }

function TResourceManager2D.LoadShaderFromFile(const AKey, AVsFile, AFsFile: String): TShader;
var
   Idx: Integer;
   Res: TResource2D;
   Shader: TShader;
   VsPtr: Pchar;
   FsPtr: Pchar;
begin
   { ── Cache hit ── }
   Idx := FResources.IndexOf(AKey);
   if Idx >= 0 then
   begin
      Res := FResources.Data[Idx];
      Res.AddRef;
      Result := TShaderResource2D(Res).Shader;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Shader reused: %s (RefCount: %d)',
         [AKey, Res.RefCount]));
      {$ENDIF}
      Exit;
   end;

   { ── Cache miss: build PChar pointers (nil = use raylib default) ── }
   if AVsFile <> '' then
   begin
      VsPtr := Pchar(AVsFile)
   end
   else
   begin
      VsPtr := nil
   end;
   if AFsFile <> '' then
   begin
      FsPtr := Pchar(AFsFile)
   end
   else
   begin
      FsPtr := nil
   end;

   Shader := raylib.LoadShader(VsPtr, FsPtr);

   if IsShaderValid(Shader) then
   begin
      AddResource(TShaderResource2D.Create(AKey, Shader));
      Result := Shader;
      {$IFDEF DEBUG}
      Logger.Info('Shader loaded from file: ' + AKey);
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Error('Shader compilation failed: ' + AKey);
      {$ENDIF}
      Result := Default(TShader);
   end;
end;

{ ── Shader (from GLSL source strings) ───────────────────────────────────── }

function TResourceManager2D.LoadShaderFromMemory(const AKey, AVsCode, AFsCode: String): TShader;
var
   Idx: Integer;
   Res: TResource2D;
   Shader: TShader;
   VsPtr: Pchar;
   FsPtr: Pchar;
begin
   { ── Cache hit ── }
   Idx := FResources.IndexOf(AKey);
   if Idx >= 0 then
   begin
      Res := FResources.Data[Idx];
      Res.AddRef;
      Result := TShaderResource2D(Res).Shader;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Shader reused: %s (RefCount: %d)', [AKey, Res.RefCount]));
      {$ENDIF}
      Exit;
   end;

   { ── Cache miss: compile from source strings ── }
   if AVsCode <> '' then
   begin
      VsPtr := Pchar(AVsCode)
   end
   else
   begin
      VsPtr := nil
   end;
   if AFsCode <> '' then
   begin
      FsPtr := Pchar(AFsCode)
   end
   else
   begin
      FsPtr := nil
   end;

   Shader := raylib.LoadShaderFromMemory(VsPtr, FsPtr);

   if IsShaderValid(Shader) then
   begin
      AddResource(TShaderResource2D.Create(AKey, Shader));
      Result := Shader;
      {$IFDEF DEBUG}
      Logger.Info('Shader compiled from memory: ' + AKey);
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Error('Shader compilation failed (from memory): ' + AKey);
      {$ENDIF}
      Result := Default(TShader);
   end;
end;

procedure TResourceManager2D.UnloadShader(const AKey: String);
begin
   UnloadByKey(FResources, AKey);
end;

{ ── Generic helpers ─────────────────────────────────────────────────────── }

procedure TResourceManager2D.Clear;
var
   I: Integer;
begin
   for I := FResources.Count - 1 downto 0 do
   begin
      FResources.Data[I].Free
   end;
   FResources.Clear;
   {$IFDEF DEBUG}
   Logger.Info('All resources cleared');
   {$ENDIF}
end;

function TResourceManager2D.GetResourceCount: Integer;
begin
   Result := FResources.Count;
end;

{ Estimates GPU memory used by texture and font atlas resources (RGBA = 4 B/px) }
function TResourceManager2D.GetMemoryUsage: Int64;
var
   I: Integer;
   Res: TResource2D;
begin
   Result := 0;
   for I := 0 to FResources.Count - 1 do
   begin
      Res := FResources.Data[I];
      if Res Is TTextureResource2D then
      begin
         Inc(Result, TTextureResource2D(Res).Texture.Width * TTextureResource2D(Res).Texture.Height * 4)
      end
      else
      if Res Is TFontResource2D then
      { Font atlas texture — same RGBA estimate }
      begin
         Inc(Result, TFontResource2D(Res).Font.Texture.Width * TFontResource2D(Res).Font.Texture.Height * 4)
      end;
      { Shaders and sounds/music: negligible or unmeasurable here }
   end;
end;

procedure TResourceManager2D.PrintResourceStats;
var
   I: Integer;
   Res: TResource2D;
begin
   {$IFDEF DEBUG}
   Logger.Info('=== RESOURCE MANAGER STATS ===');
   Logger.Info(Format('Total resources : %d', [FResources.Count]));
   Logger.Info(Format('Est. VRAM usage : %.2f MB', [GetMemoryUsage / 1024.0 / 1024.0]));
   Logger.Info('------------------------------');
   for I := 0 to FResources.Count - 1 do
   begin
      Res := FResources.Data[I];
      Logger.Info(Format('  [%d] %-8s  RefCount: %d  — %s', [I, ResourceTypeName(Res.ResourceType), Res.RefCount, Res.Name]));
   end;
   Logger.Info('==============================');
   {$ENDIF}
end;

initialization

finalization
   TResourceManager2D.FreeInstance;

end.
