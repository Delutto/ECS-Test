unit P2D.Core.ResourceManager;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils, fgl, raylib;

type
   { TResourceType2D }
   TResourceType2D = (rtTexture, rtSound, rtMusic, rtFont, rtShader);

   { TResource2D }
   TResource2D = class
   private
      FName: string;
      FRefCount: Integer;
      FResourceType: TResourceType2D;
   public
      constructor Create(const AName: string; AType: TResourceType2D);
      procedure AddRef;
      function Release: Integer;
      property Name: string read FName;
      property RefCount: Integer read FRefCount;
      property ResourceType: TResourceType2D read FResourceType;
   end;

   { TTextureResource2D }
   TTextureResource2D = class(TResource2D)
   private
      FTexture: TTexture2D;
   public
      constructor Create(const AName: string; const ATexture: TTexture2D);
      destructor Destroy; override;
      property Texture: TTexture2D read FTexture;
   end;

   { TSoundResource2D }
   TSoundResource2D = class(TResource2D)
   private
      FSound: TSound;
   public
      constructor Create(const AName: string; const ASound: TSound);
      destructor Destroy; override;
      property Sound: TSound read FSound;
   end;

   { TMusicResource2D }
   TMusicResource2D = class(TResource2D)
   private
      FMusic: TMusic;
   public
      constructor Create(const AName: string; const AMusic: TMusic);
      destructor Destroy; override;
      property Music: TMusic read FMusic;
   end;

   { TResourceMap2D }
   TResourceMap2D = specialize TFPGMap<string, TResource2D>;

   { TResourceManager2D }
   TResourceManager2D = class
   private
      FResources: TResourceMap2D;
      class var FInstance: TResourceManager2D;
      constructor Create;
   public
      destructor Destroy; override;
      class function Instance: TResourceManager2D;
      class procedure FreeInstance;

      // Texture Management
      function LoadTexture(const AFileName: string): TTexture2D;
      procedure UnloadTexture(const AFileName: string);

      // Sound Management
      function LoadSound(const AFileName: string): TSound;
      procedure UnloadSound(const AFileName: string);

      // Music Management
      function LoadMusic(const AFileName: string): TMusic;
      procedure UnloadMusic(const AFileName: string);

      // Generic Resource Management
      procedure AddResource(AResource: TResource2D);
      function GetResource(const AName: string): TResource2D;
      procedure Clear;

      // Debug & Stats
      function GetResourceCount: Integer;
      function GetMemoryUsage: Int64;
      procedure PrintResourceStats;
   end;

implementation

uses
   P2D.Utils.Logger;

{ TP2DResource }

constructor TResource2D.Create(const AName: string; AType: TResourceType2D);
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

{ TTextureResource2D }

constructor TTextureResource2D.Create(const AName: string; const ATexture: TTexture2D);
begin
   inherited Create(AName, rtTexture);

   FTexture := ATexture;
end;

