@echo off
:: ========================================================================= ::
:: WinTimeBackup - Time Machine for Windows                                  ::
:: by Julian Gieseke (mail@juliangieseke.de)                                 ::
:: based on ln.exe by Hermann Schinagel (Hermann.Schinagl@gmx.net)           ::
:: http://schinagl.priv.at/nt/ln/ln.html                                     ::
::                                                                           ::
:: This Script is provided AS IS!                                            ::
:: ========================================================================= ::
:: About this Script:                                                        ::
::                                                                           ::
:: This script provides a simple implementation of a File History Snapshot   ::
:: like Backup using ln.exe. Its functionality is highly inspired by Apple   ::
:: Time Machine and Synology Time Backup/Hyper Backup. Like Time Backup and  ::
:: Time Machine, it uses a file based approach with hardlinks instead of a   ::
:: Database file like Hyper Backup and many other Backup Solutions do.       ::
:: ========================================================================= ::
:: Changelog:                                                                ::
::                                                                           ::
:: v 0.1 alpha (first working version)                                      ::
:: - basic time machine like functionality provided                          ::
:: ========================================================================= ::






:: ========================================================================= ::
:: User Options
:: ========================================================================= ::
:: @TODO: Put all this into a Configfile

:: Set Output to cmd (uses echo)
:: 0 = nothing, 1 = some status info @ stdout
set DEBUG=1

:: ln.exe (change if yours isnt in PATH)
set LN=ln.exe

:: Source Folder for Backup, as you can include/exclude almost anything 
:: later on, use the most top Folder.
:: you can use a parameter if you want (%~1)
::set SRC=%~1
:: or something fixed
set SRC=D:

:: Destination Folder
:: you can use %~dp0 if your script is at destionation folder
::set DST=%~dp0
:: or parameter
::set DST=%~1
:: or something fixed
set DST=S:\Github

:: Name of the Backup, used for subfolder if USESUB=1
::set BKPNAME=Backup
:: if you want you can use a paramter for this
::set BKPNAME=%~1
:: or simply the filename of this script
set BKPNAME=TestA

:: Puts all Backups and Logs into a Subfolder named BKPNAME.
:: set to 1 if you want to use DST/BKPNAME as root folder for Backup 
set USESUB=1

:: Set to 1,2,3 if you want to save ln.exes output to logfiles 
:: for more info on loglevel see ln.exe --quiet doc 
set LOGLEVEL=2

:: Place Logfiles into that folder, relative from %DST%
:: sadly ln.exe cant put theses files into the backuped folder.
:: use . if for same folder as Backups. 
::set LOGFILENAME=.
:: or give folder name/path
::set LOGFILEPATH=log
:: that SHOULD work
set LOGFILEPATH=..\log

:: if 1 logs for deleted snapshots will be deleted
set DELETELOGFILES=1


:: ========================================================================= ::
:: BACKUP SETS
:: This script is intended to be called once a day, if you want to call it
:: every hour (or anything else), change these settings accordingly.
::
:: @TODO: a more recursive approach would be nice
:: ========================================================================= ::

:: set names of backup sets
:: they have to be different and 
:: !WARNING! you have to restart your backup after changing them!
:: ...or at least rename them manually 
set NAME1=D
set NAME2=W
set NAME3=M
set NAME4=Y

:: set how many copies of each set should kept
:: you can change this at any time, but it will delete old backups immediatly!
:: also if one is zero, all following are 0 too
::set KEEP1=28
::set KEEP2=8
::set KEEP3=9
::set KEEP4=1
set KEEP1=4
set KEEP2=2
set KEEP3=2
set KEEP4=2



:: set interval for second, third & fourth 
:: this is used for ID modulo INTERVAL calulations when moving backups to the next set.
:: !!! These Values have to be SMALLER OR EQUAL to the KEEP* BEFORE it (INTERVAL3 <= KEEP2 ) and >0!
:: every week, set to 14 for bi-weekly
set INTERVAL2=2
:: every four weeks
set INTERVAL3=2
:: every 12 months
set INTERVAL4=1

:: ========================================================================= ::
:: INCLUDES/EXCLUDES
:: ========================================================================= ::

