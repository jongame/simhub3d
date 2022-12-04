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
    dbq_sms: TZQuery;
    dbc_sms: TZConnection;
    dbq_used: ^TZQuery;
    counteractivationid: integer;
    Telegram_offset: integer;
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
    function SendSMSToServer(url, Data: string; logs: boolean = false): string;
    procedure CheckSendSMS();
    function DB_open(): boolean;
    procedure DB_fix();
    procedure DB_close();
    procedure RunIIN();
  public
    timersec: QWord;
    bindimei, bindimei_sim, urlactivesms_active, newsim_delay: boolean;
    reset_timer: integer;
    simbank_swapig: boolean;
    drawbox: boolean;
    _stagestarter: integer;
    telegram_bot_id: string;
    servername, servercountry, urlactivesms, urldatabasesms, simbank: string;
    iinsl: TStringList;
    iinslcount: integer;
    property stagestarter: integer read _RSTAGESTARTER write _WSTAGESTARTER default 0;
    procedure SwapThread(a, b: integer);
    function Telegram_getupdates():string;
    procedure Telegram_SendSMS(const sl,n, t: string);
    procedure Telegram_Send(const telega, Text: string);
    function AddToSendSms2service(nomer, otkogo, Text, date: string):string;
    procedure AddToSendSms(nomer, otkogo, Text, date: string);
    procedure AddToActivateNomer(nomer, opera, state: string);
    procedure SMSDeleteService(const ids, service: string);
    procedure SMSDeleteService2(const ids, service: string);
    function SMSCheckService(const service, otkogo, Text: string): string;
    function SMSCheckAllService(const n: integer): string;
    function SMSCheckTriggers(const ot, text: string):string;
    function SendNomeraToServer():boolean;
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
    //exit;
  end;

  serverwork := True;
  SimPort := SerialPorts.Count - 1;
  SetLength(Last10sms, SimPort + 1);
  SetLength(AM, SimPort + 1);
  telegram_bot_id := DB_getvalue('telegrambot');
  urlactivesms := DB_getvalue('urlactivesms');
  servername := DB_getvalue('servername');
  servercountry := DB_getvalue('servercountry');
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
        begin
          if (CutCodeInSms(Text, arrayoffilteractivation[j][i].cutsms)='') then
            continue;
          exit(CutCodeInSms(Text, arrayoffilteractivation[j][i].cutsms));
        end;
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
      if (SMSCheckService(tag_services[j], AM[n].smshistory[i].otkogo, AM[n].smshistory[i].Text) <> '') then
      begin
        if (Result = '') then
          Result := tag_services[j]
        else
          Result := Result + ',' + tag_services[j];
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
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'INSERT INTO `sms` (`nomer`, `datetime`, `otkogo`, `text`) VALUES (:nomer, :datetime, :otkogo, :text);';
    dbq_used^.ParamByName('nomer').AsString := nomer;
    dbq_used^.ParamByName('datetime').AsString := datetime;
    dbq_used^.ParamByName('otkogo').AsString := otkogo;
    dbq_used^.ParamByName('text').AsString := Text;
    dbq_used^.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_deletesms(nomer, datetime, otkogo, Text: string);
begin
  _cs.Enter;
  try
    if (urldatabasesms<>'')  then
    begin
      dbq.Close;
      dbq.SQL.Text := 'DELETE FROM `sms` WHERE (`nomer`=:nomer)AND(`datetime`=:datetime)AND(`otkogo`=:otkogo)AND(`text`=:text);';
      dbq.ParamByName('nomer').AsString := nomer;
      dbq.ParamByName('datetime').AsString := datetime;
      dbq.ParamByName('otkogo').AsString := otkogo;
      dbq.ParamByName('text').AsString := Text;
      dbq.ExecSQL;
    end;
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'DELETE FROM `sms` WHERE (`nomer`=:nomer)AND(`datetime`=:datetime)AND(`otkogo`=:otkogo)AND(`text`=:text);';
    dbq_used^.ParamByName('nomer').AsString := nomer;
    dbq_used^.ParamByName('datetime').AsString := datetime;
    dbq_used^.ParamByName('otkogo').AsString := otkogo;
    dbq_used^.ParamByName('text').AsString := Text;
    dbq_used^.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_deletesms(id: integer);
