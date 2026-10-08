@echo off
set WINEDEBUG=+timestamp,+pid,+tid,err+all,warn+seh,trace+android,trace+winhttp,trace+wininet,trace+service,trace+process,trace+loaddll,trace+sync,trace+file
call :redist x64
if errorlevel 1 goto :done
call :redist x86
if errorlevel 1 goto :done
>C:\office-setup\phase.txt echo office-setup
C:\office-setup\setup.exe /configure C:\office-setup\configuration.xml
set INSTALL_EXIT=%ERRORLEVEL%
:done
>C:\office-setup\exit-code.txt echo %INSTALL_EXIT%
exit /b %INSTALL_EXIT%
:redist
>C:\office-setup\phase.txt echo visual-cpp-%1
C:\office-setup\vc_redist.%1.exe /install /quiet /norestart /log C:\office-setup\logs\vcredist-%1.log
set INSTALL_EXIT=%ERRORLEVEL%
>C:\office-setup\vcredist-%1-exit.txt echo %INSTALL_EXIT%
if %INSTALL_EXIT%==3010 set INSTALL_EXIT=0
exit /b %INSTALL_EXIT%
