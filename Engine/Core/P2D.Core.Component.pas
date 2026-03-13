unit P2D.Core.Component;

{$mode objfpc}{$H+}

interface

uses
   SysUtils,
   P2D.Core.Types;

type
   // -------------------------------------------------------------------------
   // Every concrete component must descend from TComponent2D.
   // The class variable FID is used as a unique type-identifier per class.
   // -------------------------------------------------------------------------
   TComponent2D = class
   private
      FOwnerEntity: TEntityID;
      FEnabled    : Boolean;
   public
      constructor Create; virtual;
      property OwnerEntity: TEntityID read FOwnerEntity write FOwnerEntity;
      property Enabled    : Boolean   read FEnabled     write FEnabled;
   end;

   TComponent2DClass = class of TComponent2D;

implementation

constructor TComponent2D.Create;
begin
   inherited Create;

   FEnabled := True;
   FOwnerEntity := INVALID_ENTITY;
end;

end.
