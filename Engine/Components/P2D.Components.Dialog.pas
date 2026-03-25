unit P2D.Components.Dialog;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, P2D.Core.Component, P2D.Core.Types;

const
   DIALOG_NODE_END = -1;

type
   TDialogChoice2D = record
      Text: string;
      NextNode: integer;
   end;

   PDialogNode2D = ^TDialogNode2D;

   TDialogNode2D = record
      Speaker, Text, PortraitKey: string;
      Choices: array[0..3] of TDialogChoice2D;
      ChoiceCount: integer;
      AutoAdvance: boolean;
      NextNode: integer;
      DisplayTime: single;
   end;

   TDialogComponent2D = class(TComponent2D)
   private
      FNodes: array of TDialogNode2D;
      FNodeCount, FCurrentNode: integer;
      FActive: boolean;
      FDisplayTimer: single;
   public
      constructor Create; override;
      function AddNode(const Spk, Txt: string; const Port: string = ''; AutoAdv: boolean = False; DT: single = 3): integer;
      procedure AddChoice(NodeIdx: integer; const Txt: string; Next: integer);
      function GetNode(Idx: integer): PDialogNode2D;
      function GetCurrentNode: PDialogNode2D;
      procedure StartDialog;
      procedure AdvanceDialog(Choice: integer = -1);
      procedure Tick(ADelta: single);
      property NodeCount: integer read FNodeCount;
      property CurrentNode: integer read FCurrentNode;
      property Active: boolean read FActive;
      property DisplayTimer: single read FDisplayTimer;
   end;

implementation

uses
   P2D.Core.ComponentRegistry, P2D.Common;

constructor TDialogComponent2D.Create;
begin
   inherited Create;
   FNodeCount := 0;
   FCurrentNode := -1;
   FActive := False;
   FDisplayTimer := 0;
   SetLength(FNodes, 8);
end;

function TDialogComponent2D.AddNode(const Spk, Txt, Port: string; AutoAdv: boolean; DT: single): integer;
begin
   if FNodeCount >= Length(FNodes) then
      SetLength(FNodes, Length(FNodes) * 2);
   FillChar(FNodes[FNodeCount], SizeOf(TDialogNode2D), 0);
   FNodes[FNodeCount].Speaker := Spk;
   FNodes[FNodeCount].Text := Txt;
   FNodes[FNodeCount].PortraitKey := Port;
   FNodes[FNodeCount].AutoAdvance := AutoAdv;
   FNodes[FNodeCount].DisplayTime := DT;
   FNodes[FNodeCount].NextNode := DIALOG_NODE_END;
   Result := FNodeCount;
   Inc(FNodeCount);
end;

procedure TDialogComponent2D.AddChoice(NodeIdx: integer; const Txt: string; Next: integer);
var
   N: integer;
begin
   if (NodeIdx < 0) or (NodeIdx >= FNodeCount) then
      Exit;
   N := FNodes[NodeIdx].ChoiceCount;
   if N >= MAX_DIALOG_CHOICES then
      Exit;
   FNodes[NodeIdx].Choices[N].Text := Txt;
   FNodes[NodeIdx].Choices[N].NextNode := Next;
   Inc(FNodes[NodeIdx].ChoiceCount);
end;

function TDialogComponent2D.GetNode(Idx: integer): PDialogNode2D;
begin
   if (Idx >= 0) and (Idx < FNodeCount) then
      Result := @FNodes[Idx]
   else
      Result := nil;
end;

function TDialogComponent2D.GetCurrentNode: PDialogNode2D;
begin
   Result := GetNode(FCurrentNode);
end;

procedure TDialogComponent2D.StartDialog;
begin
   if FNodeCount = 0 then
      Exit;
   FCurrentNode := 0;
   FActive := True;
   FDisplayTimer := 0;
end;

procedure TDialogComponent2D.AdvanceDialog(Choice: integer);
var
   N: PDialogNode2D;
begin
   N := GetCurrentNode;
   if N = nil then
   begin
      FActive := False;
      Exit;
   end;
   if Choice >= 0 then
   begin
      if (N^.ChoiceCount > 0) and (Choice < N^.ChoiceCount) then
         FCurrentNode := N^.Choices[Choice].NextNode
      else
         FCurrentNode := DIALOG_NODE_END;
   end
   else
      FCurrentNode := N^.NextNode;
   FDisplayTimer := 0;
   if FCurrentNode = DIALOG_NODE_END then
      FActive := False;
end;

procedure TDialogComponent2D.Tick(ADelta: single);
var
   N: PDialogNode2D;
begin
   if not FActive then
      Exit;
   N := GetCurrentNode;
   if (N <> nil) and N^.AutoAdvance then
   begin
      FDisplayTimer := FDisplayTimer + ADelta;
      if FDisplayTimer >= N^.DisplayTime then
         AdvanceDialog;
   end;
end;

initialization
   ComponentRegistry.Register(TDialogComponent2D);
end.
