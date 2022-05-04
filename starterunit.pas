unit starterunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lazutf8, portcons, myfunctions, syncobjs, HTTPSend, synautil, synacode, RegExpr,
 {$IFDEF UNIX}

 {$ELSE}
  Registry,
 {$ENDIF}
  Process, ssl_openssl, http, ZConnection, ZDataset, fpjson;

type

  { TMyStarter }

  TMyStarter = class(TThread)
  private
    dbq: TZQuery;
    dbc: TZConnection;
    counteractivationid: integer;
    lastcheckhash: string;
    arrayofsmstosend: TArraysmstosend;
    //arrayofactivation: TArrayofACTIVATION_OBJECT;
    arrayoffilteractivation: array[0..63] of TArrayofMyServiceSms;
    arraytelegramclients: array of MyTelegramCLient;
    arrayoftriggers: array of MyTrigger;
    _cs: TCriticalSection;

    function LoadSerialPorts(): TStringList;
    procedure ShowError(s: string);
    procedure ShowInfo(s: string; _modemid: integer = -1);
    function _RSTAGESTARTER: integer;
    procedure _WSTAGESTARTER(const Value: integer);
    function SendSMSToServer(url, Data: string): string;
    procedure SendNomeraToServer();
    procedure CheckSendSMS();
    function DB_open(): boolean;
    procedure DB_fix();
    procedure DB_close();
  public
    drawbox: boolean;
    _stagestarter: integer;
    telegram_bot_id: string;
    servername, urlactivesms: string;
    property stagestarter: integer read _RSTAGESTARTER write _WSTAGESTARTER default 0;
    procedure SwapThread(a, b: integer);
    procedure Telegram_SendSMS(const sl,n, t: string);
    procedure Telegram_Send(const telega, Text: string);
    procedure AddToSendSms(nomer, otkogo, Text, date: string);
    procedure AddToActivateNomer(nomer, opera, state: string);
    procedure SMSDeleteService(const ids, service: string);
    procedure SMSDeleteService2(const ids, service: string);
    function SMSCheckService(const service, otkogo, Text: string): string;
    function SMSCheckAllService(const n: integer): string;
    function SMSCheckTriggers(const ot, text: string):string;
    procedure DB_addsms(nomer, datetime, otkogo, Text: string);
    procedure DB_deletesms(nomer, datetime, otkogo, Text: string);overload;
    procedure DB_deletesms(id: integer);overload;
    procedure DB_loadsms(idthread: integer);

    procedure DB_triggers_load();
    procedure DB_triggers_save(const val: string);
    function DB_triggers_text: string;

    procedure DB_servicefilter_load();
    procedure DB_servicefilter_save(const s: string);
    function DB_servicefilter_text: string;

    procedure DB_telegramclient_load();
    procedure DB_telegramclient_save(const s: string);
    function DB_telegramclient_text(): string;

    function DB_getvalue(key: string): string;
    procedure DB_setvalue(key, Value: string);
    constructor Create;
    destructor Destroy; override;
  protected
    procedure StartALL();
    procedure Execute; override;
  end;

implementation

uses
  maind, modemunit;

procedure TMyStarter.StartALL();
var
  i: integer;
  SerialPorts: TStringList;
begin

  SerialPorts := LoadSerialPorts();
  ShowInfo('Портов:' + IntToStr(SerialPorts.Count));
  if SerialPorts.Count = 0 then
  begin
    ShowInfo('Serial Port не найдены.');
    exit;
  end;

  serverwork := True;
  SimPort := SerialPorts.Count - 1;
  SetLength(Last10sms, SimPort + 1);
  SetLength(AM, SimPort + 1);
  telegram_bot_id := DB_getvalue('telegrambot');
  urlactivesms := DB_getvalue('urlactivesms');
  servername := DB_getvalue('servername');
  for i := 0 to High(AM) do
    AM[i] := nil;

  for i := 0 to High(AM) do
  begin
    AM[i] := TMyModem.Create(i);
    AM[i].scom := SerialPorts[i];
  end;
end;

function TMyStarter.SMSCheckService(const service, otkogo, Text: string): string;
var
  serv: string;
  i, j: integer;
