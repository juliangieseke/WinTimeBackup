@echo off
:: ========================================================================= ::
:: WinTimeBackup - Time Machine for Windows                                  ::
:: by Julian Gieseke (mail@juliangieseke.de)                                 ::
:: based on ln.exe by Hermann Schinagel (Hermann.Schinagl@gmx.net)           ::
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
:: 0 = nothing, 1 = some status, 2 = technical stuff
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
set DST=%~dp0
:: or parameter
::set DST=%~1
:: or something fixed
::set DST=E:\Backups

:: Name of the Backup, used for subfolder if USESUB=1
::set BKPNAME=Backup
:: if you want you can use a paramter for this
::set BKPNAME=%~1
:: or simply the filename of this script
set BKPNAME=%~n0

:: Puts all Backups and Logs into a Subfolder named BKPNAME.
:: set to 1 if you want to use DST/BKPNAME as root folder for Backup 
set USESUB=0

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
:: you have to restart your backup after changing them! 
set NAMEFIRST=daily
set NAMESECOND=weekly
set NAMETHIRD=monthly
set NAMEFOURTH=yearly

:: set how many copies of each set should kept
:: you can change this at any time
set KEEPFIRST=14
set KEEPSECOND=8
set KEEPTHIRD=12
set KEEPFOURTH=2


:: set interval for second, third & fourth 
:: this is used for ID modulo INTERVAL calulations when moving backups to the next set.
:: !!! These Values have to be SMALLER then their corresponding KEEP*
:: every week, set to 14 for bi-weekly
set INTERVALSECOND=7
:: every four weeks
set INTERVALTHIRD=4
:: every 12 months
set INTERVALFOURTH=12

:: ========================================================================= ::
:: INCLUDES/EXCLUDES
:: ========================================================================= ::
:: !!! All options also apply when moving backups to the next set !!!

set OPT=%OPT% --excludedir "Archiv"
set OPT=%OPT% --excludedir "Aufnahmen"
set OPT=%OPT% --excludedir "Bilder"
set OPT=%OPT% --excludedir "Dokumente"
::set OPT=%OPT% --excludedir "Filme"
set OPT=%OPT% --excludedir "Hörbücher"
::set OPT=%OPT% --excludedir "Kamera Upload"
set OPT=%OPT% --excludedir "Lightroom"
::set OPT=%OPT% --excludedir "Musik"
::set OPT=%OPT% --excludedir "Resilio"
::set OPT=%OPT% --excludedir "Serien"
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
:: THATS IT - DONE CHANGE ANYTHING BELOW THIS LINE
:: ========================================================================= ::


set WTB_VERSION=v 0.1 alpha

if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo WinTimeBackup %WTB_VERSION%


setLocal EnableDelayedExpansion

::get datetime from ln.exe
for /f "delims=" %%a in ('%LN% --datetime') do set DATETIME=%%a

:: set suffix for copying process.
set PROGRESSSUFFIX=inprogress
set ERRORSUFFIX=failed

:: cut off trailing slashes from SRC & DST
IF %SRC:~-1%==\ SET SRC=%SRC:~0,-1%
IF %DST:~-1%==\ SET DST=%DST:~0,-1%

:: get GUID from drive letter for SRC & DST
set SRCLETTER=%SRC:~0,1%
set SRCPATH=%SRC:~3%
for /f "delims= " %%a in ('mountvol %SRCLETTER%:\ /L') do set SRCVOL=%%a
set SRCVOL=%SRCVOL:~0,-1%

set DSTLETTER=%DST:~0,1%
set DSTPATH=%DST:~3%
for /f "delims= " %%a in ('mountvol %DSTLETTER%:\ /L') do set DSTVOL=%%a
set DSTVOL=%DSTVOL:~0,-1%

:: ln.exe should use GUID for Destination
set LNDEST=%DSTVOL%\%DSTPATH%
:: and needs a relative logfilepath
set RLOGFILEPATH=%LOGFILEPATH%

:: add %BKPNAME% to dest if USESUB==1
if %USESUB%==1 (
	set LNDEST=%LNDEST%\%BKPNAME%
	set DST=%DST%\%BKPNAME%
	set DSTPATH=%DSTPATH%\%BKPNAME%
	set RLOGFILEPATH=%BKPNAME%\%LOGFILEPATH%
	if not exist "!DST!" mkdir "!DST!"
)

