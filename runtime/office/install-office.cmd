@echo off
set WINEDEBUG=+timestamp,+pid,+tid,err+all,warn+seh,trace+android,trace+winhttp,trace+wininet,trace+service,trace+process,trace+loaddll,trace+sync,trace+file
C:\office-setup\setup.exe /configure C:\office-setup\configuration.xml
>C:\office-setup\exit-code.txt echo %ERRORLEVEL%