begin
  Result := '';
  serv := StringReplace(service, ' ', '', [rfreplaceall]);
  if (serv='') then exit();
  repeat
    if (Pos(',', serv) <> 0) then
    begin
      j := TagServiceToIntActivation(Copy(serv, 1, Pos(',', serv) - 1));
      Delete(serv, 1, Pos(',', serv));
      if (j = -1) then
        continue;
    end
    else
    begin
      j := TagServiceToIntActivation(serv);
      if (j = -1) then
        exit;
      serv := '';
    end;
    if Length(arrayoffilteractivation[j]) = 0 then
      exit;
    for i := 0 to High(arrayoffilteractivation[j]) do
    begin
      if (arrayoffilteractivation[j][i].otkogo <> '')AND(otkogo<>'') then
        if (ExecRegExpr(arrayoffilteractivation[j][i].otkogo, otkogo) = False) then
          continue;
      if (arrayoffilteractivation[j][i].textsms <> '')AND(Text<>'') then
        if (ExecRegExpr(arrayoffilteractivation[j][i].textsms, Text) = False) then
          continue;
      if (arrayoffilteractivation[j][i].cutsms = '') then
      begin
        exit(Text);
      end
      else
      begin
        if (Text <> '') then
          exit(CutCodeInSms(Text, arrayoffilteractivation[j][i].cutsms));
      end;
    end;
  until serv = '';
end;

function TMyStarter.SMSCheckAllService(const n: integer): string;
var
  i, j: integer;
begin
  Result := '';
  for j := 0 to High(arrayoffilteractivation) do
  begin
    for i := 0 to High(AM[n].smshistory) do
    begin
      if (SMSCheckService(IntToTagServiceActivation(j), AM[n].smshistory[i].otkogo, AM[n].smshistory[i].Text) <> '') then
      begin
        if (Result = '') then
          Result := IntToTagServiceActivation(j)
        else
          Result := Result + ',' + IntToTagServiceActivation(j);
        break;
      end;
    end;
  end;
end;

function TMyStarter.SMSCheckTriggers(const ot, text: string): string;
var
  i: integer;
begin
  result := '';
  if (ot='') OR (text='') then
    exit;
  for i := 0 to High(arrayoftriggers) do
  begin
    if (arrayoftriggers[i].input.otkogo <> '')AND(ot<>'') then
      if (ExecRegExpr(arrayoftriggers[i].input.otkogo, ot) = False) then
        continue;
    if (arrayoftriggers[i].input.textsms <> '')AND(text<>'') then
      if (ExecRegExpr(arrayoftriggers[i].input.textsms, text) = False) then
        continue;
    exit(arrayoftriggers[i].output);
  end;
end;

procedure TMyStarter.DB_addsms(nomer, datetime, otkogo, Text: string);
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'INSERT INTO "sms" ("nomer", "datetime", "otkogo", "text") VALUES (:nomer, :datetime, :otkogo, :text);';
    dbq.ParamByName('nomer').AsString := nomer;
    dbq.ParamByName('datetime').AsString := datetime;
    dbq.ParamByName('otkogo').AsString := otkogo;
    dbq.ParamByName('text').AsString := Text;
    dbq.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_deletesms(nomer, datetime, otkogo, Text: string);
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'DELETE FROM "sms" WHERE ("nomer"=:nomer)AND("datetime"=:datetime)AND("otkogo"=:otkogo)AND("text"=:text);';
    dbq.ParamByName('nomer').AsString := nomer;
    dbq.ParamByName('datetime').AsString := datetime;
    dbq.ParamByName('otkogo').AsString := otkogo;
    dbq.ParamByName('text').AsString := Text;
    dbq.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_deletesms(id: integer);
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'DELETE FROM "sms" WHERE ("id"=:id);';
    dbq.ParamByName('id').AsString := inttostr(id);
    dbq.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_loadsms(idthread: integer);