:: add logfile & loglevel
if not exist "%DST%\%LOGFILEPATH%" mkdir "%DST%\%LOGFILEPATH%"
set OPT=%OPT% --quiet %LOGLEVEL%

set errlev=0

if %DEBUG% GTR 0 set OPT=--progress %OPT%


:: ========================================================================= ::
:: PART I: Copying new Files
:: ========================================================================= ::


pushd %DST%

if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Backing up: "%BKPNAME%" 
if %DEBUG% GTR 0 echo from: "%SRC%"
if %DEBUG% GTR 0 echo to: "%DST%"

:: @TODO Need to catch CTRL+c somehow to rename failed backups (see below), otherwise after one 
:: failed no more backups are started...
:: http://stackoverflow.com/questions/27130050/batch-script-if-user-press-ctrlc-do-a-command-before-exitting
if exist "????-??-?? ??-??-?? * %PROGRESSSUFFIX%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Already Backing up, skipping this run!
	
	goto errorexit
)

if %DEBUG% GTR 0 echo =========================================================================

if exist "????-??-?? ??-??-?? * %NAMEFIRST%" (
	:: get last backup and increase its ID by 1
	for /f "tokens=1,2,3 delims= " %%a in ('dir /b /AD /O:N "????-??-?? ??-??-?? * %NAMEFIRST%"') do ( 
		set "LastBackup=%%a %%b %%c %NAMEFIRST%"
		set /a NextId=%%c+1
	)
	popd
	
	if %DEBUG% GTR 0 echo Found old backup: "!LastBackup!"
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Copying files to: "%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%" ...
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo Calling ln.exe:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log" --delorean "%SRC%" "%LNDEST%\!LastBackup!" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"
	
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo ln.exe progress:
	
	%LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log" --delorean "%SRC%" "%LNDEST%\!LastBackup!" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"
	
	set errlev=!errorlevel!
) else (
	:: first backup! copying the files
	popd
	set NextId=0
	
	if %DEBUG% GTR 0 echo No old backup found.
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Copying to "%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"...
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo Calling ln.exe:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log" --copy "%SRC%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo ln.exe progress:
	
	%LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log" --copy "%SRC%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"
	
	set errlev=!errorlevel!
)

if %DEBUG% GTR 1 echo =========================================================================
if %DEBUG% GTR 1 echo ln.exe Returncode was "%errlev%" and its output was:
if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 type "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log"

if !errlev! NEQ 0 ( 
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Backup failed. Trying to rename failed backup:
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo Calling ln.exe:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.errorlog" --move "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %ERRORSUFFIX%"
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo ln.exe progress:
	
	%LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.errorlog" --move "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %ERRORSUFFIX%"
	
	set errlev2=!errorlevel!
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo ln.exe Returncode was "%errlev%" and its output was:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 type "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.errorlog"
	
	if errlev2 EQU 0 (
		if %DEBUG% GTR 0 echo =========================================================================
		if %DEBUG% GTR 0 echo Renaming successfull
	)
	
	::prev error..
	goto errorexit
) else (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Copying successfull. Renaming folder to "%DATETIME% %NextId% %NAMEFIRST%"
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo Calling ln.exe:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.log" --move "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST%"
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo ln.exe progress:
	
	%LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.log" --move "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST%"

	set errlev=!errorlevel!

	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo ln.exe Returncode was "%errlev%" and its output was:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 type "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.log"

	if !errlev! NEQ 0 goto errorexit

	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Renaming successfull
)

:: ========================================================================= ::
:: PART II: Checking/Renaming old Backups
:: ========================================================================= ::
:: (That Code is dirrrty...)

:: first set intervals to needed values.
set /a INTERVALTHIRD=%INTERVALTHIRD%*%INTERVALSECOND%
set /a INTERVALFOURTH=%INTERVALFOURTH%*%INTERVALTHIRD% 


if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Checking old %NAMEFIRST% backups ...