set OPT=--excludedir "Archiv"
::set OPT=%OPT% --excludedir "Aufnahmen"
set OPT=%OPT% --excludedir "Bilder"
set OPT=%OPT% --excludedir "Dokumente"
set OPT=%OPT% --excludedir "Filme"
set OPT=%OPT% --excludedir "H”rbcher"
set OPT=%OPT% --excludedir "Kamera Upload"
set OPT=%OPT% --excludedir "Lightroom"
set OPT=%OPT% --excludedir "Musik"
set OPT=%OPT% --excludedir "Resilio"
set OPT=%OPT% --excludedir "Serien"
set OPT=%OPT% --excludedir "SteamApps"

set OPT=%OPT% --excludedir "$RECYCLE.BIN"
set OPT=%OPT% --excludedir "System Volume Information"

set OPT=%OPT% --exclude ".DS_Store"
set OPT=%OPT% --exclude "Thumbs.db"
set OPT=%OPT% --excludedir ".sync"
set OPT=%OPT% --excludedir ".git"
set OPT=%OPT% --excludedir ".svn"
set OPT=%OPT% --exclude "*.ts"


:: ========================================================================= ::
:: THATS IT - DONT CHANGE ANYTHING BELOW THIS LINE
:: ========================================================================= ::


set WTB_VERSION=v 0.1 alpha

if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo WinTimeBackup %WTB_VERSION%

setLocal EnableDelayedExpansion

::get datetime from ln.exe
for /f "tokens=1,2 delims= " %%a in ('ln.exe --datetime') do (
	set LNDATE=%%a
	set LNTIME=%%b
)
set LNDATEY=%LNDATE:~0,4%
set LNDATEM=%LNDATE:~5,2%
set LNDATED=%LNDATE:~8,2%
set LNTIMEH=%LNTIME:~0,2%
set LNTIMEM=%LNTIME:~3,2%
set LNTIMES=%LNTIME:~6,2%

:: Well, you found some advanced options.. be careful!


:: dont use - (datetime from ln uses it)
:: dont use . (filenames)
:: space and underscore should be ok :)
set "DLMTR= "

:: has to be one token (no space allowed)!
:: be careful with sorting - this has to be distinct!
set DATETIME=%LNDATEY%%LNDATEM%%LNDATED%-%LNTIMEH%%LNTIMEM%%LNTIMES%
set DATEFORMAT=????????-??????

:: set suffix for copying process.
set COPYSUFFIX=wip
set ERRORSUFFIX=failed
set DOUBLESUFFIX=duplicate

:: cut off trailing slashes from user inputs
IF %SRC:~-1% EQU \ SET SRC=%SRC:~0,-1%
IF %DST:~-1% EQU \ SET DST=%DST:~0,-1%
IF %LOGFILEPATH:~-1% EQU \ SET LOGFILEPATH=%LOGFILEPATH:~0,-1%

:: get GUID from drive letter for DST 
:: and save it for ln specific path
for /f "delims= " %%a in ('mountvol %DST:~0,2%\ /L') do set DSTVOL=%%a

:: ln.exe should use GUID instead of Drive Letter
set LNDST=%DSTVOL:~0,-1%\%DST:~3%

:: add %BKPNAME% to dest if USESUB==1
if %USESUB% EQU 1 (
	set LNDST=%LNDST%\%BKPNAME%
	set DST=%DST%\%BKPNAME%
	set LOGFILEPATH=%LOGFILEPATH%
	if not exist "%DST%\%BKPNAME%" mkdir "%DST%\%BKPNAME%"
)

:: add loglevel & loglevel
if not exist "%DST%\%LOGFILEPATH%" mkdir "%DST%\%LOGFILEPATH%"
set OPT=%OPT% --quiet %LOGLEVEL%

if %DEBUG% GTR 1 set OPT=%OPT% --progress

:: store DST as CD
pushd %DST%

:: ========================================================================= ::
:: PART I: Copying new Files
:: ========================================================================= ::


if %DEBUG% GTR 0 echo.
if %DEBUG% GTR 0 echo Backup Name: "%BKPNAME%" 
if %DEBUG% GTR 0 echo        From: "%SRC%"
if %DEBUG% GTR 0 echo          To: "%DST%"

