@echo off
rem SAP-VPN Windows Launcher

rem Fix PATH, sometimes the shell does not include perl
set PATH=%PATH%;C:\Strawberry\perl\bin
set VPN_CLIENT_DIR="C:\Program Files\SoftEther VPN Client"

perl -x -S "%~dpn0.pl" %*