unit maind;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}BaseUnix,{$ELSE}windows,{$ENDIF}Classes, SysUtils, starterunit, syncobjs, myfunctions, modemunit, portcons, LazUtf8, RegExpr, HTTPSend, synautil, ssl_openssl;


procedure dMain();
function checkupdate():boolean;
procedure update_index_script();
procedure MainMemoWrite(const a: string; i: integer = -1);

const
  PROGRAM_NAME = 'SIMHUBDAEMON';
  version = 137;

var
  timestart: string;
  daempath: string;
  debugmode: boolean;
  debugsms: boolean;
  reboot_after_freeze: boolean = true;
  MainmemoCS: TCriticalSection;
  mainmemo: TStringList;

  Last10sms: array of array of string;
  AM: array of TMyModem;
  starter: TMyStarter = nil;
  MySimBank: TMySimBank = nil;
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
  randomize;
  //TCriticalSection
  MainmemoCS := TCriticalSection.Create();
  //TStringList
  mainmemo := TStringList.Create;
  randomize;
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
  Mutex: THandle;
  i: integer;
begin
  writeln('v', version);
  if FileExists(extractfilepath(paramstr(0))+'upd.bat') then
  begin
    update_index_script();
    DeleteFile(extractfilepath(paramstr(0))+'upd.bat');
  end;
  if ParamStr(1) <> 'ignore' then
    if checkupdate() then
      exit;
  if ParamStr(1) = 'debug' then
  begin
    writeln('Debug sms');
    debugsms := true;
  end
  else
    debugsms := false;

  if ParamStr(1) = 'noreboot' then
  begin
    writeln('noreboot');
    reboot_after_freeze := false;
  end;

  debugmode := true;

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
  if ParamStr(1) = 'ussd' then
    while (True) do
    begin
      writeln(UTF8ToConsole('Введите текст:'));
      readln(Text);
      writeln('USSD:'+USSDResponse(Text));
      writeln('UCS:'+UCSToAnsi(Text));

    end;

  CloseAnother();

  {$IFDEF UNIX}

  {$ELSE}
    i := 5;
    if reboot_after_freeze then
      while (true) do
      begin
        Mutex:=CreateMutex(nil,True,'SIMHUB3DAEMON');
        if GetLastError=0 then
          break
        else
          writeln('error close');

        if (i=0) then
        begin
          writeln('Reboot after 15 sec');
          sleep(15000);
          debuglog('reboot');
          reboot();
        end;
        dec(i);
        sleep(1000);
      end;
  {$ENDIF}


  timestart := TimeDMYHM();
  Init();

  Starter := TMyStarter.Create;
  while serverwork do
    sleep(50);

  while starterwork do
    sleep(50);
  for i := Low(AM) to High(AM) do
    AM[i].Terminate;
  sleep(100);
  Deinit();
  {$IFDEF UNIX}

  {$ELSE}
  if reboot_after_freeze then
    ReleaseMutex(Mutex);
  {$ENDIF}

end;

function checkupdate():boolean;
var
  M: TMemoryStream;
  HTTP: THTTPSend;
  res: boolean;
  s: string;
  v: integer;
  i: integer;
