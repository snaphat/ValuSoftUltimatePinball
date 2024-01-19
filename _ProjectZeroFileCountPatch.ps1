# Fixes the file count in Project Zero's 'PZ_G1024.BNK'.

# Define the file name
$filePrefix = "PZ"
$fileName1024 = "${filePrefix}_G1024.BNK"

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

function Fix-FileCount {
    param (
        [string]$archivePath
    )

    function Invoke-Body() {
        # Open the archive file for reading
        $archive = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)

        # Move to the footer section to read metadata
        $archive.Seek(-18, [System.IO.SeekOrigin]::End)  # Footer is 18 bytes

        # Read header
        $footerBytes = New-Object byte[] 18
        $archive.Read($footerBytes, 0, 18)
        $header = [System.Text.Encoding]::UTF8.GetString($footerBytes[0..7])
        $numFiles = [BitConverter]::ToInt32($footerBytes[14..17], 0)

        # Check for correct header
        if ($header -ne "Wildfire") {
            throw "Invalid archive format"
        }

        # Make sure there is the expected 'incorrect' file count
        if ($numFiles -ne 14643) {
            throw "Unexpected file count"
        }

        # Correct file count
        $archive.Seek(-4, [System.IO.SeekOrigin]::End)
        $correctFileCountBytes = [BitConverter]::GetBytes(57)
        $archive.Write($correctFileCountBytes, 0, 4)
        $archive.Close()
    }

    Invoke-Body | Select-Object -Last 0
}

Fix-FileCount $fileName1024
