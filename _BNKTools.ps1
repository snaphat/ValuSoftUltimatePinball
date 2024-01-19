function Read-FilenameFromFile {
    param (
        [System.IO.FileStream]$file
    )
    function Inner-Body() {
        $bytes = New-Object byte[] 32
        $file.Read($bytes, 0, 32)
        $nullPos = [Array]::IndexOf($bytes, [byte]0)

        if ($nullPos -ne -1) {
            $bytes = $bytes[0..($nullPos - 1)]
        }

        [System.Text.Encoding]::UTF8.GetString($bytes).trim()
    }
    Inner-Body | Select-Object -Last 1
}

function Extract-File-Contents {
    param (
        [string]$archivePath,
        [string]$extractionfilename
    )

    function Invoke-Body() {
        # Open the archive file for reading
        $archive = [System.IO.File]::OpenRead($archivePath)

        # Move to the footer section to read metadata
        $archive.Seek(-18, [System.IO.SeekOrigin]::End)  # Footer is 18 bytes

        $footerBytes = New-Object byte[] 18
        $archive.Read($footerBytes, 0, 18)
        $header = [System.Text.Encoding]::UTF8.GetString($footerBytes[0..7])
        $numFiles = [BitConverter]::ToInt32($footerBytes[14..17], 0)

        # Check for correct header
        if ($header -ne "Wildfire") {
            throw "Invalid archive format"
        }

        $archiveSize = $archive.Length

        # Calculate the start of the directory
        $directoryStart = $archiveSize - 18 - ($numFiles * 48)  # 48 bytes per directory entry

        # Iterate through each file in the directory
        for ($i = 0; $i -lt $numFiles; $i++) {
            # Seek to 'filename string'
            $archive.Position = $directoryStart + ($i * 48)

            # Read filename, offset from end, and file length
            $filename = (Read-FilenameFromFile $archive)

            $offsetBytes = New-Object byte[] 16
            $archive.Read($offsetBytes, 0, 16)

            $fileOffsetFromEnd = [BitConverter]::ToInt32($offsetBytes[0..3], 0)
            $fileLength = [BitConverter]::ToInt32($offsetBytes[4..7], 0)
            $unknown = $offsetBytes[8..15]

            # Compute 'file offset from start'
            $fileOffsetFromStart = $archiveSize - $fileOffsetFromEnd

            # Check for invalid offsets
            if ($fileOffsetFromStart -lt 0 -or $fileOffsetFromStart + $fileLength -gt $archiveSize) {
                Write-Host "Error: Invalid offset for file $filename"
                continue
            }

            # Read file data
            $archive.Position = $fileOffsetFromStart
            $fileData = New-Object byte[] $fileLength
            $archive.Read($fileData, 0, $fileLength)

            # Check for matching filename
            if ($filename -eq $extractionfilename) {
                $archive.Close()

                $fileContents = [PSCustomObject]@{
                    name    = $filename
                    data    = $filedata
                    unknown = $unknown
                }

                return $fileContents
            }
        }
        $archive.Close()

        # Throw error
        throw "Extract file contents failed. Failed to find file '$extractionfilename'"
    }

    $fileContents = Invoke-Body

    return $fileContents
}

function Replace-File {
    param (
        [string]$archivePath,
        [PSCustomObject]$fileContents
    )

    function Invoke-Body() {
        # Open the archive file for reading
        $archive = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)

        # Move to the footer section to read metadata
        $archive.Seek(-18, [System.IO.SeekOrigin]::End)  # Footer is 18 bytes

        $footerBytes = New-Object byte[] 18
        $archive.Read($footerBytes, 0, 18)
        $header = [System.Text.Encoding]::UTF8.GetString($footerBytes[0..7])
        $numFiles = [BitConverter]::ToInt32($footerBytes[14..17], 0)

        # Check for correct header
        if ($header -ne "Wildfire") {
            throw "Invalid archive format"
        }

        $archiveSize = $archive.Length

        # Calculate the start of the directory
        $directoryStart = $archiveSize - 18 - ($numFiles * 48)  # 48 bytes per directory entry

        $fileFound = $false

        # Iterate through each file in the directory
        for ($i = 0; $i -lt $numFiles; $i++) {
            # Seek to 'filename string'
            $archive.Position = $directoryStart + ($i * 48)

            # Read filename, offset from end, and file length
            $filename = (Read-FilenameFromFile $archive)

            $offsetBytes = New-Object byte[] 8
            $archive.Read($offsetBytes, 0, 8)

            $fileOffsetFromEnd = [BitConverter]::ToInt32($offsetBytes[0..3], 0)
            $fileLength = [BitConverter]::ToInt32($offsetBytes[4..7], 0)

            # Compute 'file offset from start'
            $fileOffsetFromStart = $archiveSize - $fileOffsetFromEnd

            # Check for invalid offsets
            if ($fileOffsetFromStart -lt 0 -or $fileOffsetFromStart + $fileLength -gt $archiveSize) {
                Write-Host "Error: Invalid offset for file $filename"
                continue
            }

            # Check for matching filename
            if ($filename -eq $fileContents.name) {
                $fileFound = $true

                # Compute the difference in file size
                $fileLengthDiff = $fileContents.data.Length - $fileLength

                # Seek to 'file length'
                $archive.Position = $directoryStart + $i * 48 + 36

                # Replace file length with new file length
                $newLengthBytes = [BitConverter]::GetBytes($fileContents.data.Length)
                $archive.Write($newLengthBytes, 0, 4)
                $archive.Write($fileContents.unknown, 0, 8)

                for ($j = 0; $j -lt $numFiles; $j++) {
                    # Seek to 'file offset from end'
                    $archive.Position = $directoryStart + $j * 48 + 32

                    # Grab original 'file offset from end'
                    $offsetEndBytes = New-Object byte[] 4
                    $archive.Read($offsetEndBytes, 0, 4)
                    $jFileOffsetFromEnd = [BitConverter]::ToInt32($offsetEndBytes, 0)

                    # Check if file offset will be affected by file size changes
                    if ($jFileOffsetFromEnd -ge $fileOffsetFromEnd) {
                        $archive.Position = $directoryStart + $j * 48 + 32
                        # Write new 'file offset from end' based off of difference in replacement file length difference
                        $newOffsetEndBytes = [BitConverter]::GetBytes($jFileOffsetFromEnd + $fileLengthDiff)
                        $archive.Write($newOffsetEndBytes, 0, 4)
                    }
                }

                # Seek to just after the original file
                $archive.Position = $fileOffsetFromStart + $fileLength

                # Record all data after the original file
                $dataChunkSize = $archiveSize - $archive.Position
                $dataChunk = New-Object byte[] $dataChunkSize
                $archive.Read($dataChunk, 0, $dataChunkSize)

                # Seek to before the original file
                $archive.Position = $fileOffsetFromStart

                # Write the replacement file data
                $archive.Write($fileContents.data, 0, $fileContents.data.Length)

                # Write the data that followed the original file
                $archive.Write($dataChunk, 0, $dataChunkSize)

                # Update directory start
                $directoryStart += $fileLengthDiff

                # Update archive size
                $archiveSize += $fileLengthDiff
            }
        }

        if ($fileFound -ne $true) {
            # Throw error
            $filename = $fileContents.name
            throw "Replace file contents failed. Failed to find file '$filename'"
        }
    }

    Invoke-Body | Select-Object -Last 0
}