pushd %DST%
for /f "skip=%KEEPFIRST% tokens=1,2,3 delims= " %%a in ('dir /b /A:D /O:-N "????-??-?? ??-??-?? * %NAMEFIRST%"') do (
	set /a MODULO=%%c %% %INTERVALSECOND%
	
	if %DEBUG% GTR 0 echo Modulo of "%%a %%b %%c %NAMEFIRST%" with Interval %INTERVALSECOND% is !MODULO!
	
	if !MODULO! NEQ 0 (
		if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %%c %NAMEFIRST%" ...
		%LN% --deeppathdelete "%%a %%b %%c %NAMEFIRST%" > nul
		
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %%c %NAMEFIRST%" ...
			del "%LOGFILEPATH%\%%a %%b %%c *.log" > nul
		)
	) else (
		if %DEBUG% GTR 0 echo Renaming old backup set "%%a %%b %%c %NAMEFIRST%"
		if %DEBUG% GTR 0 echo                      to "%%a %%b %%c %NAMESECOND%" ...
		%LN% --output "%RLOGFILEPATH%\%%a %%b %%c %NAMESECOND%.move.log" --move "%LNDEST%\%%a %%b %%c %NAMEFIRST%" "%LNDEST%\%%a %%b %%c %NAMESECOND%" 
	)
)

if exist "????-??-?? ??-??-?? * %NAMESECOND%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Checking old %NAMESECOND% backups ...

	for /f "skip=%KEEPSECOND% tokens=1,2,3 delims= " %%a in ('dir /b /A:D /O:-N "????-??-?? ??-??-?? * %NAMESECOND%"') do (
		set /a MODULO=%%c %% %INTERVALTHIRD%
	
		if %DEBUG% GTR 0 echo Modulo of "%%a %%b %%c %NAMESECOND%" with Interval %INTERVALTHIRD% is !MODULO!
	
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %%c %NAMESECOND%" ...
			%LN% --deeppathdelete "%%a %%b %%c %NAMESECOND%" > nul
			
			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %%c %NAMESECOND%" ...
				del "%LOGFILEPATH%\%%a %%b %%c *.log" > nul
			)
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a %%b %%c %NAMESECOND%"
			if %DEBUG% GTR 0 echo                      to "%%a %%b %%c %NAMETHIRD%" ...
			%LN% --output "%RLOGFILEPATH%\%%a %%b %%c %NAMETHIRD%.move.log" --move "%LNDEST%\%%a %%b %%c %NAMESECOND%" "%LNDEST%\%%a %%b %%c %NAMETHIRD%" 
		)
	)
)

if exist "????-??-?? ??-??-?? * %NAMETHIRD%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Checking old %NAMETHIRD% backups ...

	for /f "skip=%KEEPTHIRD% tokens=1,2,3 delims= " %%a in ('dir /b /A:D /O:-N "????-??-?? ??-??-?? * %NAMETHIRD%"') do (
		set /a MODULO=%%c %% %INTERVALFOURTH%
	
		if %DEBUG% GTR 0 echo Modulo of "%%a %%b %%c %NAMETHIRD%" with Interval %INTERVALFOURTH% is !MODULO!
		
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %%c %NAMETHIRD%" ...
			%LN% --deeppathdelete "%%a %%b %%c %NAMETHIRD%" > nul

			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %%c %NAMETHIRD%" ...
				del "%LOGFILEPATH%\%%a %%b %%c *.log" > nul
			)
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a %%b %%c %NAMETHIRD%" 
			if %DEBUG% GTR 0 echo                      to "%%a %%b %%c %NAMEFOURTH%" ...
			%LN% --output "%RLOGFILEPATH%\%%a %%b %%c %NAMEFOURTH%.move.log" --move "%LNDEST%\%%a %%b %%c %NAMETHIRD%" "%LNDEST%\%%a %%b %%c %NAMEFOURTH%" 
		)
	)
)

if exist "????-??-?? ??-??-?? * %NAMEFOURTH%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Checking old %NAMEFOURTH% backups ...

	for /f "skip=%KEEPFOURTH% tokens=1,2,3 delims= " %%a in ('dir /b /A:D /O:-N "????-??-?? ??-??-?? * %NAMEFOURTH%"') do (
		if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %%c %NAMEFOURTH%" ...
		%LN% --deeppathdelete "%%a %%b %%c %NAMEFOURTH%" > nul
		
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %%c %NAMEFOURTH%" ...
			del "%LOGFILEPATH%\%%a %%b %%c *.log" > nul
		)
	)
)

popd

if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Done.
if %DEBUG% GTR 0 echo =========================================================================

:errorexit
if %DEBUG% GTR 0 echo =========================================================================
exit /b %errlev%




