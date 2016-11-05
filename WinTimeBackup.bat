@echo off
:: ========================================================================= ::
:: WinTimeBackup - Time Machine for Windows                                  ::
:: by Julian Gieseke (mail@juliangieseke.de)                                 ::
:: based on ln.exe by Hermann Schinagel (Hermann.Schinagl@gmx.net)           ::
:: http://schinagl.priv.at/nt/ln/ln.html
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
:: Changelog:
::
:: v 0.1 alpha 1 (first working version)
:: - basic time machine like functionality provided
:: ========================================================================= ::






:: ========================================================================= ::
:: User Options
:: ========================================================================= ::

:: Set Output to cmd (uses echo)
:: 0 = nothing, 1 = some status info @ stdout
set DEBUG=2

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
set BKPNAME=%~n0

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
set LOGFILEPATH=log
:: that SHOULD work
::set LOGFILEPATH=..\log

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
set NAMEFIRST=D
set NAMESECOND=W
set NAMETHIRD=M
set NAMEFOURTH=Y

:: set how many copies of each set should kept
:: you can change this at any time, but keep them >0!
::set KEEPFIRST=28
::set KEEPSECOND=8
::set KEEPTHIRD=9
::set KEEPFOURTH=1
:: @TODO: allow 0
set KEEPFIRST=4
set KEEPSECOND=3
set KEEPTHIRD=2
set KEEPFOURTH=1



:: set interval for second, third & fourth 
:: this is used for ID modulo INTERVAL calulations when moving backups to the next set.
:: !!! These Values have to be SMALLER OR EQUAL to the KEEP* BEFORE it (INTERVALTHIRD <= KEEPSECOND )
:: every week, set to 14 for bi-weekly
set INTERVALSECOND=2
:: every four weeks
set INTERVALTHIRD=2
:: every 12 months
set INTERVALFOURTH=2

:: ========================================================================= ::
:: INCLUDES/EXCLUDES
:: ========================================================================= ::

set OPT=--excludedir "Archiv"
set OPT=%OPT% --excludedir "Aufnahmen"
set OPT=%OPT% --excludedir "Bilder"
set OPT=%OPT% --excludedir "Dokumente"
set OPT=%OPT% --excludedir "Filme"
set OPT=%OPT% --excludedir "H”rbcher"
::set OPT=%OPT% --excludedir "Kamera Upload"
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
::set OPT=%OPT% --exclude "*.ts"


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
	if not exist "%BKPNAME%" mkdir "%BKPNAME%"
)

:: store DST as CD
pushd %DST%

:: add loglevel & loglevel
if not exist "%LOGFILEPATH%" mkdir "%LOGFILEPATH%"
set OPT=%OPT% --quiet %LOGLEVEL%

if %DEBUG% GTR 0 set OPT=%OPT% --progress

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
	if %DEBUG% GTR 0 echo Backup already running or script was killed before. 
	if %DEBUG% GTR 0 echo Starting a new Backup, future backups will use the newest one. 
	if %DEBUG% GTR 0 echo This CAN cause issues - check your Backups! 
)
:: @todo find a better solution, it looks like lk can somehow continue running backups?!


if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.

if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMEFIRST%" (
	:: get last backup and increase its ID by 1
	for /f "tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /AD /O:N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMEFIRST%"') do ( 
		set "LastBackup=%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%"
		set /a NextId=%%b+1
	)
	
	if %DEBUG% GTR 0 echo Found old backup: "!LastBackup!"

	set LNPARAMS=--output "%LOGFILEPATH%\%DATETIME%%DLMTR%!NextId!.log" --delorean "%SRC%" "%LNDST%\!LastBackup!" "%LNDST%\%DATETIME%%DLMTR%!NextId!%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%"
	
) else (
	:: first backup! copying the files
	set NextId=0
	
	if %DEBUG% GTR 0 echo No old backup found.
	
	set LNPARAMS=--output "%LOGFILEPATH%\%DATETIME%%DLMTR%!NextId!.log" --copy "%SRC%" "%LNDST%\%DATETIME%%DLMTR%!NextId!%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%"
)

if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo Copying to "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%"...


if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo %LN% %OPT% %LNPARAMS%

:: calling ln.exe here
%LN% %OPT% %LNPARAMS%

if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo %LN% exit code was %errorlevel%
	
if %errorlevel% NEQ 0 ( 
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Copying failed. See Logfile "%LOGFILEPATH%\%DATETIME%%DLMTR%%NextId%.log" for details
	
	%LN% --quiet --move "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%" "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%ERRORSUFFIX%" > nul
	
	goto errorexit
)

:: what happens if second backup is faster then first?
:: what does that mean for data consistency?
:: @TODO: doesnt work when folder was renamed while this script runs..
if exist "%DATEFORMAT%%DLMTR%%NextID%%DLMTR%%NAMEFIRST%" (
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Finished backup with same ID "%NextId%" already exists, marking this one as duplicate.
	
	%LN% --quiet --move "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%" "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%DOUBLESUFFIX%" > nul
	
	goto errorexit
)