var
  i: integer;
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'SELECT * FROM "sms" WHERE "nomer"=''' + AM[idthread].nomer + ''' ORDER BY "id" DESC LIMIT 1000;';
    dbq.Open;
    SetLength(AM[idthread].smshistory, dbq.RecordCount);
    for i := dbq.RecordCount - 1 downto 0 do
    begin
      AM[idthread].smshistory[i].idinbase := dbq.FieldByName('id').AsInteger;
      AM[idthread].smshistory[i].datetime := dbq.FieldByName('datetime').AsString;
      AM[idthread].smshistory[i].otkogo := dbq.FieldByName('otkogo').AsString;
      AM[idthread].smshistory[i].Text := dbq.FieldByName('text').AsString;
      dbq.Next;
    end;
  finally
    dbq.Close;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_triggers_load;
var
  s: string;
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'SELECT * FROM "triggers";';
    dbq.Open;
    while not dbq.EOF do
    begin
      SetLength(arrayoftriggers, Length(arrayoftriggers) + 1);
      s := dbq.FieldByName('input').AsString;
      arrayoftriggers[High(arrayoftriggers)].input.otkogo := Copy(s, 1, Pos(':', s) - 1);
      Delete(s, 1, Pos(':', s));
      arrayoftriggers[High(arrayoftriggers)].input.textsms := Copy(s, 1, Pos(':', s) - 1);
      Delete(s, 1, Pos(':', s));
      arrayoftriggers[High(arrayoftriggers)].input.cutsms := s;
      arrayoftriggers[High(arrayoftriggers)].output := dbq.FieldByName('output').AsString;
      dbq.Next;
    end;
  finally
    dbq.Close;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_triggers_save(const val: string);
var
  i: integer;
  sl: TStringList;
  s: string;
begin
  _cs.Enter;
  sl := TStringList.Create();
  try
    sl.Text := val;
    SetLength(arrayoftriggers, sl.Count);
    for i:=0 to sl.Count-1 do
    begin
      s := sl.Strings[i];
      arrayoftriggers[i].input.otkogo := Copy(s, 1, Pos(':', s) - 1);
      Delete(s, 1, Pos(':', s));
      arrayoftriggers[i].input.textsms := Copy(s, 1, Pos(':', s) - 1);
      Delete(s, 1, Pos(':', s));
      arrayoftriggers[i].input.cutsms := Copy(s, 1, Pos('=', s) - 1);
      Delete(s, 1, Pos('=', s));
      arrayoftriggers[i].output := s;
    end;
    dbq.Close;
    dbq.SQL.Text := 'DELETE FROM "triggers";';
    dbq.ExecSQL;
    for i:=0 to High(arrayoftriggers) do
    begin
      dbq.SQL.Text := 'INSERT OR IGNORE INTO "triggers"("id", "input", "output") VALUES (:id, :input, :output);';
      dbq.ParamByName('id').AsInteger := i + 1;
      dbq.ParamByName('input').AsString := arrayoftriggers[i].input.otkogo + ':' + arrayoftriggers[i].input.textsms + ':' + arrayoftriggers[i].input.cutsms;
      dbq.ParamByName('output').AsString := arrayoftriggers[i].output;
      dbq.ExecSQL;
    end;
  finally
    sl.Free;
    _cs.Leave;
  end;
end;

function TMyStarter.DB_triggers_text: string;
var
  i: integer;
  sl: TStringList;
begin
  result := '';
  sl := TStringList.Create();
  _cs.Enter;
  try
    for i:=0 to High(arrayoftriggers) do
    begin
      sl.Add(arrayoftriggers[i].input.otkogo + ':' + arrayoftriggers[i].input.textsms + ':' + arrayoftriggers[i].input.cutsms+'='+arrayoftriggers[i].output);
    end;
    result := sl.Text;
  finally
    sl.Free;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_servicefilter_load();
var
  i, j: integer;
  t: TStringList;
  s: string;
begin
  _cs.Enter;
  try
    dbq.Close;
    for i := 0 to 18 do
    begin
      dbq.SQL.Text := 'INSERT OR IGNORE INTO "filter_service"("service", "filter") VALUES (:service, :filter);';
      dbq.ParamByName('service').AsString := IntToTagServiceActivation(i);
      dbq.ParamByName('filter').AsString := 'EXAMPLE_OTKOGO:EXAMPLE_TEXT:';
      dbq.ExecSQL;
    end;
  finally
    _cs.Leave;
  end;

  _cs.Enter;
  t := TStringList.Create;
  try
    dbq.Close;
    dbq.SQL.Text := 'SELECT * FROM "filter_service";';
    dbq.Open;
    while not dbq.EOF do
    begin
      t.Text := dbq.FieldByName('filter').AsString;
      if (t.Text='') then
        t.Text := 'EXAMPLE_OTKOGO:EXAMPLE_TEXT:';
      i := TagServiceToIntActivation(dbq.FieldByName('service').AsString);
      if (i <> -1) then
      begin
        SetLength(arrayoffilteractivation[i], t.Count);
        for j := 0 to t.Count - 1 do
        begin
          s := t.Strings[j];
          arrayoffilteractivation[i, j].otkogo := Copy(s, 1, Pos(':', s) - 1);
          Delete(s, 1, Pos(':', s));
          arrayoffilteractivation[i, j].textsms := Copy(s, 1, Pos(':', s) - 1);
          Delete(s, 1, Pos(':', s));
          arrayoffilteractivation[i, j].cutsms := s;
        end;
      end;
      dbq.Next;
    end;
  finally
    dbq.Close;
    t.Free;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_servicefilter_save(const s: string);
var
  i, j: integer;
  temp_string: string;
  t, t2: TStringList;
begin
  _cs.Enter;
  t := TStringList.Create;
  t.Text := s;
  t2 := TStringList.Create;
  try
    for i := 0 to High(arrayoffilteractivation) do
    begin
      if (Length(arrayoffilteractivation[i])=0) then
        continue;
      t2.Text := '';
      t2.Add('EXAMPLE_OTKOGO:EXAMPLE_TEXT:');
      for j := 0 to t.Count - 1 do
        if (IntToTagServiceActivation(i) = t.Names[j]) then
        begin
          temp_string := t.Strings[j];
          if (Pos('EXAMPLE_OTKOGO:EXAMPLE_TEXT:', temp_string)<>0) then
            continue;
          Delete(temp_string, 1, Pos('=', temp_string));
          t2.Add(temp_string);
        end;
      dbq.SQL.Text := 'UPDATE "filter_service" SET "filter" = :filter WHERE "service" = :service;';
      dbq.ParamByName('service').AsString := IntToTagServiceActivation(i);
      dbq.ParamByName('filter').AsString := t2.Text;
      dbq.ExecSQL;
    end;
  finally
    t.Free;
    t2.Free;
    _cs.Leave;
  end;
  DB_servicefilter_load();
end;

function TMyStarter.DB_servicefilter_text: string;
var
  i, j: integer;
  t: TStringList;
begin
  Result := '';
  t := TStringList.Create;
  _cs.Enter;
  try
    for i := 0 to High(arrayoffilteractivation) do
      for j := 0 to High(arrayoffilteractivation[i]) do
      begin
        t.add(IntToTagServiceActivation(i) + '=' + arrayoffilteractivation[i, j].otkogo + ':' + arrayoffilteractivation[i, j].textsms +
          ':' + arrayoffilteractivation[i, j].cutsms);
      end;
    Result := t.Text;
  finally
    t.Free;
    _cs.Leave;
  end;
end;

function TMyStarter._RSTAGESTARTER: integer;
begin
  _cs.Enter;
  try
    Result := _stagestarter;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter._WSTAGESTARTER(const Value: integer);
begin
  _cs.Enter;
  try
    _stagestarter := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyStarter.SendSMSToServer(url, Data: string): string;
var
  HTTP: THTTPSend;
begin

  Result := '';
  HTTP := THTTPSend.Create;
  HTTP.Sock.ConnectionTimeout := 2500;
  try
    try
      WriteStrToStream(HTTP.Document, Data);
      HTTP.MimeType := 'application/x-www-form-urlencoded';
      if HTTP.HTTPMethod('POST', url) then
      begin
         SetLength(Result, HTTP.Document.Size);
         HTTP.Document.ReadBuffer(Result[1], HTTP.Document.Size);
      end;
    except
      on E : Exception do
        debuglog('SendSMSToServer:'+E.ClassName+' : '+E.Message);
    end;
    debuglog('SendSMSToServer:'+IntToStr(HTTP.ResultCode)+' : '+url+' : '+Data);
  finally
    HTTP.Free;
  end;
end;

procedure TMyStarter.SendNomeraToServer();
var
  s,t: string;
  i: integer;
begin
  if (urlactivesms = '') then
    exit;
  s := '';
  with TJSONObject.Create do
    try
      Strings['servername'] := servername;
      Integers['port_count'] := Length(AM);
      for i := 0 to High(AM) do
      begin
        if (AM[i].MODEM_STATE <> MODEM_MAIN_WHILE) or (AM[i].nomer = Nomer_Neopredelen) or (AM[i].nomer = data_neopredelen) or (AM[i].operatorNomer = SIM_UNKNOWN) then
          continue;
        if (AM[i].statesim <> 1) AND (AM[i].statesim <> 5) then
          continue;
        t := SMSCheckAllService(i);
        Arrays[AM[i].nomer] := CreateJSONArray([operator_names_to_activate[AM[i].operatorNomer],t,i+1]);
      end;
      s := FormatJSON(AsCompressedJSON);
    finally
      Free;
    end;
  if SendSMSToServer(urlactivesms, s) <> 'ok' then
    debuglog('Ошибка отправки на сервер. Сервер не сказал ok.');
end;

procedure TMyStarter.CheckSendSMS();
var
  temp: smstosend;
  postdata: ansistring;
begin
  while True do
  begin
    _cs.Enter;
    try
      if (Length(arrayofsmstosend) = 0) then
        exit;
      temp := arrayofsmstosend[0];
    finally
      _cs.Leave;
    end;
    case temp.typesnd of
      1:
      begin
        with TJSONObject.Create do
          try
            Strings['nomer'] := temp.nomer;
            Strings['otkogo'] := temp.otkogo;
            Strings['text'] := temp.Text;
            Strings['time'] := temp.date;
            postdata := FormatJSON(AsCompressedJSON);
          finally
            Free;
          end;
        if (urlactivesms <> '') then
          if (SendSMSToServer(urlactivesms, postdata) <> 'ok') then
            exit; //Отправка не удалась, выходим
      end;
      2:
      begin
        with TJSONObject.Create do
          try
            Strings['service'] := temp.date;
            Strings['nomer'] := temp.nomer;
            Strings['code'] := temp.otkogo;
            Strings['text'] := temp.Text;
            postdata := FormatJSON(AsCompressedJSON);
          finally
            Free;
          end;
        if (urlactivesms <> '') then
          if (SendSMSToServer(urlactivesms, postdata) <> 'ok') then
            exit; //Отправка не удалась, выходим
      end;
    end;
    //Значит успешно отправили смс или команду на активацию или деактивацию, удаляем первый элемент очереди
    _cs.Enter;
    try
      DeleteArrayIndex(arrayofsmstosend, 0);
    finally
      _cs.Leave;
    end;
  end;
end;

function TMyStarter.DB_open(): boolean;
var
  stage: byte;
begin
  stage := 0;
  Result := False;
  dbc := TZConnection.Create(nil);
  dbq := TZQuery.Create(nil);
  dbc.Database := extractfilepath(ParamStr(0)) + 'data.db';
  dbc.Protocol := 'sqlite-3';
  dbq.Connection := dbc;
  try
    if (not FileExists(extractfilepath(ParamStr(0)) + 'data.db')) then
    begin //Создаём таблицы
      dbq.SQL.Text := 'CREATE TABLE "keyvalue" ("key"  TEXT NOT NULL, "value"  TEXT, PRIMARY KEY ("key"));';
      dbq.ExecSQL;
      dbq.SQL.Text :=
        'CREATE TABLE "sms" ("id"  INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL DEFAULT 0, "nomer"  TEXT(16) NOT NULL, "datetime"  TEXT, "otkogo"  TEXT, "text"  TEXT);';
      dbq.ExecSQL;
      dbq.SQL.Text := 'CREATE INDEX "n" ON "sms" ("nomer" ASC);';
      dbq.ExecSQL;
      DB_setvalue('ignore', '');
      DB_setvalue('urlactivesms', '');
      DB_setvalue('servername', 'new server');
    end;
    dbq.SQL.Text := 'CREATE TABLE IF NOT EXISTS "telegram" ("id" INTEGER PRIMARY KEY AUTOINCREMENT,"idtelegram" TEXT,"service" TEXT,UNIQUE ("idtelegram" ASC));';
    dbq.ExecSQL;
    dbq.SQL.Text := 'CREATE TABLE IF NOT EXISTS "filter_service" ("service" TEXT NOT NULL,"filter" TEXT,PRIMARY KEY ("service"));';
    dbq.ExecSQL;
    dbq.SQL.Text := 'CREATE TABLE IF NOT EXISTS "triggers" ("id" INTEGER NOT NULL, "input" TEXT NULL, "output" TEXT NULL, PRIMARY KEY ("id"));';
    dbq.ExecSQL;
    stage := 1;
    dbq.SQL.Text := 'INSERT OR IGNORE INTO "keyvalue"("key", "value") VALUES (''telegrambot'', '''');';
    dbq.ExecSQL;
    stage := 2;
    Result := True;
  except
    on E: Exception do
      ShowInfo(E.ClassName + ':' + E.Message + IntToStr(stage));
  end;
