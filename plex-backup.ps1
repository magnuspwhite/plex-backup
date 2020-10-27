# Location of the backup folder (the current backup will be created in a timestamped subfolder).
$BackupRootDir = "S:\Backup\Plex"

# Name of the backup file holding exported Plex registry key.
$BackupRegKeyFileName = "Plex.reg"

# Name of the ZIP file holding Plex application data files and folders.
$BackupZipFileName = "Plex.zip"

# Temp folder used to stage archiving job (use local drive for efficiency).
$TempZipFileDir = $env:TEMP

# Plex registry key path.
$PlexRegKey = "HKCU\Software\Plex, Inc.\Plex Media Server"

# Location of the Plex application data folder (default "$env:LOCALAPPDATA\Plex Media Server")
$PlexAppDataFolder = "C:\Plex\Plex Media Server"

# The following application folders do not need to be backed up.
$ExcludeFolders = @("Diagnostics", "Scanners", "Crash Reports", "Updates", "Logs")

# Regular expression used to find names of the Plex Windows services.
$PlexServiceNameMatchString = "^Plex"

# Name of the Plex Media Server executable file.
$PlexServerExeFileName = "Plex Media Server.exe"

# Number of backups to retain: 0 - retain all, 1 - latest backup only, 2 - latest and one before it, etc.
$RetainBackups = 3

# Get list of all running Plex services.
$PlexServices = Get-Service | 
    Where-Object {$_.Name -match $PlexServiceNameMatchString} | 
		Where {$_.status –eq 'Running'}

# Stop all running Plex services.
if ($PlexServices.Count -gt 0)
{
    Write-Host "Stopping Plex service(s):"
    foreach ($PlexService in $PlexServices)
    {
        Write-Host " " $PlexService.Name
        Stop-Service -Name $PlexService.Name -Force
    }
}

# Get path of the Plex Media Server executable.
$PlexServerExePath = Get-Process | 
    Where-Object {$_.Path -match $PlexServerExeFileName + "$" } | 
		Select-Object -ExpandProperty Path

# Stop Plex Media Server executable (if it's still running).
if ($PlexServerExePath)
{
    Write-Host "Stopping Plex Media Server process:"
    Write-Host " " $PlexServerExeFileName
    taskkill /f /im $PlexServerExeFileName /t >$nul 2>&1
}

# Get current timestamp that will be used as a backup folder.
$BackupDir = (Get-Date).ToString("yyyy-MM-dd-HHmmss-plex-backup")

# Make sure that the backup parent folder exists.
New-Item -Path $BackupRootDir -ItemType Directory -Force | Out-Null

# Build backup folder path.
$BackupDirPath = Join-Path $BackupRootDir $BackupDir
Write-Host "New backup will be created under:"
Write-Host " " $BackupRootDir

# If the backup folder already exists, rename it by appending 1 (or next sequential number).
if (Test-Path -Path $BackupDirPath -PathType Container)
{
    $i = 1

    # Parse through all backups of backup folder (with appended counter).
    while (Test-Path -Path $BackupPath + "." + $i -PathType Container)
    {
        $i++
    }

    Write-Host "Renaming old backup folder to " + $BackupDir + "." + $i + "."
    Rename-Item -Path $BackupPath -NewName $BackupDir + "." + $i
}

# Delete old backup folders.
if ($RetainBackups -gt 0)
{
    # Get all folders with names matching our pattern "yyyyMMddHHmmss" from newest to oldest.
    $OldBackupDirs = Get-ChildItem -Path $BackupRootDir -Directory | 
        Where-Object { $_.Name -match '^\d{14}$' } | 
			Sort-Object -Descending

    $i = 1

    if ($OldBackupDirs.Count -ge $RetainBackups)
    {
        Write-Host "Purging old backup folder(s):"
    }

    foreach ($OldBackupDir in $OldBackupDirs)
    {
        if ($i -ge $RetainBackups)
        {
             Write-Host " " $OldBackupDir.Name
             Remove-Item $OldBackupDir.FullName -Force -Recurse -ErrorAction SilentlyContinue
        }

        $i++
    }
}

# Create new backup folder.
Write-Host "Creating new backup folder:"
Write-Host " " $BackupDir
New-Item -Path $BackupDirPath -ItemType Directory -Force | Out-Null

# Export Plex registry key.
Write-Host "Backing up registry key:"
Write-Host " " $PlexRegKey
Write-Host "to file:"
Write-Host " " $BackupRegKeyFileName
Write-Host "in:"
Write-Host " " $BackupDirPath
reg export $PlexRegKey (Join-Path $BackupDirPath $BackupRegKeyFileName) | Out-Null

# Compress Plex media folders.
$TempZipFileName= (New-Guid).Guid + ".zip"
$TempZipFilePath= Join-Path $TempZipFileDir $TempZipFileName

Write-Host "Copying Plex app data from:"
Write-Host " " $PlexAppDataFolder
Write-Host "to a temp file:"
Write-Host " " $TempZipFileName
Write-Host "in:"
Write-Host " " $TempZipFileDir
Get-ChildItem $PlexAppDataFolder -Directory  | 
    Where { $_.Name -notin $ExcludeFolders } | 
        Compress-Archive -DestinationPath $TempZipFilePath -Update

# Copy temp zip file to the backup folder.
Write-Host "Copying temp file:"
Write-Host " " $TempZipFileName
Write-Host "from:"
Write-Host " " $TempZipFileDir
Write-Host "to:"
Write-Host " " $BackupZipFileName
Write-Host "in:"
Write-Host " " $BackupDirPath
Start-BitsTransfer -Source $TempZipFilePath -Destination (Join-Path $BackupDirPath $BackupZipFileName)

# Delete temp file.
Write-Host "Deleting temp file:"
Write-Host " " $TempZipFileName
Write-Host "from:"
Write-Host " " $TempZipFileDir
Remove-Item $TempZi
