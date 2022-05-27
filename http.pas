unit http;

{$mode objfpc}{$H+}

interface

uses
  Classes, blcksock, Synsock, Synautil, synacode, SysUtils, lazutf8, jsonparser, fpjson, myfunctions, httpsend, RegExpr, strutils;

type
  CommandAndArgument = array of string;

  TTCPHttpDaemon = class(TThread)
  private
    Sock: TTCPBlockSocket;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute; override;
  end;

  { TTCPHttpThrd }

  TTCPHttpThrd = class(TThread)
  private
    Sock: TTCPBlockSocket;
    function GetMainTable(s: string): string;
    function GetSendMemo(i: integer): string;
    function GetRecvMemo(i: integer): string;
    function GetSmsMemo(i: integer): string;
    function Jsonmainmemo(const a, b, c, d, e, f: integer; const g: string):string;
    function Jsongetport(const a: integer): string;
    function ExecutePostData(const url, Data: string): string;
    function ExecuteGetData(url: string): string;
    function SendAllData(url, Data: string): string;
    function Str2httpcommand(const uri: string): TStringList;
    function mygetDecode(const s: string): string;
    function getlistports(): string;
    function getlistportsimei(): string;
    function getlistportsnomera(): string;
    function setlistports(const s: string): boolean;
    function setlistportsnomera(const s: string): boolean;
    function Filter_memo(const s,c: string): string;
  public
    Headers: TStringList;
    InputData, OutputData: TMemoryStream;
    constructor Create(hsock: tSocket);
    destructor Destroy; override;
    procedure Execute; override;
    function ProcessHttpRequest(const Request, URI, Data: string): integer;
  end;

function httphash(s: string): integer;

implementation

uses
  maind, portcons, Process, modemunit;

function httphash(s: string): integer;
var
  p: PChar;
  unicode: cardinal;
  CPLen: integer;
begin
  CPLen := 1;
  unicode := 1;
  Result := 0;
  if (Length(s) = 0) then
    exit;

  p := PChar(s);
  while ((CPLen <> 0) and (unicode <> 0)) do
  begin
    unicode := UTF8CharacterToUnicode(p, CPLen);
    if ((($30 <= unicode) and (unicode <= $39)) or (($410 <= unicode) and (unicode <= $44F)) or (($61 <= unicode) and (unicode <= $7A)) or
      (($41 <= unicode) and (unicode <= $5A))) then
      Result := ((Result shl 5) - Result) + unicode;
    Inc(p, CPLen);
  end;
end;

function TTCPHttpThrd.ExecutePostData(const url, Data: string): string;
var
  d: TStringList;
  i, j: integer;
  t: string;
  b: boolean;
