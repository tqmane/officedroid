@echo off
C:\office-setup\setup.exe /configure C:\office-setup\configuration.xml
>C:\office-setup\exit-code.txt echo %ERRORLEVEL%
