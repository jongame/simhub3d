unit modemunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Synaser, lazutf8, Graphics, portcons, myfunctions, syncobjs, RegExpr, LCLIntf, ssl_openssl, strutils;

type

  { TMyModem }

  TMyModem = class(TThread)
  private
    _sendtimeout, _counttimeoutsend, timeoutinsendsms: integer;//таймаут на оправку команды, количество попыток
    sendsms: array of MySmsSend;//Отправка смс
    resultcode_sendsms: integer;
    timeoutindeletesms: integer; //Таймаут на удаление смс
    Serial: TBlockSerial;
    deletemsg: array of integer;
    //_servicearray: string;
    //_recvs,_recvsOK:string;
    tempsendsms: string;
    procedure tickSendsms();
    procedure MyStart();
    procedure TextSendAdd(s: string);
    procedure TextRecvAdd(s: string);
    procedure TextSmsAdd(s: string);
    procedure Str2Operator(s: string);
    procedure Str2Nomer(s: string);
    function ParseCFUN(s: string): integer;
    function _RPORT_STATE: TPORT_STATE;
    procedure _WPORT_STATE(const Value: TPORT_STATE);
    function _RMODEM_STATE: byte;
    procedure _WMODEM_STATE(const Value: byte);
    function _RNOMER: string;
    procedure _WNOMER(const Value: string);
    function _RARENDATYPE: integer;
    procedure _WARENDATYPE(const Value: integer);
    function _RSELECTED: boolean;
    procedure _WSELECTED(const Value: boolean);
    function _RCHECKALL: integer;
    procedure _WCHECKALL(const Value: integer);
    function _RPULS: boolean;
    procedure _WPULS(const Value: boolean);
    function _RCOMMENT: string;
    procedure _WCOMMENT(const Value: string);
    function _RURL: string;
    procedure _WURL(const Value: string);
    function _Rticktack: longword;
    procedure _Wticktack(const Value: longword);
    function _Ruserid: integer;
    procedure _Wuserid(const Value: integer);
    function _Rstatesim: TSIM_OPERATOR_STATE;
    procedure _Wstatesim(const Value: TSIM_OPERATOR_STATE);
    function _Rmodemstate: byte;
    procedure _Wmodemstate(const Value: byte);
  public
    newsim: boolean;
    secondussdcmd: string;
    _cs: TCriticalSection;
    _ticktack: longword;
    _PORT_STATE: TPORT_STATE;
    _MODEM_STATE: byte;
    ModemModel: TSIMHUB_MODEL;
    operatorNomer: TSIM_OPERATOR;
    DEBUG_STATE, idthread, _arendatype, countsms, _userid: integer;

    RecvText, scom, _comment, _NOMER, _url, IMEI, ICC, ant, nomersmsservice, regOperator: string;
    _actsms: string;
    _SendText, _RecvText, _SmsText: TStringList;
    sms: MyFullSmS;
    sms2: array of MySmSPacket;
    _selected: boolean;
    _puls: boolean;
    smshistory: TArrayofMySmsinFile;
    _checkall: integer;
    __ticktack: integer;
     _modemstate: byte;
    _statesim: TSIM_OPERATOR_STATE;
    property ticktack: longword read _Rticktack write _Wticktack;
    property PORT_STATE: TPORT_STATE read _RPORT_STATE write _WPORT_STATE;
    property MODEM_STATE: byte read _RMODEM_STATE write _WMODEM_STATE;
    property nomer: string read _RNOMER write _WNOMER;
    property comment: string read _RCOMMENT write _WCOMMENT;
    property url: string read _RURL write _WURL;
    property arendatype: integer read _RARENDATYPE write _WARENDATYPE;
    property selected: boolean read _RSELECTED write _WSELECTED;
    property checkall: integer read _RCHECKALL write _WCHECKALL;
    property puls: boolean read _RPULS write _WPULS;
    property statesim: TSIM_OPERATOR_STATE read _Rstatesim write _Wstatesim;
    property modemstate: byte read _Rmodemstate write _Wmodemstate;
    procedure SetURL2Modem(Text: string);
    procedure ZaprosNomera();
    procedure SetNomer(s: string);
    procedure Activate();
    procedure Deactivate();
    procedure AddToSendSms(komu, Text: string);
    procedure AddToSendSms2(t: string);
    function SendSms_timeout(komu, text: string):integer;
    procedure Send(s: string);
    procedure SendUSSD(s: string);
    procedure OnSms(const date, Notkogo, Text: ansistring);
    procedure SMSHistoryLoadorClear();
    procedure SMSHistoryAdd(t: string); overload;
    procedure SMSHistoryAdd(ot, t: string); overload;
    procedure SMSHistoryAdd(date, ot, t: string); overload;
    function SMSHistoryDelete(time, otkogo, text: string):boolean;overload;
    function SMSHistoryDelete(id: integer):boolean;overload;
    procedure SaveToDb(force: boolean = false);
    constructor Create(i: integer);
    destructor Destroy; override;
  protected
    procedure ShowSms(a, b: string);
    function CheckMsg(hash: string): boolean;
    function Getsms2(l, k: integer; s: string; var Text: string): boolean;
    procedure ReadAll4(const s: ansistring);
    procedure ReadAll(const s: ansistring);
    procedure MyRecv();
    procedure SendandState(s: string);
    procedure RecvState(i: integer = -1);
    procedure WorkPort;
    procedure Execute; override;
  end;



implementation

uses
  maind;

procedure TMyModem.Str2Operator(s: string);
var
  toper: string;
begin
  if Pos('"', s) <> 0 then
    s := Copy(s, Pos('"', s) + 1, PosEx('"', s, Pos('"', s) + 1) - (Pos('"', s) + 1))
  else
    exit;
  toper := Upcase(s);
  case toper of
    //Россия
    'MTS-RUS', 'MTS RUS', 'MTS': OperatorNomer := SIM_MTS;
    '25099', 'BEE L', 'BEE LINE', 'BEELINE': OperatorNomer := SIM_BEELINE;
    'MEGAFON', 'NWGSM RUS': OperatorNomer := SIM_MEGAFON;
    '25020', '40177', 'CC 250 NC 03', 'TELE2', 'MOBILE TELECOM SERVICE': OperatorNomer := SIM_TELE2;
    //Казахстан
    'ALTEL': OperatorNomer := SIM_ALTEL;
    'KCELL': OperatorNomer := SIM_KCELL;
    'ASTELIT': OperatorNomer := SIM_ASTELIT;
    'LIVE:)', 'LIFECELL': OperatorNomer := SIM_LIFE;
    'ACTIV': OperatorNomer := SIM_ACTIV;
    'BEELINE KZ': OperatorNomer := SIM_BEELINE_KZ;
    //Украина
    'UA-KYIVSTAR', 'KYIVSTAR': OperatorNomer := SIM_KYIVSTAR;
    'MTS UKR': OperatorNomer := SIM_MTS_UKR;
    'UMC': OperatorNomer := SIM_UMC_UKR;
    'YEZZZ!': OperatorNomer := SIM_YEZZZ;
    //Белоруссия
    'MTS BY': OperatorNomer := SIM_MTCBY;
    'BY VELCOM': OperatorNomer := SIM_VELCOM;
  end;
end;

procedure TMyModem.Str2Nomer(s: string);
begin
  if (Pos('myphone', s) = 0) then
    exit;
  Delete(s, 1, Pos('"', s));
  nomer := '+' + Copy(s, 1, Pos('"', s) - 1);
end;

