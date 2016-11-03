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
:: v 0.1 alpha 2
:: - changed logfile deletion code
::
:: v 0.1 alpha 1 (first working version)
:: - basic time machine like functionality provided
:: ========================================================================= ::






:: ========================================================================= ::
:: User Options
:: ========================================================================= ::

:: Set Output to cmd (uses echo)
:: 0 = nothing, 1 = some status, 2 = technical stuff
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
:: !WARNING! you have to restart your backup after changing them!
:: ...or at least rename them manually 
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
:: !!! These Values have to be SMALLER OR EQUAL to the KEEP* BEFORE it (INTERVALTHIRD <= KEEPSECOND )
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
::set OPT=%OPT% --exclude "*.ts"


:: ========================================================================= ::
:: THATS IT - DONE CHANGE ANYTHING BELOW THIS LINE
:: ========================================================================= ::


set WTB_VERSION=v 0.1 alpha

if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo WinTimeBackup %WTB_VERSION%


setLocal EnableDelayedExpansion

::get datetime from ln.exe
for /f "tokens=1,2 delims= " %%a in ('ln.exe --datetime') do (
	set LNDATE=%%a
	set LNTIME=%%b
)

:: has to be one token (no space allowed)!
set DATETIME=%LNDATE%_%LNTIME%
set DATEFORMAT=????-??-??_??-??-??

:: set suffix for copying process.
set PROGRESSSUFFIX=working
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

if %DEBUG% GTR 1 set OPT=--progress %OPT%


:: ========================================================================= ::
:: PART I: Copying new Files
:: ========================================================================= ::


pushd %DST%

if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Backup Name: "%BKPNAME%" 
if %DEBUG% GTR 0 echo        From: "%SRC%"
if %DEBUG% GTR 0 echo          To: "%DST%"

:: @TODO Need to catch CTRL+c somehow to rename failed backups (see below), otherwise after one 
:: failed no more backups are started...
:: http://stackoverflow.com/questions/27130050/batch-script-if-user-press-ctrlc-do-a-command-before-exitting
if exist "%DATEFORMAT% * %PROGRESSSUFFIX%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Already Backing up, skipping this run!
	
	goto errorexit
)

if %DEBUG% GTR 0 echo =========================================================================

if exist "%DATEFORMAT% * %NAMEFIRST%" (
	:: get last backup and increase its ID by 1
	for /f "tokens=1,2 delims= " %%a in ('dir /b /AD /O:N "%DATEFORMAT% * %NAMEFIRST%"') do ( 
		set "LastBackup=%%a %%b %NAMEFIRST%"
		set /a NextId=%%b+1
	)
	popd
	
	if %DEBUG% GTR 0 echo Found old backup: "!LastBackup!"
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Copying files to: "%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%" ...
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo Calling ln.exe:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log" --delorean "%SRC%" "%LNDEST%\!LastBackup!" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo ln.exe progress:
	
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
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo ln.exe progress:
	
	%LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log" --copy "%SRC%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%"
	
	set errlev=!errorlevel!
)

if %DEBUG% GTR 1 echo =========================================================================
if %DEBUG% GTR 1 echo ln.exe Returncode was "%errlev%" and its output was:
if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 type "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.copy.log"

if !errlev! NEQ 0 ( 
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Copying failed. Trying to rename failed backup:
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo Calling ln.exe:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.errlog" --move "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %ERRORSUFFIX%"
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo ln.exe progress:
	
	%LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.errlog" --move "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% !NextId! %NAMEFIRST% %ERRORSUFFIX%"
	
	set errlev2=!errorlevel!
	
	if %DEBUG% GTR 1 echo =========================================================================
	if %DEBUG% GTR 1 echo ln.exe Returncode was "%errlev2%" and its output was:
	if %DEBUG% GTR 1 echo.
	if %DEBUG% GTR 1 type "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.errlog"
	
	if errlev2 EQU 0 (
		del "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.errlog" > nul
		if %DEBUG% GTR 0 echo =========================================================================
		if %DEBUG% GTR 0 echo Renaming successfull
	)
	
	::prev error..
	goto errorexit
)

if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Copying successfull.

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
for /f "skip=%KEEPFIRST% tokens=1,2 delims= " %%a in ('dir /b /A:D /O:-N "%DATEFORMAT% * %NAMEFIRST%"') do (
	set /a MODULO=%%b %% %INTERVALSECOND%
	
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Modulo of "%%a %%b %NAMEFIRST%" with Interval %INTERVALSECOND% is !MODULO!
	
	if !MODULO! NEQ 0 (
		if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %NAMEFIRST%" ...
		%LN% --deeppathdelete "%%a %%b %NAMEFIRST%" > nul
		
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %NAMEFIRST%" ...
			del "%LOGFILEPATH%\%%a %%b *.log" > nul
		)
		
	) else (
		if %DEBUG% GTR 0 echo Renaming old backup set "%%a %%b %NAMEFIRST%"
		if %DEBUG% GTR 0 echo                      to "%%a %%b %NAMESECOND%" ...
		%LN% --quiet 1 --output "%RLOGFILEPATH%\%%a %%b %NAMESECOND%.move.log" --move "%LNDEST%\%%a %%b %NAMEFIRST%" "%LNDEST%\%%a %%b %NAMESECOND%" 
		if !errorlevel! EQU 0 del "%LOGFILEPATH%\%%a %%b %NAMESECOND%.move.log" > nul
	)
)

