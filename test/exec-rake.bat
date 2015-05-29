@echo off
call "%~dps0%artd-setenv.bat" exec
set PATH=%PATH%;%ARTD_USER_SHELL_PATHS%
rake "%1" "%2" "%3" "%4" "%5" "%6" "%7" "%8" "%9"
