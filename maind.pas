unit maind;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}BaseUnix,{$ELSE}{$ENDIF}Classes, SysUtils, starterunit, syncobjs, myfunctions, modemunit, portcons, LazUtf8, RegExpr, httpsend;

procedure dMain();
procedure MainMemoWrite(const a: string; i: integer = -1);

const
  PROGRAM_NAME = 'SIMHUBDAEMON';

var
  timestart: string;
  i, pid: integer;
  daempath: string;
  debugmode: boolean;

  MainmemoCS: TCriticalSection;
  mainmemo: TStringList;

  Last10sms: array of array of string;
  AM: array of TMyModem;

  starter: TMyStarter = nil;
  starterwork: boolean = True;
  serverwork: boolean = True;
  SimPort: integer = 0;

  tempansi: ansistring;

implementation

function CloseAnother():boolean;
var
  HTTP: THTTPSend;
begin
  HTTP := THTTPSend.Create;
  HTTP.Sock.ConnectionTimeout := 500;
  try
    Result := HTTP.HTTPMethod('GET', 'http://127.0.0.1/starter/exit');
    if Result then
      sleep(2500);
  finally
    HTTP.Free;
  end;
end;

procedure WriteConsole(const s: string);
begin
  writeln(s);
end;

procedure Init();
begin
  //TCriticalSection
  MainmemoCS := TCriticalSection.Create();
  //TStringList
  mainmemo := TStringList.Create;

  daempath := ExtractFileDir(ParamStr(0)) + _DIROS;
  debugmode := False;
end;

procedure Deinit();
begin
  mainmemo.Free;
  MainmemoCS.Free;
end;

procedure dMain();
var
  Text, exp, res: string;
begin
  if ParamStr(1) = 'exp' then
    while (True) do
    begin
      writeln(UTF8ToConsole('Введите текст:'));
      readln(Text);
      writeln(UTF8ToConsole('Введите выражение:'));
      readln(exp);
      writeln(UTF8UpperCase(Text) + ':' + UTF8UpperCase(exp));
      if ExecRegExpr(UTF8UpperCase(exp), UTF8UpperCase (Text)) = False then
        res := 'Совпадений нет :'
      else
        res := 'Совпадение есть:';
      if CutCodeInSms(Text, exp) = '' then
        res := res + 'Не найдено.'
      else
        res := res + CutCodeInSms(Text, exp);
      writeln(UTF8ToConsole(res));
    end;
  CloseAnother();
  timestart := TimeDMYHM();
  Init();
  pid := GetProcessID;
  debugmode := True;

  Starter := TMyStarter.Create;
  while serverwork do
    sleep(50);

  while starterwork do
    sleep(50);
  for i := Low(AM) to High(AM) do
    AM[i].Terminate;
  Deinit();
end;

procedure MainMemoWrite(const a: string; i: integer);
begin
  MainmemoCS.Enter;
  try
    if i <> -1 then
    begin
      if (AM[i].nomer <> Nomer_Neopredelen) then
        MainMemo.Add(TimeHM + ':' + '[' + AM[i].nomer + '] ' + a)
      else
        MainMemo.Add(TimeHM + ':' + '[' + AM[i].nomer + '][' + IntToStr(AM[i].idthread + 1) + '] ' + a);
      if debugmode then
        writeln(TimeHM + ':' + IntToStr(i + 1) + UTF8ToConsole(a));
    end
    else
    begin
      MainMemo.Add(TimeHM + ':' + a);
      if debugmode then
        writeln(TimeHM + ':' + UTF8ToConsole(a));
    end;
  finally
    MainmemoCS.Leave;
  end;
end;

end.
