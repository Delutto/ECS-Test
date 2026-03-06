unit P2D.Core.ResourceManager;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils, fgl, raylib;

type
   { TP2DResourceType }
   TP2DResourceType = (rtTexture, rtSound, rtMusic, rtFont, rtShader);

   { TP2DResource }
   TP2DResource = class
   private
      FName: string;
      FRefCount: Integer;
      FResourceType: TP2DResourceType;
   public
      constructor Create(const AName: string; AType: TP2DResourceType);
      procedure AddRef;
      function Release: Integer;
      property Name: string read FName;
      property RefCount: Integer read FRefCount;
      property ResourceType: TP2DResourceType read FResourceType;
   end;

   { TP2DTextureResource }
   TP2DTextureResource = class(TP2DResource)
   private
      FTexture: TTexture2D;
   public
      constructor Create(const AName: string; const ATexture: TTexture2D);
      destructor Destroy; override;
      property Texture: TTexture2D read FTexture;
   end;

   { TP2DSoundResource }
   TP2DSoundResource = class(TP2DResource)
   private
      FSound: TSound;
   public
      constructor Create(const AName: string; const ASound: TSound);
      destructor Destroy; override;
      property Sound: TSound read FSound;
   end;

   { TResourceMap }
   TResourceMap = specialize TFPGMap<string, TP2DResource>;

   { TP2DResourceManager }
   TP2DResourceManager = class
   private
      FResources: TResourceMap;
      class var FInstance: TP2DResourceManager;
      constructor Create;
   public
      destructor Destroy; override;
      class function Instance: TP2DResourceManager;
      class procedure FreeInstance;

      // Texture Management
      function LoadTexture(const AFileName: string): TTexture2D;
      procedure UnloadTexture(const AFileName: string);

      // Sound Management
      function LoadSound(const AFileName: string): TSound;
      procedure UnloadSound(const AFileName: string);

      // Generic Resource Management
      procedure AddResource(AResource: TP2DResource);
      function GetResource(const AName: string): TP2DResource;
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

constructor TP2DResource.Create(const AName: string; AType: TP2DResourceType);
begin
   inherited Create;

   FName := AName;
   FResourceType := AType;
   FRefCount := 1;
end;

procedure TP2DResource.AddRef;
begin
   Inc(FRefCount);
end;

function TP2DResource.Release: Integer;
begin
   Dec(FRefCount);
   Result := FRefCount;
end;

{ TP2DTextureResource }

constructor TP2DTextureResource.Create(const AName: string; const ATexture: TTexture2D);
begin
   inherited Create(AName, rtTexture);

   FTexture := ATexture;
end;

destructor TP2DTextureResource.Destroy;
begin
   UnloadTexture(FTexture);
   Logger.Info('Texture unloaded: ' + FName);

   inherited;
end;

{ TP2DSoundResource }

constructor TP2DSoundResource.Create(const AName: string; const ASound: TSound);
begin
   inherited Create(AName, rtSound);

   FSound := ASound;
end;

destructor TP2DSoundResource.Destroy;
begin
   UnloadSound(FSound);
   Logger.Info('Sound unloaded: ' + FName);

   inherited;
end;

{ TP2DResourceManager }

constructor TP2DResourceManager.Create;
begin
   inherited Create;

   FResources := TResourceMap.Create;
   FResources.Sorted := True;
   Logger.Info('ResourceManager initialized');
end;

destructor TP2DResourceManager.Destroy;
begin
  Clear;
  FResources.Free;
  Logger.Info('ResourceManager destroyed');

  inherited;
end;

class function TP2DResourceManager.Instance: TP2DResourceManager;
begin
   if FInstance = nil then
      FInstance := TP2DResourceManager.Create;
   Result := FInstance;
end;

class procedure TP2DResourceManager.FreeInstance;
begin
   FreeAndNil(FInstance);
end;

function TP2DResourceManager.LoadTexture(const AFileName: string): TTexture2D;
var
   Res: TP2DResource;
   Index: Integer;
