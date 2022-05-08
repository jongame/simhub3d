unit portcons;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses
  Classes, SysUtils;

type
  MyFullSmS = record
    id: integer;
    Adtext: string;
    sizepdu: integer;
    tpsca: array[0..1] of byte;
    Nservice: string;
    tpmti: byte;
    tpoa: array [0..1] of byte;
    Notkogo: string;
    tpid: byte;
    tpdcs: byte;
    tpscts: string;
    Datasend: string;
    tpudl: byte;
    tpud: array[0..0] of byte;
    tpudhsize: byte;
    Text: string;
  end;

type
  smstosend = record
    typesnd: byte;
    nomer: string;
    otkogo: string;
    date: string;
    Text: string;
  end;

type
  MyServiceSms = record
    otkogo: string;
    textsms: string;
  end;

type
  MySmSPacket = record
    Name: string;
    Text: array of string;
  end;

type
  MyFilterSms = record
    typeFilter: integer;
    otkogo: string;
    textsms: string;
  end;

type
  MyServiceFilter = record
    idbit, idbase: integer;
    Name: string;
    Data: array of MyServiceSms;
  end;

type
  MyBlockFilter = record
    id: integer;
    Name: string;
    Data: array of MyFilterSms;
    typefilter: integer;
  end;

type
  MySqlZapros = record
    t, idt: byte;
    q: string;
  end;


type
  MySmsSend = record
    id: integer;
    komu, Text: string;
  end;

type
  ACTIVATION_OBJECT = record
    id: integer;
    idmodem: integer;
    service: integer;
    state: byte;
    datetime: longword;
    code: string;
  end;

type
  MyFilterObject = record
    otkogo: string;
    textsms: string;
    cutsms: string;
  end;

type
  MyTelegramCLient = record
    telegram: string;
    service: string;
  end;

type
  MySmsinFile = record
    idinbase: integer;
    otkogo: string;
    datetime: string;
    Text: string;
  end;


type
   MyTrigger = record
    input: MyFilterObject;
    output: string;
  end;


type
  TArrayString = array of string;
  TArrayinteger = array of integer;
  TArrayMySqlZapros = array of MySqlZapros;
  TArrayMySmsSend = array of MySmsSend;
  mytarrayofinteger = array of integer;
  mytarrayofstring = array of string;
  TArraysmstosend = array of smstosend;
  TArrayofACTIVATION_OBJECT = array of ACTIVATION_OBJECT;
  TArrayofMyServiceSms = array of MyFilterObject;
  TArrayofMySmsinFile = array of MySmsinFile;



type
  TPORT_STATE = (PORT_CREATE, PORT_WAIT, PORT_WORK, PORT_RESTART, PORT_DISCONNECT, PORT_ZAPROS_NOMERA, PORT_ZAPROS_NOMERA_IZ_SIM, PORT_ACTIV_NOMERA, PORT_DEACTIV_NOMERA, PORT_EXIT);
  TSIM_OPERATOR = (SIM_UNKNOWN, SIM_MTS, SIM_BEELINE, SIM_MEGAFON, SIM_TELE2, SIM_KCELL, SIM_ALTEL, SIM_ASTELIT, SIM_LIFE, SIM_ACTIV,
    SIM_KYIVSTAR, SIM_MTS_UKR, SIM_UMC_UKR, SIM_MTCBY, SIM_VELCOM, SIM_BEELINE_KZ);
  TSIMHUB_MODEL = (MODEL_UNKOWN, Q2403, TC35i, MC55, M35, M590);
  TSIM_OPERATOR_STATE = (SIM_NOT_REG_NOT_SEARCH, SIM_HOME_NETWORK, SIM_NOT_REG_SEARCH, SIM_REG_DENIED, SIM_UKNOW_STATE, SIM_ROAMING);

  { TSIM_OPERATOR_STATE_HELPER }

  TSIM_OPERATOR_STATE_HELPER = type helper for TSIM_OPERATOR_STATE
    function ToString:string;
    function parseCREG(const s: string):TSIM_OPERATOR_STATE;
  end;

