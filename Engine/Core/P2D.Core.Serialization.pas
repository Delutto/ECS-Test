unit P2D.Core.Serialization;

{$mode ObjFPC}{$H+}

interface

uses
   Classes,
   SysUtils,
   fpjson,
   jsonparser,
   P2D.Core.Entity,
   P2D.Core.Component,
   P2D.Core.World;

type
   { ISerializable2D }
   ISerializable2D = interface
      ['{8F3D2A1C-9B4E-4F21-A8C3-1D5E6F7A8B9C}']
      function Serialize: TJSONObject;
      procedure Deserialize(const AJSON: TJSONObject);
   end;

   { TSerializable2D }
   TSerializable2D = class
   public
      class function SerializeEntity(AEntity: TEntity): TJSONObject;
      class function DeserializeEntity(const AJSON: TJSONObject; AWorld: TWorld): TEntity;

      class function SerializeWorld(AWorld: TWorld): TJSONObject;
      class procedure DeserializeWorld(const AJSON: TJSONObject; AWorld: TWorld);

      class procedure SaveEntityToFile(AEntity: TEntity; const AFileName: String);
      class function LoadEntityFromFile(const AFileName: String; AWorld: TWorld): TEntity;

      class procedure SaveWorldToFile(AWorld: TWorld; const AFileName: String);
      class procedure LoadWorldFromFile(const AFileName: String; AWorld: TWorld);
   end;

implementation

uses
   P2D.Utils.Logger,
   P2D.Core.Types;

   { TSerializable2D }
class function TSerializable2D.SerializeEntity(AEntity: TEntity): TJSONObject;
var
   i: Integer;
   ComponentsArray: TJSONArray;
   Component: TComponent2D;
   ComponentObj: TJSONObject;
begin
   Result := TJSONObject.Create;
   try
      Result.Add('id', AEntity.ID);
      Result.Add('active', AEntity.Alive);

      ComponentsArray := TJSONArray.Create;
      for i := 0 to AEntity.ComponentCount - 1 do
      begin
         Component := AEntity.Components[i];

         if Supports(Component, ISerializable2D) then
         begin
            ComponentObj := TJSONObject.Create;
            ComponentObj.Add('class', Component.ClassName);
            ComponentObj.Add('data', (Component as ISerializable2D).Serialize);
            ComponentsArray.Add(ComponentObj);
         end
         else
         begin
            Logger.Warning(Format('Component %s does not support serialization', [Component.ClassName]));
         end;
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

class function TSerializable2D.DeserializeEntity(const AJSON: TJSONObject; AWorld: TWorld): TEntity;
var
   ComponentsArray: TJSONArray;
   i: Integer;
   ComponentObj: TJSONObject;
   ComponentClass: TComponent2DClass;
   Component: TComponent2D;
   ClassName: String;
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
            ComponentClass := TComponent2D.FindClass(ClassName) as TComponent2DClass;

            if Assigned(ComponentClass) then
            begin
               Component := ComponentClass.Create;
               if Supports(Component, ISerializable2D) then
               begin
                  (Component as ISerializable2D).Deserialize(ComponentObj.Get('data', TJSONObject(nil)));
                  Result.AddComponent(Component);
               end
               else
               begin
                  Component.Free;
                  Logger.Warning(Format('Component %s does not support deserialization', [ClassName]));
               end;
            end
            else
            begin
               Logger.Error('Component class not found: ' + ClassName);
            end;
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

class function TSerializable2D.SerializeWorld(AWorld: TWorld): TJSONObject;
var
   EntitiesArray: TJSONArray;
   i: Integer;
begin
   Result := TJSONObject.Create;
   try
      EntitiesArray := TJSONArray.Create;

      for i := 0 to AWorld.EntityCount - 1 do
      begin
         EntitiesArray.Add(SerializeEntity(AWorld.Entities[i]));
      end;

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

class procedure TSerializable2D.DeserializeWorld(const AJSON: TJSONObject; AWorld: TWorld);
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
         begin
            DeserializeEntity(EntitiesArray.Objects[i], AWorld);
         end;
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

class procedure TSerializable2D.SaveEntityToFile(AEntity: TEntity; const AFileName: String);
var
   JSON: TJSONObject;
   JSONString: String;
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

class function TSerializable2D.LoadEntityFromFile(const AFileName: String; AWorld: TWorld): TEntity;
var
   FileStream: TFileStream;
   JSONString: String;
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

class procedure TSerializable2D.SaveWorldToFile(AWorld: TWorld; const AFileName: String);
var
   JSON: TJSONObject;
   JSONString: String;
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

class procedure TSerializable2D.LoadWorldFromFile(const AFileName: String; AWorld: TWorld);
var
   FileStream: TFileStream;
   JSONString: String;
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