if %DEBUG% GTR 0 echo.
if %DEBUG% GTR 0 echo Copying successful.
if %DEBUG% GTR 0 echo.
if %DEBUG% GTR 0 echo Renaming folder "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%"
if %DEBUG% GTR 0 echo              to "%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%"

%LN% --quiet --move "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%%DLMTR%%COPYSUFFIX%" "%LNDST%\%DATETIME%%DLMTR%%NextId%%DLMTR%%NAMEFIRST%" > nul

if %errorlevel% EQU 0 (
	if %DEBUG% GTR 0 echo. && echo Backup successful.
)


:: ========================================================================= ::
:: PART II: Checking/Renaming old Backups
:: ========================================================================= ::
:: (That Code is dirrrty...)

:: first set intervals to needed values.
set /a INTERVALTHIRD=%INTERVALTHIRD%*%INTERVALSECOND%
set /a INTERVALFOURTH=%INTERVALFOURTH%*%INTERVALTHIRD% 

if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo Cleaning up old Backups

if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMEFIRST%" (
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Checking old %NAMEFIRST% backups ...

	for /f "skip=%KEEPFIRST% tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMEFIRST%"') do (
		set /a MODULO=%%b %% %INTERVALSECOND%
		
		if %DEBUG% GTR 0 echo.
		if %DEBUG% GTR 1 echo Modulo of "%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%" with Interval %INTERVALSECOND% is !MODULO!
		
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%" ...
			%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%" > nul
			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%" ...
				del "%LOGFILEPATH%\%%a%DLMTR%%%b.log" > nul
			)
			
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%"
			if %DEBUG% GTR 0 echo                      to "%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" ...
			
			%LN% --quiet --move "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAMEFIRST%" "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" > nul
		)
	)
)

if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMESECOND%" (
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Checking old %NAMESECOND% backups ...

	for /f "skip=%KEEPSECOND% tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMESECOND%"') do (
		set /a MODULO=%%b %% %INTERVALTHIRD%
	
		if %DEBUG% GTR 0 echo.
		if %DEBUG% GTR 1 echo Modulo of "%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" with Interval %INTERVALTHIRD% is !MODULO!
	
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" ...
			%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" > nul
			
			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" ...
				del "%LOGFILEPATH%\%%a%DLMTR%%%b.log" > nul
			)
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a%DLMTR%%%b%DLMTR%%NAMESECOND%"
			if %DEBUG% GTR 0 echo                      to "%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" ...
			%LN% --quiet --move "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAMESECOND%" "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" > nul
		)
	)
)

if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMETHIRD%" (
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Checking old %NAMETHIRD% backups ...

	for /f "skip=%KEEPTHIRD% tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMETHIRD%"') do (
		set /a MODULO=%%b %% %INTERVALFOURTH%
	
		if %DEBUG% GTR 0 echo.
		if %DEBUG% GTR 1 echo Modulo of "%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" with Interval %INTERVALFOURTH% is !MODULO!
		
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" ...
			%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" > nul

			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" ...
				del "%LOGFILEPATH%\%%a%DLMTR%%%b.log" > nul
			)
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" 
			if %DEBUG% GTR 0 echo                      to "%%a%DLMTR%%%b%DLMTR%%NAMEFOURTH%" ...
			%LN% --quiet --move "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAMETHIRD%" "%LNDST%\%%a%DLMTR%%%b%DLMTR%%NAMEFOURTH%" > nul
		)
	)
)

if exist "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMEFOURTH%" (
	if %DEBUG% GTR 0 echo.
	if %DEBUG% GTR 0 echo Checking old %NAMEFOURTH% backups ...

	for /f "skip=%KEEPFOURTH% tokens=1,2 delims=%DLMTR%" %%a in ('dir /b /A:D /O:-N "%DATEFORMAT%%DLMTR%*%DLMTR%%NAMEFOURTH%"') do (
		if %DEBUG% GTR 0 echo.
		if %DEBUG% GTR 0 echo Removing old backup set "%%a%DLMTR%%%b%DLMTR%%NAMEFOURTH%" ...
		%LN% --deeppathdelete "%%a%DLMTR%%%b%DLMTR%%NAMEFOURTH%" > nul
		
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 0 echo Removing Logfile for "%%a%DLMTR%%%b%DLMTR%%NAMEFOURTH%" ...
			del "%LOGFILEPATH%\%%a%DLMTR%%%b.log" > nul
		)
	)
)
if %DEBUG% GTR 0 echo.
if %DEBUG% GTR 0 echo Cleanup done.


:errorexit
if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.
if %DEBUG% GTR 0 echo Done.
if %DEBUG% GTR 0 echo. && echo ========================================================================= && echo.

popd

exit /b %errorlevel%