destructor TTextureResource2D.Destroy;
begin
   UnloadTexture(FTexture);
   {$IFDEF DEBUG}
   Logger.Info('Texture unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ TSoundResource2D }
constructor TSoundResource2D.Create(const AName: string; const ASound: TSound);
begin
   inherited Create(AName, rtSound);

   FSound := ASound;
end;

destructor TSoundResource2D.Destroy;
begin
   UnloadSound(FSound);
   {$IFDEF DEBUG}
   Logger.Info('Sound unloaded: ' + FName);
   {$ENDIF}

   inherited;
end;

{ TMusicResource2D }
constructor TMusicResource2D.Create(const AName: string; const AMusic: TMusic);
begin
   inherited Create(AName, rtMusic);

   FMusic := AMusic;
end;

destructor TMusicResource2D.Destroy;
begin
   UnloadMusicStream(FMusic);
   {$IFDEF DEBUG}
   Logger.Info('Music unloaded: ' + FName);
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
      FInstance := TResourceManager2D.Create;
   Result := FInstance;
end;

class procedure TResourceManager2D.FreeInstance;
begin
   FreeAndNil(FInstance);
end;

function TResourceManager2D.LoadTexture(const AFileName: string): TTexture2D;
var
   Res: TResource2D;
   Index: Integer;
begin
   Index := FResources.IndexOf(AFileName);

   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      Res.AddRef;
      Result := TTextureResource2D(Res).Texture;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Texture reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
      {$ENDIF}
   end
   else
   begin
      if FileExists(PChar(AFileName)) then   ////////////////////////// ISSO AQUI PODE DAR MERDA !!!!!
      begin
         Result := raylib.LoadTexture(PChar(AFileName));
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
end;

procedure TResourceManager2D.UnloadTexture(const AFileName: string);
var
   Index: Integer;
   Res: TResource2D;
begin
   Index := FResources.IndexOf(AFileName);
   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      if Res.Release <= 0 then
      begin
         FResources.Delete(Index);
         Res.Free;
         {$IFDEF DEBUG}
         Logger.Info('Texture released: ' + AFileName);
         {$ENDIF}
      end
      else
      begin
         {$IFDEF DEBUG}
         Logger.Debug(Format('Texture ref decreased: %s (RefCount: %d)', [AFileName, Res.RefCount]));
         {$ENDIF}
      end;
   end;
end;

function TResourceManager2D.LoadSound(const AFileName: string): TSound;
var
   Res: TResource2D;
   Index: Integer;
begin
   Index := FResources.IndexOf(AFileName);

   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      Res.AddRef;
      Result := TSoundResource2D(Res).Sound;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Sound reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
      {$ENDIF}
   end
   else
   begin
      if FileExists(PChar(AFileName)) then
      begin
         Result := raylib.LoadSound(PChar(AFileName));
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
end;

procedure TResourceManager2D.UnloadSound(const AFileName: string);
var
   Index: Integer;
   Res: TResource2D;
begin
   Index := FResources.IndexOf(AFileName);
   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      if Res.Release <= 0 then
      begin
         FResources.Delete(Index);
         Res.Free;
         {$IFDEF DEBUG}
         Logger.Info('Sound released: ' + AFileName);
         {$ENDIF}
      end
      else
      begin
         {$IFDEF DEBUG}
         Logger.Debug(Format('Sound ref decreased: %s (RefCount: %d)', [AFileName, Res.RefCount]));
         {$ENDIF}
      end;
   end;
end;

function TResourceManager2D.LoadMusic(const AFileName: string): TMusic;
var
   Res: TResource2D;
   Index: Integer;
begin
   Index := FResources.IndexOf(AFileName);

   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      Res.AddRef;
      Result := TMusicResource2D(Res).Music;
      {$IFDEF DEBUG}
      Logger.Debug(Format('Music reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
      {$ENDIF}
   end
   else
   begin
      if FileExists(PChar(AFileName)) then
      begin
         Result := raylib.LoadMusicStream(PChar(AFileName));
         AddResource(TMusicResource2D.Create(AFileName, Result));
         {$IFDEF DEBUG}
         Logger.Info('Music loaded: ' + AFileName);
         {$ENDIF}
      end
      else
      begin
         {$IFDEF DEBUG}
         Logger.Error('Sound file not found: ' + AFileName);
         {$ENDIF}
         Result := Default(TMusic);
      end;
   end;
end;

procedure TResourceManager2D.UnloadMusic(const AFileName: string);
var
   Index: Integer;
   Res: TResource2D;
begin
   Index := FResources.IndexOf(AFileName);
   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      if Res.Release <= 0 then
      begin
         FResources.Delete(Index);
         Res.Free;
         {$IFDEF DEBUG}
         Logger.Info('Music released: ' + AFileName);
         {$ENDIF}
      end
      else
      begin
         {$IFDEF DEBUG}
         Logger.Debug(Format('Music ref decreased: %s (RefCount: %d)', [AFileName, Res.RefCount]));
         {$ENDIF}
      end;
   end;
end;

procedure TResourceManager2D.AddResource(AResource: TResource2D);
begin
   FResources.Add(AResource.Name, AResource);
end;

function TResourceManager2D.GetResource(const AName: string): TResource2D;
var
   Index: Integer;
begin
   Index := FResources.IndexOf(AName);
   if Index >= 0 then
      Result := FResources.Data[Index]
   else
      Result := nil;
end;

procedure TResourceManager2D.Clear;
var
   i: Integer;
begin
   for i := FResources.Count - 1 downto 0 do
      FResources.Data[i].Free;
   FResources.Clear;
   {$IFDEF DEBUG}
   Logger.Info('All resources cleared');
   {$ENDIF}
end;

function TResourceManager2D.GetResourceCount: Integer;
begin
   Result := FResources.Count;
end;

function TResourceManager2D.GetMemoryUsage: Int64;
var
   i: Integer;
   Res: TResource2D;
begin
   Result := 0;
   for i := 0 to FResources.Count - 1 do
   begin
      Res := FResources.Data[i];
      if Res is TTextureResource2D then
         Result := Result + TTextureResource2D(Res).Texture.width * TTextureResource2D(Res).Texture.height * 4; // RGBA
   end;
end;

procedure TResourceManager2D.PrintResourceStats;
var
   i: Integer;
   Res: TResource2D;
begin
   {$IFDEF DEBUG}
   Logger.Info('=== RESOURCE MANAGER STATS ===');
   Logger.Info(Format('Total Resources: %d', [FResources.Count]));
   Logger.Info(Format('Memory Usage: %.2f MB', [GetMemoryUsage / 1024 / 1024]));
   Logger.Info('--- Resource List ---');
   {$ENDIF}
   for i := 0 to FResources.Count - 1 do
   begin
      Res := FResources.Data[i];
      {$IFDEF DEBUG}
      Logger.Info(Format('  [%d] %s (Type: %d, RefCount: %d)', [i, Res.Name, Ord(Res.ResourceType), Res.RefCount]));
      {$ENDIF}
   end;
   {$IFDEF DEBUG}
   Logger.Info('==============================');
   {$ENDIF}
end;

initialization

finalization
   TResourceManager2D.FreeInstance;

end.