:: @TODO Need to catch CTRL+c somehow to rename failed backups (see below), otherwise after one 
:: failed no more backups are started...
:: http://stackoverflow.com/questions/27130050/batch-script-if-user-press-ctrlc-do-a-command-before-exitting
if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%COPYSUFFIX%" (
	if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
	if %DEBUG% GTR 0 echo  ^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!
	if %DEBUG% GTR 0 echo  ^^!^^!^^! Backup already running or script was killed before              ^^!^^!^^! 
	if %DEBUG% GTR 0 echo  ^^!^^!^^! Starting a new Backup, future backups will use the newest one   ^^!^^!^^! 
	if %DEBUG% GTR 0 echo  ^^!^^!^^! This can cause issues - check your Backups^^!                     ^^!^^!^^! 
	if %DEBUG% GTR 0 echo  ^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!^^!
)
:: @todo find a better solution, it looks like lk can somehow continue running backups?!


if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.

if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME1%" (
	:: get last backup and increase its ID by 1
	for /f "tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /AD /O:N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME1%"') do ( 
		set "LastBackup=%%a%DLMTR%%%b%DLMTR%%NAME1%"
		set /a NextId=%%b+1
	)
	
	if %DEBUG% GTR 0 echo Found old backup: "!LastBackup!"

	set LNPARAMS=--output "%LOGFILEPATH%\%BKPNAME%%DLMTR%%DATETIME%%DLMTR%!NextId!.log" --delorean "%SRC%" "%LNDST%\!LastBackup!" "%LNDST%\%DATETIME%%DLMTR%!NextId!%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%"
	
) else (
	:: first backup! copying the files
	set NextId=0
	
	if %DEBUG% GTR 0 echo No old backup found.
	
	set LNPARAMS=--output "%LOGFILEPATH%\%BKPNAME%%DLMTR%%DATETIME%%DLMTR%!NextId!.log" --copy "%SRC%" "%LNDST%\%DATETIME%%DLMTR%!NextId!%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%"
)

if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo Backing up "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%"...

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Copying to "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%"...


if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo %LN% %OPT% %LNPARAMS%

:: calling ln.exe here
%LN% %OPT% %LNPARAMS%

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo %LN% exit code was %errorlevel%
	
if %errorlevel% NEQ 0 ( 
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Copying failed. See Logfile "%LOGFILEPATH%\%BKPNAME%%DLMTR%%DATETIME%%DLMTR%%NextId%.log" for details
	
	%LN% --quiet --move "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%" "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%ERRORSUFFIX%" > nul
	
	goto errorexit
)

:: what happens if second backup is faster then first?
:: what does that mean for data consistency?
:: @TODO: doesnt work when folder was renamed while this script runs..
if exist "%DATEFORMAT%%DLMTR%%NextID%%DLMTR%%NAME1%" (
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Finished backup with same ID "%NextId%" already exists, marking this one as duplicate.
	
	%LN% --quiet --move "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%" "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%DOUBLESUFFIX%" > nul
	
	goto errorexit
)

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Copying successful.
if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Renaming folder "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%"
if %DEBUG% GTR 1 echo              to "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%"

%LN% --quiet --move "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%%DLMTR%%COPYSUFFIX%" "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAME1%" > nul

if %errorlevel% EQU 0 (
	if %DEBUG% GTR 0 echo. && echo Backup successful.
) else goto errorexit


:: ========================================================================= ::
:: PART II: Checking/Renaming old Backups
:: ========================================================================= ::
:: (These have to be functions...)

:: first set intervals to needed values.
set /a INTERVAL3=%INTERVAL3%*%INTERVAL2%
set /a INTERVAL4=%INTERVAL4%*%INTERVAL3% 

if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo Cleaning up old Backups

if not exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME1%" goto cleanup_done

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Checking old %NAME1% backups ...

if %KEEP1% GTR 0 (
	if %DEBUG% GTR 1 echo Keeping %KEEP1% %NAME1% backups
	set "SKIP=skip=%KEEP1% "
) else (
	set "SKIP="
)

for /f "%SKIP%tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME1%"') do (
	
	if %DEBUG% GTR 0 echo.
	
	if %KEEP2% GTR 0 (
		set /a MODULO=%%b %% %INTERVAL2%
		if %DEBUG% GTR 1 echo Modulo of "%%a%DLMTR%%%b%DLMTR%%NAME1%" with Interval %INTERVAL2% is !MODULO!
	) else (
		:: set to >0 to delete all old backups of this set
		set MODULO=1
	)
	
	if !MODULO! NEQ 0 (
		if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAME1%" ...
		%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAME1%" > nul
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 1 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAME1%" ...
			del "%LOGFILEPATH%\%BKPNAME%%DLMTR%%%a%DLMTR%%%b.log" > nul
		)
		
	) else (
		if %DEBUG% GTR 0 echo Renaming old backup set "%%a%DLMTR%%%b%DLMTR%%NAME1%"
		if %DEBUG% GTR 0 echo                      to "%%a%DLMTR%%%b%DLMTR%%NAME2%" ...
		
		%LN% --quiet --move "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAME1%" "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAME2%" > nul
	)
)

