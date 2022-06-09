@echo off
Setlocal enabledelayedexpansion

Set "Pattern=Backend"
Set "Replace=HA - Master"

Set "Path_To_Work_In=C:\Virtual Machines\Red Hat Enterprise v6.4 x64 - HA - Master"

cd %Path_To_Work_In%

For %%# in ("*") Do (
    Set "File=%%~nx#"
    Ren "%%#" "!File:%Pattern%=%Replace%!"
)

Pause