function TMyModem.ParseCFUN(s: string): integer;
begin
  Result := 1;
  Delete(s, 1, Pos('+CFUN:', s) + 5);
  s := Copy(s, 1, Pos(#10, s) - 1);
  try
    Result := StrToInt(s);
  finally

  end;
end;

procedure TMyModem.TextSendAdd(s: string);
begin
  _cs.Enter;
  try
    if _SendText.Count <> 0 then
      if _SendText.Strings[0] = s then
        Exit;
    _SendText.Text := s + #13#10 + _SendText.Text;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem.TextRecvAdd(s: string);
begin
  _cs.Enter;
  try
    if _RecvText.Count <> 0 then
      if _RecvText.Strings[0] = s then
        Exit;
    _RecvText.Text := s + #13#10 + _RecvText.Text;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem.TextSmsAdd(s: string);
begin
  _cs.Enter;
  try
    if _SmsText.Count <> 0 then
      if _SmsText.Strings[0] = s then
        Exit;
    _SmsText.Text := s + #13#10 + _SmsText.Text;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RPORT_STATE: TPORT_STATE;
begin
  _cs.Enter;
  try
    Result := _PORT_STATE;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WPORT_STATE(const Value: TPORT_STATE);
begin
  _cs.Enter;
  try
    _PORT_STATE := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RMODEM_STATE: byte;
begin
  _cs.Enter;
  try
    Result := _MODEM_STATE;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WMODEM_STATE(const Value: byte);
begin
  _cs.Enter;
  try
    _MODEM_STATE := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RNOMER: string;
begin
  _cs.Enter;
  try
    Result := _nomer;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WNOMER(const Value: string);
begin
  _cs.Enter;
  try
    _nomer := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RARENDATYPE: integer;
begin
  _cs.Enter;
  try
    Result := _arendatype;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WARENDATYPE(const Value: integer);
begin
  _cs.Enter;
  try
    _arendatype := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RSELECTED: boolean;
begin
  _cs.Enter;
  try
    Result := _selected;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WSELECTED(const Value: boolean);
begin
  _cs.Enter;
  try
    _selected := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RCHECKALL: integer;
begin
  _cs.Enter;
  try
    Result := _checkall;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WCHECKALL(const Value: integer);
begin
  _cs.Enter;
  try
    _checkall := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RPULS: boolean;
begin
  _cs.Enter;
  try
    Result := _puls;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WPULS(const Value: boolean);
begin
  _cs.Enter;
  try
    _puls := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RCOMMENT: string;
begin
  _cs.Enter;
  try
    Result := _comment;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WCOMMENT(const Value: string);
begin
  _cs.Enter;
  try
    _comment := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._RURL: string;
begin
  _cs.Enter;
  try
    Result := _url;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._WURL(const Value: string);
begin
  _cs.Enter;
  try
    _url := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._Rticktack: longword;
begin
  _cs.Enter;
  try
    Result := _ticktack;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._Wticktack(const Value: longword);
begin
  _cs.Enter;
  try
    _ticktack := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._Ruserid: integer;
begin
  _cs.Enter;
  try
    Result := _userid;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._Wuserid(const Value: integer);
begin
  _cs.Enter;
  try
    _userid := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._Rstatesim: TSIM_OPERATOR_STATE;
begin
  _cs.Enter;
  try
    Result := _statesim;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._Wstatesim(const Value: TSIM_OPERATOR_STATE);
begin
  _cs.Enter;
  try
    _statesim := Value;
  finally
    _cs.Leave;
  end;
end;

function TMyModem._Rmodemstate: byte;
begin
  _cs.Enter;
  try
    Result := _modemstate;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem._Wmodemstate(const Value: byte);
begin
  _cs.Enter;
  try
    _modemstate := Value;
  finally
    _cs.Leave;
  end;
end;

constructor TMyModem.Create(i: integer);
begin
  inherited Create(False);
  secondussdcmd := '';
  _cs := TCriticalSection.Create();
  ticktack := GetTickCount64();
  idthread := i;
  __ticktack := 0;
  PORT_STATE := PORT_CREATE;
  MODEM_STATE := MODEM_NULL;
  ModemModel := MODEL_UNKOWN;
  DEBUG_STATE := 0;
  operatorNomer := SIM_UNKNOWN;
  countsms := 0;
  RecvText := '';
  scom := '';
  comment := '';
  url := '';
  _sendtimeout := 0;
  _counttimeoutsend := 0;
  timeoutinsendsms := 0;
  resultcode_sendsms := 0;
  nomer := data_neopredelen;
  IMEI := '123456789012345';
  ICC := '123456789012345';
  ant := '';
  nomersmsservice := '';
  regOperator := '';
  SetLength(smshistory, 0);
  modemstate := $ff;
  statesim := SIM_UKNOW_STATE;
  _SendText := TStringList.Create();
  _RecvText := TStringList.Create();
  _SmsText := TStringList.Create();
  newsim := false;
end;

destructor TMyModem.Destroy;
begin
  _cs.Free;
end;

procedure TMyModem.SetURL2Modem(Text: string);
begin
  URL := Text;
end;

procedure TMyModem.ZaprosNomera();
begin
  nomer := Nomer_Neopredelen;
  SMSHistoryLoadorClear();
  case OperatorNomer of
    SIM_MTS: SendUSSD('*111*0887#');
    SIM_BEELINE: SendUSSD('*110*10#'); //SendUSSD('*160#');
    SIM_MEGAFON: SendUSSD('*205#');
    SIM_TELE2: SendUSSD('*201#'); //SendUSSD('*201#');

    SIM_KCELL: SendUSSD('*114#');
    SIM_ALTEL: SendUSSD('*802#');
    SIM_ASTELIT: SendUSSD('*114#');
    SIM_LIFE: SendUSSD('**161#');
    SIM_ACTIV: SendUSSD('*114#');

    SIM_KYIVSTAR: SendUSSD('*161#');
    SIM_UMC_UKR: SendUSSD('*161#');
    SIM_MTS_UKR: SendUSSD('*161#');
    SIM_YEZZZ: SendUSSD('*161#');

    SIM_VELCOM: SendUSSD('*147#');
    SIM_MTCBY: SendUSSD('*147#');
    SIM_BEELINE_KZ: SendUSSD('*160#');
  end;
end;

procedure TMyModem.SetNomer(s: string);
begin
  nomer := s;
  SMSHistoryLoadorClear();
  SaveToDb();
end;

procedure TMyModem.Activate();
var
  opera: string;
begin
  if (nomer = Nomer_Neopredelen) then
    exit;
  ShowSms('0', ' активирован.');
  SMSHistoryAdd('Активирован.');
  opera := operator_names[operatorNomer];
  starter.AddToActivateNomer(nomer, opera, 'ACTIVE');
end;

procedure TMyModem.Deactivate();
var
  opera: string;
begin
  if (nomer = Nomer_Neopredelen) then
    exit;
  ShowSms('0', ' деактивирован.');
  SMSHistoryAdd('Деактивирован.');
  opera := operator_names[operatorNomer];
  starter.AddToActivateNomer(nomer, opera, 'DEACTIVE');
end;

procedure TMyModem.AddToSendSms(komu, Text: string);
begin
  _cs.Enter;
  try
    SetLength(sendsms, Length(sendsms) + 1);
    sendsms[High(sendsms)].komu := StringReplace(komu, '+', '', [rfreplaceall]);
    sendsms[High(sendsms)].Text := Text;
  finally
    _cs.Leave;
  end;
end;

procedure TMyModem.AddToSendSms2(t: string);
var
  komu, text: string;
begin
  komu := Copy(t,1,Pos(' ',t)-1);
  text := t;
  Delete(text, 1, Pos(' ',text));
  AddToSendSms(komu,text);
end;

function TMyModem.SendSms_timeout(komu, text: string): integer;
var
  timeout: integer;
begin
  resultcode_sendsms := 0;
  timeout := 600;
  AddToSendSms(komu, text);
  while (timeout<>0)AND(resultcode_sendsms=0) do
  begin
    dec(timeout);
    sleep(50);
  end;
  result := resultcode_sendsms;
end;

procedure TMyModem.SendUSSD(s: string);
begin
  case ModemModel of
    Q2403:
      Send('AT+CUSD=1,"' + s + '"');
    TC35i:
      Send('ATD' + s + ';');
    MC55:
      Send('ATD' + s + ';');
    M35:
      Send('AT+CUSD=1,"' + s + '"'); //Send('ATD' + s + ';');
    else
      Send('AT+CUSD=1,"' + s + '"');
  end;
end;

procedure TMyModem.SMSHistoryLoadorClear();
begin
  SetLength(smshistory, 0);
  if nomer = Nomer_Neopredelen then
    exit;
  starter.DB_loadsms(idthread);
end;

procedure TMyModem.Send(s: string);
var
  sa: ansistring;
begin
  try
    sa := ansistring(s) + ansichar($0D);
    if Serial.InstanceActive then
      Serial.SendString(sa);
    TextSendAdd(s);
  except
    on E: Exception do
      TextSmsAdd('error_send{' + E.ClassName + '}[' + E.Message + ']');
  end;
end;

procedure TMyModem.SendandState(s: string);
begin
  _sendtimeout := 1;
  Send(s);
  MODEM_STATE := MODEM_STATE + 1;
  sleep(100);
end;

procedure TMyModem.RecvState(i: integer = -1);
begin
  if i = -1 then
    MODEM_STATE := MODEM_STATE + 1
  else
    MODEM_STATE := i;
  _sendtimeout := 0;
  _counttimeoutsend := 0;
end;

procedure TMyModem.ReadAll(const s: ansistring);
var
  k, l: integer;
  t, j: ansistring;
  temp: byte;
begin
  try
    sms.tpudhsize := 0;
    l := 0;
    k := 0;
    t := s;
    Delete(t, 1, Pos('+CMGR:', t));

    Delete(t, 1, Pos(#10, t));
    sms.tpsca[0] := MyReadByte(t);

    sms.tpsca[1] := MyReadByte(t);

    sms.Nservice := Copy(t, 1, (sms.tpsca[0] - 1) * 2);
    Delete(t, 1, (sms.tpsca[0] - 1) * 2);

    sms.tpmti := MyReadByte(t);
    sms.tpoa[0] := MyReadByte(t);
    sms.tpoa[1] := MyReadByte(t);

    temp := sms.tpoa[1] and $70;

    if (temp = 0) or (temp = $10) then
    begin
      if (sms.tpoa[0] and 1) = 0 then
      begin
        sms.Notkogo := MyFormatNomer(Copy(t, 1, sms.tpoa[0]));
        Delete(t, 1, sms.tpoa[0]);
      end
      else
      begin
        sms.Notkogo := MyFormatNomer(Copy(t, 1, sms.tpoa[0] + 1));
        Delete(t, 1, sms.tpoa[0] + 1);
      end;
    end;

    if temp = $50 then
    begin
      sms.Notkogo := MyReadByteS(t, Ceil(sms.tpoa[0] / 2));
      sms.Notkogo := Bit7tostring2(sms.Notkogo, round((sms.tpoa[0] / 2) / 0.875), 0);
    end;
    sms.tpid := MyReadByte(t);
    sms.tpdcs := MyReadByte(t);

    sms.tpscts := MyReadByteS2(t, 7);
    sms.tpscts := myswaptime(sms.tpscts);
    sms.tpudl := MyReadByte(t);

    if ((sms.tpmti and $40) <> 0) and (sms.tpdcs <> $0) then
    begin
      sms.tpudhsize := MyReadByte(t);
      sms.tpudl := sms.tpudl - sms.tpudhsize;
      j := MyReadByteS(t, sms.tpudhsize - 2);
      l := MyReadByte(t);
      k := MyReadByte(t);
    end;

    if ((sms.tpmti and $40) <> 0) and (sms.tpdcs = $0) then
    begin
      sms.tpudhsize := MyReadByte(t);
      sms.tpudl := sms.tpudl - sms.tpudhsize - 2;
      j := MyReadByteS(t, sms.tpudhsize - 2);
      l := MyReadByte(t);
      k := MyReadByte(t);
      sms.tpudhsize := sms.tpudhsize + 1;
    end;

    case sms.tpdcs of
      $0:
        sms.Text := Bit7tostring2(MyReadByteS(t, ceil((sms.tpudl * 7) / 8)), sms.tpudl, sms.tpudhsize);
      $01:
        sms.Text := Bit7tostring2(MyReadByteS(t, ceil((sms.tpudl * 7) / 8)), sms.tpudl, sms.tpudhsize);
      $08:
        sms.Text := UCSToAnsi(MyReadByteS(t, sms.tpudl));
      $10:
        sms.Text := Bit7tostring2(MyReadByteS(t, ceil((sms.tpudl * 7) / 8)), sms.tpudl, sms.tpudhsize);
      $F5:
        sms.Text := UCSToAnsi(MyReadByteS(t, sms.tpudl));
      else
        TextSmsAdd('SMS ошибка:"' + sms.Notkogo + '" ' + ':' + inttohex(sms.tpdcs, 2));
    end;

    if sms.tpudhsize <> 0 then
      if Getsms2(l, k, j, sms.Text) = False then
        exit;
    OnSms(sms.tpscts, sms.Notkogo, sms.Text);
  except
    on E: Exception do
      TextSmsAdd('ReadAll:' + E.ClassName + ':' + E.Message + 'thread' + IntToStr(idthread));
  end;
end;

procedure TMyModem.ReadAll4(const s: ansistring);
var
  k, l: integer;
  t, j: string;
  temp: byte;
  _debugstate: byte;
begin
  l := 0;
  k := 0;
  t := s;
  _debugstate := 0;
  while (Pos('+CMGL: ', t) <> 0) do
  begin
    try
      _debugstate := 1;
      sms.tpudhsize := 0;
      Delete(t, 1, Pos('+CMGL: ', t) + 6);
      sms.id := StrToInt(Copy(t, 1, Pos(',', t) - 1));
      Delete(t, 1, Pos(#10, t));
      sms.tpsca[0] := MyReadByte(t);
      sms.tpsca[1] := MyReadByte(t);
      _debugstate := 2;
      if (sms.tpsca[0] = $00) and (sms.tpsca[1] = $FF) then
      begin
        SetLength(deletemsg, Length(deletemsg) + 1);
        deletemsg[High(deletemsg)] := sms.id;
        Continue;
      end;
      _debugstate := 3;
      sms.Nservice := Copy(t, 1, (sms.tpsca[0] - 1) * 2);
      Delete(t, 1, (sms.tpsca[0] - 1) * 2);
      sms.tpmti := MyReadByte(t);
      sms.tpoa[0] := MyReadByte(t);
      sms.tpoa[1] := MyReadByte(t);
      temp := sms.tpoa[1] and $70;
      _debugstate := 4;
      if (temp = 0) or (temp = $10) then
      begin
        if (sms.tpoa[0] and 1) = 0 then
        begin
          sms.Notkogo := MyFormatNomer(Copy(t, 1, sms.tpoa[0]));
          Delete(t, 1, sms.tpoa[0]);
        end
        else
        begin
          sms.Notkogo := MyFormatNomer(Copy(t, 1, sms.tpoa[0] + 1));
          Delete(t, 1, sms.tpoa[0] + 1);
        end;
      end;
      _debugstate := 5;
      if (temp = $50) or (temp = $20) then
      begin
        sms.Notkogo := MyReadByteS(t, Ceil(sms.tpoa[0] / 2));
        sms.Notkogo := Bit7tostring2(sms.Notkogo, round((sms.tpoa[0] / 2) / 0.875), 0);
      end;
      _debugstate := 6;
      sms.tpid := MyReadByte(t);
      sms.tpdcs := MyReadByte(t);
      sms.tpscts := MyReadByteS2(t, 7);
      sms.tpscts := myswaptime(sms.tpscts);
      sms.tpudl := MyReadByte(t);
      _debugstate := 7;
      if ((sms.tpmti and $40) <> 0) and (sms.tpdcs <> $0) then
      begin
        sms.tpudhsize := MyReadByte(t);
        sms.tpudl := sms.tpudl - sms.tpudhsize;
        j := MyReadByteS(t, sms.tpudhsize - 2);
        l := MyReadByte(t);
        k := MyReadByte(t);
      end;
      _debugstate := 8;
      if ((sms.tpmti and $40) <> 0) and (sms.tpdcs = $0) then
      begin
        sms.tpudhsize := MyReadByte(t);
        sms.tpudl := sms.tpudl - sms.tpudhsize - 2;
        j := MyReadByteS(t, sms.tpudhsize - 2);
        l := MyReadByte(t);
        k := MyReadByte(t);
        sms.tpudhsize := sms.tpudhsize + 1;
      end;
      _debugstate := 9;
      case sms.tpdcs of
        $0:
          sms.Text := Bit7tostring2(MyReadByteS(t, ceil((sms.tpudl * 7) / 8)), sms.tpudl, sms.tpudhsize);
        $01:
          sms.Text := Bit7tostring2(MyReadByteS(t, ceil((sms.tpudl * 7) / 8)), sms.tpudl, sms.tpudhsize);
        $08:
          sms.Text := UCSToAnsi(MyReadByteS(t, sms.tpudl));
        $10:
          sms.Text := Bit7tostring2(MyReadByteS(t, ceil((sms.tpudl * 7) / 8)), sms.tpudl, sms.tpudhsize);
        $F5:
          sms.Text := UCSToAnsi(MyReadByteS(t, sms.tpudl));
        else
          TextSmsAdd('SMS ошибка:"' + sms.Notkogo + '" ' + ':' + inttohex(sms.tpdcs, 2));
      end;
      _debugstate := 10;
      SetLength(deletemsg, Length(deletemsg) + 1);
      deletemsg[High(deletemsg)] := sms.id;
      _debugstate := 11;
      if sms.tpudhsize <> 0 then
        if Getsms2(l, k, j, sms.Text) = False then
          continue;
      _debugstate := 12;
      OnSms(sms.tpscts, sms.Notkogo, sms.Text);
    except
      on E: Exception do
        TextSmsAdd('ReadAll4:' + E.ClassName + ':' + E.Message + 'thread:' + IntToStr(idthread) + ':[' + IntToStr(_debugstate) + ']');
    end;
  end;
end;

function TMyModem.Getsms2(l, k: integer; s: string; var Text: string): boolean;
var
  i, t: integer;
  temp: string;
begin
  Result := False;
  t := -1;
  for i := 0 to High(sms2) do
    if sms2[i].Name = s then
      t := i;

  if t <> -1 then
  begin
    sms2[t].Text[k - 1] := Text;
  end
  else
  begin
    SetLength(sms2, Length(sms2) + 1);
    t := High(sms2);
    sms2[t].Name := s;
    SetLength(sms2[t].Text, l);
    for i := 0 to High(sms2[t].Text) do
      sms2[t].Text[i] := '';
    sms2[t].Text[k - 1] := Text;
  end;

  temp := '';
  for i := 0 to High(sms2[t].Text) do
    if sms2[t].Text[i] <> '' then
      temp := temp + sms2[t].Text[i]
    else
      exit;

  Text := temp;
  Result := True;

  for i := t + 1 to Length(sms2) - 1 do
    sms2[i - 1] := sms2[i];
  SetLength(sms2, Length(sms2) - 1);
end;

function TMyModem.CheckMsg(hash: string): boolean;
var
  i: integer;
begin
  Result := False;
  for I := 0 to High(Last10sms[idthread]) do
    if Last10sms[idthread, i] = hash then
    begin
      Result := True;
      exit;
    end;
  if length(Last10sms[idthread]) < 10 then
  begin
    SetLength(Last10sms[idthread], length(Last10sms[idthread]) + 1);
    Last10sms[idthread, High(Last10sms[idthread])] := hash;
  end
  else
  begin
    DeleteArrayIndex(last10sms[idthread], 0);
    SetLength(Last10sms[idthread], length(Last10sms[idthread]) + 1);
    Last10sms[idthread, High(Last10sms[idthread])] := hash;
  end;
end;

procedure TMyModem.SMSHistoryAdd(t: string);
begin
  SMSHistoryAdd(TimeDMYHM(), 'SYSTEM', t);
end;

procedure TMyModem.SMSHistoryAdd(ot, t: string);
begin
  SMSHistoryAdd(TimeDMYHM, ot, t);
end;

procedure TMyModem.SMSHistoryAdd(date, ot, t: string);
var
  f: Textfile;
  i: integer;
begin
  if nomer = Nomer_Neopredelen then
    exit;
  SetLength(smshistory, Length(smshistory) + 1);
  smshistory[High(smshistory)].idinbase := 0;
  smshistory[High(smshistory)].datetime := date;
  smshistory[High(smshistory)].otkogo := ot;
  smshistory[High(smshistory)].Text := t;
  starter.DB_addsms(nomer, date, ot, t);
  ForceDirectories(extractfilepath(ParamStr(0)) + 'data');
  AssignFile(f, extractfilepath(ParamStr(0)) + 'data' + _DIROS + nomer + '.txt');
  try
    if FileExists(extractfilepath(ParamStr(0)) + 'data' + _DIROS + nomer + '.txt') = False then
      Rewrite(f)
    else
      Append(f);
    writeln(f, ReplaceProbel(smshistory[High(smshistory)].datetime) + 'tjJyA' + ReplaceProbel(smshistory[High(smshistory)].otkogo) +
      'tjJyA' + ReplaceProbel(smshistory[High(smshistory)].Text));
  finally
    CloseFile(f);
  end;

  for i:=0 to High(smshistory) do
    if (starter.SMSCheckService('aa', smshistory[i].otkogo, smshistory[i].Text)<>'') then
    begin
      ForceDirectories(extractfilepath(ParamStr(0)) + 'data2');
      AssignFile(f, extractfilepath(ParamStr(0)) + 'data2' + _DIROS + nomer + '.txt');
      try
        if FileExists(extractfilepath(ParamStr(0)) + 'data2' + _DIROS + nomer + '.txt') = False then
          Rewrite(f)
        else
          Append(f);
        writeln(f, ReplaceProbel(smshistory[High(smshistory)].datetime) + 'tjJyA' + ReplaceProbel(smshistory[High(smshistory)].otkogo) +
          'tjJyA' + ReplaceProbel(smshistory[High(smshistory)].Text));
      finally
        CloseFile(f);
      end;
      exit;
    end;
end;

function TMyModem.SMSHistoryDelete(time, otkogo, text: string): boolean;
var
  i: integer;
begin
  result := false;
  if nomer = Nomer_Neopredelen then
    exit;

  for i:=0 to High(smshistory) do
  begin
    if ((smshistory[i].datetime=time)AND
    (smshistory[i].otkogo=otkogo)AND
    (smshistory[i].text=text)) then
    begin
      DeleteArrayIndex(smshistory, i);
      if (smshistory[i].idinbase<>0) then
        starter.DB_deletesms(smshistory[i].idinbase)
      else
        starter.DB_deletesms(nomer, time, otkogo, text);
      exit(true);
    end;
  end;
end;

function TMyModem.SMSHistoryDelete(id: integer): boolean;
begin
  result := false;
  if (smshistory[id].idinbase<>0) then
    starter.DB_deletesms(smshistory[id].idinbase)
  else
    starter.DB_deletesms(nomer, smshistory[id].datetime, smshistory[id].otkogo, smshistory[id].text);
  DeleteArrayIndex(smshistory, id);
  exit(true);
end;

procedure TMyModem.SaveToDb(force: boolean);
var
  s: string;
begin
  s := starter.DB_getvalue(IMEI);
  if ((s <> '')AND(force=false)) then
  begin
    starter.DB_setvalue(IMEI, ParseConfigData(s) + ',' + nomer + ',' + ICC)
  end
  else
  begin
    starter.DB_setvalue(IMEI, IntToStr(idthread + 1) + ',' + nomer + ',' + ICC);
  end;
end;

procedure TMyModem.tickSendsms();
var
  telpdu, textpdu : string;
begin
  if length(sendsms[0].Text) > 70 then
  begin
    TextSmsAdd('Не удалось отправить на ' + sendsms[0].komu + ', больше 70 символов.');
    DeleteArrayIndex(sendsms, 0);
    exit;
  end;
  telpdu := '0100' + NormalNomer2PDU(SendSms[0].komu);
  textpdu := utf16tohex(SendSms[0].text);
  textpdu := telpdu + '00'+'0'+'8' + Format('%.2x',[Length(textpdu) div 2]) + textpdu;
  tempsendsms := '00' + textpdu;
  if (ModemModel=MC55) then
  begin
    Send('AT+CMGF=1');
    sleep(50);
    if ((Length(SendSms[0].komu)=11)AND(SendSms[0].komu[1]='7')) then
      Send('AT+CMGS="+' + SendSms[0].komu + '"')
    else
      Send('AT+CMGS="' + SendSms[0].komu + '"');
  end
  else
    Send('AT+CMGS=' + IntToStr(ceil(Length(textpdu) / 2)));

  _sendtimeout := 0;
  timeoutinsendsms := 0;
  MODEM_STATE := MODEM_SMS_SEND_NEEDACCEPT;
end;

procedure TMyModem.MyStart();
begin
  ShowSms('', TimeHM + ' запустился.');
  if (nomer = Nomer_Neopredelen) then
    ZaprosNomera();
  if (OperatorNomer = SIM_UNKNOWN) then
  begin
    //ShowSms(IntToStr(idthread), IntToStr(idthread) + ' Неизвестный оператор');
    TextSmsAdd('Thread:' + IntToStr(idthread) + ' Sms:' + IntToStr(countsms) + ' ' + operator_names[operatorNomer]);
  end
  else
  begin
    TextSmsAdd('Thread:' + IntToStr(idthread) + ' Sms:' + IntToStr(countsms) + ' ' + operator_names[operatorNomer]);
  end;

  if ModemModel = MODEL_UNKOWN then
  begin
    TextSmsAdd('Не удалось определить модем!');
  end;

  SMSHistoryLoadorClear();
  Checkall := 1;
  try
    if Length(smshistory)=0 then
      exit;
    if (DateTimeToUnix(Now())-DateTimeToUnix(StrToDateTime(StringReplace(smshistory[0].datetime, '-', '-', [rfreplaceall]))))<600 then
    begin
      TextSmsAdd('Новая сим, 10 мин');
      newsim := true;
    end;
  except
    on E: Exception do
    begin
      debuglog(smshistory[0].datetime+'!' + E.ClassName + ':' + E.Message);
    end;
  end;
end;

procedure TMyModem.ShowSms(a, b: string);
begin
  if (a <> '') then
  begin
    MainMemoWrite(b, idthread);
  end;
  TextSmsAdd(b);
end;

procedure TMyModem.OnSms(const date, Notkogo, Text: ansistring);
var
  restriggers: string;
begin
  if (starter.SMSCheckService('ignore', Notkogo, Text)<>'') then
    exit;
  if CheckMsg(hashb(Notkogo + date + Text, 128)) = False then
  begin

  end
  else
  begin
    //ShowSms('ПОВТОР:"' + Notkogo + '"', 'ПОВТОР:"' + Notkogo + '" ' + date + '->' + Text);
    exit;
  end;

  if ((UTF8Pos('Сіздің нөміріңіз', Text) <> 0) or (UTF8Pos('nomer', Text) <> 0) or (UTF8Pos('номер', Text) <> 0) or (UTF8Pos('Номер', Text) <> 0) or
    (UTF8Pos('Vash nomer velcom:', Text) <> 0) or (UTF8Pos('Vash nomer:', Text) <> 0)) and (Nomer = Nomer_Neopredelen) then
  begin
    if (Length(GetNumber(Text)) = 11) then
      nomer := '+'+GetNumber(Text)
    else
      if (Length(GetNumber(Text)) = 12) then
      nomer := '+' + GetNumber(Text);
    case OperatorNomer of
      SIM_MTS:
      begin

      end;
      SIM_BEELINE:
      begin

      end;
      SIM_MEGAFON:
      begin
        if (Length(GetNumber(Text)) = 10) then
          nomer := '+7' + GetNumber(Text);
      end;
      SIM_TELE2:
      begin
        if (UTF8Pos('Ваш федеральный номер +7', Text)<>0) then
          nomer := '+'+Copy(GetNumber(Text),1,11);
      end;
      SIM_ALTEL:
      begin

      end;
      SIM_ASTELIT:
      begin

      end;
      SIM_KCELL:
      begin

      end;
      SIM_LIFE:
      begin

      end;
      SIM_ACTIV:
      begin

      end;
      SIM_KYIVSTAR:
      begin

      end;
      SIM_MTS_UKR:
      begin

      end;
      SIM_UMC_UKR:
      begin

      end;
      SIM_MTCBY:
      begin

      end;
      SIM_VELCOM:
      begin

      end;
    end;
    if isPhoneNomer(nomer) then
    begin
      SMSHistoryLoadorClear();
      SMSHistoryAdd(Text);
      SaveToDb();
    end
    else
      nomer := Nomer_Neopredelen;
  end;
  if (nomer = Nomer_Neopredelen) and (Text = 'Неверный сервисный номер') and (OperatorNomer = SIM_TELE2) then
  begin
    OperatorNomer := SIM_ALTEL;
    PORT_STATE := PORT_ZAPROS_NOMERA;
    ShowSms('', '[' + date + ']' + Notkogo + '->' + Text);
    exit;
  end;
  if (nomer = Nomer_Neopredelen) and (Pos('IMSI:', Text) <> 0) and (OperatorNomer = SIM_KYIVSTAR) then
  begin
    OperatorNomer := SIM_BEELINE;
    PORT_STATE := PORT_ZAPROS_NOMERA;
    ShowSms('', '[' + date + ']' + Notkogo + '->' + Text);
    exit;
  end;
  if (nomer = Nomer_Neopredelen) and (Notkogo = 'USSD') then
  begin
    ShowSms('', '[' + date + ']' + Notkogo + '->' + Text);
    exit;
  end;
  restriggers := starter.SMSCheckTriggers(Notkogo, text);
  if (restriggers<>'') then
  begin
    ShowSms('', 'Trigger[' + date + ']' + Notkogo + '->' + Text);
    if (restriggers='reset') then
    begin
      Send('AT+CFUN=1,1');
      sleep(2000);
      PORT_STATE := PORT_RESTART;
    end;
    if (Copy(restriggers, 1, Pos(':',restriggers)-1)='CALL') then
    begin
      Send('ATD'+Copy(restriggers, Pos(':', restriggers) + 1, Length(restriggers) - Pos(':', restriggers))+';');
    end
    else if (Copy(restriggers, 1, Pos(':',restriggers)-1)='USSD') then
    begin
      SendUSSD(Copy(restriggers, Pos(':', restriggers) + 1, Length(restriggers) - Pos(':', restriggers)));
    end else
      AddToSendSms(Copy(restriggers, 1, Pos(':',restriggers)-1), Copy(restriggers, Pos(':', restriggers) + 1, Length(restriggers) - Pos(':', restriggers)));
    exit;
  end;
  ShowSms(Notkogo, '[' + date + ']' + Notkogo + '->' + Text);
  starter.Telegram_SendSMS(nomer, Notkogo, Text);
  SMSHistoryAdd(date, Notkogo, Text);
  starter.AddToSendSms(nomer, Notkogo, Text, date);
end;

procedure TMyModem.WorkPort;
var
  tmps: string;
  i: integer;
begin
  case MODEM_STATE of
    MODEM_NULL:
    begin
      try
        if (starter.bindimei=false) then
        begin
          tmps := starter.DB_getvalue(scom);
          if (tmps<>'') then
          begin
            i := StrToInt(tmps);
            if ((i>=0)AND(i<=High(AM))) then
              starter.SwapThread(idthread, i);
          end;
        end;
        Serial := TBlockSerial.Create;
        Serial.RaiseExcept := True;
        Serial.LinuxLock := True;
          {$IFDEF UNIX}
        Serial.Connect('/dev/serial/by-path/' + scom);
          {$ELSE}
        Serial.Connect(scom);
          {$ENDIF}
        Serial.Config(115200, 8, 'N', 0, False, False);
        Sleep(50);
        if (Serial.InstanceActive = False) then
        begin
          MODEM_STATE := MODEM_FATAL_ERROR;
          PORT_STATE := PORT_DISCONNECT;
          exit;
        end;
          {$IFDEF UNIX}
        TextSendAdd(scom);
          {$ELSE}
        TextSendAdd(scom);
          {$ENDIF}
        MODEM_STATE := MODEM_STATE + 1;
      except
        on E: Exception do
        begin
              {$IFDEF linux}
          TextSendAdd('ERROR SERIAL!' + E.ClassName + ':' + E.Message);
          TextSendAdd('[' + scom + ']');
              {$ENDIF}
              {$IFDEF windows}
          TextSendAdd('ERROR SERIAL!' + E.ClassName + ':' + E.Message + scom);
              {$ENDIF}
          MODEM_STATE := MODEM_FATAL_ERROR;
          PORT_STATE := PORT_DISCONNECT;
          exit;
        end;
      end;
    end;
    MODEM_ERROR:
    begin
      Sleep(2500);
      exit;
    end;
    MODEM_FATAL_ERROR:
    begin
      Sleep(5000);
      exit;
    end;
    MODEM_WAIT_WHILE:
    begin
      Sleep(2500);
      exit;
    end;
    MODEM_NEED_RESTART_AT_CPMS:
    begin
      if Checkall = 1 then
        CheckAll := 2;
      Sleep(250);
      MODEM_STATE := MODEM_AS_CPMS;
      exit;
    end;
    MODEM_NEED_RESTART_AT:
    begin
      CheckAll := 0;
      Sleep(250);
      _cs.Enter;
      try
        _SendText.Clear;
        _RecvText.Clear;
      finally
        _cs.Leave;
      end;

      MODEM_STATE := MODEM_AS_ATE0;
      exit;
    end;
    MODEM_AS_ATE0: SendandState('ATE0');
    MODEM_AS_ATI:
    begin
      SendandState('ATI');
      OperatorNomer := SIM_UNKNOWN;
    end;
    MODEM_AS_CGSN: SendandState('AT+CGSN');
    MODEM_AS_CFUN: SendandState('AT+CFUN?');
    MODEM_AS_CMEE: SendandState('AT+CMEE=1');
    MODEM_AS_CMGF: SendandState('AT+CMGF=0');
    MODEM_AS_CPIN: SendandState('AT+CPIN?');
    MODEM_AS_ICC:
      case ModemModel of
        Q2403: SendandState('AT+CCID');
        TC35i: SendandState('AT+CXXCID');
        MC55: SendandState('AT+CXXCID');
        M35: SendandState('AT+QCCID');
        M590: SendandState('AT+CCID');
        else
          SendandState('AT+CXXCID');
      end;
    MODEM_AS_CREG: SendandState('AT+CREG?');
    MODEM_AS_COPS: SendandState('AT+COPS?');
    MODEM_AS_QSPN:
    begin
      if (ModemModel=M35) then
        SendandState('AT+QSPN?')
      else
        MODEM_STATE := MODEM_STATE +2;
    end;
    MODEM_AS_CPBR:
    begin
      //if ((ModemModel=M35)OR(ModemModel=TC35i))AND(nomer=Nomer_Neopredelen) then
      SendandState('AT+CPBR=1')
      //else
      //  MODEM_STATE := MODEM_STATE +2;
    end;
    MODEM_AS_CPAS: SendandState('AT+CPAS');
    MODEM_AS_CSQ: SendandState('AT+CSQ');
    MODEM_AS_CNMI: SendandState('AT+CNMI=2,1,0,0');
    MODEM_AS_CSCA: SendandState('AT+CSCA?');
    MODEM_AS_CPMS:
      case ModemModel of
        Q2403: SendandState('AT+CPMS="SM"');
        TC35i: SendandState('AT+CPMS="MT"');
        MC55: SendandState('AT+CPMS="MT"');
        M35: SendandState('AT+CPMS="MT"');
        else
          SendandState('AT+CPMS="SM"');
      end;
    MODEM_AS_CMGL: SendandState('AT+CMGL=4');

    MODEM_MAIN_WHILE:
    begin
      if Length(deletemsg) <> 0 then
      begin
        Send('AT+CMGD=' + IntToStr(deletemsg[High(deletemsg)]));
        SetLength(deletemsg, Length(deletemsg) - 1);
        MODEM_STATE := MODEM_AS_DELETEMSG;
        timeoutindeletesms := 0;
        exit;
      end;

      if Length(sendsms) <> 0 then
      begin
        tickSendsms();
      end;
        {else
        if countsms <> 0 then
        begin
          countsms := 0;
          Send('AT+CMGL=4');
          MODEM_STATE:=MODEM_AR_CMGL;
          exit;
          //sleep(10);
        end; }
      Inc(__ticktack);
      if (__ticktack > 100) and (Length(deletemsg) = 0) then
      begin
        MODEM_STATE := MODEM_NEED_RESTART_AT_CPMS;
        __ticktack := 0;
      end;
    end;
    MODEM_AS_DELETEMSG:
    begin
      Inc(timeoutindeletesms);
      if (timeoutindeletesms > 100) then
        PORT_STATE := PORT_RESTART;
    end;
    MODEM_SMS_SEND_NEEDACCEPT:
    begin
      Inc(timeoutinsendsms);
      sleep(250);
      if timeoutinsendsms = 40 then
      begin
        TextSmsAdd('Таймаут отправки смс.0');
        DeleteArrayIndex(sendsms, 0);
        Send(#26);
        MODEM_STATE := MODEM_MAIN_WHILE;
      end;
    end;
    MODEM_SMS_SEND_WAITACCEPT:
    begin
      Inc(timeoutinsendsms);
      sleep(250);
      if timeoutinsendsms = 25 then
      begin
        TextSmsAdd('Таймаут отправки смс.1');
        MODEM_STATE := MODEM_MAIN_WHILE;
      end;
    end;
    MODEM_LOAD_DATA:
    begin
      if (Length(IMEI) <> 15) or (IMEI = '123456789012345') then
      begin //Неверный серийник.
        RecvState(MODEM_AS_CGSN);
        exit;
      end;
      tmps := starter.DB_getvalue(IMEI);
      if (tmps <> '') then
      begin
        i := StrToInt(ParseConfigData(tmps)) - 1;
        if starter.bindimei then
          if ((i>=0)AND(i<=High(AM))) then
            starter.SwapThread(idthread, i);
        nomer := ParseConfigData(tmps);
        ICC := ParseConfigData(tmps);
      end;
      RecvState(MODEM_AS_ATI);
      exit;
    end;
  end;

  if Serial.InstanceActive then
    if Serial.CanReadEx(10) then
    begin
      MyRecv();
      if MODEM_STATE = MODEM_MAIN_WHILE then
        sleep(250);
    end
    else
      sleep(250);

  if _sendtimeout <> 0 then
    Inc(_sendtimeout);

  if _sendtimeout = 30 then//Таймаут на команду
  begin
    _sendtimeout := 0;
    MODEM_STATE := MODEM_STATE - 1;
    Inc(_counttimeoutsend);//Увеличиваем счетчик ошибок.
    if (_counttimeoutsend = 3) then
    begin
      TextSmsAdd('3 ошибки таймаут [' + MODEMSTATE2Str(MODEM_STATE) + '].');
      RecvState(MODEM_ERROR);
    end;
  end;
end;

procedure TMyModem.MyRecv();
var
  s, sok, temp, temphex, tmps: string;
  i, tempsize: integer;
  buff: array of byte;
  OKIN: boolean;
begin
  DEBUG_STATE := 1;
  tempsize := Serial.WaitingDataEx();
  SetLength(buff, tempsize);
  Serial.RecvBufferEx(@buff[0], tempsize, 0);
  temphex := '';
  temp := '';
  for i := 0 to High(buff) do
    if (($20 <= buff[i]) and (buff[i] <= $7E)) or (buff[i] = $0A) then
    begin
      temp := temp + Chr(buff[i]);
      RecvText := RecvText + Chr(buff[i]);
      temphex := temphex + IntToHex(buff[i], 2);
    end;

  temp := RecvText;
  if Pos(#10, temp) <> 0 then
  begin
    DEBUG_STATE := 2;
    s := '';
    sOK := '';
    OKIN := False;
    temp := RecvText;
    if Pos('OK' + #10, temp) <> 0 then
    begin
      OKIN := True;
      sOk := Copy(temp, 1, Pos('OK' + #10, temp) + 1);
      s := StringReplace(temp, #10, '<CR>', [rfreplaceall]);
      Delete(RecvText, 1, Pos('OK' + #10, RecvText) + 2);
      DEBUG_STATE := 3;
    end
    else
      while Pos(#10, temp) <> 0 do
      begin
        s := s + Copy(temp, 1, Pos(#10, temp));
        Delete(temp, 1, Pos(#10, temp));
        DEBUG_STATE := 4;
      end;
    DEBUG_STATE := 5;

    if (StringReplace(s, #10, '', [rfreplaceall]) = '')AND(Length(temp)<>2) then
      exit;

    if OKIN then
    begin
      TextRecvAdd(StringReplace(sOK, #10, '', [rfreplaceall]));

      case MODEM_STATE of
        MODEM_AR_ATI:
        begin
          if Pos('TC35i', sOK) <> 0 then
            ModemModel := TC35i;
          if Pos('MC39i', sOK) <> 0 then
            ModemModel := TC35i; //ModemModel := TC35i;
          if Pos('MC35i', sOK) <> 0 then
            ModemModel := TC35i;
          if Pos('MC52', sOK) <> 0 then
            ModemModel := MC55;
          if Pos('MC55', sOK) <> 0 then
            ModemModel := MC55;
          if Pos('M26', sOK) <> 0 then
            ModemModel := M35;
          if Pos('M35', sOK) <> 0 then
            ModemModel := M35;
          if Pos('WAVECOM', sOK) <> 0 then
            ModemModel := Q2403;
          if Pos('M590', sOK) <> 0 then
            ModemModel := M590;

          if ModemModel <> MODEL_UNKOWN then
          begin
            MODEM_STATE := MODEM_STATE + 1;
            exit;
          end
          else
          begin
            TextSmsAdd('E(AR_ATI):' + s);
            exit;
          end;
        end;
        MODEM_AR_CGSN://Серийный номер порта
        begin
          IMEI := GetNumber(sOK);
          //if GetCheckLuna(tempIMEI)=false then begin TextSmsAdd('E(AR_CGSN)LUNA:'+s); exit; end; //Убрал проверку на Luna
          MODEM_STATE := MODEM_LOAD_DATA;
          exit;
        end;
        MODEM_AR_CFUN:
        begin
          if (ParseCFUN(sOK) <> 1) then
          begin
            Send('AT+CFUN=1');
            sleep(2000);
            PORT_STATE := PORT_RESTART;
            exit;
          end;
          MODEM_STATE := MODEM_STATE + 1;
          exit;
        end;
        MODEM_AR_ATE0, MODEM_AR_CMEE, MODEM_AR_CMGF: //Не фани и Текстовый режим
        begin
          MODEM_STATE := MODEM_STATE + 1;
          exit;
        end;
        MODEM_AR_CPIN://Проверка сим
        begin
          if GetStatePin(sOK) = 'READY' then
          begin
            MODEM_STATE := MODEM_STATE + 1;
            exit;
          end
          else
          begin
            TextSmsAdd('E(AR_CPIN):' + s);
            exit;
          end;
        end;
        MODEM_AR_ICC://Проверка CIID
        begin
          if GetCheckLuna(GetNumber(sOK)) = False then
          begin
            {TextSmsAdd('E(AR_ICC)LUNA:' + s);
            exit;  }
          end;
          tmps := GetNumber(sOK);
          if (tmps <> ICC) then
          begin
            TextSmsAdd('Похоже вставлена новая сим карта, сбросываю номер.');
            CheckAll := 0;
            ICC := tmps;
            nomer := Nomer_Neopredelen;
            SaveToDb();
          end;
          RecvState();
          exit;
        end;
        MODEM_AR_CREG://Проверка сети
        begin
          statesim := TSIM_OPERATOR_STATE.parseCREG(s);
          TextRecvAdd(statesim.toString);
          if (statesim = SIM_REG_DENIED) then
          begin
            MODEM_STATE := MODEM_WAIT_WHILE;
            TextSmsAdd('Регистрации отказано.');
            exit;
          end;
          {if (statesim <> 1) then
          begin
            sleep(2000);
            PORT_STATE := PORT_RESTART;
            exit;
          end;}
          RecvState();
          exit;
        end;
        MODEM_AR_COPS://Чё за оператор
        begin
          Str2Operator(sOK);
          RecvState();
          exit;
        end;
        MODEM_AR_QSPN://Чё за оператор 2
        begin
          Str2Operator(sOK);
          if ((ModemModel=M35)OR(ModemModel=TC35i))AND(nomer=Nomer_Neopredelen) then
            RecvState()
          else
            RecvState(MODEM_AS_CPAS);
          exit;
        end;
        MODEM_AR_CPBR://Что за номер из адресной книги
        begin
          //+CPBR: 1,"77473985176",129,"myphone"
          Str2Nomer(sOK);
          RecvState();
          exit;
        end;
        MODEM_AR_CPAS://Готов модем?
        begin
          if (Str2GotovLiModem(sOK) = 0) or (Str2GotovLiModem(sOK) = 1) or (Str2GotovLiModem(sOK) = 2) then
          begin
            MODEM_STATE := MODEM_STATE + 1;
            exit;
          end
          else
            TextSmsAdd('МОДЕМ НЕ ГОТОВ?');
        end;
        MODEM_AR_CSQ://Уровень сигнала
        begin
          ant := Str2UrovenSignala(sOK);
          RecvState();
          exit;
        end;
        MODEM_AR_CNMI://Уровень сигнала
        begin
          RecvState();
          exit;
        end;
        MODEM_AR_CSCA: //Сервис смс
        begin
          nomersmsservice := GetSmSService(sOK);
          case OperatorNomer of
            SIM_MTS: ;
            SIM_BEELINE: ;
            SIM_MEGAFON: ;
            SIM_TELE2: ;
            SIM_ALTEL: ;
            SIM_KCELL: ;
            SIM_ASTELIT: ;
            SIM_LIFE: ;
            SIM_KYIVSTAR: ;
            SIM_MTS_UKR: ;
            SIM_UMC_UKR:
              if (nomersmsservice = '770707070007') then
                OperatorNomer := SIM_ALTEL;
            SIM_MTCBY: ;
            SIM_VELCOM: ;
          end;
          RecvState();
          exit;
        end;
        MODEM_AR_CPMS://Сколько смс есть в памяти
        begin
          Delete(s, 1, Pos('+CPMS: ', s) + 6);
          if (Checkall = 0) then
            MyStart;
          if (Checkall = 2) then
            Checkall := 1;
          if StrToInt(Copy(s, 1, Pos(',', s) - 1)) <> 0 then
          begin
            RecvState();
            exit;
          end;
          RecvState(MODEM_MAIN_WHILE);
          exit;
        end;
        MODEM_AR_CMGL://Читаем смс
        begin
          if Pos('+CMGL', sOK) <> 0 then
          begin
            ReadAll4(sOK);
            RecvState(MODEM_MAIN_WHILE);
            exit;
          end;
          if Pos('+CMGR', sOK) <> 0 then
          begin
            ReadAll(sOK);
            Send('AT+CMGD=' + IntToStr(sms.id));
            RecvState(MODEM_AS_DELETEMSG);
            timeoutindeletesms := 0;
            exit;
          end;
        end;
        MODEM_AS_DELETEMSG:
        begin
          RecvState(MODEM_MAIN_WHILE);
        end;
        MODEM_SMS_SEND_WAITACCEPT:
          if Pos('+CMGS:', s) <> 0 then
          begin
            //SMSHistoryAdd('SENDSMS','Отправил смс на номер:'+sendsms[0].komu+' с текстом:'+sendsms[0].Text);
            resultcode_sendsms := 1;
            TextSmsAdd('СМС отправилось! ' + sendsms[0].komu);
            DeleteArrayIndex(sendsms, 0);
            if ModemModel <> Q2403 then
              Send('AT+CMGF=0');
            RecvState(MODEM_MAIN_WHILE);
          end
          else
          begin
            TextSmsAdd('СМС не удалось отправить! ' + sendsms[0].komu + ': ' + sendsms[0].text);
            resultcode_sendsms := -1;
            DeleteArrayIndex(sendsms, 0);
            if ModemModel <> Q2403 then
              Send('AT+CMGF=0');
            RecvState(MODEM_MAIN_WHILE);
          end;
        MODEM_MAIN_WHILE:
        begin
          if Pos('+CMGL', sOK) <> 0 then
          begin
            ReadAll4(sOK);
            exit;
          end;
          if Pos('+CMGR', sOK) <> 0 then
          begin
            ReadAll(sOK);
            Send('AT+CMGD=' + IntToStr(sms.id));
            RecvState(MODEM_AS_DELETEMSG);
            timeoutindeletesms := 0;
            exit;
          end;
          if (Pos('+CUSD: 1', sOK) <> 0) OR (Pos('+CUSD: 2', sOK) <> 0) then
          begin
            OnSms(TimeDMYHM(), 'USSD', USSDResponse(sOK));
            if (secondussdcmd<>'') then
            begin
              SendUSSD(secondussdcmd);
              secondussdcmd := '';
            end;
            exit;
          end;
          if (StringReplace(sOK, #10, '', [rfreplaceall]) <> 'OK') then
            TextSmsAdd('SYSTEM:' + sOK);
        end;
      end;
    end
    else///////////////////ЕСЛИ БЕЗ ОК////////////
    begin
      TextRecvAdd('(' + StringReplace(s, #10, '<CR>', [rfreplaceall]) + ')');
      case MODEM_STATE of
        MODEM_MAIN_WHILE:
        begin
          if (Pos('RING', s) <> 0) then
          begin
            Delete(RecvText, Pos('RING', RecvText), Pos(#10, RecvText, Pos('RING', RecvText) + 1));
          end;
          if (Pos('+CLIP:', s) <> 0) then
          begin
            OnSms(TimeDMYHM(), 'ЗВОНОК', CLIP2Nomer(s));
            Delete(RecvText, Pos('RING', RecvText), Pos(#10, RecvText, Pos('+CLIP:', RecvText) + 1));
            exit;
          end;
          if (Pos('+CMTI:', s) <> 0) then
          begin
            sms.id := Str2NomerSmS(s);
            if sms.id <> -1 then
            begin
              case ModemModel of
                Q2403: Send('AT+CMGF=0 ;+CMGR=' + IntToStr(sms.id));
                TC35i: Send('AT+CMGR=' + IntToStr(sms.id));
                MC55: Send('AT+CMGR=' + IntToStr(sms.id));
                M35: Send('AT+CMGR=' + IntToStr(sms.id));
                else
                  Send('AT+CMGR=' + IntToStr(sms.id));
              end;
            end
            else
              TextSmsAdd('E(+CMTI):' + s);
            Delete(RecvText, Pos('+CMTI:', RecvText), Pos(#10, RecvText, Pos('+CMTI:', RecvText) + 1));
          end;
          if (Pos('+CUSD: 4', s) <> 0) then
          begin
            TextSmsAdd('Ошибка USSD запроса.');
            Delete(RecvText, Pos('+CUSD: 4', RecvText), Pos(#10, RecvText, Pos('+CUSD: 4', RecvText) + 1));
            exit;
          end;
          if Pos('+CUSD: 2', s) <> 0 then
          begin
            OnSms(TimeDMYHM(), 'USSD', USSDResponse(s));
            Delete(RecvText, Pos('+CUSD: 2', RecvText), Pos(#10, RecvText, Pos('+CUSD: 2', RecvText) + 1));
            exit;
          end;
          if (Pos('+CME ERROR', s) <> 0) then
          begin
            Delete(RecvText, Pos('+CME ERROR', RecvText), Pos(#10, RecvText, Pos('+CME ERROR', RecvText) + 1));
            exit;
          end;
        end;
        MODEM_AS_DELETEMSG:
        begin
          if (Pos('^SYSSTART', s) <> 0) then
          begin
            RecvText := '';
            sleep(5000);
            MODEM_STATE := MODEM_AS_ATE0;
            exit;
          end;
        end;
        MODEM_SMS_SEND_NEEDACCEPT:
        begin
          if Length(temp) = 2 then
            if (temp[1] = chr($3E)) and (temp[2] = chr($20)) then
            begin
              Delete(temp, 1, 2);
              _cs.Enter;
              try
                if (ModemModel=MC55) then
                  Send(SendSms[0].Text)
                else
                  Send(tempsendsms);
              finally
                _cs.Leave;
              end;
              Send(#26);
              if (ModemModel=MC55) then
                Send('AT+CMGF=0');
              RecvState(MODEM_SMS_SEND_WAITACCEPT);
            end;
        end;
        MODEM_SMS_SEND_WAITACCEPT:
        begin
          if (Pos('+CME ERROR', s) <> 0) or (Pos('+CMS ERROR', s) <> 0) then
          begin
            resultcode_sendsms := StrToInt(GetNumber(Copy(s,Pos('+CM', RecvText), Pos(#10, RecvText, Pos('+CM', RecvText) + 1))));
            Delete(RecvText, Pos('+CM', RecvText), Pos(#10, RecvText, Pos('+CM', RecvText) + 1));
            TextSmsAdd('СМС не удалось отправить! ' + sendsms[0].komu);
            DeleteArrayIndex(sendsms, 0);
            if ModemModel <> Q2403 then
              Send('AT+CMGF=0');
            RecvState(MODEM_MAIN_WHILE);
          end;
        end;
        MODEM_AR_CMGL:
        begin
          if Pos('+CMGL', s) <> 0 then
            _sendtimeout := 0;
        end;
        MODEM_AR_CPIN:
        begin//Проверка сим
          if GetStatePin(s) = 'READY' then
          begin
            MODEM_STATE := MODEM_STATE + 1;
            exit;
          end;
          if ((Pos('+CME ERROR:', s) <> 0) or (Pos('+CMS ERROR:', s) <> 0)) then
          begin
            TextSmsAdd(GetErrorSim(s));
            if GetErrorSimRestart(s) then
              RecvState(MODEM_AS_ATE0)
            else
            begin
              RecvState(MODEM_ERROR);
              if (nomer <> Nomer_Neopredelen) and (Pos('+CME ERROR: 10', s) <> 0) then
              begin
                nomer := data_neopredelen;
                //IMEI := '123456789012345';
                SaveToDb();
              end;
            end;
          end;
        end;//Конец проверка сим
      end;
    end;
  end;
end;

procedure TMyModem.Execute;
begin
  sleep(10 * (idthread + 1));
  while (not Terminated) do
  begin
    sleep(10);
    case PORT_STATE of
      PORT_WORK: WorkPort; //РАБОТА

      //Заного грузим данные, инициалиция и работа
      PORT_RESTART:
      begin
        PORT_STATE := PORT_WAIT;
        Serial.CloseSocket;
      end;

      //Ждём запуска или отдыхаем
      PORT_CREATE, PORT_WAIT:
      begin
        sleep(250);
        //if idinbase<>0 then
        _SendText.Clear;
        _RecvText.Clear;
        PORT_STATE := PORT_WORK;
        MODEM_STATE := MODEM_NULL;
      end;
      PORT_DISCONNECT: WorkPort;
      PORT_ZAPROS_NOMERA:
      begin
        ZaprosNomera();
        PORT_STATE := PORT_WORK;
      end;
      PORT_ZAPROS_NOMERA_IZ_SIM:
      begin
        SetNomer(Nomer_Neopredelen);
        MODEM_STATE := MODEM_AS_CPBR;
        PORT_STATE := PORT_WORK;
      end;
      PORT_ACTIV_NOMERA:
      begin
        Activate();
        PORT_STATE := PORT_WORK;
      end;
      PORT_DEACTIV_NOMERA:
      begin
        Deactivate();
        PORT_STATE := PORT_WORK;
      end;
    end;
    puls := not puls;
  end;

  Serial.Free;
  PORT_STATE := PORT_EXIT;
end;

end.