begin
  Result := '{"result":"error"}';
  d := TStringList.Create;
  try
    d.Text := StringReplace(Data, '&', #13, [rfreplaceall]);
    case url of
      '/debug/sendsms':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        t := DecodeURL(d.Values['id']);
        while (t<>'') do
        begin
          if (Pos(',',t)<>0) then
          begin
            AM[StrToInt(Copy(t,1,Pos(',',t)-1)) - 1].OnSms(TimeDMYHM(), DecodeURL(ReplaceString(d.Values['otkogo'], '+', '%20')), DecodeURL(ReplaceString(d.Values['text'], '+', '%20')));
            Delete(t,1,Pos(',',t));
          end
          else
          begin
            AM[StrToInt(t) - 1].OnSms(TimeDMYHM(), DecodeURL(ReplaceString(d.Values['otkogo'], '+', '%20')), DecodeURL(ReplaceString(d.Values['text'], '+', '%20')));
            t := '';
          end;
        end;
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Отправил.</p></body>';
      end;
      '/config/filter':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        starter.DB_servicefilter_save(DecodeURL(ReplaceString(d.Values['val'], '+', '%20')));
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Обновил.</p></body>';
      end;
      '/config/triggers':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        starter.DB_triggers_save(DecodeURL(ReplaceString(d.Values['val'], '+', '%20')));
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Обновил.</p></body>';
      end;
      '/config/iin':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        starter.iinsl.Text := DecodeURL(ReplaceString(d.Values['val'], '+', '%20'));
        starter.iinslcount := 1;
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Выполнил.</p></body>';
      end;
      '/config/telegram':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        starter.telegram_bot_id := DecodeURL(ReplaceString(d.Values['token'], '+', '%20'));
        starter.DB_setvalue('telegrambot', starter.telegram_bot_id);
        starter.DB_telegramclient_save(DecodeURL(ReplaceString(d.Values['telegramclients'], '+', '%20')));
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Обновил.</p></body>';
      end;
      '/config/ports':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        if (d.IndexOfName('imei')<>-1) then
        begin
          starter.bindimei := true;
          starter.DB_setvalue('bindimei', 'true');
        end
        else
        begin
          starter.bindimei := false;
          starter.DB_setvalue('bindimei', 'false');
        end;

        if setlistports(DecodeURL(ReplaceString(d.Values['val'], '+', '%20'))) then
          Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Обновил.</p></body>'
        else
          Result := '<head><meta http-equiv="refresh" content="5;URL="' + url +
            '" /></head><body><p>Ошибка, неверное количество портов.</p></body>';
        starter.DB_setvalue('ignore', DecodeURL(ReplaceString(d.Values['ignoreval'], '+', '%20')));
      end;
      '/config/portsnomera':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        setlistportsnomera(DecodeURL(ReplaceString(d.Values['val'], '+', '%20')));
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Обновил.</p></body>';
      end;
      '/config/urlsms':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        starter.urlactivesms := DecodeURL(ReplaceString(d.Values['urlactivesms'], '+', '%20'));
        starter.servername := DecodeURL(ReplaceString(d.Values['servername'], '+', '%20'));
        starter.servercountry := DecodeURL(ReplaceString(d.Values['servercountry'], '+', '%20'));
        starter.DB_setvalue('urlactivesms', starter.urlactivesms);
        starter.DB_setvalue('urldatabasesms', DecodeURL(ReplaceString(d.Values['urldatabasesms'], '+', '%20')));
        starter.DB_setvalue('servername', starter.servername);
        starter.DB_setvalue('servercountry', starter.servercountry);
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Обновил.</p></body>';
      end;
      '/config/delete_services':
      begin
        Headers.Clear;
        Headers.Add('Content-type: Text/Html; charset=utf-8');
        starter.SMSDeleteService2(DecodeURL(ReplaceString(d.Values['id'], '+', '%20')), DecodeURL(ReplaceString(d.Values['service'], '+', '')));
        Result := '<head><meta http-equiv="refresh" content="1;URL="' + url + '" /></head><body><p>Выполнил.</p></body>';
      end;
      '/port/delete_sms':
      begin
        if ((0 <= StrToInt(d.Values['id'])) and (StrToInt(d.Values['id']) <= High(AM))) then
        begin
          AM[StrToInt(d.Values['id'])].SMSHistoryDelete(DecodeURL(ReplaceString(d.Values['time'], '+', '%20')), DecodeURL(ReplaceString(d.Values['otkogo'], '+', '%20')),
          DecodeURL(ReplaceString(d.Values['text'], '+', '%20')));
          Result := '{"cmd":"done"}';
        end;
      end;
      '/port/allreset':
      begin
        for i := 0 to High(AM) do
          AM[i].PORT_STATE := PORT_RESTART;
        Result := '{"cmd":"done"}';
      end;
      '/port/allresetimei':
      begin
        for i := 0 to High(AM) do
          AM[i].Send('AT+EGMR=1,7,"'+AM[i].GetRandomIMEI()+'"');
        Result := '{"cmd":"done"}';
      end;
      '/port/delete_service':
      begin
        starter.SMSDeleteService(DecodeURL(d.Values['id']), DecodeURL(ReplaceString(d.Values['service'], '+', '')));
        Result := '{"cmd":"done"}';
      end;
      '/port/reset':
      begin
        t := DecodeURL(d.Values['id']);
        while (t<>'') do
        begin
          if (Pos(',',t)<>0) then
          begin
            AM[StrToInt(Copy(t,1,Pos(',',t)-1))].PORT_STATE := PORT_RESTART;
            Delete(t,1,Pos(',',t));
          end
          else
          begin
            AM[StrToInt(t)].PORT_STATE := PORT_RESTART;
            t := '';
          end;
        end;
        Result := '{"cmd":"done"}';
      end;
      '/port/zaprosnomera':
      begin
        t := DecodeURL(d.Values['id']);
        while (t<>'') do
        begin
          if (Pos(',',t)<>0) then
          begin
            AM[StrToInt(Copy(t,1,Pos(',',t)-1))].PORT_STATE := PORT_ZAPROS_NOMERA;
            Delete(t,1,Pos(',',t));
          end
          else
          begin
            AM[StrToInt(t)].PORT_STATE := PORT_ZAPROS_NOMERA;
            t := '';
          end;
        end;
        Result := '{"cmd":"done"}';
      end;
      '/port/zaprosnomera2':
      begin
        t := DecodeURL(d.Values['id']);
        while (t<>'') do
        begin
          if (Pos(',',t)<>0) then
          begin
            AM[StrToInt(Copy(t,1,Pos(',',t)-1))].PORT_STATE := PORT_ZAPROS_NOMERA_IZ_SIM;
            Delete(t,1,Pos(',',t));
          end
          else
          begin
            AM[StrToInt(t)].PORT_STATE := PORT_ZAPROS_NOMERA_IZ_SIM;
            t := '';
          end;
        end;
        Result := '{"cmd":"done"}';
      end;
      '/port/setnomer':
      begin
        if ((0 <= StrToInt(d.Values['id'])) and (StrToInt(d.Values['id']) <= High(AM))) then
        begin
          AM[StrToInt(d.Values['id'])-1].SetNomer(DecodeURL(ReplaceString(d.Values['nomer'], '+', '%20')));
          Result := '{"cmd":"done"}';
        end;
      end;

      '/port/activnomera':
      begin
        if ((0 <= StrToInt(d.Values['id'])) and (StrToInt(d.Values['id']) <= High(AM))) then
        begin
          AM[StrToInt(d.Values['id'])].PORT_STATE := PORT_ACTIV_NOMERA;
          Result := '{"cmd":"done"}';
        end;
      end;
      '/port/deactivnomera':
      begin
        if ((0 <= StrToInt(d.Values['id'])) and (StrToInt(d.Values['id']) <= High(AM))) then
        begin
          AM[StrToInt(d.Values['id'])].PORT_STATE := PORT_DEACTIV_NOMERA;
          Result := '{"cmd":"done"}';
        end;
      end;
      '/port/sendatcmd':
      begin
        if ((0 <= StrToInt(d.Values['id'])) and (StrToInt(d.Values['id']) <= High(AM))) then
        begin
          AM[StrToInt(d.Values['id'])].Send(mygetDecode(d.Values['cmd']));
          Result := '{"cmd":"done"}';
        end;
      end;
      '/port/sendsms':
      begin
        t := mygetDecode(d.Values['id']);
        repeat
          if (Pos(',', t) <> 0) then
          begin
            if ((0 <= StrToInt(Copy(t, 1, Pos(',', t) - 1))) and (StrToInt(Copy(t, 1, Pos(',', t) - 1)) <= High(AM))) then
              AM[StrToInt(Copy(t, 1, Pos(',', t) - 1))].AddToSendSms(DecodeURL(d.Values['nomer']), DecodeURL(d.Values['text']));
            Delete(t, 1, Pos(',', t));
          end
          else
          begin
            AM[StrToInt(t)].AddToSendSms(DecodeURL(d.Values['nomer']), DecodeURL(d.Values['text']));
            t := '';
          end;
        until t = '';
        Result := '{"cmd":"done"}';
      end;
      '/port/all_sendsms':
      begin
        for i := 0 to High(AM) do
          AM[i].AddToSendSms(DecodeURL(d.Values['nomer']), DecodeURL(d.Values['text']));
        Result := '{"cmd":"done"}';
      end;
      '/port/all_sendsms_noreg':
      begin
        for i := 0 to High(AM) do
        begin
          b := True;
          for j := 0 to High(AM[i].smshistory) do
            if (starter.SMSCheckService('ig', AM[i].smshistory[j].otkogo, AM[i].smshistory[j].Text) <> '') then
              b := False;
          if (b) then
            AM[i].AddToSendSms(DecodeURL(d.Values['nomer']), DecodeURL(d.Values['text']));
        end;
        Result := '{"cmd":"done"}';
      end;
      '/port/sendsms_ponomeru':
      begin
        Result := '{"cmd":"not found"}';
        for i := 0 to High(AM) do
          if (AM[i].nomer = DecodeURL(d.Values['id'])) then
          begin
            AM[i].AddToSendSms(DecodeURL(d.Values['nomer']), DecodeURL(d.Values['text']));
            Result := '{"cmd":"done"}';
          end;
      end;
      '/port/sendsms_ponomeru_long_poll':
      begin
        Result := '{"cmd":"not found"}';
        for i := 0 to High(AM) do
          if (AM[i].nomer = DecodeURL(d.Values['id'])) then
          begin
            case AM[i].SendSms_timeout(DecodeURL(d.Values['nomer']), DecodeURL(d.Values['text'])) of
            -1:exit('{"cmd":"error"}');
             0:exit('{"cmd":"error"}');
             1:exit('{"cmd":"done"}');
            else
              exit('{"cmd":"error"}');
            end;
          end;
      end;
      '/port/neopredelensendatcmd':
      begin
        for i := 0 to High(AM) do
        begin
          if (AM[i].nomer = Nomer_Neopredelen) then
            AM[StrToInt(d.Values['id'])].Send(mygetDecode(d.Values['cmd']));
          Result := '{"cmd":"done"}';
        end;
      end;
      '/port/allsendatcmd':
      begin
        for i := 0 to High(AM) do
        begin
          AM[StrToInt(d.Values['id'])].Send(mygetDecode(d.Values['cmd']));
          Result := '{"cmd":"done"}';
        end;
      end;
      '/port/allzapros':
      begin
        for i := 0 to High(AM) do
          AM[i].PORT_STATE := PORT_ZAPROS_NOMERA;
        Result := '{"cmd":"done"}';
      end;
      '/port/neopredelenzapros':
      begin
        for i := 0 to High(AM) do
          if (AM[i].nomer = Nomer_Neopredelen) then
            AM[i].PORT_STATE := PORT_ZAPROS_NOMERA;
        Result := '{"cmd":"done"}';
      end;
      '/get/mainmemo':
        Result := Jsonmainmemo(StrToInt(d.Values['mainmemo']), StrToInt(d.Values['sendmemo']), StrToInt(d.Values['recvmemo']),
          StrToInt(d.Values['smsmemo']), StrToInt(d.Values['maintable']), StrToInt(d.Values['port']), DecodeURL(d.Values['filter']));
      '/get/port':
        Result := Jsongetport(StrToInt(d.Values['id']));
      '/main/exit':
      begin
        serverwork := False;
      end;
      '/main/restart':
      begin
        Result := '{"cmd":"done"}';
        try
          {$IFDEF UNIX}
          with TProcess.Create(nil) do
          begin
            Executable := '/home/user/one.sh';
            Parameters.Add('');
            Execute;
            Free;
          end;
          {$ELSE}
            start_self();
          {$ENDIF}
        except
          on E: Exception do
            Result := '{"cmd":"error","info":"' + E.ClassName + ':' + E.Message + '"}';
        end;
        serverwork := False;
      end;
      '/main/rebootsystem':
      begin
        Result := '{"cmd":"done"}';
        try
          {$IFDEF UNIX}
          with TProcess.Create(nil) do
          begin
            Executable := '/sbin/reboot';
            Parameters.Add('');
            Execute;
            Free;
          end;
          {$ELSE}

          {$ENDIF}
        except
          on E: Exception do
            Result := '{"cmd":"error","info":"' + E.ClassName + ':' + E.Message + '"}';
        end;
      end;
      '/main/memoclear':
      begin
        MainmemoCS.Enter;
        try
          mainmemo.Clear;
        finally
          MainmemoCS.Leave;
        end;
        Result := '{"cmd":"done"}';

      end;
      '/starter/setbasa':
      begin
        Result := Data;
      end;
    end;
  finally
    d.Free;
  end;
end;

function TTCPHttpThrd.ExecuteGetData(url: string): string;
var
  i, k: integer;
  J: TJSONObject;
  tnomer, code: string;
begin
  J := TJSONObject.Create;
  try
    case Str2httpcommand(url).ValueFromIndex[1] of
      'alldata':
      begin
        for i := 0 to High(AM) do
          J.Add(IntToStr(i + 1), AM[i].nomer);
        J.Add('result', 'done');
      end;
      'sendalldata':
      begin
        for i := 0 to High(AM) do
          J.Add(IntToStr(i + 1), AM[i].nomer);
        J.Add('result', 'done');
        SendAllData('http://192.168.1.1/loadsms.php', J.FormatJSON);
      end;

      'exit':
      begin
        serverwork := False;
        J.Add('result', 'done');
      end;
      'state':
      begin
        Result := '';
        for i := 0 to High(AM) do
        begin
          Result := Result + 'MS:' + IntToStr(AM[i].MODEM_STATE) + ' PS:' + IntToStr(byte(AM[i].PORT_STATE)) + '<cr>';
        end;
        J.Add('result', Result);
      end;
      'get_sms2service':
      begin
        result := 'error';
        tnomer := DecodeURL(Str2httpcommand(url).Values['nomer']);
        for i := 0 to High(AM) do
          if (AM[i]<>nil) then
            if (AM[i].nomer=tnomer) then
            begin
              for k:=High(AM[i].smshistory) downto 0 do
              begin
                code := starter.SMSCheckService(DecodeURL(Str2httpcommand(url).Values['service']),AM[i].smshistory[k].otkogo,AM[i].smshistory[k].text);
                if code<>'' then
                begin
                  J.Add('code', code);
                  break;
                end;
              end;
              result := 'done';
            end;
        J.Add('result', Result);
      end;
    end;
    Result := J.FormatJSON;
  finally
    j.Free;
  end;

end;

function TTCPHttpThrd.SendAllData(url, Data: string): string;
var
  HTTP: THTTPSend;
begin
  Result := '';
  HTTP := THTTPSend.Create;
  HTTP.Sock.ConnectionTimeout := 5000;
  try
    WriteStrToStream(HTTP.Document, Data);
    HTTP.MimeType := 'application/json';
    if HTTP.HTTPMethod('POST', url) then
    begin
      SetLength(Result, HTTP.Document.Size);
      HTTP.Document.ReadBuffer(Result[1], HTTP.Document.Size);
    end;
  finally
    HTTP.Free;
  end;
end;

function TTCPHttpThrd.Str2httpcommand(const uri: string): TStringList;
var
  s, temp: string;
  c: word;
begin
  s := uri;
  Result := TStringList.Create;
  c := 0;
  while Pos('/', s) <> 0 do
  begin
    Delete(s, 1, Pos('/', s));
    if Pos('/', s) = 0 then
      break;
    Result.Values[IntToStr(c)] := mygetDecode(Copy(s, 1, Pos('/', s) - 1));
    Inc(c);
  end;
  if Pos('?', s) = 0 then
  begin
    Result.Values['document'] := mygetDecode(s);
    exit;
  end
  else
  begin
    Result.Values['document'] := mygetDecode(Copy(s, 1, Pos('?', s) - 1));
    Delete(s, 1, Pos('?', s));
  end;

  while Length(s) <> 0 do
  begin
    if Pos('&', s) <> 0 then
    begin
      temp := Copy(s, 1, Pos('&', s) - 1);
      Delete(s, 1, Pos('&', s));
    end
    else
    begin
      temp := s;
      s := '';
    end;

    if Pos('=', temp) <> 0 then
      Result.Values[mygetDecode(Copy(temp, 1, Pos('=', temp) - 1))] := mygetDecode(Copy(temp, Pos('=', temp) + 1, Length(temp) - Pos('=', temp)));
  end;
end;

function TTCPHttpThrd.mygetDecode(const s: string): string;
var
  i: integer;
begin
  Result := s;
  i := Pos('%', Result);
  while i <> 0 do
  begin
    Result := StringReplace(Result, Copy(Result, i, 3), Chr(StrToInt('$' + Copy(Result, i + 1, 2))), [rfreplaceall]);
    i := Pos('%', Result);
  end;
end;

function TTCPHttpThrd.getlistports(): string;
var
  i: integer;
  t: TStringList;
begin
  Result := '';
  t := TStringList.Create;
  try
    for i := 0 to High(AM) do
      t.Add(AM[i].scom);
    Result := t.Text;
  finally
    t.Free;
  end;
end;

function TTCPHttpThrd.getlistportsimei(): string;
var
  i: integer;
  t: TStringList;
begin
  Result := '';
  t := TStringList.Create;
  try
    for i := 0 to High(AM) do
      t.Add(AM[i].scom+':'+AM[i].imei);
    Result := t.Text;
  finally
    t.Free;
  end;
end;

function TTCPHttpThrd.getlistportsnomera(): string;
var
  i: integer;
  t: TStringList;
begin
  Result := '';
  t := TStringList.Create;
  try
    for i := 0 to High(AM) do
      t.Add(IntToStr(i+1)+'='+AM[i].nomer);
    Result := t.Text;
  finally
    t.Free;
  end;
end;

function TTCPHttpThrd.setlistports(const s: string): boolean;
var
  i, j: integer;
  t: TStringList;
begin
  Result := True;
  t := TStringList.Create;
  try
    t.Text := s;
    if (t.Count <> Length(AM)) then
      exit(False);
    for i := 0 to t.Count - 1 do
      for j := 0 to High(AM) do
        if (t.Strings[i] = AM[j].scom) then
        begin
          starter.SwapThread(i, j);
          if starter.bindimei=false then
            starter.DB_setvalue(t.Strings[i], IntToStr(i));
          AM[j].SaveToDb();
          AM[i].SaveToDb(True);
        end;
  finally
    t.Free;
  end;
end;

function TTCPHttpThrd.setlistportsnomera(const s: string): boolean;
var
  i: integer;
  t: TStringList;
begin
  Result := True;
  t := TStringList.Create;
  try
    t.Text := s;
    for i := 0 to t.Count - 1 do
    begin
      if (AM[StrToInt(t.Names[i])-1].nomer<>t.ValueFromIndex[i]) then
        AM[StrToInt(t.Names[i])-1].SetNomer(t.ValueFromIndex[i]);
    end;
  finally
    t.Free;
  end;
end;

function TTCPHttpThrd.Filter_memo(const s,c: string): string;
var
  st, st2: TStringList;
  i: integer;
  s2: string;
begin
  if (c='') then
    exit(s);
  result := '';

  st := TStringList.Create;
  st2:= TStringList.Create;
  st.Text := s;
  for i:=0 to st.Count-1 do
  begin
    s2 := starter.SMSCheckService(c, st.Strings[i], st.Strings[i]);
    if (s2<>'') then
      st2.Add(st.Strings[i]);
  end;
  result := st2.Text;
  st.Free;
  st2.Free;
end;

constructor TTCPHttpDaemon.Create;
begin
  inherited Create(False);
  sock := TTCPBlockSocket.Create;
  FreeOnTerminate := True;
end;

destructor TTCPHttpDaemon.Destroy;
begin
  Sock.Free;
  inherited Destroy;
end;

procedure TTCPHttpDaemon.Execute;
var
  ClientSock: TSocket;
begin
  with sock do
  begin
    while (True) do
    begin
      CreateSocket;
      setLinger(True, 10000);
      bind('0.0.0.0', '80');
      listen;

      if (GetLocalSinPort = 80) then
        break;
      sleep(500);
      sock.CloseSocket;
      sleep(500);
    end;
    MainMemoWrite('HTTP запущен.');
    repeat
      if terminated then
        break;
      if canread(1000) then
      begin
        ClientSock := accept;
        if lastError = 0 then
          TTCPHttpThrd.Create(ClientSock);
      end;
    until serverwork=false;
    CloseSocket();
  end;
end;

{ TTCPHttpThrd }

function TTCPHttpThrd.GetMainTable(s: string): string;
var
  i, j: integer;
  b: boolean;
begin
  if (s='') then
    s := 'aa';
  Result := '{';
  for j := 0 to High(AM) do
  begin
    Result += '"' + IntToStr(j) + '":[';
    Result += '"' + AM[j].nomer + '",';
    Result += '"' + IntToStr(AM[j].MODEM_STATE) + '",';
    b := False;
    for i := 0 to High(AM[j].smshistory) do
      if (starter.SMSCheckService(s, AM[j].smshistory[i].otkogo, AM[j].smshistory[i].Text) <> '') then
      begin
        b := True;
        break;
      end;
    if (b) then
      Result += '"0"],'
    else
      Result += '"1"],';
  end;
  Result[Length(Result)] := '}';//заменяем запятую
end;

function TTCPHttpThrd.GetSendMemo(i: integer): string;
begin
  Result := '';
  if (i = -1) then
    exit;
  AM[i]._cs.Enter;
  try
    Result := AM[i]._SendText.Text;
  finally
    AM[i]._cs.Leave;
  end;
end;

function TTCPHttpThrd.GetRecvMemo(i: integer): string;
begin
  Result := '';
  if (i = -1) then
    exit;
  AM[i]._cs.Enter;
  try
    Result := AM[i]._RecvText.Text;
  finally
    AM[i]._cs.Leave;
  end;
end;

function TTCPHttpThrd.GetSmsMemo(i: integer): string;
begin
  Result := '';
  if (i = -1) then
    exit;
  AM[i]._cs.Enter;
  try
    Result := AM[i]._SmsText.Text + #13#10 + AM[i].RecvText;
  finally
    AM[i]._cs.Leave;
  end;
end;

function TTCPHttpThrd.Jsonmainmemo(const a, b, c, d, e, f: integer; const g: string): string;
var
  J: TJSONObject;
  s: string;
begin
  try
  J := TJSONObject.Create;
  s := Filter_memo(mainmemo.Text, g);
  if (a <> httphash(s)) then
    J.Add('mainmemo', s)
  else
    J.Add('mainmemo', 0);

  if (b <> httphash(GetSendMemo(f))) then
    J.Add('sendmemo', GetSendMemo(f))
  else
    J.Add('sendmemo', 0);

  if (c <> httphash(GetRecvMemo(f))) then
    J.Add('recvmemo', GetRecvMemo(f))
  else
    J.Add('recvmemo', 0);

  if (d <> httphash(GetSmsMemo(f))) then
    J.Add('smsmemo', GetSmsMemo(f))
  else
    J.Add('smsmemo', 0);

  if (e <> httphash(GetMainTable(g))) then
    J.Add('maintable', GetMainTable(g))
  else
    J.Add('maintable', 0);
  Result := J.FormatJSON;
  FreeAndNil(J);
  except
    on E : Exception do
      DebugLog('Jsonmainmemo:' + E.ClassName+' : '+E.Message);
  end;
end;

function TTCPHttpThrd.Jsongetport(const a: integer): string;
var
  i: integer;
begin
  with TJSONObject.Create do
    try
      Arrays['history'] := CreateJSONArray([]);
      //if (Length(AM[a].smshistory) < 25) then
      //  lowar := 0
      //else
      //  lowar := Length(AM[a].smshistory) - 25;
      for i := High(AM[a].smshistory) downto 0 do
        Arrays['history'].Add(CreateJSONArray([AM[a].smshistory[i].otkogo, AM[a].smshistory[i].datetime, AM[a].smshistory[i].Text]));
      Strings['result'] := 'done';
      Result := FormatJSON([foSingleLineArray, foSkipWhiteSpace]);
    finally
      Free;
    end;
end;

constructor TTCPHttpThrd.Create(hsock: tSocket);
begin
  sock := TTCPBlockSocket.Create;
  Headers := TStringList.Create;
  InputData := TMemoryStream.Create;
  OutputData := TMemoryStream.Create;
  Sock.socket := HSock;
  FreeOnTerminate := True;
  Priority := tpNormal;
  inherited Create(False);
end;

destructor TTCPHttpThrd.Destroy;
begin
  Sock.Free;
  Headers.Free;
  InputData.Free;
  OutputData.Free;
  inherited Destroy;
end;

procedure TTCPHttpThrd.Execute;
var
  timeout: integer;
  s: string;
  method, uri, protocol, Data: string;
  size: integer;
  x, n, i: integer;
  resultcode: integer;
  Close: boolean;
  buff: array of byte;
begin
  timeout := 10000;
  repeat
    //read request line
    if serverwork=false then
      exit;
    s := sock.RecvString(timeout);
    if sock.lasterror <> 0 then
      Exit;
    if s = '' then
      Exit;
    method := fetch(s, ' ');
    if (s = '') or (method = '') then
      Exit;
    uri := fetch(s, ' ');
    if uri = '' then
      Exit;
    protocol := fetch(s, ' ');
    headers.Clear;
    size := -1;
    Close := False;
    //read request headers
    if protocol <> '' then
    begin
      if pos('HTTP/', protocol) <> 1 then
        Exit;
      if pos('HTTP/1.1', protocol) <> 1 then
        Close := True;
      repeat
        s := sock.RecvString(Timeout);
        if sock.lasterror <> 0 then
          Exit;
        if s <> '' then
          Headers.add(s);
        if Pos('CONTENT-LENGTH:', Uppercase(s)) = 1 then
          Size := StrToIntDef(SeparateRight(s, ' '), -1);
        if Pos('CONNECTION: CLOSE', Uppercase(s)) = 1 then
          Close := True;
      until s = '';
    end;
    //recv document...
    InputData.Clear;
    Data := '';
    if size >= 0 then
    begin
      InputData.SetSize(Size);
      x := Sock.RecvBufferEx(InputData.Memory, Size, Timeout);
      InputData.SetSize(x);
      SetLength(buff, x);
      InputData.ReadBuffer(buff[0], x);
      for i := 0 to x - 1 do
        Data := Data + Chr(buff[i]);
      if sock.lasterror <> 0 then
        Exit;
    end;
    OutputData.Clear;
    ResultCode := ProcessHttpRequest(method, uri, Data);
    sock.SendString(protocol + ' ' + IntToStr(ResultCode) + CRLF);
    if protocol <> '' then
    begin
      headers.Add('Content-length: ' + IntToStr(OutputData.Size));
      if Close then
        headers.Add('Connection: close');
      headers.Add('Date: ' + Rfc822DateTime(now));
      headers.Add('Server: Synapse HTTP server');
      headers.Add('');
      for n := 0 to headers.Count - 1 do
        sock.sendstring(headers[n] + CRLF);
    end;
    if sock.lasterror <> 0 then
      Exit;
    Sock.SendBuffer(OutputData.Memory, OutputData.Size);
    if Close then
      Break;
  until (Sock.LastError <> 0);
end;

function TTCPHttpThrd.ProcessHttpRequest(const Request, URI, Data: string): integer;
var
  l: TStringList;
  tstring: string;
  ts: string;
  i: integer;
begin
  Result := 504;
  try
    //LogiFile(Request+':'+URI+':'+data);
    if request = 'GET' then
    begin
      if URI = '/' then
      begin
        headers.Clear;
        headers.Add('Content-type: Text/Html; charset=utf-8');
        l := TStringList.Create;
        try
          l.LoadFromFile(extractfilepath(ParamStr(0)) + 'index.html');
          l.Text := StringReplace(l.Text, '_PROGRAM_NAME_', PROGRAM_NAME, [rfReplaceAll]);
          l.Text := StringReplace(l.Text, '_MAIN_TABLE_TAG_', HTTPGetMainTable(SimPort + 1), [rfReplaceAll]);
          l.SaveToStream(OutputData);
        finally
          l.Free;
        end;
      end;
      if URI = '/getmainmemo' then
      begin
        headers.Clear;
        headers.Add('Content-type: Text/Html; charset=utf-8');
        l := TStringList.Create;
        try
          l.Text := mainmemo.Text;
          l.SaveToStream(OutputData);
        finally
          l.Free;
        end;
      end;
      case Str2httpcommand(URI).ValueFromIndex[0] of
        'debug':
        begin
          headers.Clear;
          headers.Add('Content-type: Text/Html; charset=utf-8');
          l := TStringList.Create;
          try
            l.Text := 'done';
            case Str2httpcommand(URI).ValueFromIndex[1] of
              'sendsms':
              begin
                ts := '';
                tstring := DecodeURL(Str2httpcommand(URI).Values['id']);
                while (tstring<>'') do
                begin
                  if (Pos(',',tstring)<>0) then
                  begin
                    i := StrToInt(Copy(tstring,1,Pos(',',tstring)-1))+1;
                    Delete(tstring,1,Pos(',',tstring));
                    if (ts='') then
                      ts := IntToStr(i)
                    else
                      ts := ts + ','+IntToStr(i);
                  end
                  else
                  begin
                    i := StrToInt(tstring)+1;
                    tstring := '';
                    if (ts='') then
                      ts := IntToStr(i)
                    else
                      ts := ts + ','+IntToStr(i);
                  end;
                end;
                if (ts='') then
                  ts := '1';

                l.Text :=
                  '<form action="/debug/sendsms" method="post"><table width="200px" height="auto"><tr><td><input type="text" name="id" value="'+ts+'"></td>' +
                  '<td><input type="text" name="otkogo" value="+79876543210"></td><td><input type="submit" value="Отправить"></td></tr><tr><td colspan="3">'
                  +
                  '<textarea rows="5" cols="40" name="text">Тестовая смс</textarea></td></tr></form></td></tr></table>';
              end;
            end;

            l.SaveToStream(OutputData);
          finally
            l.Free;
          end;
        end;
        'config':
        begin
          headers.Clear;
          headers.Add('Content-type: Text/Html; charset=utf-8');
          l := TStringList.Create;
          try
            l.Text := 'uknow';
            case Str2httpcommand(URI).ValueFromIndex[1] of
              'filter': l.Text := '<form action="/config/filter" method="post"><textarea rows="15" cols="45" name="val">' +
                  starter.DB_servicefilter_text() + '</textarea><input type="submit" value="Сохранить"></form>';
              'triggers': l.Text := '<form action="/config/triggers" method="post"><p style="margin-bottom: 0px;margin-top: 0px;">OTKOGO:TEXT:=KOMU:TEXT</p><p style="margin-bottom: 0px;margin-top: 0px;">OTKOGO:TEXT:=reset</p><textarea rows="14" cols="45" name="val">' +
                  starter.DB_triggers_text() + '</textarea><input type="submit" value="Сохранить"></form>';
              'iin': l.Text := '<form action="/config/iin" method="post"><p style="margin-bottom: 0px;margin-top: 0px;">Список:</p><textarea rows="15" cols="80" name="val"></textarea><input type="submit" value="Выполнить"></form>';
              'telegram': l.Text :=
                  '<form action="/config/telegram" method="post"><p style="margin-bottom: 0px;margin-top: 0px;">Токет бота:</p><textarea rows="5" cols="50" name="token">' +
                  starter.DB_getvalue('telegrambot') +
                  '</textarea><p style="margin-bottom: 0px;margin-top: 0px;">Телеграм клиенты:</p><textarea rows="5" cols="50" name="telegramclients">' +
                  starter.DB_telegramclient_text() + '</textarea><input type="submit" value="Сохранить"></form>';
              'ports': l.Text := '<form action="/config/ports" method="post"><textarea rows="10" cols="50" name="val">' +
                  getlistports() + '</textarea><br><input type="checkbox" '+ifthen(starter.bindimei, 'checked ', '')+'name="imei" value="1">Привязать по IMEI<br><p style="margin-bottom: 0px;margin-top: 0px;">Игнорировать порты:</p><textarea rows="2" cols="50" name="ignoreval">' +
                  starter.DB_getvalue('ignore') + '</textarea><input type="submit" value="Сохранить"></form>';
              'portsimei': l.Text := '<form action="/config/portsimei" method="post"><textarea rows="15" cols="80" name="val">' +
                  getlistportsimei() + '</textarea></form>';
              'portsnomera': l.Text := '<form action="/config/portsnomera" method="post"><textarea rows="15" cols="50" name="val">' +
                  getlistportsnomera() + '</textarea><input type="submit" value="Сохранить"></form>';
              'urlsms': l.Text := '<html><head><meta http-equiv="content-type" content="text/html; charset=UTF-8"></head><body><form action="/config/urlsms" method="post">'+
                          '<p style="margin-bottom: 0px;margin-top: 0px;">Имя сервера:</p><input type="text" size="60" name="servername" value="' + starter.servername + '">'+
                          '<p style="margin-bottom: 0px;margin-top: 0px;">Страна сим карт(ru\uk\kz)</p><input type="text" size="60" name="servercountry" value="' + starter.servercountry + '">'+
                          '<p style="margin-bottom: 0px;margin-top: 0px;">URL активации:</p><input type="text" size="60" name="urlactivesms" value="' + starter.urlactivesms + '">'+
                          '<p style="margin-bottom: 0px;margin-top: 0px;">База данных (user:password@hostname:port):</p><input type="text" size="60" name="urldatabasesms" value="' + starter.DB_getvalue('urldatabasesms') + '"><br>'+
                          '<input type="submit" value="Сохранить"></form></body></html>';
              'delete_services':
              begin
              ts := '';
                for i:=Low(AM) to High(AM) do
                  if (ts='') then
                    ts := IntToStr(i+1)
                  else
                    ts := ts + ','+IntToStr(i+1);
                l.Text :=
                  '<form action="/config/delete_services" method="post"><p style="margin-bottom: 0px;margin-top: 0px;">Номера портов(пример: 1,5,7):</p><textarea rows="3" cols="50" name="id">'
                  + ts + '</textarea><p style="margin-bottom: 0px;margin-top: 0px;">Сервисы(пример: vk,ok):</p><textarea rows="3" cols="50" name="service">ig'
                  + '</textarea><input type="submit" value="Выполнить"></form>';
              end;
              'nomera':
              begin
                  with TJSONObject.Create do
                    try
                      Arrays['nomera'] := CreateJSONArray([]);
                      for i := 0 to High(AM) do
                      begin
                        if (AM[i].nomer = Nomer_Neopredelen) or (AM[i].nomer = data_neopredelen) or (AM[i].operatorNomer = SIM_UNKNOWN) then
                          continue;
                        ts := starter.SMSCheckAllService(i);
                          if (Pos('aa',ts)=0) then
                          continue;
                        Arrays['nomera'].Add(AM[i].nomer);
                      end;

                      headers.Clear;
                      headers.Add('Content-type: application/json');
                      l.Text := FormatJSON([foSingleLineArray, foSkipWhiteSpace]);
                    finally
                      Free;
                    end;
              end;
            end;
            l.SaveToStream(OutputData);
          finally
            l.Free;
          end;
        end;
        'starter':
        begin
          headers.Clear;
          headers.Add('Content-Type:application/json; charset=utf-8');
          l := TStringList.Create;
          try
            l.Text := ExecuteGetData(URI);
            l.SaveToStream(OutputData);
          finally
            l.Free;
          end;
        end;
      end;

      if (Pos('.js', URI) <> 0) or (Pos('.css', URI) <> 0) then
      begin
        headers.Clear;
        if (Pos('.js', URI) <> 0) then
          headers.Add('Content-Type: application/javascript');
        if (Pos('.css', URI) <> 0) then
          headers.Add('Content-Type: text/css');
        tstring := URI;
        Delete(tstring, 1, 1);
        StringReplace(tstring, '/', _DIROS, [rfreplaceall]);
        if (FileExists(extractfilepath(ParamStr(0)) + URI)) then
          OutputData.LoadFromFile(extractfilepath(ParamStr(0)) + URI);
      end;
      Result := 200;
    end;

    if request = 'POST' then
    begin
      headers.Clear;
      headers.Add('Content-Type:application/json; charset=utf-8');
      l := TStringList.Create;
      try
        l.Text := ExecutePostData(URI, Data);
        l.SaveToStream(OutputData);
      finally
        l.Free;
      end;
      Result := 200;
    end;

  except
    on E: Exception do
      LogiFile(E.ClassName + ' поднята ошибка, с сообщением : ' + E.Message);
  end;
end;

end.
