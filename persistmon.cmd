@ECHO OFF

REM Differential analysis of persistence points using SysInternals
REM autorunsc.exe

REM Lots of files named with unique timestamps, so to make it easy (and
REM uniform)...
SET STAMP=%DATE:~10%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%
SET PERSISTMON_BASENAME=persistmon-%STAMP%

REM autorunsc.exe writes output in Unicode, but Vim doesn't display that very
REM nicely, so everything is converted to UTF-8 for visual comparison when
REM necessary.
SET PERSISTMON_UCS2=%PERSISTMON_BASENAME%-ucs2.csv
SET PERSISTMON_UTF8=%PERSISTMON_BASENAME%-utf8.csv
SET PERSISTMON_LAST_UCS2=persistmon-last-ucs2.csv
SET PERSISTMON_LAST_UTF8=persistmon-last-utf8.csv

SET REG_WINL_NTFY_PATH=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\Notify
SET WINL_NTFY=reg_winlogon_notify-%STAMP%.txt
SET WINL_NTFY_LAST=reg_winlogon_notify-last.txt
SET QUIETLY=^>NUL 2^>^&1

REM Requires SysInternals Suite for autorunsc.exe
REM Requires Cygwin64 for iconv.exe
REM Requires gvim for visual differential analysis
SET DEPENDS=autorunsc.exe \cygwin64\bin\iconv.exe gvim.exe

:Depends
	FOR %%f IN (%DEPENDS%) DO (
		REM Look for in path or current directory
		where %%f > nul 2>&1
		IF ERRORLEVEL 1 (
			REM Look for at absolute path
			IF NOT EXIST %%f (
				ECHO This script depends on %%f, which could not be found.
				ECHO Press any key to close...
				PAUSE %QUIETLY%
				EXIT /B 1
			)
		)
	)

:Start
	autorunsc.exe -avcf > "%PERSISTMON_UCS2%"
	\cygwin64\bin\iconv.exe -f UCS-2 -t UTF-8 "%PERSISTMON_UCS2%" > "%PERSISTMON_UTF8%"
	REG QUERY "%REG_WINL_NTFY_PATH%" /s > "%WINL_NTFY%"

:CmpPersist
	FC.EXE "%PERSISTMON_UCS2%" "%PERSISTMON_LAST_UCS2%" %QUIETLY%
	IF ERRORLEVEL 1 (
		ECHO Warning: changes detected in autoruns
		start gvim -d "%PERSISTMON_LAST_UTF8%" "%PERSISTMON_UTF8%"
	) ELSE (
		ECHO No changes detected in autoruns
	)

:CmpNtfy
	FC.EXE "%WINL_NTFY%" "%WINL_NTFY_LAST%" %QUIETLY%
	IF ERRORLEVEL 1 (
		ECHO Warning: changes detected in Winlogon\Notify
		start gvim -d "%WINL_NTFY_LAST%" "%WINL_NTFY%"
	) ELSE (
		ECHO No changes detected in Winlogon\Notify
	)

:Hist
	ECHO Press any key to overwrite last logs...
	PAUSE %QUIETLY%

	REM Creating lastlogs
	COPY "%WINL_NTFY%" "%WINL_NTFY_LAST%" %QUIETLY%
	COPY "%PERSISTMON_UCS2%" "%PERSISTMON_LAST_UCS2%" %QUIETLY%
	COPY "%PERSISTMON_UTF8%" "%PERSISTMON_LAST_UTF8%" %QUIETLY%

	REM Saving history
	IF NOT EXIST history MKDIR history %QUIETLY%
	MOVE "%WINL_NTFY%" "history\%WINL_NTFY%" %QUIETLY%
	MOVE "%PERSISTMON_UCS2%" "history\%PERSISTMON_UCS2%" %QUIETLY%
	MOVE "%PERSISTMON_UTF8%" "history\%PERSISTMON_UTF8%" %QUIETLY%

	REM This is repeated every time the script is run because files that are added
	REM to the directory from within this script do not appear to be automatically
	REM compressed like files that are created using the "New >" option within
	REM Windows Explorer's right-click context menu.
	compact /c history %QUIETLY%
	compact /c history\* %QUIETLY%
