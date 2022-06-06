unit myfunctions;

{$mode objfpc}{$H+}

interface

uses
 Classes, strutils,portcons,lazutf8,RegExpr, SysUtils
 {$IFDEF UNIX}

 {$ELSE}
 , windows
 {$ENDIF}
 ;

type
  CommandAndArgument = array of string;
  TArrayofinteger = array of integer;
  TArrayofbyte = array of byte;

function TagServiceToIntActivation(s: string): integer;
function IntToTagServiceActivation(i: integer): string;

//function TagOperatorToInt(const a: string): TSIM_OPERATOR;
//function IntOperatorToTag(const a: TSIM_OPERATOR): string;

function CutCodeInSms(sms,rexp:string):string;
function HTTPGetMainTable(c:integer):string;
function ParseConfigData(var t:string):string;
function GetNumber(const s: string): string;
function GetStatePin(t:string):string;
function CLIP2Nomer(const st: string):string;
function Str2GotovLiModem(s:string):integer;
function Str2UrovenSignala(s:string):string;
function GetSmSService(s:string):string;
function Str2NomerSmS(s:string):integer;
function MyReadByte(var s:string):Byte;
function MyFormatNomer(const s:string):string;
function MyReadByteS(var s:string; k:integer):string;
function Ceil(const X: Extended): Integer;
function Bit7tostring2(t:string):string;overload;
function Bit7tostring2(t:string;l,k:integer):string;overload;
function MyReadByteS2(var s:string; k:integer):string;
function myswaptime(const s:string):string;
function UCSToAnsi(s:string):string;
function USSDResponse(s:string):string;
function DateTimeToUnix(ConvDate: TDateTime): Longint;
function UnixToDateTime(USec: Longint): TDateTime;
function HashB(S: AnsiString; LenHash: Integer = 256): AnsiString;
function PORTSTATE2Str(b:byte): string;
function MODEMSTATE2Str(b:byte): string;
function TimeDMYHMS():string;
function TimeDMYHM():string;
function TimeHM():string;
function TimeHMS():string;
function TimeDMY():string;
function TimeYMDHM():string;overload;
function TimeYMDHM(a:tdatetime):string;overload;
function Pos(a,b:string;c:cardinal):integer;overload;

procedure DeleteArrayIndex(var X: TArrayofMySmsinFile; Index: Integer);overload;
procedure DeleteArrayIndex(var X: TArraysmstosend; Index: Integer);overload;
procedure DeleteArrayIndex(var X: TArrayString; Index: Integer);overload;
procedure DeleteArrayIndex(var X: TArrayMySqlZapros; Index: Integer);overload;
procedure DeleteArrayIndex(var X: TArrayMySmsSend; Index: Integer);overload;
function ReplaceProbel(s:string):string;
function ReturnProbel(s:string):string;
function GetBit(x: int64; Num: Byte): Boolean;
procedure SetBit(var x: int64; Num: Byte);
function isPhoneNomer(s:string):boolean;
function GetTempCPU:string;
function ErrorTr(id:integer;s:string):string;
function FinishTr(id:integer):string;
procedure LogiFile(s:string;_TypeExecute:string = '');
function DeleteSystemChar(s:string):string;
function MStrToHex(s:string):ansistring;
function MHexToStr(s:ansistring):string;
function Byte2Str(const arr: TArrayofbyte; forcestr: boolean): string;
function Str2Byte(const str: string; autohex: boolean): TArrayofbyte;
function NormalNomer2PDU(t:string):string;
function utf16tohex(s: string):string;
procedure DebugLog(s:string);overload;
procedure DebugLog(s,fs:string);overload;
procedure start_self();
procedure TextToFile(text, filename: string);

implementation

uses
 jsonparser, fpjson, maind;


function utf16tohex(s: string):string;
var
  l: integer;
  c: cardinal;
begin
  result := '';
  while UTF8Length(s)<>0 do
  begin
    c := UTF8CodepointToUnicode(@s[1], l);
    if (l<>2) then
      result := result + '00' + IntToHex(c, 2)
    else
      result := result + IntToHex(c, 4);
    UTF8Delete(s,1,1);
  end;
