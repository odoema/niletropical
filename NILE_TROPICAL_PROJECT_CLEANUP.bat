@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM NILE TROPICAL - PROJECT CLEANUP / ARCHITECTURE NORMALIZER
REM
REM Run from the Flutter project root:
REM   C:\...\nile_tropical>
REM
REM PURPOSE
REM   1. Creates a timestamped safety backup.
REM   2. Ensures the intended shared architecture folders exist.
REM   3. Detects duplicate/misplaced service files.
REM   4. Moves the newly-created root OrderService into a SAFE
REM      staging area instead of silently overwriting the existing
REM      production OrderService.
REM   5. Leaves existing application code untouched.
REM
REM IMPORTANT
REM   This script deliberately DOES NOT delete files or overwrite
REM   existing source code. The existing shared/services/order_service.dart
REM   must be reviewed against the new implementation before replacement.
REM ============================================================

echo.
echo ============================================================
echo        NILE TROPICAL PROJECT CLEANUP
echo ============================================================
echo.

REM ----- Confirm project root -----
if not exist "pubspec.yaml" (
    echo ERROR: pubspec.yaml was not found.
    echo Please run this file from the Nile Tropical project root.
    echo.
    pause
    exit /b 1
)

if not exist "lib" (
    echo ERROR: lib folder was not found.
    echo This does not appear to be the Nile Tropical Flutter root.
    echo.
    pause
    exit /b 1
)

REM ----- Timestamp for backup/staging -----
for /f "tokens=1-4 delims=/ " %%a in ("%date%") do (
    set DD=%%a
    set MM=%%b
    set YYYY=%%c
)
set "STAMP=%YYYY%_%MM%_%DD%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "STAMP=%STAMP: =0%"

set "BACKUP=.project_cleanup_backup_%STAMP%"
set "STAGING=lib\_cleanup_staging"

echo Project root:
echo %CD%
echo.
echo Backup folder:
echo %BACKUP%
echo.

REM ----- Create backup -----
echo [1/6] Creating safety backup...

mkdir "%BACKUP%" >nul 2>&1
mkdir "%BACKUP%\lib" >nul 2>&1

if exist "lib\services\order_service.dart" (
    copy /Y "lib\services\order_service.dart" "%BACKUP%\lib\order_service_root.dart" >nul
)

if exist "lib\shared\services\order_service.dart" (
    copy /Y "lib\shared\services\order_service.dart" "%BACKUP%\lib\order_service_shared.dart" >nul
)

if exist "lib\shared\services\supabase_service.dart" (
    copy /Y "lib\shared\services\supabase_service.dart" "%BACKUP%\lib\supabase_service_shared.dart" >nul
)

if exist "lib\shared\models\cart.dart" (
    copy /Y "lib\shared\models\cart.dart" "%BACKUP%\lib\cart_shared.dart" >nul
)

echo       Backup created.
echo.

REM ----- Ensure architecture folders -----
echo [2/6] Checking architecture folders...

if not exist "lib\core\config" mkdir "lib\core\config"
if not exist "lib\core\supabase" mkdir "lib\core\supabase"
if not exist "lib\shared\models" mkdir "lib\shared\models"
if not exist "lib\shared\providers" mkdir "lib\shared\providers"
if not exist "lib\shared\services" mkdir "lib\shared\services"
if not exist "lib\shared\widgets" mkdir "lib\shared\widgets"
if not exist "lib\data\repositories" mkdir "lib\data\repositories"

echo       Architecture folders verified.
echo.

REM ----- Create staging area -----
echo [3/6] Creating cleanup staging area...
if not exist "%STAGING%" mkdir "%STAGING%"
echo       Staging area: %STAGING%
echo.

REM ----- Handle duplicate root OrderService -----
echo [4/6] Handling duplicate OrderService...

if exist "lib\services\order_service.dart" (
    echo       Found:
    echo         lib\services\order_service.dart
    echo.
    echo       Existing canonical service:
    echo         lib\shared\services\order_service.dart
    echo.

    if exist "lib\shared\services\order_service.dart" (
        echo       BOTH files exist.
        echo       Moving the newly-created root file to staging.
        echo       NO existing file will be overwritten.
        echo.

        if exist "%STAGING%\order_service_root_candidate.dart" (
            echo       Existing staging candidate found.
            echo       Leaving current files untouched.
        ) else (
            move /Y "lib\services\order_service.dart" "%STAGING%\order_service_root_candidate.dart" >nul
            echo       Moved to:
            echo         %STAGING%\order_service_root_candidate.dart
        )
    ) else (
        echo       No shared OrderService exists.
        echo       Moving root OrderService into the canonical shared services folder.
        move /Y "lib\services\order_service.dart" "lib\shared\services\order_service.dart" >nul
        echo       Moved to:
        echo         lib\shared\services\order_service.dart
    )
) else (
    echo       No root-level duplicate found.
)

echo.

REM ----- Check expected canonical files -----
echo [5/6] Checking canonical files...

call :checkfile "lib\core\config\env.dart"
call :checkfile "lib\core\supabase\supabase_client.dart"
call :checkfile "lib\shared\models\cart.dart"
call :checkfile "lib\shared\services\supabase_service.dart"
call :checkfile "lib\shared\services\order_service.dart"

echo.

REM ----- Show final tree -----
echo [6/6] Cleanup complete - showing relevant structure.
echo.
echo ------------------------------------------------------------
echo Relevant lib structure:
echo ------------------------------------------------------------
tree "lib" /F
echo ------------------------------------------------------------
echo.

echo ============================================================
echo IMPORTANT NEXT STEP
echo ============================================================
echo.
echo The project has NOT been destructively rewritten.
echo.
echo The root duplicate OrderService, if present, was staged at:
echo   lib\_cleanup_staging\order_service_root_candidate.dart
echo.
echo A backup was created at:
echo   %BACKUP%
echo.
echo We should now compare:
echo   1. lib\shared\services\order_service.dart
echo   2. lib\_cleanup_staging\order_service_root_candidate.dart
echo.
echo Only after that comparison should the final OrderService be chosen.
echo.
echo Recommended test:
echo   flutter analyze
echo.
pause
exit /b 0

:checkfile
if exist "%~1" (
    echo       [OK] %~1
) else (
    echo       [MISSING] %~1
)
exit /b 0