end;

procedure TMyStarter.DB_fix();
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'DELETE FROM sms WHERE otkogo="SYSTEM" AND text LIKE "Ваш номер %";';
    dbq.ExecSQL;
    dbq.SQL.Text := 'DELETE FROM sms WHERE id NOT IN (SELECT id FROM sms ORDER BY id DESC LIMIT 100000);';
    dbq.ExecSQL;
    dbq.SQL.Text := 'VACUUM;';
    dbq.ExecSQL;
    dbq.Close;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_close();
begin
  dbq.Free;
  dbc.Free;
end;

procedure TMyStarter.SwapThread(a, b: integer);
var
  t: TMyModem;
begin
  if a = b then
    exit;
  _cs.Enter;
  try
    t := AM[a];
    AM[a] := AM[b];
    AM[a].idthread := a;
    AM[b] := t;
    AM[b].idthread := b;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.Telegram_SendSMS(const sl, n, t: string);
var
  i: integer;
  s: string;
begin
  if (telegram_bot_id = '') then
    exit;
  for i := 0 to High(arraytelegramclients) do
  begin
    if (arraytelegramclients[i].service = '') then
      continue;
    if (arraytelegramclients[i].service = 'all') then
    begin
      Telegram_Send(arraytelegramclients[i].telegram, '[' + sl + ']:' + n + Chr($0A) + t);
      continue;
    end;
    s := SMSCheckService(arraytelegramclients[i].service, n, t);
    if (s <> '') then
      Telegram_Send(arraytelegramclients[i].telegram, s);
  end;