begin
   Index := FResources.IndexOf(AFileName);

   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      Res.AddRef;
      Result := TP2DTextureResource(Res).Texture;
      Logger.Debug(Format('Texture reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
   end
   else
   begin
      if FileExists(AFileName) then
      begin
         Result := raylib.LoadTexture(PChar(AFileName));
         AddResource(TP2DTextureResource.Create(AFileName, Result));
         Logger.Info('Texture loaded: ' + AFileName);
      end
      else
      begin
         Logger.Error('Texture file not found: ' + AFileName);
         Result := Default(TTexture2D);
      end;
   end;
end;

procedure TP2DResourceManager.UnloadTexture(const AFileName: string);
var
   Index: Integer;
   Res: TP2DResource;
begin
   Index := FResources.IndexOf(AFileName);
   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      if Res.Release <= 0 then
      begin
         FResources.Delete(Index);
         Res.Free;
         Logger.Info('Texture released: ' + AFileName);
      end
      else
         Logger.Debug(Format('Texture ref decreased: %s (RefCount: %d)', [AFileName, Res.RefCount]));
   end;
end;

function TP2DResourceManager.LoadSound(const AFileName: string): TSound;
var
   Res: TP2DResource;
   Index: Integer;
begin
   Index := FResources.IndexOf(AFileName);

   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      Res.AddRef;
      Result := TP2DSoundResource(Res).Sound;
      Logger.Debug(Format('Sound reused: %s (RefCount: %d)', [AFileName, Res.RefCount]));
   end
   else
   begin
      if FileExists(AFileName) then
      begin
         Result := raylib.LoadSound(PChar(AFileName));
         AddResource(TP2DSoundResource.Create(AFileName, Result));
         Logger.Info('Sound loaded: ' + AFileName);
      end
      else
      begin
         Logger.Error('Sound file not found: ' + AFileName);
         Result := Default(TSound);
      end;
   end;
end;

procedure TP2DResourceManager.UnloadSound(const AFileName: string);
var
   Index: Integer;
   Res: TP2DResource;
begin
   Index := FResources.IndexOf(AFileName);
   if Index >= 0 then
   begin
      Res := FResources.Data[Index];
      if Res.Release <= 0 then
      begin
         FResources.Delete(Index);
         Res.Free;
         Logger.Info('Sound released: ' + AFileName);
      end
      else
         Logger.Debug(Format('Sound ref decreased: %s (RefCount: %d)', [AFileName, Res.RefCount]));
   end;
end;

procedure TP2DResourceManager.AddResource(AResource: TP2DResource);
begin
   FResources.Add(AResource.Name, AResource);
end;

function TP2DResourceManager.GetResource(const AName: string): TP2DResource;
var
   Index: Integer;
begin
   Index := FResources.IndexOf(AName);
   if Index >= 0 then
      Result := FResources.Data[Index]
   else
      Result := nil;
end;

procedure TP2DResourceManager.Clear;
var
   i: Integer;
begin
   for i := FResources.Count - 1 downto 0 do
      FResources.Data[i].Free;
   FResources.Clear;
   Logger.Info('All resources cleared');
end;

function TP2DResourceManager.GetResourceCount: Integer;
begin
   Result := FResources.Count;
end;

function TP2DResourceManager.GetMemoryUsage: Int64;
var
   i: Integer;
   Res: TP2DResource;
begin
   Result := 0;
   for i := 0 to FResources.Count - 1 do
   begin
      Res := FResources.Data[i];
      if Res is TP2DTextureResource then
         Result := Result + TP2DTextureResource(Res).Texture.width * TP2DTextureResource(Res).Texture.height * 4; // RGBA
   end;
end;

procedure TP2DResourceManager.PrintResourceStats;
var
   i: Integer;
   Res: TP2DResource;
begin
   Logger.Info('=== RESOURCE MANAGER STATS ===');
   Logger.Info(Format('Total Resources: %d', [FResources.Count]));
   Logger.Info(Format('Memory Usage: %.2f MB', [GetMemoryUsage / 1024 / 1024]));
   Logger.Info('--- Resource List ---');
   for i := 0 to FResources.Count - 1 do
   begin
      Res := FResources.Data[i];
      Logger.Info(Format('  [%d] %s (Type: %d, RefCount: %d)', [i, Res.Name, Ord(Res.ResourceType), Res.RefCount]));
   end;
   Logger.Info('==============================');
end;

initialization

finalization
   TP2DResourceManager.FreeInstance;

end.
