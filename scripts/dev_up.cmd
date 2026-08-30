@echo off
setlocal EnableDelayedExpansion
REM Passerelle Windows vers scripts/dev_up.sh.
REM
REM Pourquoi ce fichier : sous Windows, `bash` tout court est résolu par
REM PowerShell vers C:\Windows\System32\bash.exe — celui de WSL. Sans
REM distribution Linux installée, il échoue sur
REM « execvpe(/bin/bash) failed: No such file or directory », une erreur
REM qui n'a rien à voir avec le script. On vise donc le bash de Git,
REM nommément, jamais par son nom court.

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"

REM Dernier recours : déduire l'emplacement depuis git.exe lui-même, qui
REM vit dans <Git>\cmd\ — son bash est donc dans <Git>\bin\.
if not defined BASH (
  for /f "delims=" %%G in ('where git 2^>nul') do (
    if not defined BASH (
      set "GITCMD=%%~dpG"
      if exist "!GITCMD!..\bin\bash.exe" set "BASH=!GITCMD!..\bin\bash.exe"
    )
  )
)

if not defined BASH (
  echo Git Bash introuvable. Installer Git pour Windows ^(git-scm.com^),
  echo ou lancer a la main : bash scripts/dev_up.sh
  REM Sortie 0 volontaire : un prealable ne doit jamais empecher un lancement.
  exit /b 0
)

"%BASH%" "%~dp0dev_up.sh" %*
REM Le script shell sort toujours en 0 ; on relaie quand meme son code.
exit /b %ERRORLEVEL%