begin
  _cs.Enter;
  try
    if (urldatabasesms<>'')  then
    begin
      dbq.Close;
      dbq.SQL.Text := 'DELETE FROM `sms` WHERE (`id`=:id);';
      dbq.ParamByName('id').AsString := inttostr(id);
      dbq.ExecSQL;
    end;
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'DELETE FROM `sms` WHERE (`id`=:id);';
    dbq_used^.ParamByName('id').AsString := inttostr(id);
    dbq_used^.ExecSQL;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_loadsms(idthread: integer);
var
  i: integer;
  tc: integer;
begin
  _cs.Enter;
  try
    if (urldatabasesms<>'')  then
    begin
      dbq.Close;
      dbq.SQL.Text := 'SELECT * FROM `sms` WHERE `nomer`=''' + AM[idthread].nomer + ''' ORDER BY `id` DESC LIMIT 1000;';
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
    end;
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'SELECT * FROM `sms` WHERE `nomer`=''' + AM[idthread].nomer + ''' ORDER BY `id` DESC LIMIT 1000;';
    dbq_used^.Open;
    tc := Length(AM[idthread].smshistory);
    SetLength(AM[idthread].smshistory, tc + dbq_used^.RecordCount);
    for i := (dbq_used^.RecordCount + tc) - 1 downto tc do
    begin
      AM[idthread].smshistory[i].idinbase := dbq_used^.FieldByName('id').AsInteger;
      AM[idthread].smshistory[i].datetime := dbq_used^.FieldByName('datetime').AsString;
      AM[idthread].smshistory[i].otkogo := dbq_used^.FieldByName('otkogo').AsString;
      AM[idthread].smshistory[i].Text := dbq_used^.FieldByName('text').AsString;
      dbq_used^.Next;
    end;
  finally
    dbq_used^.Close;
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_triggers_load;
var
  s: string;
begin
  _cs.Enter;
  try
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'SELECT * FROM `triggers`;';
    dbq_used^.Open;
    while not dbq_used^.EOF do
    begin
      SetLength(arrayoftriggers, Length(arrayoftriggers) + 1);
      s := dbq_used^.FieldByName('input').AsString;
      arrayoftriggers[High(arrayoftriggers)].input.otkogo := Copy(s, 1, Pos(':', s) - 1);
      Delete(s, 1, Pos(':', s));
      arrayoftriggers[High(arrayoftriggers)].input.textsms := Copy(s, 1, Pos(':', s) - 1);
      Delete(s, 1, Pos(':', s));
      arrayoftriggers[High(arrayoftriggers)].input.cutsms := s;
      arrayoftriggers[High(arrayoftriggers)].output := dbq_used^.FieldByName('output').AsString;
      dbq_used^.Next;
    end;
  finally
    dbq_used^.Close;
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
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'DELETE FROM `triggers`;';
    dbq_used^.ExecSQL;
    for i:=0 to High(arrayoftriggers) do
    begin
      dbq_used^.SQL.Text := 'INSERT INTO `triggers`(`id`, `input`, `output`) VALUES (:id, :input, :output);';
      dbq_used^.ParamByName('id').AsInteger := i + 1;
      dbq_used^.ParamByName('input').AsString := arrayoftriggers[i].input.otkogo + ':' + arrayoftriggers[i].input.textsms + ':' + arrayoftriggers[i].input.cutsms;
      dbq_used^.ParamByName('output').AsString := arrayoftriggers[i].output;
      dbq_used^.ExecSQL;
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
    dbq_used^.Close;
    for i := Low(tag_services) to High(tag_services) do
    begin
      if urldatabasesms<>'' then
        dbq_used^.SQL.Text := 'INSERT IGNORE INTO `filter_service`(`service`, `filter`) VALUES (:service, :filter);'
      else
        dbq_used^.SQL.Text := 'INSERT OR IGNORE INTO `filter_service`("service", "filter") VALUES (:service, :filter);';
      dbq_used^.ParamByName('service').AsString := tag_services[i];
      dbq_used^.ParamByName('filter').AsString := 'EXAMPLE_OTKOGO:EXAMPLE_TEXT:';
      dbq_used^.ExecSQL;
    end;
  finally
    _cs.Leave;
  end;

  _cs.Enter;
  t := TStringList.Create;
  try
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'SELECT * FROM `filter_service`;';
    dbq_used^.Open;
    while not dbq_used^.EOF do
    begin
      t.Text := dbq_used^.FieldByName('filter').AsString;
      if (t.Text='') then
        t.Text := 'EXAMPLE_OTKOGO:EXAMPLE_TEXT:';
      i := TagServiceToIntActivation(dbq_used^.FieldByName('service').AsString);
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
      dbq_used^.Next;
    end;
  finally
    dbq_used^.Close;
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
        if (tag_services[i] = t.Names[j]) then
        begin
          temp_string := t.Strings[j];
          if (Pos('EXAMPLE_OTKOGO:EXAMPLE_TEXT:', temp_string)<>0) then
            continue;
          Delete(temp_string, 1, Pos('=', temp_string));
          t2.Add(temp_string);
        end;
      dbq_used^.SQL.Text := 'UPDATE `filter_service` SET `filter` = :filter WHERE `service` = :service;';
      dbq_used^.ParamByName('service').AsString := tag_services[i];
      dbq_used^.ParamByName('filter').AsString := t2.Text;
      dbq_used^.ExecSQL;
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
        t.add(tag_services[i] + '=' + arrayoffilteractivation[i, j].otkogo + ':' + arrayoffilteractivation[i, j].textsms +
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

function TMyStarter.SendSMSToServer(url, Data: string; logs: boolean): string;
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
    if (logs)or(HTTP.ResultCode<>200) then
      debuglog('SendSMSToServer:'+IntToStr(HTTP.ResultCode)+' : '+url+' : '+Data);
  finally
    HTTP.Free;
  end;
end;

function TMyStarter.SendNomeraToServer(): boolean;
var
  s,t,ds: string;
  i: integer;
begin
  result := true;
  if (urlactivesms = '')OR(urlactivesms_active=false) then
    exit;
  result := false;
  s := '';
  ds := '';
  with TJSONObject.Create do
    try
      Strings['servername'] := servername;
      Strings['servercountry'] := servercountry;
      Integers['port_count'] := Length(AM);
      for i := 0 to High(AM) do
      begin
        if (AM[i].MODEM_STATE <> MODEM_MAIN_WHILE) or (AM[i].nomer = Nomer_Neopredelen) or (AM[i].nomer = data_neopredelen) or (AM[i].operatorNomer = SIM_UNKNOWN) then
        begin
          if debugsms then
          begin
            if (AM[i].MODEM_STATE <> MODEM_MAIN_WHILE) then
              ds := ds + '['+IntToStr(i)+'] MODEM_STATE,';
            if (AM[i].operatorNomer = SIM_UNKNOWN) then
              ds := ds + '['+IntToStr(i)+'] SIM_UNKNOWN,';
            if (AM[i].nomer = Nomer_Neopredelen) or (AM[i].nomer = data_neopredelen) then
              ds := ds + '['+IntToStr(i)+'] NOMER,';
          end;
          continue;
        end;
        if (AM[i].statesim <> SIM_HOME_NETWORK) AND (AM[i].statesim <> SIM_ROAMING) then
        begin
          if debugsms then
            ds := ds + '['+IntToStr(i)+'] state sim,';
          continue;
        end;
        if (AM[i].newsim) then
        begin
          if debugsms then
            ds := ds + '['+IntToStr(i)+'] new sim,';
          continue;
        end;
        t := SMSCheckAllService(i);
        Arrays[AM[i].nomer] := CreateJSONArray([operator_names_to_activate[AM[i].operatorNomer],t,i+1]);
      end;
      s := FormatJSON(AsCompressedJSON);
    finally
      Free;
    end;
  debuglog('send nomera' + ds);
  t := SendSMSToServer(urlactivesms, s, debugsms);
  if t <> 'ok' then
    debuglog('Ошибка отправки на сервер. Сервер не сказал ok.' + t)
  else
    result := true;
end;

procedure TMyStarter.CheckSendSMS();
var
  temp: smstosend;
  postdata: ansistring;
  t: int64;
begin
  t := GetTickCount64();
  while ((GetTickCount64()-t)<1000) do
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
          if (SendSMSToServer(urlactivesms, postdata, debugsms) <> 'ok') then
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
          if (SendSMSToServer(urlactivesms, postdata, debugsms) <> 'ok') then
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
  s: string;
begin
  stage := 0;
  Result := False;
  _cs.Enter;
  dbc_sms := TZConnection.Create(nil);
  dbq_sms := TZQuery.Create(nil);
  dbc_sms.Protocol := 'MariaDB-10';
  dbq_sms.Connection := dbc_sms;

  dbc := TZConnection.Create(nil);
  dbq := TZQuery.Create(nil);
  dbc.Database := extractfilepath(ParamStr(0)) + 'data.db';
  dbc.Protocol := 'sqlite-3';
  dbq.Connection := dbc;
  try
    if (not FileExists(extractfilepath(ParamStr(0)) + 'data.db')) then
    begin //Создаём таблицы
      dbq.SQL.Text := 'CREATE TABLE `keyvalue` ("key"  TEXT NOT NULL, "value"  TEXT, PRIMARY KEY ("key"));';
      dbq.ExecSQL;
      DB_setvalue('ignore', '');
      DB_setvalue('bindimei', 'false');
      DB_setvalue('bindimei_sim', 'false');
      DB_setvalue('urlactivesms_active', 'true');
      DB_setvalue('urlactivesms', '');
      DB_setvalue('urldatabasesms', '');
      DB_setvalue('servername', 'new server');
      DB_setvalue('servercountry', 'ru');
    end;
    urldatabasesms := DB_getvalue('urldatabasesms');
    s := urldatabasesms;
    if (urldatabasesms = '') then
    begin
      inc(stage);
      dbq_used := @dbq;
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `telegram` ("id" INTEGER PRIMARY KEY AUTOINCREMENT,"idtelegram" TEXT,"service" TEXT,UNIQUE ("idtelegram" ASC));';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `filter_service` ("service" TEXT NOT NULL,"filter" TEXT,PRIMARY KEY ("service"));';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `triggers` ("id" INTEGER NOT NULL, "input" TEXT NULL, "output" TEXT NULL, PRIMARY KEY ("id"));';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `keyvalue` ("key"  TEXT NOT NULL, "value"  TEXT, PRIMARY KEY ("key"));';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS `sms` ("id"  INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL DEFAULT 0, "nomer"  TEXT(16) NOT NULL, "datetime"  TEXT, "otkogo"  TEXT, "text"  TEXT);';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text := 'CREATE INDEX IF NOT EXISTS "n" ON `sms` ("nomer" ASC);';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text := 'INSERT OR IGNORE INTO `keyvalue`("key", "value") VALUES (''telegrambot'', '''');';
      dbq_used^.ExecSQL;
    end
    else
    begin
      inc(stage);
      dbc_sms.User :=Copy(s,1,Pos(':',s)-1);
      Delete(s,1,Pos(':',s));
      dbc_sms.Password :=Copy(s,1,Pos('@',s)-1);
      Delete(s,1,Pos('@',s));
      dbc_sms.HostName:=Copy(s,1,Pos(':',s)-1);
      Delete(s,1,Pos(':',s));
      dbc_sms.Port := StrToInt(s);
      dbq_used := @dbq_sms;
      inc(stage);
      dbq_used^.SQL.Text := 'CREATE DATABASE IF NOT EXISTS `sms3d`;';
      dbq_used^.ExecSQL;
      inc(stage);
      dbq_used^.SQL.Text := 'USE `sms3d`;';
      dbq_used^.ExecSQL;
      inc(stage);
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `telegram`  (`id` integer AUTO_INCREMENT,`idtelegram` text,`service` text ,PRIMARY KEY (`id`));';
      dbq_used^.ExecSQL;
      inc(stage);
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `filter_service` (`service` TEXT NOT NULL,`filter` TEXT,PRIMARY KEY (`service`(100)));';
      dbq_used^.ExecSQL;
      inc(stage);
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `triggers` (`id` INTEGER NOT NULL, `input` TEXT NULL, `output` TEXT NULL, PRIMARY KEY (`id`));';
      dbq_used^.ExecSQL;
      inc(stage);
      dbq_used^.SQL.Text := 'CREATE TABLE IF NOT EXISTS `keyvalue` (`key`  TEXT NOT NULL, `value`  TEXT, PRIMARY KEY (`key`(100)));';
      dbq_used^.ExecSQL;
      dbq_used^.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS `sms` (`id` int NOT NULL AUTO_INCREMENT,`nomer` varchar(16) NULL,`datetime` varchar(255) NULL,`otkogo` varchar(255) NULL,`text` varchar(255) NULL,PRIMARY KEY (`id`),INDEX `n`(`nomer`));';
      dbq_used^.ExecSQL;
    end;
    if DB_getvalue('bindimei')='' then DB_setvalue('bindimei', 'false');
    if DB_getvalue('bindimei_sim')='' then DB_setvalue('bindimei_sim', 'false');
    if DB_getvalue('urlactivesms_active')='' then DB_setvalue('urlactivesms_active', 'true');
    if DB_getvalue('newsim_delay')='' then DB_setvalue('newsim_delay', 'false');
    if DB_getvalue('simbank_swapig')='' then DB_setvalue('simbank_swapig', 'false');
    if DB_getvalue('reset_timer')='' then DB_setvalue('reset_timer', '180');

    stage := 2;
    Result := True;
  except
    on E: Exception do
      ShowInfo(E.ClassName + ':' + E.Message + ' ' + IntToStr(stage));
  end;
  _cs.Leave;
