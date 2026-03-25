unit P2D.Core.Pathfinding;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math;

type
   TPathPoint2D = record
      Col, Row: integer;
   end;

   TNS = (nsOpen, nsClosed, nsNone);

   TNode = record
      G, H, F: single;
      PC, PR: integer;
      S: TNS;
   end;

   TPathArray2D = array of TPathPoint2D;

   TAStarGrid2D = class
   private
      FCols, FRows: integer;
      FW: array of boolean;
      FN: array of TNode;
      procedure ResetN;
      function NI(C, R: integer): integer; inline;
      function IB(C, R: integer): boolean; inline;
      function Heur(C, R, GC, GR: integer): single; inline;
      procedure ReconP(GC, GR: integer; out P: TPathArray2D);
   public
      constructor Create(AC, AR: integer);
      procedure SetSize(AC, AR: integer);
      procedure SetWalkable(C, R: integer; W: boolean);
      function IsWalkable(C, R: integer): boolean;
      procedure Clear;
      function FindPath(SC, SR, GC, GR: integer; out P: TPathArray2D; Diag: boolean = False): boolean;
      property Cols: integer read FCols;
      property Rows: integer read FRows;
   end;

implementation

uses
   P2D.Common;

function TAStarGrid2D.NI(C, R: integer): integer;
begin
   Result := R * FCols + C;
end;

function TAStarGrid2D.IB(C, R: integer): boolean;
begin
   Result := (C >= 0) and (C < FCols) and (R >= 0) and (R < FRows);
end;

function TAStarGrid2D.Heur(C, R, GC, GR: integer): single;
begin
   Result := PATHFINDING_HEURISTIC_W * (Abs(C - GC) + Abs(R - GR));
end;

procedure TAStarGrid2D.ResetN;
var
   I: integer;
begin
   for I := 0 to Length(FN) - 1 do
      with FN[I] do
      begin
         G := MaxSingle;
         H := 0;
         F := MaxSingle;
         PC := -1;
         PR := -1;
         S := nsNone;
      end;
end;

procedure TAStarGrid2D.ReconP(GC, GR: integer; out P: TPathArray2D);
var
   Sp: array of TPathPoint2D;
   Cnt, C, R, Idx, I: integer;
begin
   Cnt := 0;
   SetLength(Sp, FCols * FRows);
   C := GC;
   R := GR;
   while (C >= 0) and (R >= 0) do
   begin
      Sp[Cnt].Col := C;
      Sp[Cnt].Row := R;
      Inc(Cnt);
      Idx := NI(C, R);
      C := FN[Idx].PC;
      R := FN[Idx].PR;
   end;
   SetLength(P, Cnt - 1);
   for I := 0 to Cnt - 2 do
      P[I] := Sp[Cnt - 2 - I];
end;

constructor TAStarGrid2D.Create(AC, AR: integer);
begin
   inherited Create;
   FCols := 0;
   FRows := 0;
   SetSize(AC, AR);
end;

procedure TAStarGrid2D.SetSize(AC, AR: integer);
var
   Sz, I: integer;
begin
   if (AC <= 0) or (AR <= 0) then
      Exit;
   FCols := AC;
   FRows := AR;
   Sz := AC * AR;
   SetLength(FW, Sz);
   SetLength(FN, Sz);
   for I := 0 to Sz - 1 do
      FW[I] := True;
end;

procedure TAStarGrid2D.SetWalkable(C, R: integer; W: boolean);
begin
   if IB(C, R) then
      FW[NI(C, R)] := W;
end;

function TAStarGrid2D.IsWalkable(C, R: integer): boolean;
begin
   if IB(C, R) then
      Result := FW[NI(C, R)]
   else
      Result := False;
end;

procedure TAStarGrid2D.Clear;
var
   I: integer;
begin
   for I := 0 to Length(FW) - 1 do
      FW[I] := True;
end;

function TAStarGrid2D.FindPath(SC, SR, GC, GR: integer; out P: TPathArray2D; Diag: boolean): boolean;
const
   CD: array[0..3, 0..1] of integer = ((0, -1), (0, 1), (-1, 0), (1, 0));
   DD: array[0..7, 0..1] of integer = ((0, -1), (0, 1), (-1, 0), (1, 0),
      (-1, -1), (1, -1), (-1, 1), (1, 1));
var
   OL: array of integer;
   OC, DC, Cur, Nbr, Best, I, D, CC, CR, NC, NR: integer;
   TG: single;
   Found: boolean;
begin
   P := nil;
   Result := False;
   if not IB(SC, SR) or not IB(GC, GR) then
      Exit;
   if not IsWalkable(GC, GR) then
      Exit;
   ResetN;
   DC := 4;
   if Diag then
      DC := 8;
   Cur := NI(SC, SR);
   FN[Cur].G := 0;
   FN[Cur].H := Heur(SC, SR, GC, GR);
   FN[Cur].F := FN[Cur].H;
   FN[Cur].S := nsOpen;
   SetLength(OL, PATHFINDING_MAX_NODES);
   OC := 1;
   OL[0] := Cur;
   Found := False;
   while (OC > 0) and not Found do
   begin
      Best := 0;
      for I := 1 to OC - 1 do
         if FN[OL[I]].F < FN[OL[Best]].F then
            Best := I;
      Cur := OL[Best];
      if Cur = NI(GC, GR) then
      begin
         Found := True;
         Break;
      end;
      OL[Best] := OL[OC - 1];
      Dec(OC);
      FN[Cur].S := nsClosed;
      CC := Cur mod FCols;
      CR := Cur div FCols;
      for D := 0 to DC - 1 do
      begin
         if Diag then
         begin
            NC := CC + DD[D][0];
            NR := CR + DD[D][1];
         end
         else
         begin
            NC := CC + CD[D][0];
            NR := CR + CD[D][1];
         end;
         if not IB(NC, NR) or not IsWalkable(NC, NR) then
            Continue;
         Nbr := NI(NC, NR);
         if FN[Nbr].S = nsClosed then
            Continue;
         TG := FN[Cur].G + 1.0;
         if FN[Nbr].S = nsNone then
         begin
            FN[Nbr].H := Heur(NC, NR, GC, GR);
            FN[Nbr].S := nsOpen;
            if OC < PATHFINDING_MAX_NODES then
            begin
               OL[OC] := Nbr;
               Inc(OC);
            end;
         end;
         if TG < FN[Nbr].G then
         begin
            FN[Nbr].G := TG;
            FN[Nbr].F := TG + FN[Nbr].H;
            FN[Nbr].PC := CC;
            FN[Nbr].PR := CR;
         end;
      end;
   end;
   if Found then
   begin
      ReconP(GC, GR, P);
      Result := Length(P) > 0;
   end;
end;

end.