const
{$IFDEF UNIX}
  MDRL = '-';
  _DIROS = '/';
  _DRAW_NOMER_FONT_SIZE = 16;
  _DRAW_STATE_FONT_SIZE = 9;
{$ELSE}
  MDRL = '.';
  _DIROS = '\';
  _DRAW_NOMER_FONT_SIZE = 14;
  _DRAW_STATE_FONT_SIZE = 7;
{$ENDIF}

  ///СОСТОЯНИЕ МОДЕМА///
  MODEM_NULL = 0;
  MODEM_AS_ATE0 = 1;
  MODEM_AR_ATE0 = 2;
  MODEM_AS_CGSN = 3;
  MODEM_AR_CGSN = 4;
  MODEM_AS_ATI  = 5;
  MODEM_AR_ATI  = 6;
  MODEM_AS_CFUN = 7;
  MODEM_AR_CFUN = 8;
  MODEM_AS_CMEE = 9;
  MODEM_AR_CMEE = 10;
  MODEM_AS_CMGF = 11;
  MODEM_AR_CMGF = 12;
  MODEM_AS_CPIN = 13;
  MODEM_AR_CPIN = 14;
  MODEM_AS_ICC  = 15;
  MODEM_AR_ICC  = 16;
  MODEM_AS_CREG = 17;
  MODEM_AR_CREG = 18;
  MODEM_AS_COPS = 19;
  MODEM_AR_COPS = 20;
  MODEM_AS_QSPN = 21;
  MODEM_AR_QSPN = 22;
  MODEM_AS_CPBR = 23;
  MODEM_AR_CPBR = 24;
  MODEM_AS_CPAS = 25;
  MODEM_AR_CPAS = 26;
  MODEM_AS_CSQ  = 27;
  MODEM_AR_CSQ  = 28;
  MODEM_AS_CNMI = 29;
  MODEM_AR_CNMI = 30;
  MODEM_AS_CSCA = 31;
  MODEM_AR_CSCA = 32;
  MODEM_AS_CPMS = 33;
  MODEM_AR_CPMS = 34;
  MODEM_AS_CMGL = 35;
  MODEM_AR_CMGL = 36;


  MODEM_AS_USSD = 200;
  MODEM_AR_USSD = 201;

  MODEM_MAIN_WHILE = 100;
  MODEM_AS_DELETEMSG = 101;
  MODEM_AS_WHATSAPP = 102;
  MODEM_LOAD_DATA = 105;
  MODEM_SMS_SEND_NEEDACCEPT = 110;
  MODEM_SMS_SEND_WAITACCEPT = 111;
  MODEM_NEED_RESTART_AT_CPMS = 195;
  MODEM_NEED_RESTART_AT = 196;
  MODEM_WAIT_WHILE = 197;
  MODEM_ERROR = 198;
  MODEM_FATAL_ERROR = 199;

  operator_names: array[TSIM_OPERATOR] of string = ('Неизвестно', 'MTS', 'BEELINE', 'MEGAFON', 'TELE2', 'KCELL', 'ALTEL', 'ASTELIT',
    'LIFE', 'ACTIV', 'KYIVSTAR', 'MTS_UKR', 'UMC_UKR', 'MTCBY', 'VELCOM', 'BEELINE_KZ');
  operator_names_to_activate: array[TSIM_OPERATOR] of string = ('Неизвестно', 'mts', 'beeline', 'megafon', 'tele2', 'kcell', 'altel', 'astelit',
    'life', 'activ', 'kyivstar', 'mts_ukr', 'umc_ukr', 'mtsby', 'velcom', 'beeline_kz');

  Nomer_Neopredelen = 'Не_Определен';
  data_neopredelen = 'Не_Загружено';

  MYAPPNAME = 'SIMHUB3';

  //Типы фильтров
  FILTER_SHOW = 0;
  FILTER_SPAM = 1;
  FILTER_BLOCK = 2;
  //END
  ///STATE PROGRAM///
  STATE_SH_WORK = 'Работаю...';
  STATE_SH_CONFLICT = 'Другая копия:';
  STATE_SH_UKNOWN = 'Ошибка проверки.';
///EXIT?///////////


//ACTIVATION_COUNT_SERVCE = 15;
//ACTIVATION_NOT_USED = #48;
//ACTIVATION_USED = #49;
//ACTIVATION_WAIT = #50;
//ACTIVATION_RETRY_WAIT = #51;


//ACTIVATION_OBJECT_WAIT_CODE = 0;
//ACTIVATION_OBJECT_WAIT_RETRY = 1;
//ACTIVATION_OBJECT_CANCEL = 2;
//ACTIVATION_OBJECT_DONE = 3;


type
  ASqlserver = (SQL_SERVER_MODEM, SQL_SERVER_SMS);
  ASqlquerytype = (SQL_EXEC, SQL_OPEN);


implementation

{ TSIM_OPERATOR_STATE_HELPER }

function TSIM_OPERATOR_STATE_HELPER.ToString: string;
begin
  result := '';
  case self of
    SIM_NOT_REG_NOT_SEARCH: result := 'нет сети, нет поиска';
    SIM_HOME_NETWORK:       result := 'Домашняя сеть';
    SIM_NOT_REG_SEARCH:     result := 'Поиск сети';
    SIM_REG_DENIED:         result := 'В регистрации отказано';
    SIM_UKNOW_STATE:        result := 'Неизвестная ошибка';
    SIM_ROAMING:            result := 'Роуминг';
  end;
end;

function TSIM_OPERATOR_STATE_HELPER.parseCREG(const s: string):TSIM_OPERATOR_STATE;
begin
  result := SIM_ROAMING;
  if Pos('+CREG', s) = 0 then
    exit;
  case Copy(s, Pos('+CREG', s)+9, 1) of
    '0': result := SIM_NOT_REG_NOT_SEARCH;
    '1': result := SIM_HOME_NETWORK;
    '2': result := SIM_NOT_REG_SEARCH;
    '3': result := SIM_REG_DENIED;
    '4': result := SIM_UKNOW_STATE;
    '5': result := SIM_ROAMING;
  end;
end;

end.
