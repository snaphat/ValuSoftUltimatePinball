# Fixes the incorrect spelling of San Francisco in 'sanfran.exe'.

# Define the file name
$fileName = "sanfran.exe"

# Define the backup file name
$backupFileName = "$fileName.bak"

# Check if the target exists
if (!(Test-Path -Path $fileName)) {
    Write-Host "File to patch doesn't exist. Exiting early."
    exit
}

# Check if a backup exists. If it does, assume the file has been modified.
if (Test-Path -Path $backupFileName) {
    Write-Host "Backup file already exists. Assuming the file has been modified."
    exit
}

# Read the file bytes
$fileContent = [IO.File]::ReadAllBytes($fileName)

# Define the byte sequences for search and replace
$searchBytes = @([Byte]0x00) + [Text.Encoding]::ASCII.GetBytes("San Fransisco") + [Byte]0x00
$replaceBytes = @([Byte]0x00) + [Text.Encoding]::ASCII.GetBytes("San Francisco") + [Byte]0x00

# Search for the byte sequence
$found = $false
for ($i = 0; $i -le $fileContent.Length - $searchBytes.Length; $i++) {
    $matchFound = $true
    for ($j = 0; $j -lt $searchBytes.Length; $j++) {
        if ($fileContent[$i + $j] -ne $searchBytes[$j]) {
            $matchFound = $false
            break
        }
    }

    if ($matchFound) {
        Write-Host "Sequence found at position $i"

        # Backup the original file
        Copy-Item -Path $fileName -Destination $backupFileName
        Write-Host "Backup created."

        # Replace the found sequence
        for ($k = 0; $k -lt $replaceBytes.Length; $k++) {
            $fileContent[$i + $k] = $replaceBytes[$k]
        }

        # Write the modified bytes back to the file
        [IO.File]::WriteAllBytes($fileName, $fileContent)
        Write-Host "File has been modified."

        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "No matching sequence found. No modifications were made."
}
