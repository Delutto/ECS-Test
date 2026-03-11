unit P2D.Core.Serialization;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser,
  P2D.Core.Entity, P2D.Core.Component, P2D.Core.World;

type
  { IP2DSerializable }
  IP2DSerializable = interface
    ['{8F3D2A1C-9B4E-4F21-A8C3-1D5E6F7A8B9C}']
    function Serialize: TJSONObject;
    procedure Deserialize(const AJSON: TJSONObject);
  end;

  { TP2DSerializer }
  TP2DSerializer = class
  public
    class function SerializeEntity(AEntity: TP2DEntity): TJSONObject;
    class function DeserializeEntity(const AJSON: TJSONObject; AWorld: TP2DWorld): TP2DEntity;

    class function SerializeWorld(AWorld: TP2DWorld): TJSONObject;
    class procedure DeserializeWorld(const AJSON: TJSONObject; AWorld: TP2DWorld);

    class procedure SaveEntityToFile(AEntity: TP2DEntity; const AFileName: string);
    class function LoadEntityFromFile(const AFileName: string; AWorld: TP2DWorld): TP2DEntity;

    class procedure SaveWorldToFile(AWorld: TP2DWorld; const AFileName: string);
    class procedure LoadWorldFromFile(const AFileName: string; AWorld: TP2DWorld);
  end;

implementation

uses
  P2D.Utils.Logger, P2D.Core.Types;

{ TP2DSerializer }

class function TP2DSerializer.SerializeEntity(AEntity: TP2DEntity): TJSONObject;
var
  i: Integer;
  ComponentsArray: TJSONArray;
  Component: TP2DComponent;
  ComponentObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('id', AEntity.ID);
    Result.Add('active', AEntity.Active);

    ComponentsArray := TJSONArray.Create;
    for i := 0 to AEntity.ComponentCount - 1 do
    begin
      Component := AEntity.Components[i];

      if Supports(Component, IP2DSerializable) then
      begin
        ComponentObj := TJSONObject.Create;
        ComponentObj.Add('class', Component.ClassName);
        ComponentObj.Add('data', (Component as IP2DSerializable).Serialize);
        ComponentsArray.Add(ComponentObj);
      end
      else
        Logger.Warning(Format('Component %s does not support serialization', [Component.ClassName]));
    end;

    Result.Add('components', ComponentsArray);
  except
    on E: Exception do
    begin
      Logger.Error('Error serializing entity: ' + E.Message);
      Result.Free;
      raise;
    end;
  end;
end;

class function TP2DSerializer.DeserializeEntity(const AJSON: TJSONObject; AWorld: TP2DWorld): TP2DEntity;
var
  ComponentsArray: TJSONArray;
  i: Integer;
  ComponentObj: TJSONObject;
  ComponentClass: TP2DComponentClass;
  Component: TP2DComponent;
  ClassName: string;
begin
  Result := AWorld.CreateEntity;
  try
    Result.SetActive(AJSON.Get('active', True));

    ComponentsArray := AJSON.Get('components', TJSONArray(nil));
    if Assigned(ComponentsArray) then
    begin
      for i := 0 to ComponentsArray.Count - 1 do
      begin
        ComponentObj := ComponentsArray.Objects[i];
        ClassName := ComponentObj.Get('class', '');

        // Aqui você precisaria de um registro de classes de componentes
        // Por enquanto, vou deixar como exemplo
        ComponentClass := TP2DComponent.FindClass(ClassName) as TP2DComponentClass;

        if Assigned(ComponentClass) then
        begin
          Component := ComponentClass.Create;
          if Supports(Component, IP2DSerializable) then
          begin
            (Component as IP2DSerializable).Deserialize(ComponentObj.Get('data', TJSONObject(nil)));
            Result.AddComponent(Component);
          end
          else
          begin
            Component.Free;
            Logger.Warning(Format('Component %s does not support deserialization', [ClassName]));
          end;
        end
        else
          Logger.Error('Component class not found: ' + ClassName);
      end;
    end;
  except
    on E: Exception do
    begin
      Logger.Error('Error deserializing entity: ' + E.Message);
      Result.Free;
      raise;
    end;
  end;
end;

class function TP2DSerializer.SerializeWorld(AWorld: TP2DWorld): TJSONObject;
var
  EntitiesArray: TJSONArray;
  i: Integer;