end;

procedure TMyStarter.Telegram_Send(const telega, Text: string);
{$IFDEF UNIX}
begin
  with TProcess.Create(nil) do
  begin
    Options := [poUsePipes, poNoConsole];
    Commandline := 'wget --post-data ''chat_id=' + telega + '&text=' + EncodeURLElement(Text) + '&parse_mode=HTML'' -q -O - https://api.telegram.org/bot' + telegram_bot_id + '/sendMessage';
    Execute;
    Free;
  end;
end;
{$ELSE}
var
  M: TMemoryStream;
  s: string;
  HTTP: THTTPSend;
  res: boolean;
begin
  M := TMemoryStream.Create;
  try
    HTTP := THTTPSend.Create;
    try
      WriteStrToStream(HTTP.Document, 'chat_id=' + telega + '&text=' + EncodeURLElement(Text) + '&parse_mode=HTML');      //-472826551
      HTTP.MimeType := 'application/x-www-form-urlencoded';
      try
        res := HTTP.HTTPMethod('POST', 'https://api.telegram.org/bot' + telegram_bot_id + '/sendMessage');
      except
        on E : Exception do
          debuglog('TELEGA ERROR:'+E.ClassName+' : '+E.Message);
      end;
      if res then
      begin
        M.CopyFrom(HTTP.Document, 0);
        //M.Position := 0;
        //SetLength(s, M.Size);
        //M.ReadBuffer(s[1], M.Size);
        //debuglog('TRY_SEND: ' + telega + ' ' + Text + ' https://api.telegram.org/bot' + telegram_bot_id + '/sendMessage' + ' ' + 'chat_id=' + telega + '&text=' + EncodeURLElement(Text) + '&parse_mode=HTML' + ' RES:' + s);
      end
      else
      begin
        debuglog('ERROR1: ' + IntToStr(HTTP.ResultCode) + ' : ' + HTTP.ResultString);
        debuglog('ERROR1: ' + IntToStr(HTTP.Sock.LastError) + ' : ' + IntToStr(HTTP.Sock.LastError) + ' : ' + HTTP.Sock.LastErrorDesc +
          ':' + HTTP.Sock.SocksIP);
      end;
    finally
      HTTP.Free;
    end;
    if (res = False) then
    begin
      SetLength(s, M.Size);
      M.Position := 0;
      M.Read(s[1], Length(s));
      debuglog('text=' + EncodeURLElement(Text));
      debuglog(s);
    end;
  finally
    M.Free;
  end;
