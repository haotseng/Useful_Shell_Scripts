@echo off

REM 強制使用UTF8
chcp 65001

setlocal enabledelayedexpansion

REM 檢查是否有輸入參數
if "%~1"=="" (
  echo Error: No IP address provided.
  echo Usage: %~nx0 ip-address [interval]
  exit /b
)

REM 檢查是否有指定間隔時間
set "interval=1"
if not "%~2"=="" (
  set "interval=%~2"
)

REM 設定 IP 地址和 Ping 間隔時間
set "ip=%~1"

REM 建立 ping_log 目錄（如果還不存在的話）
if not exist "ping_log" (
  mkdir "ping_log"
)

REM 設定 log 檔名
set "timestamp=%date:~0,4%%date:~5,2%%date:~8,2%__%time:~0,2%%time:~3,2%%time:~6,2%"
set "timestamp=%timestamp: =0%"
set "log_file=ping_log\ping_%ip%_%timestamp%.log"

REM 輸出標題
echo Ping %ip% 
echo Ping %ip% , start time :  %date% %time% > "%log_file%"

:loop

REM Ping IP 並將第一行的輸出儲存為變數
set "count=0"
for /f "delims=" %%i in ('ping -n 1 %ip%') do (
  set /a "count+=1"
  if "!count!"=="2" (
    set "ping_output=%%i"
  ) 
)

REM 顯示和寫入log檔
set "ping_time= %date% %time:~0,2%:%time:~3,2%:%time:~6,2%"
echo !ping_time! : !ping_output!
echo !ping_time! : !ping_output! >> "%log_file%"

timeout /t %interval% /nobreak > nul
goto loop

endlocal