begin
  result := false;
  {$IFDEF UNIX}
  exit;
  {$ELSE}
  HTTP := THTTPSend.Create;
  try
    res := HTTP.HTTPMethod('GET', 'https://raw.githubusercontent.com/jongame/simhub3d/main/version.txt');
    if res then
    begin
      s := ReadStrFromStream(HTTP.Document, HTTP.Document.Size);
      v := StrToInt(Copy(s, 1, Pos('=', s)-1));
      Delete(s, 1, Pos('=', s));
      if (v>version) then
      begin
        writeln(UTF8ToConsole('Обновление..'));
        writeln(UTF8ToConsole(s));
        sleep(1000);
        M := TMemoryStream.Create;
        try
          HTTP.Clear;
          res := HTTP.HTTPMethod('GET', s);
          if (HTTP.ResultCode=302) then
          begin
            for i:=0 to HTTP.Headers.Count-1 do
              if Pos('Location', HTTP.Headers.Strings[i])<>0 then
              begin
                s := HTTP.Headers.Strings[i];
                Delete(s, 1, Pos('https', s)-1);
                HTTP.Clear;
                res := HTTP.HTTPMethod('GET', s);
                break;
              end;
          end;
          if (res) then
          begin
            M.CopyFrom(HTTP.Document, 0);
            M.SaveToFile(extractfilepath(paramstr(0))+'upd'+IntToStr(v)+'.exe');
            ForceDirectories(extractfilepath(paramstr(0))+'backup');
            DeleteFile(extractfilepath(paramstr(0))+'upd.bat');
            TextToFile('timeout 5 > nul', extractfilepath(paramstr(0))+'upd.bat');
            TextToFile('move "'+ paramstr(0) + '" "' + extractfilepath(paramstr(0))+'backup\simhub3d'+IntToStr(version)+'.exe"', extractfilepath(paramstr(0))+'upd.bat');
            TextToFile('move "'+ extractfilepath(paramstr(0))+'upd'+IntToStr(v)+'.exe" "' + paramstr(0) + '"', extractfilepath(paramstr(0))+'upd.bat');
            TextToFile('start /d "' + extractfilepath(paramstr(0)) + '" simhub3d.exe '+ paramstr(0), extractfilepath(paramstr(0))+'upd.bat');
            ShellExecute(0, PChar ('open'), PChar('cmd'), PChar('/c '+extractfilepath(paramstr(0))+'upd.bat'), nil, SW_NORMAL);
            //sleep(500);
            result := true;
          end;
        finally
          M.Free;
        end;
      end;
    end
    else
    writeln('error check update');
  finally
    HTTP.Free;
  end;
  {$ENDIF}
end;

procedure update_index_script;
var
  M: TMemoryStream;
  HTTP: THTTPSend;
  res: boolean;
  s: string;
  i: integer;
begin
  {$IFDEF UNIX}
  exit;
  {$ELSE}
  HTTP := THTTPSend.Create;
  try
    writeln(UTF8ToConsole('Обновление index.html и script.js'));
    M := TMemoryStream.Create;
    try
      res := HTTP.HTTPMethod('GET', 'https://raw.githubusercontent.com/jongame/simhub3d/main/complete/index.html');
      if (HTTP.ResultCode=302) then
      begin
        for i:=0 to HTTP.Headers.Count-1 do
          if Pos('Location', HTTP.Headers.Strings[i])<>0 then
          begin
            s := HTTP.Headers.Strings[i];
            Delete(s, 1, Pos('https', s)-1);
            HTTP.Clear;
            res := HTTP.HTTPMethod('GET', s);
            break;
          end;
      end;
      if (res) then
      begin
        M.CopyFrom(HTTP.Document, 0);
        M.SaveToFile(extractfilepath(paramstr(0))+'index.html');
      end;

      M.Clear;
      HTTP.Clear;
      res := HTTP.HTTPMethod('GET', 'https://raw.githubusercontent.com/jongame/simhub3d/main/complete/script.js');
      if (HTTP.ResultCode=302) then
      begin
        for i:=0 to HTTP.Headers.Count-1 do
          if Pos('Location', HTTP.Headers.Strings[i])<>0 then
          begin
            s := HTTP.Headers.Strings[i];
            Delete(s, 1, Pos('https', s)-1);
            HTTP.Clear;
            res := HTTP.HTTPMethod('GET', s);
            break;
          end;
      end;
      if (res) then
      begin
        M.CopyFrom(HTTP.Document, 0);
        M.SaveToFile(extractfilepath(paramstr(0))+'script.js');
      end;
    finally
      M.Free;
    end;
  finally
    HTTP.Free;
  end;
  writeln(UTF8ToConsole('+'));
  {$ENDIF}
end;

procedure MainMemoWrite(const a: string; i: integer);
begin
  MainmemoCS.Enter;
  try
    if i <> -1 then
    begin
      if (AM[i].nomer <> Nomer_Neopredelen) then
        MainMemo.Add(TimeHM + ':' + '[' + AM[i].nomer + '][' + IntToStr(AM[i].idthread + 1) + '] ' + a)
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