if exist "%DATEFORMAT% * %NAMESECOND%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Checking old %NAMESECOND% backups ...

	for /f "skip=%KEEPSECOND% tokens=1,2 delims= " %%a in ('dir /b /A:D /O:-N "%DATEFORMAT% * %NAMESECOND%"') do (
		set /a MODULO=%%b %% %INTERVALTHIRD%
	
		if %DEBUG% GTR 0 echo =========================================================================
		if %DEBUG% GTR 0 echo Modulo of "%%a %%b %NAMESECOND%" with Interval %INTERVALTHIRD% is !MODULO!
	
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %NAMESECOND%" ...
			%LN% --deeppathdelete "%%a %%b %NAMESECOND%" > nul
			
			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %NAMESECOND%" ...
				del "%LOGFILEPATH%\%%a %%b *.log" > nul
			)
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a %%b %NAMESECOND%"
			if %DEBUG% GTR 0 echo                      to "%%a %%b %NAMETHIRD%" ...
			%LN% --quiet 1 --output "%RLOGFILEPATH%\%%a %%b %NAMETHIRD%.move.log" --move "%LNDEST%\%%a %%b %NAMESECOND%" "%LNDEST%\%%a %%b %NAMETHIRD%" 
			if !errorlevel! EQU 0 del "%LOGFILEPATH%\%%a %%b %NAMETHIRD%.move.log" > nul
		)
	)
)

if exist "%DATEFORMAT% * %NAMETHIRD%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Checking old %NAMETHIRD% backups ...

	for /f "skip=%KEEPTHIRD% tokens=1,2 delims= " %%a in ('dir /b /A:D /O:-N "%DATEFORMAT% * %NAMETHIRD%"') do (
		set /a MODULO=%%b %% %INTERVALFOURTH%
	
		if %DEBUG% GTR 0 echo =========================================================================
		if %DEBUG% GTR 0 echo Modulo of "%%a %%b %NAMETHIRD%" with Interval %INTERVALFOURTH% is !MODULO!
		
		if !MODULO! NEQ 0 (
			if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %NAMETHIRD%" ...
			%LN% --deeppathdelete "%%a %%b %NAMETHIRD%" > nul

			if %DELETELOGFILES%==1 (
				if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %NAMETHIRD%" ...
				del "%LOGFILEPATH%\%%a %%b *.log" > nul
			)
		) else (
			if %DEBUG% GTR 0 echo Renaming old backup set "%%a %%b %NAMETHIRD%" 
			if %DEBUG% GTR 0 echo                      to "%%a %%b %NAMEFOURTH%" ...
			%LN% --quiet 1 --output "%RLOGFILEPATH%\%%a %%b %NAMEFOURTH%.move.log" --move "%LNDEST%\%%a %%b %NAMETHIRD%" "%LNDEST%\%%a %%b %NAMEFOURTH%"
			if !errorlevel! EQU 0 del "%LOGFILEPATH%\%%a %%b %NAMEFOURTH%.move.log" > nul			
		)
	)
)

if exist "%DATEFORMAT% * %NAMEFOURTH%" (
	if %DEBUG% GTR 0 echo =========================================================================
	if %DEBUG% GTR 0 echo Checking old %NAMEFOURTH% backups ...

	for /f "skip=%KEEPFOURTH% tokens=1,2 delims= " %%a in ('dir /b /A:D /O:-N "%DATEFORMAT% * %NAMEFOURTH%"') do (
		if %DEBUG% GTR 0 echo =========================================================================
		if %DEBUG% GTR 0 echo Removing old backup set "%%a %%b %NAMEFOURTH%" ...
		%LN% --deeppathdelete "%%a %%b %NAMEFOURTH%" > nul
		
		if %DELETELOGFILES%==1 (
			if %DEBUG% GTR 0 echo Removing logfiles for "%%a %%b %NAMEFOURTH%" ...
			del "%LOGFILEPATH%\%%a %%b *.log" > nul
		)
	)
)

popd

:: ========================================================================= ::
:: PART THREE: Renaming last backup (removing %PROCESSSUFFIX%)
:: ========================================================================= ::

:: @TODO: check if really successful!
if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Renaming folder to "%DATETIME% %NextId% %NAMEFIRST%"

if %DEBUG% GTR 1 echo =========================================================================
if %DEBUG% GTR 1 echo Calling ln.exe:
if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 echo %LN% %OPT% --output "%RLOGFILEPATH%\%DATETIME% %NextId% %NAMEFIRST%.move.log" --move "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST%"

%LN% --quiet 1 --output "%RLOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.log" --move "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST% %PROGRESSSUFFIX%" "%LNDEST%\%DATETIME% %NextId% %NAMEFIRST%"

set errlev=!errorlevel!

if %DEBUG% GTR 1 echo =========================================================================
if %DEBUG% GTR 1 echo ln.exe Returncode was "!errlev!" and its output was:
if %DEBUG% GTR 1 echo.
if %DEBUG% GTR 1 type "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.log"

if !errlev! EQU 0 del "%LOGFILEPATH%\%DATETIME% !NextId! %NAMEFIRST%.move.log" > nul


:errorexit
if %DEBUG% GTR 0 echo =========================================================================
if %DEBUG% GTR 0 echo Done.
exit /b %errlev%




