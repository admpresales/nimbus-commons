:: This file is to be placed in C:\Windows\System32\drivers\etc
:: Then create a shortcut on the desktop to this file and call the shortcut "hosts"
:: This batch file is used to edit the hosts file without having to pick an editor
:: it uses a shortcut (which runs minimized) to hide everything and
:: it also makes a time-stamped copy of the current hosts file in the etc folder.
:: Courtesy of Mark Steffensen
@echo off

For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
For /f "tokens=1-3 delims=/:/ " %%a in ('time /t') do (set mytime=%%a-%%b-%%c)

copy /Y C:\Windows\System32\drivers\etc\hosts C:\Windows\System32\drivers\etc\hosts-%mydate%_%mytime%.txt

Notepad++ C:\Windows\System32\drivers\etc\hosts
