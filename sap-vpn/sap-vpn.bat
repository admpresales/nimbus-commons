@echo off
rem SAP-VPN Windows Launcher

rem Fix PATH, sometimes the shell does not include perl
set PATH=%PATH%;C:\Strawberry\perl\bin

perl -x -S "%~dpn0.pl" %*