end;

function NormalNomer2PDU(t:string):string;
var
  i:integer;
  s:string;
begin
  s:=t;
  result:='';
  if (length(s) and 1) = 0 then
    for I := 0 to ceil(Length(s) / 2)-1 do
      result:=result+s[i*2+2]+s[i*2+1]
  else
    begin
    s:=s+'F';
    for I := 0 to ceil(Length(s) / 2)-1 do
      result:=result+s[i*2+2]+s[i*2+1];
    end;
  if Length(Result)<6 then
    result:='81'+result
  else
    result:='91'+result;
  result:=Format('%.2x',[Length(t)])+result;
end;

function TagServiceToIntActivation(s: string): integer;
begin
  result := -1;
  case s of
    'ignore': result :=  0;
    'aa': result :=  1;
    'fb': result :=  2;
    'vk': result :=  3;
    'ma': result :=  4;
    'ya': result :=  5;
    'go': result :=  6;
    'ig': result :=  7;
    'sn': result :=  8;
    'tg': result :=  9;
    'wa': result := 10;
    'vi': result := 11;
    'av': result := 12;
    'tw': result := 13;
    'ub': result := 14;
    'qw': result := 15;
    'gt': result := 16;
    'ok': result := 17;
    'wb': result := 18;
  end;
end;

function IntToTagServiceActivation(i: integer): string;
begin
  result := '';
  case i of
     0: result := 'ignore';
     1: result := 'aa';
     2: result := 'fb';
     3: result := 'vk';
     4: result := 'ma';
     5: result := 'ya';
     6: result := 'go';
     7: result := 'ig';
     8: result := 'sn';
     9: result := 'tg';
    10: result := 'wa';
    11: result := 'vi';
    12: result := 'av';
    13: result := 'tw';
    14: result := 'ub';
    15: result := 'qw';
    16: result := 'gt';
    17: result := 'ok';
    18: result := 'wb';
  end;
end;
{
function TagOperatorToInt(const a: string): TSIM_OPERATOR;
begin
  result := SIM_UNKNOWN;
  case a of
    'mts': result := SIM_MTS;
    'beeline': result := SIM_BEELINE;
    'megafon': result := SIM_MEGAFON;
    'velcom': result := SIM_VELCOM;
    'tele2': result := SIM_TELE2;
    'kcell': result := SIM_KCELL;
    'altel': result := SIM_ALTEL;
    'astelit': result := SIM_ASTELIT;
    'life': result := SIM_LIFE;
    'kyivstar': result := SIM_KYIVSTAR;
  end;
end;


function IntOperatorToTag(const a: TSIM_OPERATOR): string;
begin
  result := '';
  case a of
    SIM_MTS     : result := 'mts';
    SIM_BEELINE : result := 'beeline';
    SIM_MEGAFON : result := 'megafon';
    SIM_VELCOM  : result := 'velcom';
    SIM_TELE2   : result := 'tele2';
    SIM_KCELL   : result := 'kcell';
    SIM_ALTEL   : result := 'altel';
    SIM_ASTELIT : result := 'astelit';
    SIM_LIFE    : result := 'life';
    SIM_KYIVSTAR: result := 'kyivstar';
  end;
end;}

function ParseConfigData(var t: string): string;
begin
  if Pos(',',t)=0 then begin
    result := t;
    t := '';
    exit;
  end;
  result := Copy(t,1,Pos(',',t)-1);
  Delete(t,1,Pos(',',t));
end;

function ValidHex(const s: string): boolean;
var
  i:integer;
begin
  result:=false;
  for i:=Low(s) to High(s) do
    if not(
    (($30<=byte(s[i]))AND(byte(s[i])<=$39))OR
    (($41<=byte(s[i]))AND(byte(s[i])<=$46))OR
    (($61<=byte(s[i]))AND(byte(s[i])<=$66))
    ) then
      exit;
  result:=true;
end;

function Byte2Str(const arr: TArrayofbyte; forcestr: boolean): string;
var
  i:Longword;
begin
  result:='';
  if length(arr)=0 then exit;
  for i:=Low(arr) to High(arr) do
    if forcestr then
      result += Chr(arr[i])
    else
      result += IntToHex(arr[i],2);
