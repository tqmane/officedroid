@echo off
C:\office-setup\setup.exe /configure C:\office-setup\configuration.xml
echo %ERRORLEVEL%>C:\office-setup\exit-code.txt