if not exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME2%" goto cleanup_done

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Checking old %NAME2% backups ...

if %KEEP2% GTR 0 (
	if %DEBUG% GTR 1 echo Keeping %KEEP2% %NAME2% backups
	set "SKIP=skip=%KEEP2% "
) else (
	set SKIP=
)
for /f "%SKIP%tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME2%"') do (
	
	if %DEBUG% GTR 0 echo.
		
	if %KEEP3% GTR 0 (
		set /a MODULO=%%b %% %INTERVAL3%
		if %DEBUG% GTR 1 echo Modulo of "%%a%DLMTR%%%b%DLMTR%%NAME2%" with Interval %INTERVAL3% is !MODULO!
	) else (
		:: set to >0 to delete all old backups of this set
		set MODULO=1
	)

	if !MODULO! NEQ 0 (
		if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAME2%" ...
		%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAME2%" > nul
		
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 1 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAME2%" ...
			del "%LOGFILEPATH%\%BKPNAME%%DLMTR%%%a%DLMTR%%%b.log" > nul
		)
	) else (
		if %DEBUG% GTR 0 echo Renaming old backup set "%%a%DLMTR%%%b%DLMTR%%NAME2%"
		if %DEBUG% GTR 0 echo                      to "%%a%DLMTR%%%b%DLMTR%%NAME3%" ...
		%LN% --quiet --move "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAME2%" "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAME3%" > nul
	)
)



if not exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME3%" goto cleanup_done

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Checking old %NAME3% backups ...

if %KEEP3% GTR 0 (
	if %DEBUG% GTR 1 echo Keeping %KEEP3% %NAME3% backups
	set "SKIP=skip=%KEEP3% "
) else (
	set SKIP=
)
for /f "%SKIP%tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME3%"') do (
	
	if %DEBUG% GTR 0 echo.
	
	if %KEEP4% GTR 0 (
		set /a MODULO=%%b %% %INTERVAL4%
		if %DEBUG% GTR 1 echo Modulo of "%%a%DLMTR%%%b%DLMTR%%NAME3%" with Interval %INTERVAL4% is !MODULO!
	) else (
		:: set to >0 to delete all old backups of this set
		set MODULO=1
	)
	
	if !MODULO! NEQ 0 (
		if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAME3%" ...
		%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAME3%" > nul

		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 1 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAME3%" ...
			del "%LOGFILEPATH%\%BKPNAME%%DLMTR%%%a%DLMTR%%%b.log" > nul
		)
	) else (
		if %DEBUG% GTR 0 echo Renaming old backup set "%%a%DLMTR%%%b%DLMTR%%NAME3%" 
		if %DEBUG% GTR 0 echo                      to "%%a%DLMTR%%%b%DLMTR%%NAME4%" ...
		%LN% --quiet --move "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAME3%" "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAME4%" > nul
	)
)


if not exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME4%" goto cleanup_done

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo Checking old %NAME4% backups ...

if %KEEP4% GTR 0 (
	if %DEBUG% GTR 1 echo Keeping %KEEP4% %NAME4% backups
	set "SKIP=skip=%KEEP4% "
) else (
	set SKIP=
)
for /f "%SKIP%tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAME4%"') do (
	
	if %DEBUG% GTR 0 echo.
	
	if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAME4%" ...
	%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAME4%" > nul
	
	if %DELETELOGFILES%==1 (
		if %DEBUG% GTR 1 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAME4%" ...
		del "%LOGFILEPATH%\%BKPNAME%%DLMTR%%%a%DLMTR%%%b.log" > nul
	)
)


:cleanup_done
if %DEBUG% GTR 0 echo.
if %DEBUG% GTR 0 echo Cleanup done.


:errorexit
if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo Done.
if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.


:exit
popd
exit /b %errorlevel%


