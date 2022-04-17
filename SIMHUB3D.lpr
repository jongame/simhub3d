program simhub3d;

{$mode objfpc}{$H+}

uses
{$IFDEF linux}CThreads,{$ENDIF}Classes,maind,sysutils;

begin
  dMain();
end.
