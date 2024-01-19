# Fixes the corrupt pause graphics in Zodiac's 'ZO_G1024.BNK'.

. ./_BNKTools.ps1

# Define the file name
$filePrefix = "ZO"
$fileName1024 = "${filePrefix}_G1024.BNK"
$fileName800 = "${filePrefix}_G800.BNK"
$graphicFile = "${filePrefix}_LPAUS.SPB"

# Define the backup file name
$backupFileName = "$fileName1024.bak"

# Check if the target exists
if (!(Test-Path -Path $fileName1024)) {
    Write-Host "File to patch doesn't exist. Exiting early."
    exit
}

# Check if a backup exists. If it does, assume the file has been modified.
if (Test-Path -Path $backupFileName) {
    Write-Host "Backup file already exists. Assuming the file has been modified."
    exit
}

# Backup the original file
Copy-Item -Path $fileName1024 -Destination $backupFileName
Write-Host "Backup created."

# Copy pause graphics from the 800x600 table graphics into 1024x768 table.
$fileContents = Extract-File-Contents $fileName800 $graphicFile
Replace-File $fileName1024 $fileContents
