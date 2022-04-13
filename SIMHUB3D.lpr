program SIMHUB3D;

{$mode objfpc}{$H+}

uses
{$IFDEF linux}CThreads,{$ENDIF}Classes,maind,sysutils;

begin
  dMain();
end.