begin
  Result := TJSONObject.Create;
  try
    EntitiesArray := TJSONArray.Create;

    for i := 0 to AWorld.EntityCount - 1 do
      EntitiesArray.Add(SerializeEntity(AWorld.Entities[i]));

    Result.Add('entities', EntitiesArray);
    Result.Add('entity_count', AWorld.EntityCount);
  except
    on E: Exception do
    begin
      Logger.Error('Error serializing world: ' + E.Message);
      Result.Free;
      raise;
    end;
  end;
end;

class procedure TP2DSerializer.DeserializeWorld(const AJSON: TJSONObject; AWorld: TP2DWorld);
var
  EntitiesArray: TJSONArray;
  i: Integer;
begin
  try
    AWorld.Clear;

    EntitiesArray := AJSON.Get('entities', TJSONArray(nil));
    if Assigned(EntitiesArray) then
    begin
      for i := 0 to EntitiesArray.Count - 1 do
        DeserializeEntity(EntitiesArray.Objects[i], AWorld);
    end;

    Logger.Info(Format('World deserialized: %d entities loaded', [AWorld.EntityCount]));
  except
    on E: Exception do
    begin
      Logger.Error('Error deserializing world: ' + E.Message);
      raise;
    end;
  end;
end;

class procedure TP2DSerializer.SaveEntityToFile(AEntity: TP2DEntity; const AFileName: string);
var
  JSON: TJSONObject;
  JSONString: string;
  FileStream: TFileStream;
begin
  try
    JSON := SerializeEntity(AEntity);
    try
      JSONString := JSON.FormatJSON;
      FileStream := TFileStream.Create(AFileName, fmCreate);
      try
        FileStream.WriteBuffer(JSONString[1], Length(JSONString));
        Logger.Info('Entity saved to file: ' + AFileName);
      finally
        FileStream.Free;
      end;
    finally
      JSON.Free;
    end;
  except
    on E: Exception do
    begin
      Logger.Error('Error saving entity to file: ' + E.Message);
      raise;
    end;
  end;
end;

class function TP2DSerializer.LoadEntityFromFile(const AFileName: string; AWorld: TP2DWorld): TP2DEntity;
var
  FileStream: TFileStream;
  JSONString: string;
  JSON: TJSONObject;
  Parser: TJSONParser;
begin
  try
    FileStream := TFileStream.Create(AFileName, fmOpenRead);
    try
      SetLength(JSONString, FileStream.Size);
      FileStream.ReadBuffer(JSONString[1], FileStream.Size);

      Parser := TJSONParser.Create(JSONString, [joUTF8]);
      try
        JSON := Parser.Parse as TJSONObject;
        try
          Result := DeserializeEntity(JSON, AWorld);
          Logger.Info('Entity loaded from file: ' + AFileName);
        finally
          JSON.Free;
        end;
      finally
        Parser.Free;
      end;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
    begin
      Logger.Error('Error loading entity from file: ' + E.Message);
      raise;
    end;
  end;
end;

class procedure TP2DSerializer.SaveWorldToFile(AWorld: TP2DWorld; const AFileName: string);
var
  JSON: TJSONObject;
  JSONString: string;
  FileStream: TFileStream;
begin
  try
    JSON := SerializeWorld(AWorld);
    try
      JSONString := JSON.FormatJSON;
      FileStream := TFileStream.Create(AFileName, fmCreate);
      try
        FileStream.WriteBuffer(JSONString[1], Length(JSONString));
        Logger.Info('World saved to file: ' + AFileName);
      finally
        FileStream.Free;
      end;
    finally
      JSON.Free;
    end;
  except
    on E: Exception do
    begin
      Logger.Error('Error saving world to file: ' + E.Message);
      raise;
    end;
  end;
end;

class procedure TP2DSerializer.LoadWorldFromFile(const AFileName: string; AWorld: TP2DWorld);
var
  FileStream: TFileStream;
  JSONString: string;
  JSON: TJSONObject;
  Parser: TJSONParser;
begin
  try
    FileStream := TFileStream.Create(AFileName, fmOpenRead);
    try
      SetLength(JSONString, FileStream.Size);
      FileStream.ReadBuffer(JSONString[1], FileStream.Size);

      Parser := TJSONParser.Create(JSONString, [joUTF8]);
      try
        JSON := Parser.Parse as TJSONObject;
        try
          DeserializeWorld(JSON, AWorld);
          Logger.Info('World loaded from file: ' + AFileName);
        finally
          JSON.Free;
        end;
      finally
        Parser.Free;
      end;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
    begin
      Logger.Error('Error loading world from file: ' + E.Message);
      raise;
    end;
  end;
end;

end.