end;

procedure TMyStarter.DB_fix();
const
  ar_ignore_sms: array[0..1] of string = (
    '`otkogo`="SYSTEM" AND `text` LIKE "Ваш номер %"',
    '`otkogo`="7006" AND `text` LIKE "Регистрация номера НЕВОЗМОЖНА!%"'
    );
var
  i:integer;
begin
  _cs.Enter;
  try
    try
      dbq_used^.Close;
      for i:=Low(ar_ignore_sms) to High(ar_ignore_sms) do
      begin
        dbq_used^.SQL.Text := 'DELETE FROM `sms` WHERE '+StringReplace(ar_ignore_sms[i],'"','''',[rfreplaceall])+';';
        dbq_used^.ExecSQL;
      end;
      if (urldatabasesms='') then
      begin
        dbq_used^.SQL.Text := 'DELETE FROM `sms` WHERE id NOT IN (SELECT id FROM `sms` ORDER BY id DESC LIMIT 500000);';
        dbq_used^.ExecSQL;
        dbq_used^.SQL.Text := 'VACUUM;';
        dbq_used^.ExecSQL;
      end;
      dbq_used^.Close;
    except
      on E: Exception do
        debuglog('error_DB_fix{' + E.ClassName + '}[' + E.Message + ']['+dbq_used^.SQL.Text+']');
    end;
  finally
    _cs.Leave;
  end;
end;

procedure TMyStarter.DB_close();
begin
  dbq.Free;
  dbc.Free;
  dbq_sms.Free;
  dbc_sms.Free;
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

function TMyStarter.Telegram_getupdates: string;
{$IFDEF UNIX}
var
  M: TMemoryStream;
  res: string;
  buf: array[1..2048] of byte;
  Count: integer;
begin
  M := TMemoryStream.Create;
  with TProcess.Create(nil) do
  begin
    Options := [poUsePipes, poNoConsole];
    if (Telegram_offset=0) then
      Commandline := 'wget -q -O - https://api.telegram.org/'+telegram_bot_id+'/getUpdates'
    else
      Commandline := 'wget -q -O - https://api.telegram.org/'+telegram_bot_id+'/getUpdates?offset='+IntToStr(Telegram_offset);
    Execute;
    res := '';
    repeat
      Count := Output.Read(buf, 2048);
      for i := 1 to Count do
        res := res + chr(buf[i]);
    until Count = 0;
    Free;
  end;
  result := res;
end;
{$ELSE}
var
  M: TMemoryStream;
  s: string;
  HTTP: THTTPSend;
  res: boolean;
begin
  result := '';
  M := TMemoryStream.Create;
  try
    HTTP := THTTPSend.Create;
    try
      //WriteStrToStream(HTTP.Document, 'chat_id=' + telega + '&text=' + EncodeURLElement(Text) + '&parse_mode=HTML');      //-472826551
      HTTP.MimeType := 'application/x-www-form-urlencoded';
      try
        if (Telegram_offset=0) then
          res := HTTP.HTTPMethod('GET', 'wget -q -O - https://api.telegram.org/'+telegram_bot_id+'/getUpdates')
        else
          res := HTTP.HTTPMethod('GET', 'wget -q -O - https://api.telegram.org/'+telegram_bot_id+'/getUpdates'+IntToStr(Telegram_offset));
      except
        on E : Exception do
          debuglog('TELEGA ERROR:'+E.ClassName+' : '+E.Message);
      end;
      if res then
      begin
        M.CopyFrom(HTTP.Document, 0);
        result := M.ReadAnsiString();
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
  finally
    M.Free;
  end;
end;
{$ENDIF}

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

function TMyStarter.AddToSendSms2service(nomer, otkogo, Text, date: string
  ): string;
var
  j: integer;
begin
  result := '';
  if urlactivesms = '' then
    exit;
  for j := 1 to High(arrayoffilteractivation) do
  begin
    result := SMSCheckService(tag_services[j], otkogo, Text);
    if (result <> '') then
    begin
      _cs.Enter;
      try
        i := Length(arrayofsmstosend);
        SetLength(arrayofsmstosend, i + 1);
        arrayofsmstosend[i].typesnd := 2;
        arrayofsmstosend[i].date := tag_services[j];
        arrayofsmstosend[i].nomer := nomer;
        arrayofsmstosend[i].otkogo := result;
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

function TMyStarter.DB_getvalue(key: string): string;
begin
  Result := '';
  _cs.Enter;
  try
    dbq.Close;
    dbq.SQL.Text := 'SELECT * FROM `keyvalue` WHERE `key` = ''' + key + ''' LIMIT 1;';
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
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'SELECT * FROM `telegram`;';
    dbq_used^.Open;
    while not dbq_used^.EOF do
    begin
      SetLength(arraytelegramclients, Length(arraytelegramclients) + 1);
      arraytelegramclients[High(arraytelegramclients)].telegram := dbq_used^.FieldByName('idtelegram').AsString;
      arraytelegramclients[High(arraytelegramclients)].service := dbq_used^.FieldByName('service').AsString;
      dbq_used^.Next;
    end;
  finally
    dbq_used^.Close;
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
    dbq_used^.Close;
    dbq_used^.SQL.Text := 'DELETE FROM `telegram`;';
    dbq_used^.ExecSQL;
    for i := 0 to High(arraytelegramclients) do
    begin
      if urldatabasesms<>'' then
        dbq_used^.SQL.Text := 'INSERT IGNORE INTO `telegram`(`idtelegram`, `service`) VALUES (:idtelegram, :service);'
      else
        dbq_used^.SQL.Text := 'INSERT OR IGNORE INTO `telegram`(`idtelegram`, `service`) VALUES (:idtelegram, :service);';
      dbq_used^.ParamByName('idtelegram').AsString := arraytelegramclients[i].telegram;
      dbq_used^.ParamByName('service').AsString := arraytelegramclients[i].service;
      dbq_used^.ExecSQL;
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
    dbq.SQL.Text := 'REPLACE INTO `keyvalue` (`key`, `value`) VALUES (:key, :value);';
    dbq.ParamByName('key').AsString := key;
    dbq.ParamByName('value').AsString := Value;
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
    s := SMSCheckService(tag_services[j], otkogo, Text);
    if (s <> '') then
    begin
      _cs.Enter;
      try
        i := Length(arrayofsmstosend);
        SetLength(arrayofsmstosend, i + 1);
        arrayofsmstosend[i].typesnd := 2;
        arrayofsmstosend[i].date := tag_services[j];
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

procedure TMyStarter.RunIIN();
var
  i,j,k: integer;
  s, s2: string;
begin
  ShowInfo('RUNIIN '+IntToStr(iinslcount));
  s := '';
  for i:=0 to High(AM) do
  begin

    if (iinslcount<>11) then
      s := iinsl.Strings[i]
    else
    begin
      if FileExists(extractfilepath(paramstr(0))+'activ_inn.txt') = False then
      begin
        ShowInfo('Ошибка, нету файла '+extractfilepath(paramstr(0))+'activ_inn.txt');
        exit;
      end;
      iinsl.LoadFromFile('activ_inn.txt');
    end;

    case AM[i].OperatorNomer of
      SIM_ACTIV:
        begin
          case iinslcount of
            1:
            begin
              s := Copy(s, 1, Pos(' ',s,Pos(' ',s)+1)-1);
              s := StringReplace(s,';',' ',[rfreplaceall]);
              AM[i].AddToSendSms('6007', s);
            end;
            2:
            begin
              s := Copy(s, 1, Pos(' ',s,Pos(' ',s)+1)-1);
              s := StringReplace(s,';',' ',[rfreplaceall]);
              AM[i].AddToSendSms('7006', s);
            end;
            11:
            begin
              if (AM[i].SMSHistoryFind('6006', 'Устройство успешно зарегистрировано.')=-1) AND
                (AM[i].SMSHistoryFind('6006', 'Введенный ИИН не совпадает с регистрационными данными номера.')=-1) AND
                (AM[i].SMSHistoryFind('6006', 'Регистрация устройства лицам младше 14 лет разрешена только на ИИН')=-1) AND
                (AM[i].SMSHistoryFind('6006', 'ВНИМАНИЕ! Абонентский номер, на который Вы пытаетесь')=-1) AND
                (AM[i].SMSHistoryFind('6006', 'Введенный номер паспорта не совпадает с регистрационными данными номера.')=-1) then
                begin
                  j := AM[i].SMSHistoryFind('activ', 'Данный номер зарегистрирован:');
                  if j<>-1 then
                  begin
                    s2 := AM[i].smshistory[j].Text;
                    Delete(s2, 1, Pos(':',s2));
                    Delete(s2, 1, Pos(' ',s2));
                    s2 := Copy(s2,1,Pos(' ',s2,Pos(' ',s2)+1));
                    s2 := UTF8UpperString(s2);
                    for k:=0 to iinsl.Count-1 do
                    begin
                      if Pos(s2, iinsl.Strings[k])<>0 then
                      begin
                        AM[i].SendUSSD('*660*1#',GetNumber(Copy(iinsl.Strings[k],1,12)));
                        break;
                      end
                      else
                      if k=iinsl.Count-1 then
                        MainMemoWrite('Данных ИНН нет. ' + Copy(s2,1,Pos(' ',s2,Pos(' ',s2)+1)), i);
                    end;
                  end
                  else
                    AM[i].SendUSSD('*562#');
                end;
            end;
          end;
        end;
      SIM_ALTEL:
        begin
          if (iinslcount=1) then
            begin
              s := Copy(s, 1, Pos(' ',s,Pos(' ',s)+1)-1);
              s := StringReplace(s,';',' ',[rfreplaceall]);
              AM[i].AddToSendSms('6914', s);
            end;
          if (iinslcount=2) then
            begin
              AM[i].SendUSSD('*6914*1#', Copy(s, 1, Pos(';',s)-1));
            end;
        end;
      SIM_TELE2:
        begin
          if (iinslcount=1) then
            begin
              s := Copy(s, 1, Pos(' ',s,Pos(' ',s)+1)-1);
              s := StringReplace(s,';',' ',[rfreplaceall]);
              AM[i].AddToSendSms('6914', s);
            end;
          if (iinslcount=2) then
            begin
              AM[i].SendUSSD('*6914*1*1#', Copy(s, 1, Pos(';',s)-1));
            end;
        end;
      SIM_BEELINE_KZ:
        begin
          if (iinslcount=1) then
            begin
              AM[i].AddToSendSms('6914', Copy(s, 1, Pos(';',s)-1));
            end;
          if (iinslcount=2) then
            begin
              AM[i].SendUSSD('*692#', Copy(s, 1, Pos(';',s)-1));
            end;
        end;
    end;
  end;
end;

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
  iinsl := TStringList.Create;
  iinslcount := 0;
  counteractivationid := 1;
  Telegram_offset := 0;
  lastcheckhash := '';
  telegram_bot_id := '';
  drawbox := False;
  serverwork := False;
  bindimei := false;
  bindimei_sim := false;
  simbank_swapig := false;
  urlactivesms_active := true;
end;

destructor TMyStarter.Destroy;
begin
  _cs.Free;
end;

procedure TMyStarter.Execute;
var
  ttick: QWord;
  timersendnomera: QWord;
begin
  timersec := 0;
  debuglog('start');
  ShowInfo('Запускаю...');
  if (DB_open() = False) then
  begin
    ShowInfo('Ошибка файла DB, перезапуск');
    sleep(2500);
    start_self();
    serverwork := false;
    starterwork := false;
    exit; //Ошибка бд.
  end;

  bindimei := DB_getvalue('bindimei')='true';
  bindimei_sim := DB_getvalue('bindimei_sim')='true';
  urlactivesms_active := DB_getvalue('urlactivesms_active')='true';
  newsim_delay := DB_getvalue('newsim_delay')='true';
  simbank_swapig := DB_getvalue('simbank_swapig')='true';
  reset_timer := StrToInt(DB_getvalue('reset_timer'));
  DB_fix();
  StartALL();
  DB_servicefilter_load();
  DB_telegramclient_load();
  DB_triggers_load();
  MySimBank := TMySimBank.Create();

  if (serverwork = False) then
  begin
    ShowInfo('Ошибка запуска.');
    sleep(1500);
    stagestarter := 666;
    starterwork := false;
    exit();
  end;
  TTCPHttpDaemon.Create;
  ttick := GetTickCount64();
  timersendnomera := 55;
  while serverwork do
  begin
    drawbox := not drawbox;
    stagestarter := 100;
    while (GetTickCount64()-ttick)<1000 do
      sleep(5);
    inc(timersec);
    ttick := GetTickCount64() - (GetTickCount64() - ttick - 1000);
    if ((reset_timer<>0) AND ((timersec mod reset_timer) = 0)) then
    begin
      SendNomeraToServer();
      start_self();
    end;

    if (timersendnomera >= 60) then
    begin
      if SendNomeraToServer() then
      begin
        timersendnomera := 0;
      end
      else
      begin
        //ShowInfo('Ошибка отправки номеров, повтор.');
      end;
    end
    else
      inc(timersendnomera);

    if ((timersec mod 10) = 0)AND(iinslcount<>0) then
    begin
      if (reset_timer<>0) then
        reset_timer := reset_timer + 300;
      RunIIN();
      inc(iinslcount);
      if (iinslcount=3)OR(iinslcount=12) then
        iinslcount := 0;
    end;
    CheckSendSMS();
  end;
  DB_close();
  stagestarter := 666;
  starterwork := False;
end;

end.