end;
{$ENDIF}

function TMyStarter.DB_getvalue(key: string): string;
begin
  Result := '';
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'SELECT * FROM "keyvalue" WHERE "key" = ''' + key + ''' LIMIT 1;';
    dbq.Open;
    if dbq.RecordCount <> 0 then
      Result := dbq.FieldByName('value').AsString;
    dbq.Close;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_telegramclient_load();
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'SELECT * FROM "telegram";';
    dbq.Open;
    while not dbq.EOF do
    begin
      SetLength(arraytelegramclients, Length(arraytelegramclients) + 1);
      arraytelegramclients[High(arraytelegramclients)].telegram := dbq.FieldByName('idtelegram').AsString;
      arraytelegramclients[High(arraytelegramclients)].service := dbq.FieldByName('service').AsString;
      dbq.Next;
    end;
  finally
    dbq.Close;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_telegramclient_save(const s: string);
var
  i: integer;
  t: TStringList;
  st: string;
begin
  t := TStringList.Create;
  t.Text := s;
  _cs.Enter;
  try
    SetLength(arraytelegramclients, t.Count);
    for i := 0 to t.Count - 1 do
    begin
      st := t.Strings[i];
      arraytelegramclients[i].telegram := Copy(st, 1, Pos('=', st) - 1);
      Delete(st, 1, Pos('=', st));
      arraytelegramclients[i].service := st;
    end;
    dbq.Close;
    dbq.SQL.Text := 'DELETE FROM "telegram";';
    dbq.ExecSQL;
    for i := 0 to High(arraytelegramclients) do
    begin
      dbq.SQL.Text := 'INSERT OR IGNORE INTO "telegram"("idtelegram", "service") VALUES (:idtelegram, :service);';
      dbq.ParamByName('idtelegram').AsString := arraytelegramclients[i].telegram;
      dbq.ParamByName('service').AsString := arraytelegramclients[i].service;
      dbq.ExecSQL;
    end;
    SetLength(arraytelegramclients, 0);
  finally
    _cs.Leave;
    t.Free;
  end;
  DB_telegramclient_load();
end;

function TMyStarter.DB_telegramclient_text(): string;
var
  i: integer;
  t: TStringList;
begin
  Result := '';
  t := TStringList.Create;
  _cs.Enter;
  try
    for i := 0 to High(arraytelegramclients) do
    begin
      t.add(arraytelegramclients[i].telegram + '=' + arraytelegramclients[i].service);
    end;
    Result := t.Text;
  finally
    t.Free;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_setvalue(key, Value: string);
begin
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'REPLACE INTO "keyvalue" ("key", "value") VALUES (''' + key + ''', ''' + Value + ''');';
    dbq.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.AddToSendSms(nomer, otkogo, Text, date: string);
var
  j: integer;
  s: string;
begin
  if urlactivesms = '' then
    exit;
  for j := 1 to High(arrayoffilteractivation) do
  begin
    s := SMSCheckService(IntToTagServiceActivation(j), otkogo, Text);
    if (s <> '') then
    begin
      _cs.Enter;
      try
        i := Length(arrayofsmstosend);
        SetLength(arrayofsmstosend, i + 1);
        arrayofsmstosend[i].typesnd := 2;
        arrayofsmstosend[i].date := IntToTagServiceActivation(j);
        arrayofsmstosend[i].nomer := nomer;
        arrayofsmstosend[i].otkogo := s;
        arrayofsmstosend[i].Text := Text;
      finally
        _cs.Leave;
      end;
      break;
    end;
  end;

  _cs.Enter;
  try
    i := Length(arrayofsmstosend);
    SetLength(arrayofsmstosend, i + 1);
    arrayofsmstosend[i].typesnd := 1;
    arrayofsmstosend[i].nomer := nomer;
    arrayofsmstosend[i].otkogo := otkogo;
    arrayofsmstosend[i].Text := Text;
    arrayofsmstosend[i].date := date;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.AddToActivateNomer(nomer, opera, state: string);
var
  i: integer;
begin
  if urlactivesms = '' then
    exit;
  _cs.Enter;
  try
    i := Length(arrayofsmstosend);
    SetLength(arrayofsmstosend, i + 1);
    arrayofsmstosend[i].typesnd := 2;
    arrayofsmstosend[i].nomer := nomer;
    arrayofsmstosend[i].otkogo := opera;
    arrayofsmstosend[i].Text := state;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.SMSDeleteService(const ids, service: string);
var
  n,s, curser: string;
  current, i: integer;
begin
  n := ids;
  while (n<>'') do
  begin
    if (Pos(',',n)<>0) then
    begin
      current := StrToInt(Copy(n,1,Pos(',',n)-1));
      Delete(n,1,Pos(',',n));
    end
    else
    begin
      current := StrToInt(n);
      n := '';
    end;
    s := service;
    while (s<>'') do
    begin
      if (Pos(',',s)<>0) then
      begin
        curser := Copy(s,1,Pos(',',s)-1);
        Delete(s,1,Pos(',',s));
      end
      else
      begin
        curser := s;
        s := '';
      end;
      for i:=0 to High(AM[current].smshistory) do
        if (SMSCheckService(curser, AM[current].smshistory[i].otkogo, AM[current].smshistory[i].Text)<>'') then
        begin
          AM[current].SMSHistoryDelete(i);
        end;
    end;
  end;
end;

procedure TMyStarter.SMSDeleteService2(const ids, service: string);
var
  n,s, curser: string;
  current, i: integer;
begin
  n := ids;
  while (n<>'') do
  begin
    if (Pos(',',n)<>0) then
    begin
      current := StrToInt(Copy(n,1,Pos(',',n)-1))-1;
      Delete(n,1,Pos(',',n));
    end
    else
    begin
      current := StrToInt(n)-1;
      n := '';
    end;
    s := service;
    while (s<>'') do
    begin
      if (Pos(',',s)<>0) then
      begin
        curser := Copy(s,1,Pos(',',s)-1);
        Delete(s,1,Pos(',',s));
      end
      else
      begin
        curser := s;
        s := '';
      end;
      if (AM[current]<>nil) then
        for i:=High(AM[current].smshistory) downto 0 do
          if (SMSCheckService(curser, AM[current].smshistory[i].otkogo, AM[current].smshistory[i].Text)<>'') then
            begin
              AM[current].SMSHistoryDelete(i);
            end;
    end;
  end;
end;

{$IFDEF UNIX}
function TMyStarter.LoadSerialPorts(): TStringList;
var
  s: TProcess;
  res: string;
  i, Count: integer;
  buf: array[1..1024] of byte;
  ignorelist: TStringList;
begin
  s := TProcess.Create(nil);
  s.Commandline := 'dir /dev/serial/by-path';
  s.Options := [poUsePipes, poNoConsole];
  s.Execute;
  res := '';
  repeat
    Count := s.Output.Read(buf, 1024);
    for i := 1 to Count do
      res := res + chr(buf[i]);
  until Count = 0;
  s.Free;
  ignorelist := TStringList.Create;
  ignorelist.Delimiter := ' ';
  ignorelist.DelimitedText := DB_getvalue('ignore');
  ignorelist.Sorted := True;
  Result := TStringList.Create;
  Result.Delimiter := ' ';
  Result.DelimitedText := StringReplace(res, #9, #20, [rfreplaceall]);
  i := 0;
  while (i <> Result.Count) do
  begin
    if (ignorelist.Find(Result[i], Count)) then
      Result.Delete(i);
    Inc(i);
  end;
  ignorelist.Free;
end;

{$ELSE}
function TMyStarter.LoadSerialPorts(): TStringList;
var
  reg: TRegistry;
  l, ignorelist: TStringList;
  n, i: integer;
begin
  Result := TStringList.Create;
  l := TStringList.Create;
  ignorelist := TStringList.Create;
  reg := TRegistry.Create;
  ignorelist.Delimiter := ' ';
  ignorelist.DelimitedText := DB_getvalue('ignore');
  ignorelist.Sorted := True;
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    reg.OpenKey('HARDWARE\DEVICEMAP\SERIALCOMM', False);
    reg.GetValueNames(l);
    for n := 0 to l.Count - 1 do
      if (ignorelist.Find(reg.ReadString(l[n]), i) = False) then
        Result.Add(reg.ReadString(l[n]));
  finally
    reg.Free;
    l.Free;
    ignorelist.Free;
  end;
end;
{$ENDIF}

procedure TMyStarter.ShowError(s: string);
begin
  MainMemoWrite(s);
end;

procedure TMyStarter.ShowInfo(s: string; _modemid: integer = -1);
begin
  MainMemoWrite(s, _modemid);
end;

constructor TMyStarter.Create;
begin
  inherited Create(False);
  _cs := TCriticalSection.Create;
  counteractivationid := 1;
  lastcheckhash := '';
  telegram_bot_id := '';
  drawbox := False;
  serverwork := False;
  Randomize;
end;

destructor TMyStarter.Destroy;
begin
  _cs.Free;
end;

procedure TMyStarter.Execute;
var
  timermili, timersec: int64;
  first: byte;
begin
  timermili := 0;
  timersec := 0;
  first := 2;
  ShowInfo('Запускаю...');
  if (DB_open() = False) then
  begin
    ShowInfo('Ошибка файла data.db');
    exit; //Ошибка бд.
  end;
  DB_fix();
  StartALL();
  DB_servicefilter_load();
  DB_telegramclient_load();
  DB_triggers_load();

  if (serverwork = False) then
  begin
    ShowInfo('Ошибка запуска.');
    sleep(2500);
    stagestarter := 666;
    starterwork := False;
    exit();
  end;
  TTCPHttpDaemon.Create;
  while serverwork do
  begin
    drawbox := not drawbox;
    stagestarter := 100;
    Sleep(250);
    Inc(timermili);
    if timermili = 4 then
    begin
      timermili := 0;
      Inc(timersec);
      if ((timersec mod 90) = 0) then  //Говорю серверу что онлайн, раз в 90 секунд
      begin
        SendNomeraToServer();
        start_self();
      end;
      if ((timersec mod 15) = 0)AND(first>0) then
      begin
        dec(first);
        SendNomeraToServer();
      end;
      if ((timersec mod 1) = 0) then  //Отправляю смс-ки на севрер
        CheckSendSMS();
    end;
  end;
  DB_close();
  stagestarter := 666;
  starterwork := False;
end;

end.