end;

function Str2Byte(const str: string; autohex: boolean): TArrayofbyte;
var
  i:Longword;
begin
  SetLength(result,0);
  if length(str)=0 then exit;
  if length(str)=1 then
    begin
      SetLength(result,1);
      if ValidHex(str)AND(autohex) then
        result[0]:=StrToInt('$0'+str[1])
      else
        result[0]:=byte(str[1]);
      exit;
    end;
  if ValidHex(str)AND(autohex) then
  begin
    SetLength(result,length(str) div 2);
    for i:=Low(result) to High(result) do
      result[i]:=StrToInt('$'+str[i*2+1]+str[i*2+2]);
  end
  else
  begin
    SetLength(result,length(str));
    for i:=Low(result) to High(result) do
      result[i]:=byte(str[i+1]);
  end;
end;

function MStrToHex(s:string):ansistring;
var
  i:integer;
begin
  result:='';
  for i:=1 to Length(s) do
    result:=result+IntToHex(byte(s[i]),2);
end;

function MHexToStr(s:ansistring):string;
var
  i:integer;
begin
  result:='';
  for I := 1 to Length(s) div 2 do
    result:=result+chr(StrToInt('$'+s[2*i-1]+s[2*i]));
end;

function DeleteSystemChar(s:string):string;
begin
  result:=s;
  result:=StringReplace(result,#13,'',[rfReplaceAll]);
  result:=StringReplace(result,#10,'',[rfReplaceAll]);
end;

procedure LogiFile(s:string;_TypeExecute:string = '');
var
   f : Textfile;
 begin
   ForceDirectories(extractfilepath(paramstr(0)));
   AssignFile(f, extractfilepath(paramstr(0))+'debuglog.txt');
   try
     if FileExists(extractfilepath(paramstr(0))+'debuglog.txt') = False then
       Rewrite(f)
     else
     begin
       Append(f);
     end;
     Writeln(f,TimeDMYHM()+'['+_TypeExecute+']:'+ s);
   finally
     CloseFile(f);
   end;
end;    

function ErrorTr(id:integer;s:string):string;
var
  J:TJSONObject;
begin
  result:='';
  J:=TJSONObject.Create;
  J.Add('cmd_execute','false');
  J.Add('id',id);
  J.Add('response',s);
  result:=J.FormatJSON;
  FreeAndNil(J);
end;

function FinishTr(id:integer):string;
var
  J:TJSONObject;
begin
  result:='';
  J:=TJSONObject.Create;
  J.Add('cmd_execute','true');
  J.Add('id',id);
  result:=J.FormatJSON;
  FreeAndNil(J);
end;

function ReplaceProbel(s:string):string;
begin
  result:=StringReplace(s,#13,'<ACR>',[rfReplaceAll]);
  result:=StringReplace(result,#10,'<ALF>',[rfReplaceAll]);
end;

function ReturnProbel(s:string):string;
begin
  result:=StringReplace(s,'<ACR>',#13,[rfReplaceAll]);
  result:=StringReplace(result,'<ALF>',#10,[rfReplaceAll]);
end;

function isPhoneNomer(s:string):boolean;
var
  i:integer;
begin
  result:=True;
  for i := 1 to Length(s) do
    if (s[i] in ['0'..'9','+'])=false then
      exit(false);
end;


procedure DebugLog(s: string);overload;
begin
   DebugLog(s,'dlog.txt');
end;

procedure DebugLog(s, fs: string);overload;
var
   f : Textfile;
begin
  //exit;
  AssignFile(f, extractfilepath(paramstr(0))+fs);
  try
    if FileExists(extractfilepath(paramstr(0))+fs) = False then
      Rewrite(f)
    else
    begin
      Append(f);
    end;
    Writeln(f,TimeDMYHMS()+':'+ s);
  finally
    CloseFile(f);
  end;
end;

procedure start_self();
begin
  {$IFDEF UNIX}

  {$ELSE}
  ShellExecute(0,nil, PChar('SIMHUB3D.exe'),nil,nil,1)
  {$ENDIF}
end;

procedure TextToFile(text, filename: string);
var
  f : Textfile;
begin
  ForceDirectories(extractfilepath(filename));
  AssignFile(f, filename);
  try
    if FileExists(filename) = False then
     Rewrite(f)
    else
      Append(f);
    Writeln(f, Text);
  finally
    CloseFile(f);
  end;
end;

function GetTempCPU:string;
{$IFDEF UNIX}
var
   f : Textfile;
 begin
     AssignFile(f,'/sys/devices/virtual/thermal/thermal_zone0/temp');
   try
     if FileExists('/sys/devices/virtual/thermal/thermal_zone0/temp') = False then
       exit
     else
     begin
       ReSet(f);
     end;
     ReadLn(f,result);
   finally
     CloseFile(f);
   end;
{$ELSE}
begin
result:='0';
{$ENDIF}
end;

function GetBit(x: int64; Num: Byte): Boolean;
begin
  if Num>63 then Exit(False);
  Result := x and (1 shl Num) > 0;
end;

procedure SetBit(var x: int64; Num: Byte);
begin
  x := x or (1 shl Num);
end;

procedure DeleteArrayIndex(var X: TArrayMySmsSend; Index: Integer);
var
  i:integer;
begin
  if Index > High(X) then Exit;
  if Index < Low(X) then Exit;
  if Index = High(X) then
  begin
    SetLength(X, Length(X) - 1);
    Exit;
  end;
  for i:=Index to High(X)-1 do
    X[i]:=X[i+1];
  SetLength(X, Length(X) - 1);
end;

procedure DeleteArrayIndex(var X: TArrayMySqlZapros; Index: Integer);overload;
var
  i:integer;
begin
  if Index > High(X) then Exit;
  if Index < Low(X) then Exit;
  if Index = High(X) then
  begin
    SetLength(X, Length(X) - 1);
    Exit;
  end;
  for i:=Index to High(X)-1 do
    X[i]:=X[i+1];
  SetLength(X, Length(X) - 1);
end;

function Pos(a,b:string;c:cardinal):integer;overload;
begin
  result:=PosEx(a,b,c);
end;

function TimeDMYHMS():string;
begin
  result:=FormatDateTime('dd-mm-yy hh:nn:ss',Now());
end;

function TimeDMYHM():string;
begin
  result:=FormatDateTime('dd-mm-yy hh:nn',Now());
end;

function TimeYMDHM():string;
begin
  result:=FormatDateTime('yy-mm-dd hh:nn:ss',Now());
end;

function TimeYMDHM(a:tdatetime):string;
begin
  result:=FormatDateTime('yy-mm-dd hh:nn:ss',a);
end;

function TimeHM():string;
begin
  result:=FormatDateTime('hh:nn',Now());
end;

function TimeHMS():string;
begin
  result:=FormatDateTime('hh:nn:ss',Now());
end;

function TimeDMY():string;
begin
  result:=FormatDateTime('hh:nn',Now());
end;

function PORTSTATE2Str(b:byte): string;
begin
result:='UKN';
case b of
 0:exit('PORT_WAIT');
 1:exit('PORT_CREATE');
 2:exit('PORT_WORK');
 3:exit('PORT_RESTART');
255:exit('PORT_EXIT');
end;
end;

function MODEMSTATE2Str(b:byte): string;
begin
result:='UKN';
case b of
0:exit('MODEM_NULL');
1:exit('MODEM_AS_ATE0');
2:exit('MODEM_AR_ATE0');
3:exit('MODEM_AS_CGSN');
4:exit('MODEM_AR_CGSN');
5:exit('MODEM_AS_ATI');
6:exit('MODEM_AR_ATI');
7:exit('MODEM_AS_CMEE');
8:exit('MODEM_AR_CMEE');
9:exit('MODEM_AS_CMGF');
10:exit('MODEM_AR_CMGF');
11:exit('MODEM_AS_CPIN');
12:exit('MODEM_AR_CPIN');
13:exit('MODEM_AS_ICC');
14:exit('MODEM_AR_ICC');
15:exit('MODEM_AS_CREG');
16:exit('MODEM_AR_CREG');
17:exit('MODEM_AS_COPS');
18:exit('MODEM_AR_COPS');
19:exit('MODEM_AS_CPAS');
20:exit('MODEM_AR_CPAS');
21:exit('MODEM_AS_CSQ');
22:exit('MODEM_AR_CSQ');
23:exit('MODEM_AS_CNMI');
24:exit('MODEM_AR_CNMI');
25:exit('MODEM_AS_CSCA');
26:exit('MODEM_AR_CSCA');
27:exit('MODEM_AS_CPMS');
28:exit('MODEM_AR_CPMS');
29:exit('MODEM_AS_CMGL');
30:exit('MODEM_AR_CMGL');
100:exit('MODEM_MAIN_WHILE');
101:exit('MODEM_AS_DELETEMSG');
102:exit('MODEM_AS_WHATSAPP');
103:exit('MODEM_SMS_SEND_NEEDACCEPT');
104:exit('MODEM_SMS_SEND_WAITACCEPT');
254:exit('MODEM_WAIT_WHILE');
255:exit('MODEM_ERROR');
end;
end;

procedure DeleteArrayIndex(var X: TArrayofMySmsinFile; Index: Integer);
var
  i:integer;
begin
  if Index > High(X) then Exit;
  if Index < Low(X) then Exit;
  if Index = High(X) then
  begin
    SetLength(X, Length(X) - 1);
    Exit;
  end;
  for i:=Index to High(X)-1 do
    X[i]:=X[i+1];
  SetLength(X, Length(X) - 1);
end;

procedure DeleteArrayIndex(var X: TArraysmstosend; Index: Integer);
var
  i:integer;
begin
  if Index > High(X) then Exit;
  if Index < Low(X) then Exit;
  if Index = High(X) then
  begin
    SetLength(X, Length(X) - 1);
    Exit;
  end;
  for i:=Index to High(X)-1 do
    X[i]:=X[i+1];
  SetLength(X, Length(X) - 1);
end;

procedure DeleteArrayIndex(var X: TArrayString; Index: Integer);overload;
var
  i:integer;
begin
  if Index > High(X) then Exit;
  if Index < Low(X) then Exit;
  if Index = High(X) then
  begin
    SetLength(X, Length(X) - 1);
    Exit;
  end;
  for i:=Index to High(X)-1 do
    X[i]:=X[i+1];
  SetLength(X, Length(X) - 1);
end;

function HashB(S: AnsiString; LenHash: Integer = 256): AnsiString;
const Alphabet: AnsiString='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,-./:;<=>?@^_';
    AlphabetLength=84;
var
  I,j: Integer;
  m:  record
       case Cardinal of
        0: (moaX: array[0..4] of Cardinal);
        1: (b: array[0..5*4-1] of byte);
       end;
  function moaRandomLongWord: LongWord;
  var
    S: Int64;
    Xn: LongWord;
  begin
    S:=2111111111 * Int64(m.moaX[0]) +
      1492 * Int64(m.moaX[1]) +
      1776 * Int64(m.moaX[2]) +
      5115 * Int64(m.moaX[3]) +
      Int64(m.moaX[4]);
    m.moaX[4]:=LongWord(S shr 32);
    Xn:=LongWord(S);
    m.moaX[0]:=m.moaX[1];
    m.moaX[1]:=m.moaX[2];
    m.moaX[2]:=m.moaX[3];
    m.moaX[3]:=Xn;
    Result:=Xn;
  end;
begin
  for I := 0 to 19 do begin
    m.b[i]:=7;
  end;
  j:=0;
  for I := 1 to Length(s) do begin
    m.b[j]:=m.b[j] xor Byte(s[i]);
    inc(j);
    if j>19 then
      j:=0;
  end;
  SetLength(Result, LenHash);
  for I := 1 to LenHash do begin
    Result[i]:=AnsiChar(Alphabet[moaRandomLongWord mod AlphabetLength+1]);
  end;
end;

function DateTimeToUnix(ConvDate: TDateTime): Longint;
const
  UnixStartDate: TDateTime = 25569.0;
begin
Result := Round((ConvDate - UnixStartDate) * 86400);
end;

function UnixToDateTime(USec: Longint): TDateTime;
const
  UnixStartDate: TDateTime = 25569.0;
begin
Result := (Usec / 86400) + UnixStartDate;
end;

function ItNoLatin(s:string):Boolean;
var
  i:Integer;
begin
  result:=false;
  for i := 1 to Length(s) do
  try
    StrToInt('$'+s[i]);
  except
    on Exception : EConvertError do begin
      result:=true;
      exit;
    end;
  end;
end;

function USSDResponse(s:string):string;
var
  b:ansistring;
begin
  b:=UTF8ToAnsi(s);
  result:='';
  if (Pos('+CUSD: 1',b)<>0) OR (Pos('+CUSD: 2',b)<>0) then
    result:=Copy(b,Pos('"',b)+1,PosEx('"',b,Pos('"',b)+1)-(Pos('"',b)+1));
  if Pos('+CUSD: 0',b)<>0 then begin
    Delete(b,1,Pos('+CUSD: 0,80',b)+11);
    result:=Copy(b,1,Pos(',',b)-1);
  end;
  if ItNoLatin(result)=false then
    result:=UCSToAnsi(result);
end;

function UCSToAnsi(s:string):string;
  function FMT(C:string):string;
  var
     i:integer;
  begin
   i := StrToIntDef('$'+C,33);
   {$IFDEF windows}
   if i=$0A then
    begin
    Result := UnicodeToUTF8(13)+UnicodeToUTF8(10);
    exit;
    end;
   {$ENDIF}
   {case i of
    8470: i := $b9;
    1040..1103: i := i - 848;
    1105      : i := 184;
   end;  }
   Result := UnicodeToUTF8(i);
  end;
var
  C:integer;
  I:integer;
begin
  Result := '';
  C := Length(S) div 4;
  For i:=0 to C-1 do
  begin
    Result := Result + FMT(Copy(S,i*4+1,4));
  end;
end;

function myswaptime(const s:string):string;
begin
result:=Copy(s,7,2)+'-'+Copy(s,4,2)+'-'+Copy(s,1,2)+' '+Copy(s,10,2)+':'+Copy(s,13,2);
end;

function MyReadByteS2(var s:string; k:integer):string;
var
i:integer;
begin
result:='';
for i := 0 to k-1 do
begin
  result:=result+s[2]+s[1]+':';
  Delete(s,1,2);
end;
end;

function Bit7tostring2(t:string):string;
var
i:integer;
Pos,bit:integer;
a,b:array of byte;
begin
SetLength(b,Length(t) div 2);
for I := 0 to High(b) do
b[i]:=Strtoint('$'+t[(i*2)+1]+t[(i*2)+2]);
SetLength(a,trunc((Length(b)*8)/7));
pos:=0;
bit:=0;
result:='';
for i := 0 to High(a) do
begin
if bit=8 then
  bit:=0;
if bit<>0 then
  a[i]:=b[pos-1] shr (8-bit);

a[i]:=a[i] or (b[pos] shl bit);
a[i]:=a[i] and $7f;
if (bit <> 7) then
  inc(pos);
inc(bit);
if a[i]=$0 then
  a[i]:=$40;
if a[i]=$11 then
  a[i]:=$5F;
result:=result+chr(a[i]);
end;
end;

function Bit7tostring2(t:string;l,k:integer):string;
var
i:integer;
Pos,bit:integer;
a,b:array of byte;
begin
SetLength(b,Length(t) div 2);
for I := 0 to High(b) do
  begin
    try
    b[i]:=Strtoint('$'+t[(i*2)+1]+t[(i*2)+2]);
    except
      on E : Exception do

    end;
  end;
pos:=0;
bit:=k;
if (bit=0)or(bit=7) then
  SetLength(a,l)
else
  SetLength(a,l+1);
result:='';
for i := 0 to High(a) do
begin
if bit=8 then
bit:=0;
if (bit<>0)and(i<>0) then
a[i]:=b[pos-1] shr (8-bit);
a[i]:=a[i] or (b[pos] shl bit);
a[i]:=a[i] and $7f;
if (bit <> 7) then
inc(pos);
inc(bit);
if a[i]=$0 then
  a[i]:=$40;
if a[i]=$11 then
  a[i]:=$5F;
result:=result+chr(a[i]);
end;
end;

function Ceil(const X: Extended): Integer;
begin
  Result := Integer(Trunc(X));
  if Frac(X) > 0 then
    Inc(Result);
end;

function MyFormatNomer(const s:string):string;
var
i:integer;
t:string;
begin
  t:=s;
  result:='';
  for I := 1 to Length(s) div 2 do
  begin
  result:=result+t[i*2]+t[i*2-1];
  end;
  if Result[Length(Result)]='F' then
  SetLength(Result,Length(Result)-1);
end;

function MyReadByte(var s:string):Byte;
begin
result:=$FF;
try
result:=StrToInt('$'+s[1]+s[2]);
Delete(s,1,2);
except
on E : Exception do
  //WriteConsole('MyReadByte(error):#'+IntToHex(Ord(s[1]),2)+IntToHex(Ord(s[2]),2));
end;
end;

function MyReadByteS(var s:string; k:integer):string;
var
i:integer;
begin
result:='';
for i := 0 to k-1 do
begin
  if length(s)<2 then exit;
  result:=result+s[1]+s[2];
  Delete(s,1,2);
end;
end;

function Str2NomerSmS(s:string):integer;
begin
result:=-1;
if Pos('+CMTI: ',s)<>0 then
  result:=StrToInt(Copy(s,Pos(',',s)+1,PosEx(#10,s,Pos(',',s))-(Pos(',',s)+1)));
end;

function GetSmSService(s:string):string;
begin
result:='error state';
if Pos('+CSCA',s)=0 then
exit;
if Pos('"',s)<>0 then
result:=StringReplace(Copy(s,Pos('"',s)+1,PosEx('"',s,Pos('"',s)+1)-(Pos('"',s)+1)),'+','',[rfReplaceAll]);
end;

function Str2UrovenSignala(s:string):string;
begin
result:='';
if Pos('+CSQ: ',s)<>0 then
result:=Copy(s,Pos('+CSQ: ',s)+6,PosEx(#10,s,Pos('+CSQ: ',s))-(Pos('+CSQ: ',s)+6));
end;

function CLIP2Nomer(const st: string): string;
var
  s: string;
begin
  result := 'error';
  s := st;
  if Pos('"',s)=0 then exit;
  Delete(s, 1, Pos('"',s));
  if Pos('"',s)=0 then exit;
  Delete(s, Pos('"',s), Length(s)-Pos('"',s));
  result := s;
end;

function Str2GotovLiModem(s:string):integer;
begin
  result:=-1;
  if Pos('+CPAS: ',s)<>0 then
    result:=StrToInt(Copy(s,Pos('+CPAS: ',s)+7,1))
end;

function GetStatePin(t:string):string;
var
s:string;
begin
result:='';
if Pos('+CPIN',t)=0 then
exit;
s:=Copy(t,Pos('+CPIN',t)+7,Pos(#10,t,Pos('+CPIN',t)+7)-(Pos('+CPIN',t)+7));
result:=s;//Copy(s,8,Length(s)-7);
end;

function CutCodeInSms(sms, rexp: string): string;
var
  r : TRegExpr;
begin
  result := '';
  r := TRegExpr.Create;
  r.Expression := rexp;
  if r.Exec(StringReplace(StringReplace(sms,' ','',[rfreplaceall]),'-','',[rfreplaceall])) then begin
    result := r.Match[0];
  end
  else begin

  end;
  r.Free
end;

function HTTPGetMainTable(c: integer): string;
var
  i : integer;
begin
  result := '';
  for i:= 0 to c-1 do begin
    result += '<tr id="'+inttostr(i)+'"><td><div>'+Format('%2d',[i+1])+'</div></td><td><div class="nomer">Не_Определен</div></td><td><div class="state alert-danger">0</div></td><td><div class="sb_slot"></div></td></tr>';
  end;
end;

function GetNumber(const s: string): string;
var
  i: integer;
begin
  result := '';
  for i := 1 to length(s) do
    if s[i] in ['0'..'9'] then
      result := result + s[i];
end;

end.
