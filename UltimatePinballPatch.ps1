# Set ErrorActionPreference to "Stop"
$ErrorActionPreference = "Stop"

# Reset BNK cache.
[PatchTool]::Reset()

<#
.SYNOPSIS
    A utility class for handling BNK file and general file patching operations.

.DESCRIPTION
    The PatchTool class includes methods for reading data from byte arrays, manipulating BNK archives,
    and patching files with byte-level precision.
#>
class PatchTool {
    <#
    .SYNOPSIS
        Reads a 16-bit unsigned integer from a byte array at a specific offset.

    .DESCRIPTION
        Extracts a 2-byte segment from the byte array starting at the given offset and converts it to a 16-bit unsigned
        integer.

    .PARAMETER data
        The byte array from which to read.

    .PARAMETER offset
        The position in the byte array to begin reading.

    .OUTPUTS
        System.UInt16
        Returns a 16-bit unsigned integer.
    #>
    static [uint16] ReadUInt16([byte[]]$data, [uint64]$offset) {
        # Extracts a 2-byte segment from the byte array starting at the given offset
        # Converts this 2-byte segment to a 16-bit integer
        return [BitConverter]::ToUInt16($data[$offset..($offset + 1)], 0)
    }

    <#
    .SYNOPSIS
        Reads a 16-bit signed integer from a byte array at a specific offset.

    .DESCRIPTION
        Extracts a 2-byte segment from the byte array starting at the given offset and converts it to a 16-bit signed
        integer.

    .PARAMETER data
        The byte array from which to read.

    .PARAMETER offset
        The position in the byte array to begin reading.

    .OUTPUTS
        System.Int16
        Returns a 16-bit signed integer.
    #>
    static [int16] ReadInt16([byte[]]$data, [uint64]$offset) {
        # Extracts a 2-byte segment from the byte array starting at the given offset
        # Converts this 2-byte segment to a 16-bit integer
        return [BitConverter]::ToInt16($data[$offset..($offset + 1)], 0)
    }

    <#
    .SYNOPSIS
        Reads a 32-bit unsigned integer from a byte array at a specific offset.

    .DESCRIPTION
        Extracts a 4-byte segment from the byte array starting at the given offset and converts it to a 32-bit unsigned
        integer.

    .PARAMETER data
        The byte array from which to read.

    .PARAMETER offset
        The position in the byte array to begin reading.

    .OUTPUTS
        System.UInt32
        Returns a 32-bit unsigned integer.
    #>
    static [uint32] ReadUInt32([byte[]]$data, [uint64]$offset) {
        # Extracts a 4-byte segment from the byte array starting at the given offset
        # Converts this 4-byte segment to a 32-bit integer
        return [BitConverter]::ToUInt32($data[$offset..($offset + 3)], 0)
    }

    <#
    .SYNOPSIS
        Extracts a segment of a byte array starting from a specified offset.

    .DESCRIPTION
        Returns a byte array containing the extracted segment, starting at the specified offset and spanning the given
        size.

    .PARAMETER data
        The byte array to extract the segment from.

    .PARAMETER offset
        The starting position of the segment in the byte array.

    .PARAMETER size
        The length of the byte segment to extract.

    .OUTPUTS
        byte[]
        Returns the specified segment of the byte array.
    #>
    static [byte[]] ReadByteArray([byte[]]$data, [uint64]$offset, [uint64]$size) {
        # Extracts a segment of the byte array starting at $offset and ending at $offset + $size
        # The -1 adjusts the range to be inclusive of the start and exclusive of the end
        return $data[$offset..($offset + $size - 1)]
    }

    <#
    .SYNOPSIS
        Reads a string from a byte array, stopping at the first null byte.

    .DESCRIPTION
        Extracts a string from the byte array, truncated at the first null byte, using UTF-8 encoding.

    .PARAMETER data
        The byte array containing the string data.

    .OUTPUTS
        System.String
        Returns a string extracted from the byte array.
    #>
    static [string] ReadString([byte[]]$data) {
        # Finds the position of the first null byte in the array
        $nullPos = [Array]::IndexOf($data, [byte]0)
        # Determines the length of the string data; if no null byte is found, uses the full length of the array
        $actualLength = if ($nullPos -ne -1) { $nullPos } else { $data.Length }
        # Extracts the byte array segment representing the string and converts it to a .NET String
        $nameData = $data[0..($actualLength - 1)]
        return [System.Text.Encoding]::UTF8.GetString($nameData).Trim()
    }

    <#
    .SYNOPSIS
        Adds an entry from one BNK archive to another.

    .DESCRIPTION
        Performs a backup of the destination archive before adding. It loads both source and destination archives,
        clones the specified entry from the source, adds it to the destination, and then saves the changes.

    .PARAMETER sourceArchivePathAndEntry
        The source archive path and entry in the format "SourceArchivePath:SourceEntryName".

    .PARAMETER destinationArchivePathAndEntry
        The destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKAdd([string]$sourceArchivePathAndEntry, [string]$destinationArchivePathAndEntry) {
        [PatchTool]::BNKAdd($sourceArchivePathAndEntry, $destinationArchivePathAndEntry, $false)
    }

    <#
    .SYNOPSIS
        Adds an entry from one BNK archive to another or replacing an existing one.

    .DESCRIPTION
        Performs a backup of the destination archive before adding. It loads both source and destination archives,
        clones the specified entry from the source, adds it to the destination or replaces it, and then saves the
        changes.

    .PARAMETER sourceArchivePathAndEntry
        The source archive path and entry in the format "SourceArchivePath:SourceEntryName".

    .PARAMETER destinationArchivePathAndEntry
        The destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKAdd([string]$sourceArchivePathAndEntry, [string]$destinationArchivePathAndEntry, [bool]$forceReplace) {
        # Perform validations
        if ($null -eq $sourceArchivePathAndEntry) {
            throw "Source cannot be null."
        }
        if ($null -eq $destinationArchivePathAndEntry) {
            throw "Destination cannot be null."
        }

        # Split the source and destination entries into path and name.
        $sourceArchivePath, $sourceEntryName = $sourceArchivePathAndEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

        # Display the process of replacing an entry in the console.
        Write-Host "- Copying entry " -NoNewLine
        Write-Host "$sourceArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$sourceEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan  -NoNewLine
        Write-host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Load the source archive and cache it or grab the cached copy.
            $sourceArchive = [PatchTool]::cachedsourceArchives[$sourceArchivePath]
            if ($null -eq $sourceArchive) {
                $sourceArchive = [BNKArchive]::Load($sourceArchivePath)
                [PatchTool]::cachedsourceArchives.Add($sourceArchivePath, $sourceArchive)
            }

            # Load the destination archive and cache it or grab the cached copy.
            $destinationArchive = [PatchTool]::cachedDestinationArchives[$destinationArchivePath]
            if ($null -eq $destinationArchive) {
                $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
                [PatchTool]::cachedDestinationArchives.Add($destinationArchivePath, $destinationArchive)
            }

            # Grab the source entry.
            $entry = $sourceArchive.GetEntry($sourceEntryName)

            # Add the entry to the destination archive and save it.
            $destinationArchive.AddEntry($destinationEntryName, $entry, $forceReplace)
            $destinationArchive.Save()
        }
    }

    <#
    .SYNOPSIS
        Adds a new entry to a BNK Archive.

    .DESCRIPTION
        Performs a backup of the destination archive before adding. It loads the destination archives, clones the
        specified entry, adds it to the destination, and then saves the changes.

    .PARAMETER $entry
        The BNKEntry object to add to the archive.

    .PARAMETER destinationArchivePathAndEntry
        The destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKAdd([BNKEntry]$entry, [string]$destinationEntry) {
        [PatchTool]::BNKAdd($entry, $destinationEntry, $false)
    }

    <#
    .SYNOPSIS
        Adds a new entry to a BNK Archive or replaces an existing one.

    .DESCRIPTION
        Performs a backup of the destination archive before adding. It loads the destination archives, clones the
        specified entry, adds it to the destination or replaces it, and then saves the changes.

    .PARAMETER $entry
        The BNKEntry object to add to the archive.

    .PARAMETER destinationArchivePathAndEntry
        The destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKAdd([BNKEntry]$entry, [string]$destinationArchivePathAndEntry, [bool]$forceReplace) {
        # Perform validations
        if ($null -eq $entry) {
            throw "Entry cannot be null."
        }

        # Split the destination entry into path and name.
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

        # Display the process of adding an entry in the console.
        Write-Host "- Copying entry " -NoNewLine
        Write-Host "Internal" -ForeGroundColor magenta -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$([PatchTool]::ReadString($entry.name))" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Load the destination archive and cache it or grab the cached copy.
            $destinationArchive = [PatchTool]::cachedDestinationArchives[$destinationArchivePath]
            if ($null -eq $destinationArchive) {
                $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
                [PatchTool]::cachedDestinationArchives.Add($destinationArchivePath, $destinationArchive)
            }

            # Add the entry to the destination archive and save it.
            $destinationArchive.AddEntry($destinationEntryName, $entry, $forceReplace)
            $destinationArchive.Save()
        }
    }

    <#
    .SYNOPSIS
        Replaces an entry in a BNK archive with another entry.

    .DESCRIPTION
        Performs a backup of the destination archive before replacing. Loads both source and destination archives,
        clones the specified entry from the source, replaces the corresponding entry in the destination, and saves the
        changes.

    .PARAMETER sourceArchivePathAndEntry
        The source archive path and entry in the format "SourceArchivePath:SourceEntryName".

    .PARAMETER destinationArchivePathAndEntry
        The destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKReplace([string]$sourceArchivePathAndEntry, [string]$destinationArchivePathAndEntry) {
        # Perform validations
        if ($null -eq $sourceArchivePathAndEntry) {
            throw "Source cannot be null."
        }
        if ($null -eq $destinationArchivePathAndEntry) {
            throw "Destination cannot be null."
        }

        # Split the source and destination entries into path and name.
        $sourceArchivePath, $sourceEntryName = $sourceArchivePathAndEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

        # Display the process of replacing an entry in the console.
        Write-Host "- Copying entry " -NoNewLine
        Write-Host "$sourceArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$sourceEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan  -NoNewLine
        Write-host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Load the source archive and cache it or grab the cached copy.
            $sourceArchive = [PatchTool]::cachedsourceArchives[$sourceArchivePath]
            if ($null -eq $sourceArchive) {
                $sourceArchive = [BNKArchive]::Load($sourceArchivePath)
                [PatchTool]::cachedsourceArchives.Add($sourceArchivePath, $sourceArchive)
            }

            # Load the destination archive and cache it or grab the cached copy.
            $destinationArchive = [PatchTool]::cachedDestinationArchives[$destinationArchivePath]
            if ($null -eq $destinationArchive) {
                $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
                [PatchTool]::cachedDestinationArchives.Add($destinationArchivePath, $destinationArchive)
            }

            # Grab the source entry.
            $entry = $sourceArchive.GetEntry($sourceEntryName)

            # Replace the entry in the destination archive with the entry and save it.
            $destinationArchive.ReplaceEntry($destinationEntryName, $entry)
            $destinationArchive.Save()
        }
    }

    static [void] BNKReplace([BNKEntry]$entry, [string]$destinationArchivePathAndEntry) {
        # Perform validations
        if ($null -eq $entry) {
            throw "Entry cannot be null."
        }
        if ($null -eq $destinationArchivePathAndEntry) {
            throw "Destination cannot be null."
        }

        # Split the destination entry into path and name.
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

        # Display the process of replacing an entry in the console.
        Write-Host "- Copying entry " -NoNewLine
        Write-Host "Internal" -ForeGroundColor magenta -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$([PatchTool]::ReadString($entry.name))" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan  -NoNewLine
        Write-host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Load the destination archive and cache it or grab the cached copy.
            $destinationArchive = [PatchTool]::cachedDestinationArchives[$destinationArchivePath]
            if ($null -eq $destinationArchive) {
                $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
                [PatchTool]::cachedDestinationArchives.Add($destinationArchivePath, $destinationArchive)
            }

            # Replace the entry in the destination archive with the entry and save it.
            $destinationArchive.ReplaceEntry($destinationEntryName, $entry)
            $destinationArchive.Save()
        }
    }

    <#
    .SYNOPSIS
        Removes an entry from a BNK archive.

    .DESCRIPTION
        Performs a backup of the archive before removing the specified entry, then saves the changes to the archive.

    .PARAMETER archivePathAndEntry
        The archive path and entry in the format "ArchivePath:EntryName".
    #>
    static [void] BNKRemove([string]$archivePathAndEntry) {
        [PatchTool]::BNKRemove($archivePathAndEntry, $false)
    }

    <#
    .SYNOPSIS
        Removes an entry from a BNK archive.

    .DESCRIPTION
        Performs a backup of the archive before removing the specified entry, then saves the changes to the archive.

    .PARAMETER archivePathAndEntry
        The archive path and entry in the format "ArchivePath:EntryName".

    .PARAMETER ignoreNotFound
        Ignores errors from the file not being found.
    #>
    static [void] BNKRemove([string]$archivePathAndEntry, [bool]$ignoreNotFound) {
        # Split the entry into path and name.
        $archivePath, $entryName = $archivePathAndEntry -split ':'

        # Display the process of removing an entry in the console.
        Write-Host "- Deleting entry " -NoNewLine
        Write-Host "$archivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$entryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        # Perform a backup before modifying the archive.
        if ([PatchTool]::BackupFile($archivePath)) {
            # Load the destination archive and cache it or grab the cached copy.
            $archive = [PatchTool]::cachedDestinationArchives[$archivePath]
            if ($null -eq $archive) {
                $archive = [BNKArchive]::Load($archivePath)
                [PatchTool]::cachedarchives.Add($archivePath, $archive)
            }

            # Remove the specified entry, and save the changes.
            $archive.RemoveEntry($entryName, $ignoreNotFound)
            $archive.Save()
        }
    }

    <#
    .SYNOPSIS
        Performs a byte patching operation on a file.

    .DESCRIPTION
        Creates a backup of the file before patching. Searches for a specific byte sequence and replaces it with
        another. Throws an error if the sequence is not found.

    .PARAMETER filePath
        The file to be patched.

    .PARAMETER searchBytes
        The byte sequence to search for in the file.

    .PARAMETER replaceBytes
        The byte sequence to replace the found sequence with.
    #>
    static [void] PatchBytes([string]$filePath, [byte[]]$searchBytes, [byte[]]$replaceBytes) {
        [PatchTool]::PatchBytes($filePath, $searchBytes, $replaceBytes, $false)
    }

    <#
    .SYNOPSIS
        Performs a byte patching operation on a file.

    .DESCRIPTION
        Creates a backup of the file before patching. Searches for a specific byte sequence and replaces it with
        another. Throws an error if the sequence is not found and ignoreNotFound is set to false.

    .PARAMETER filePath
        The file to be patched.

    .PARAMETER searchBytes
        The byte sequence to search for in the file.

    .PARAMETER replaceBytes
        The byte sequence to replace the found sequence with.

    .PARAMETER ignoreNotFound
        Ignores errors from the match not being found.
    #>
    static [void] PatchBytes([string]$filePath, [byte[]]$searchBytes, [byte[]]$replaceBytes, [bool]$ignoreNotFound) {
        if ([PatchTool]::BackupFile($filePath)) {
            # Read the file bytes
            $fileContent = [IO.File]::ReadAllBytes($filePath)

            # Search and replace the byte sequence
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
                    # Replace the found sequence
                    for ($k = 0; $k -lt $replaceBytes.Length; $k++) {
                        $fileContent[$i + $k] = $replaceBytes[$k]
                    }

                    # Write the modified bytes back to the file
                    [IO.File]::WriteAllBytes($filePath, $fileContent)

                    Write-Host "- Binary patching " -NoNewLine
                    Write-Host "$filePath" -ForeGroundColor yellow -NoNewLine
                    Write-Host "."

                    $found = $true
                    break
                }
            }

            if (-not $found -and !$ignoreNotFound) {
                throw "No matching sequence found in '$filePath'. No changes made."
            }
        }
    }

    <#
    .SYNOPSIS
        Backs up a file to a specific directory.

    .DESCRIPTION
        Checks if the file exists and backs it up to the 'PatchBackups' directory. Does nothing if the backup already
        exists.

    .PARAMETER fileName
        The name of the file to be backed up.

    .OUTPUTS
        Boolean
        Returns True if the backup is successful or already exists, False otherwise.
    #>
    static [bool] BackupFile([string]$fileName) {
        # Check if the file exists
        if (Test-Path $fileName) {
            # Create the PatchBackups directory if it doesn't exist
            $backupDir = "PatchBackups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir
            }

            $backupFilePath = Join-Path $backupDir (Split-Path $fileName -Leaf)

            # Check if the backup file already exists
            if (Test-Path $backupFilePath) {
                return $true
            }

            # Copy the file to the backup directory
            Copy-Item -Path $fileName -Destination $backupFilePath

            return $true
        }
        else {
            return $false
        }
    }

    <#
    .SYNOPSIS
        Restores backup files to their original location.

    .DESCRIPTION
        Moves files from the 'PatchBackups' directory back to their original location, overwriting existing files if
        necessary.
    #>
    static [void] RestoreBackups() {
        $backupDir = "PatchBackups"

        # Check if the PatchBackups directory exists
        if (-not (Test-Path $backupDir)) {
            Write-Host "No backup directory found."
            return
        }

        # Get all backup files in the directory
        $backupFiles = Get-ChildItem -Path $backupDir

        if ($backupFiles.Length -gt 0) {
            Write-Host "- Restoring backups."
        }

        # Iterate through each backup file and move it to the original location
        foreach ($file in $backupFiles) {
            $originalFilePath = Join-Path (Get-Location) $file.Name

            # Move the backup file to the original location, overwriting if necessary
            Move-Item -Path $file.FullName -Destination $originalFilePath -Force
        }
    }
}

<#
.SYNOPSIS
    Represents an entry in a BNK file.

.DESCRIPTION
    This class encapsulates the details and data of a single entry within a BNK archive. It includes properties for the
    entry's data, name, uncompressed size, and compression state.
#>
class BNKEntry {
    [byte[]] $data
    [byte[]] $name
    [uint32] $uncompressedSize
    [uint32] $isCompressed

    <#
    .SYNOPSIS
        Default constructor for a BNKEntry object.

    .DESCRIPTION
        Creates and returns an empty, uninitialized BNKEntry.
    #>
    BNKEntry() {}

    <#
    .SYNOPSIS
        Constructor for initializing a BNKEntry object from archive data.

    .DESCRIPTION
        Extracts and assigns properties of a BNK file entry from the archive data based on a given offset. It calculates
        the starting point of the entry's data within the archive and reads the corresponding bytes.

    .PARAMETER archiveData
        The complete byte array of the BNK file.

    .PARAMETER entryOffset
        The offset in the byte array where this entry's data begins.
    #>
    BNKEntry([byte[]]$archiveData, [uint32]$entryOffset) {
        # Read the name (32 bytes) of the entry from the archive data at the specified entry offset
        $this.name = [PatchTool]::ReadByteArray($archiveData, $entryOffset, 32)

        # Read various integer values (each 4 bytes long) immediately following the name
        $offsetFromEnd = [PatchTool]::ReadUInt32($archiveData, $entryOffset + 32)
        $compressedSize = [PatchTool]::ReadUInt32($archiveData, $entryOffset + 36)
        $this.uncompressedSize = [PatchTool]::ReadUInt32($archiveData, $entryOffset + 40)
        $this.isCompressed = [PatchTool]::ReadUInt32($archiveData, $entryOffset + 44)

        # Calculate the start position of the entry's data based on its offset from the end of the file
        $dataStart = $archiveData.Length - $offsetFromEnd
        # Extract the data segment based on the calculated start position and compressed size
        $this.data = [PatchTool]::ReadByteArray($archiveData, $dataStart, $compressedSize)

        # Additional validation to ensure the offset and size do not exceed the archive data boundaries
        $offsetFromStart = $archiveData.Length - $offsetFromEnd
        if ($offsetFromStart -lt 0 -or $offsetFromStart + $compressedSize -gt $archiveData.Length) {
            throw "Invalid offset for file entry '$([PatchTool]::ReadString($this.name))'"
        }
    }

    <#
    .SYNOPSIS
        Initializes a BNKEntry object from a BNKWrappedEntry object.

    .DESCRIPTION
        Converts a BNKWrappedEntry back into a BNKEntry. This constructor decodes the Base64 encoded data and name from
        the BNKWrappedEntry and sets them along with the uncompressedSize and isCompressed properties to create a new
        BNKEntry object.

    .PARAMETER entry
        The BNKWrappedEntry object to be converted into a BNKEntry.
    #>
    BNKEntry([BNKWrappedEntry]$entry) {
        $this.data = [System.Convert]::FromBase64String($entry.data)
        $this.name = [System.Convert]::FromBase64String($entry.name)
        $this.uncompressedSize = $entry.uncompressedSize
        $this.isCompressed = $entry.isCompressed
    }

    <#
    .SYNOPSIS
        Wraps the current BNKEntry object into a BNKWrappedEntry object.

    .DESCRIPTION
        Encodes the current BNKEntry object's data and name into Base64 and creates a new BNKWrappedEntry object with
        these encoded values along with the uncompressedSize and isCompressed properties.

    .OUTPUTS
        BNKWrappedEntry
        Returns a BNKWrappedEntry object representing the wrapped version of the current BNKEntry.

    .EXAMPLE
        $bnkEntry = [BNKEntry]::new(...)
        $wrappedEntry = $bnkEntry.Wrap()
    #>
    [BNKWrappedEntry] Wrap() {
        return [BNKWrappedEntry]::new($this);
    }

    <#
    .SYNOPSIS
        Creates a deep copy of the current BNKEntry object.

    .DESCRIPTION
        The cloned entry will have the same data, name, uncompressedSize, and isCompressed properties.
    #>
    [BNKEntry] Clone() {
        # Create a new BNKEntry object for the clone
        $clone = [BNKEntry]::new()

        # Perform a deep copy of the data byte array
        $clone.data = [byte[]]::new($this.data.Length)
        $this.data.CopyTo($clone.data, 0)

        # Perform a deep copy of the name byte array
        $clone.name = [byte[]]::new($this.name.Length)
        $this.name.CopyTo($clone.name, 0)

        # Copy the compression-related properties as they are
        $clone.uncompressedSize = $this.uncompressedSize
        $clone.isCompressed = $this.isCompressed

        # Return the cloned BNKEntry object
        return $clone
    }

    <#
    .SYNOPSIS
        Changes the name of the entry.

    .DESCRIPTION
        Sets a new name for the entry. Throws an exception if the new name exceeds the 32-byte limit.

    .PARAMETER newName
        The new name to set for the entry.
    #>
    [void] Rename([string]$newName) {
        # Convert the string to a byte array (UTF8 encoding)
        $newNameBytes = [System.Text.Encoding]::UTF8.GetBytes($newName)

        # Check if the byte array exceeds 32 bytes
        if ($newNameBytes.Length -gt 32) {
            throw "New name exceeds the maximum allowed length of 32 bytes."
        }

        # Calculate the number of padding bytes needed
        $paddingLength = 32 - $newNameBytes.Length

        # Create an array of zero bytes (null bytes) for padding
        $paddingBytes = New-Object byte[] $paddingLength

        # Concatenate the newNameBytes with the padding bytes
        $paddedNameBytes = $newNameBytes + $paddingBytes

        # Assign the padded byte array to the name
        $this.name = $paddedNameBytes
    }

    [void] Decompress() {
        if (!$this.isCompressed) { return }
        $decompressedData = New-Object System.Collections.Generic.List[byte]
        $destBuffer = New-Object byte[] 4096  # Circular buffer of 4096 bytes
        $bufferPointer = 0xFEE  # Initial buffer pointer, can vary based on implementation
        $i = 0

        while ($i -lt $this.data.Length) {
            $ControlByte = $this.data[$i]
            $i += 1

            for ($Bit = 0; $Bit -lt 8; $Bit++) {
                if ($i -ge $this.data.Length) {
                    break
                }

                if ($ControlByte -band (1 -shl $Bit)) {
                    # Literal byte
                    $Byte = $this.data[$i]
                    $i += 1
                    $decompressedData.Add($Byte)
                    $destBuffer[$bufferPointer] = $Byte
                    $bufferPointer = ($bufferPointer + 1) -band 0xFFF
                }
                else {
                    if ($i + 1 -ge $this.data.Length) {
                        break
                    }

                    # Extract offset and length based on the provided format
                    $Offset = ((($this.data[$i + 1] -shr 4) -band 0xF) -shl 8) -bor $this.data[$i]
                    $Length = ($this.data[$i + 1] -band 0xF) + 3
                    $i += 2

                    for ($j = 0; $j -lt $Length; $j++) {
                        $Byte = $destBuffer[($Offset + $j) -band 0xFFF]
                        $decompressedData.Add($Byte)
                        $destBuffer[$bufferPointer] = $Byte
                        $bufferPointer = ($bufferPointer + 1) -band 0xFFF
                    }
                }
            }
        }

        $this.isCompressed = $false
        $this.data = $decompressedData
        if($this.data.Length -ne $this.uncompressedSize) {
            throw "Error: Decompression size does not match expected size $($this.data.Length) != $($this.uncompressedSize)"
        }
    }
}

<#
.SYNOPSIS
    Represents a wrapped version of a BNKEntry object with Base64 encoded data.

.DESCRIPTION
    BNKWrappedEntry encodes BNKEntry object data and names into Base64. It retains the original entry properties and
    supports conversion back to BNKEntry.
#>
class BNKWrappedEntry {
    [string] $data
    [string] $name
    [uint32] $uncompressedSize
    [uint32] $isCompressed

    <#
    .SYNOPSIS
        Initializes a new instance of the BNKWrappedEntry class from a BNKEntry object.

    .DESCRIPTION
        This constructor takes a BNKEntry object, converts its data and name to Base64 encoded strings, and retains its
        uncompressedSize and isCompressed properties.

    .PARAMETER entry
        The BNKEntry object to wrap.

    .EXAMPLE
        $bnkEntry = [BNKEntry]::new(...)
        $wrappedEntry = [BNKWrappedEntry]::new($bnkEntry)
    #>
    BNKWrappedEntry([BNKEntry]$entry) {
        $this.data = [System.Convert]::ToBase64String($entry.data)
        $this.name = [System.Convert]::ToBase64String($entry.name)
        $this.uncompressedSize = $entry.uncompressedSize
        $this.isCompressed = $entry.isCompressed
    }

    <#
    .SYNOPSIS
        Initializes a new instance of the BNKWrappedEntry class using provided data and properties.

    .DESCRIPTION
        This constructor initializes a BNKWrappedEntry object using provided Base64 encoded data and name, along with
        uncompressedSize and isCompressed values.

    .PARAMETER data
        Base64 encoded string representing the entry's data.

    .PARAMETER name
        Base64 encoded string representing the entry's name.

    .PARAMETER uncompressedSize
        Size of the uncompressed data.

    .PARAMETER isCompressed
        Indicates whether the data is compressed.

    .EXAMPLE
        $wrappedEntry = [BNKWrappedEntry]::new($data, $name, $uncompressedSize, $isCompressed)
    #>
    BNKWrappedEntry([string]$data, [string]$name, [uint32]$uncompressedSize, [uint32]$isCompressed) {
        $this.data = $data
        $this.name = $name
        $this.uncompressedSize = $uncompressedSize
        $this.isCompressed = $isCompressed
    }

    <#
    .SYNOPSIS
        Converts the wrapped entry back into a BNKEntry object.

    .DESCRIPTION
        This method decodes the Base64 encoded data and name in the BNKWrappedEntry object and returns a new BNKEntry
        object with these properties.

    .OUTPUTS
        BNKEntry
        Returns a BNKEntry object reconstructed from the BNKWrappedEntry.

    .EXAMPLE
        $unwrappedEntry = $wrappedEntry.Unwrap()
    #>
    [BNKEntry] Unwrap() {
        return [BNKEntry]::new($this);
    }

    <#
    .SYNOPSIS
        Outputs a PowerShell command that can recreate the current BNKWrappedEntry object.

    .DESCRIPTION
        This method generates and prints a PowerShell command line that can be used to recreate the current
        BNKWrappedEntry object. Useful for debugging or logging the state of the object.

    .OUTPUTS
        Void
        Outputs the creation command to the console but does not return any value.

    .EXAMPLE
        $wrappedEntry.Dump()
    #>
    [void] Dump() {
        Write-Host "`$entry = [BNKWrappedEntry]::New(`"$($this.data)`", `"$($this.name)`", $($this.uncompressedSize), $($this.isCompressed)).Unwrap()"
    }
}

<#
.SYNOPSIS
    Represents a BNK archive.

.DESCRIPTION
    This class encapsulates the data and functionality for working with BNK files. It includes methods for loading and
    saving archives, adding, removing, and replacing entries.
#>
class BNKArchive {
    [string] $archivePath
    [BNKEntry[]] $entries

    <#
    .SYNOPSIS
        Constructor to initialize BNKArchive from a file path.

    .DESCRIPTION
        Reads the BNK file data from the given path and parses it into entries and footer.

    .PARAMETER archivePath
        The file path of the BNK file to be processed.
    #>
    BNKArchive([string]$archivePath) {
        # Check that the archive exists.
        if (!(Test-Path $archivePath -PathType Leaf)) {
            throw "'$archivePath' not found!"
        }

        $this.archivePath = $archivePath
        $this.entries = @()  # Initialize the entries array as empty

        # Read the entire file as a byte array
        $archiveData = Get-Content -Path $archivePath -Encoding Byte -Raw

        # Calculate the start position of the footer data, assuming the footer is 18 bytes from the end
        $footerStart = $archiveData.Length - 18

        # Extract the header (14 bytes)
        $header = [PatchTool]::ReadByteArray($archiveData, $footerStart, 14)

        # Extract the file count (4 bytes)
        $fileCount = [PatchTool]::ReadUInt32($archiveData, $footerStart + 14)

        # Validate the header to ensure it matches the expected format (e.g., "Wildfire`0")
        if (Compare-Object $header ([Text.Encoding]::UTF8.GetBytes("Wildfire") + [byte[]](0x00, 0x00, 0x00, 0x00, 0x01, 0x00))) {
            throw "Error: Invalid archive format"
        }

        # Calculate the starting offset for entries in the archive
        $entryOffset = $archiveData.Length - 18 - ($fileCount * 48)  # 48 bytes per directory entry

        # Extract each entry from the archive data
        for ($i = 0; $i -lt $fileCount; $i++) {
            # Create a new BNKEntry from the archive data at the current offset
            $entry = [BNKEntry]::new($archiveData, $entryOffset)
            # Append the entry to the entries array
            $this.entries += $entry
            # Move to the next entry's offset
            $entryOffset += 48
        }
    }

    <#
    .SYNOPSIS
        Loads a BNKArchive from a specified file path.

    .DESCRIPTION
        Creates and returns a new instance of the BNKArchive class based on the provided archive path.

    .PARAMETER archivePath
        The file path of the BNK archive to be loaded.

    .OUTPUTS
        BNKArchive
        An instance of the BNKArchive class.
    #>
    static [BNKArchive] Load([string]$archivePath) {
        # Create a new instance of BNKArchive using the provided file path and return it
        return [BNKArchive]::new($archivePath)
    }

    <#
    .SYNOPSIS
        Checks if an entry exists in the archive.

    .DESCRIPTION
        Determines if the archive contains an entry with a specific name. This method performs a case-insensitive
        comparison to check for the presence of an entry.

    .PARAMETER name
        The name of the entry to search for in the archive.

    .OUTPUTS
        Boolean
        Returns True if the entry exists in the archive, False otherwise.
    #>
    [bool] HasEntry([string]$name) {
        foreach ($entry in $this.entries) {
            # Perform a case-insensitive comparison of the entry's name with the provided name
            if ([PatchTool]::ReadString($entry.name) -ieq $name) {
                return $true
            }
        }

        # Return false if no entry with the specified name is found
        return $false
    }

    <#
    .SYNOPSIS
        Gets an entry from the archive.

    .DESCRIPTION
        Returns a reference to the entry from the archive based on its name. Returns null if the entry is not found.

    .PARAMETER name
        The name of the entry retrieve.
    #>
    [BNKEntry] GetEntry([string]$name) {
        $foundEntries = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -ieq $name }
        if ($null -ne $foundEntries) { return $foundEntries[0] } else { return $null }
    }

    <#
    .SYNOPSIS
        Clones an entry from the archive.

    .DESCRIPTION
        Creates a deep copy of an entry from the archive based on its name. Throws an error if no entry with
        the specified name is found.

    .PARAMETER name
        The name of the entry to clone.
    #>
    [BNKEntry] CloneEntry([string]$name) {
        # Create and return a deep copy of the found entry
        return GetEntry($name).clone()
    }

    <#
    .SYNOPSIS
        Adds a new entry to the archive.

    .DESCRIPTION
        Adds a new entry to the archive, identified by the name within the passed-in BNKEntry object. This method
        performs a deep copy of the provided BNKEntry object.

    .PARAMETER entry
        The BNKEntry object to add to the archive.
    #>
    [void] AddEntry([BNKEntry]$entry) {
        $this.AddEntry([PatchTool]::ReadString($entry.name), $entry, $false)
    }

    <#
    .SYNOPSIS
        Adds a new entry to the archive or replaces an existing one.

    .DESCRIPTION
        Adds a new entry to the archive, identified by the name within the passed-in BNKEntry object; or, if an entry
        with the same name already exists and 'forceReplace' is set to True, replaces it. This method performs a deep
        copy of the provided BNKEntry object.

    .PARAMETER entry
        The BNKEntry object to add to the archive.

    .PARAMETER forceReplace
        A Boolean flag indicating whether to forcibly replace an existing entry with the same name. If True, an existing
        entry with the same name will be replaced; if False, the new entry will only be added if no existing entry has
        the same name.
    #>
    [void] AddEntry([BNKEntry]$entry, [bool]$forceReplace) {
        $this.AddEntry([PatchTool]::ReadString($entry.name), $entry, $forceReplace)
    }

    <#
    .SYNOPSIS
        Adds a new entry to the archive, specified by the entry name parameter.

    .DESCRIPTION
        Adds a new entry to the archive, identified by the provided entry name parameter, with those from the passed-in
        BNKEntry object. The name within the BNKEntry object is not used. This method performs a deep copy of the
        provided BNKEntry object.

    .PARAMETER entryName
        The name of the entry to add to the archive.

    .PARAMETER entry
        The BNKEntry object to add to the archive. The name within this BNKEntry is not used for identifying the entry
        to be added.
    #>
    [void] AddEntry([string]$entryName, [BNKEntry]$entry) {
        $this.AddEntry($entryName, $entry, $false)
    }

    <#
    .SYNOPSIS
        Adds a new entry to the archive or replaces an existing one, specified by the entry name parameter.

    .DESCRIPTION
        Adds a new entry to the archive, identified by the provided entry name parameter, with those from the passed-in
        BNKEntry object; or, if an entry with the same name already exists and 'forceReplace' is set to True, replaces
        it. The name within the BNKEntry object is not used. This method performs a deep copy of the provided BNKEntry
        object.

    .PARAMETER entryName
        The name of the entry to add to the archive or replace.

    .PARAMETER entry
        The BNKEntry object to add to the archive or replace. The name within this BNKEntry is not used for identifying
        the entry to be added.

    .PARAMETER forceReplace
        A Boolean flag indicating whether to forcibly replace an existing entry with the same name. If True, an existing
        entry with the same name will be replaced; if False, the new entry will only be added if no existing entry has
        the same name.
    #>
    [void] AddEntry([string]$entryName, [BNKEntry]$entry, [bool]$forceReplace) {
        # Perform validations
        if ($null -eq $entryName) {
            throw "Entry name cannot be null."
        }
        if ($null -eq $entry) {
            throw "Entry cannot be null."
        }
        if ($entry.data.Length -eq 0) {
            throw "Entry cannot contain zero length data."
        }

        # Check for duplicate entry names
        $foundEntry = $this.GetEntry($entryName)
        if ($null -ne $foundEntry) {
            if (!$forceReplace) {
                throw "An entry with the name '$entryName' already exists."
            }
            else {
                # modify the entry data
                $foundEntry.data = [byte[]]::new($entry.data.Length)
                $entry.data.CopyTo($foundEntry.data, 0)
                $foundEntry.uncompressedSize = $entry.uncompressedSize
                $foundEntry.isCompressed = $entry.isCompressed
                return
            }
        }

        # Clone the new entry to ensure independence and retain the original name of the entry
        $clone = $entry.Clone()
        $clone.Rename($entryName);

        # Add the new entry
        $this.entries += $clone
    }

    <#
    .SYNOPSIS
        Replaces an existing entry in the archive.

    .DESCRIPTION
        Replaces the data and properties of an existing entry in the archive, identified by the name within the
        passed-in BNKEntry object. This method performs a deep copy of the provided BNKEntry object.

    .PARAMETER entry
        The BNKEntry object providing new data and properties.
    #>
    [void] ReplaceEntry([BNKEntry]$entry) {
        $this.replaceEntry([PatchTool]::ReadString($entry.name), $entry);
    }

    <#
    .SYNOPSIS
        Replaces an existing entry in the archive, specified by the entry name parameter.

    .DESCRIPTION
        Replaces the data and properties of an existing entry in the archive, identified by the provided entry name
        parameter, with those from the passed-in BNKEntry object. The name within the BNKEntry object is not used. This
        method performs a deep copy of the provided BNKEntry object.

    .PARAMETER entryName
        The name of the entry to replace within the archive.

    .PARAMETER entry
        The BNKEntry object providing new data and properties. The name within this BNKEntry is not used for identifying
        the entry to be replaced.
    #>
    [void] ReplaceEntry([string]$entryName, [BNKEntry]$entry) {
        # Perform validations
        if ($null -eq $entryName) {
            throw "Entry name cannot be null."
        }
        if ($null -eq $entry) {
            throw "Entry cannot be null."
        }
        if ($entry.data.Length -eq 0) {
            throw "Entry cannot contain zero length data."
        }

        # Find the index of the entry to be replaced based on the provided name
        $foundEntry = $this.GetEntry($entryName)

        # Throw an error if the specified entry is not found in the archive
        if ($null -eq $foundEntry) {
            throw "Entry with name '$entryName' not found."
        }

        # modify the entry data
        $foundEntry.data = [byte[]]::new($entry.data.Length)
        $entry.data.CopyTo($foundEntry.data, 0)
        $foundEntry.uncompressedSize = $entry.uncompressedSize
        $foundEntry.isCompressed = $entry.isCompressed
    }

    <#
    .SYNOPSIS
        Removes an existing entry in the archive.

    .DESCRIPTION
        Removes an entry from the archive, identified by the passed-in name. Throws an error if the entry is not found.

    .PARAMETER name
        The name of the entry to remove.
    #>
    [void] RemoveEntry([string]$name) {
        $this.RemoveEntry($name, $false)
    }

    <#
    .SYNOPSIS
        Removes an existing entry in the archive.

    .DESCRIPTION
        Removes an entry from the archive, identified by the passed-in name. Throws an error if the entry is not found
        and ignoreNotFound is set to false.

    .PARAMETER name
        The name of the entry to remove.

    .PARAMETER ignoreNotFound
        Ignores errors from the file not being found.
    #>
    [void] RemoveEntry([string]$name, [bool]$ignoreNotFound) {
        # Perform validations
        if ($null -eq $name) {
            throw "Name cannot be null."
        }

        # Attempt to remove the entry with the specified name
        $originalCount = $this.entries.Count
        $this.entries = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -ine $name }

        # Check if any entry was removed
        if ($this.entries.Count -eq $originalCount -and !$ignoreNotFound) {
            throw "Entry with name '$name' not found."
        }
    }

    <#
    .SYNOPSIS
        Saves the BNKArchive to the original file.

    .DESCRIPTION
        Writes the contents of the archive, including all entries and the footer, back to the original file
        specified during the creation of the BNKArchive object. This is an overloaded method that uses the
        archive's own path for saving.

    .OUTPUTS
        None. This method writes the updated archive data to the file system.
    #>
    [void] Save() {
        $this.Save($this.archivePath)
    }

    <#
    .SYNOPSIS
        Saves the BNKArchive to a file.

    .DESCRIPTION
        Writes the contents of the archive, including all entries and the footer, to a file.

    .PARAMETER fileName
        The file name to save the archive to.
    #>
    [void] Save([string]$fileName) {
        # Sort entries before saving
        $this.entries = $this.entries | Sort-Object { [PatchTool]::ReadString($_.name) }

        # Open a file stream for writing
        $fileStream = [System.IO.FileStream]::new($fileName, [System.IO.FileMode]::Create)

        # Tally offset from end to get total file size
        $offsetFromEnd = $this.entries.Length * 48 + 18 # add directory and footer sizes

        # Write each entry's data to the file stream
        foreach ($entry in $this.entries) {
            # Write the main data of the entry
            $fileStream.Write($entry.data, 0, $entry.data.Length)

            # Add file size to offset from end
            $offsetFromEnd += $entry.data.Length
        }

        # Write metadata for each entry
        foreach ($entry in $this.entries) {
            # Check if the name field is exactly 32 bytes
            if ($entry.name.Length -ne 32) {
                throw "Error Saving: Entry name must be exactly 32 bytes."
            }

            # Write the entry's name and other metadata fields
            $fileStream.Write($entry.name, 0, $entry.name.Length)
            $fileStream.Write([BitConverter]::GetBytes($offsetFromEnd), 0, 4)
            $fileStream.Write([BitConverter]::GetBytes($entry.data.Length), 0, 4)
            $fileStream.Write([BitConverter]::GetBytes($entry.uncompressedSize), 0, 4)
            $fileStream.Write([BitConverter]::GetBytes($entry.isCompressed), 0, 4)

            $offsetFromEnd -= $entry.data.Length
        }

        # Write the footer information
        $fileStream.Write(([Text.Encoding]::UTF8.GetBytes("Wildfire") + [byte[]](0x00, 0x00, 0x00, 0x00, 0x01, 0x00)), 0, 14)
        $fileStream.Write([BitConverter]::GetBytes($this.entries.Length), 0, 4)

        # Close the file stream
        $fileStream.Close()
    }
}

class SpriteChunk {
    [int16] $drawOffset
    #[byte[]] $data
    [uint32] $chunkOffset;
    [uint16] $chunkLength;
    [byte[]] $archiveData
    SpriteChunk([byte[]]$archiveData, [uint32]$offset) {
        $this.archiveData = $archiveData
        $this.drawOffset = [PatchTool]::ReadInt16($archiveData, $offset)
        $this.chunkLength = [PatchTool]::ReadUInt16($archiveData, $offset+2)
        $offset += 4


        if($this.chunkLength -eq 0x0) {
            #throw "Sprite Chunk Length of zero not allowed (@ file offset $($offset-2))"
            $this.chunkOffset = 0
        }
        elseif($this.chunkLength -ne 0xffff) {
            $this.chunkOffset = $offset
            # $this.data = [PatchTool]::ReadByteArray($archiveData, $offset, $this.chunkLength)
        }
    }

    [byte] GetByte([uint32]$index) {
        return $this.archiveData[$this.chunkOffset + $index]
    }

    [uint64] TotalSize() {
        if ($this.chunkOffset -ne 0) { return 4 + $this.chunkLength } else { return 4 }
    }
}

class Sprite {
    [int32] $width
    [int32] $height
    [uint32] $centerX
    [uint32] $centerY
    [SpriteChunk[]] $chunks

    Sprite([byte[]]$archiveData, [uint32]$offset) {
        $this.chunks = @()  # Initialize the chunks array as empty

        $this.width =  [PatchTool]::ReadUInt32($archiveData, $offset)
        $this.height =  [PatchTool]::ReadUInt32($archiveData, $offset+4)
        $this.centerX =  [PatchTool]::ReadUInt32($archiveData, $offset+8)
        $this.centerY =  [PatchTool]::ReadUInt32($archiveData, $offset+12)
        $spriteLength = [PatchTool]::ReadUInt32($archiveData, $offset+16)
        $offset += $this.HeaderSize()

        $spriteEnd = $offset + $spriteLength
        while($offset -lt $spriteEnd) {
            $this.chunks += [SpriteChunk]::new($archiveData, $offset)
            $offset += $this.chunks[-1].TotalSize()
        }

        if($spriteLength -ne $this.ChunksSize()) {
            throw "Sprite Length does not match decoded sprite length in file ($spriteLength != $($this.ChunksSize()))"
        }
    }

    [uint64] HeaderSize() {
        return 4 * 5
    }

    [uint64] ChunksSize() {
        return ($this.chunks | ForEach-Object { $_.TotalSize() } | Measure-Object -Sum).Sum
    }

    [uint64] TotalSize() {
        return $this.HeaderSize() + $this.ChunksSize()
    }
}

class SpriteBank {
    [string] $archivePath
    [uint32] $count
    [Sprite[]] $sprites

    SpriteBank([string]$archivePath) {
        # Check that the archive exists.
        if (!(Test-Path $archivePath -PathType Leaf)) {
            throw "'$archivePath' not found!"
        }

        $this.archivePath = $archivePath
        $this.sprites = @()  # Initialize the sprites array as empty

        # Read the entire file as a byte array
        $archiveData = Get-Content -Path $archivePath -Encoding Byte -Raw

        $spriteCount = [PatchTool]::ReadUInt32($archiveData, 0)

        $offset = $this.HeaderSize()

        for ($i = 0; $i -lt $spriteCount; $i++) {
            if($offset -eq $archiveData.Length) {
                break
            }
            $this.sprites += [Sprite]::new($archiveData, $offset)
            $offset += $this.sprites[-1].TotalSize()
        }

        if($archiveData.Length -ne $this.TotalSize()) {
            throw "SpriteBank Length does not match file size ($($archiveData.Length) != $($this.TotalSize()))"
        }
    }

    [uint64] HeaderSize() {
        return 4
    }

    [uint64] SpritesSize() {
        return ($this.sprites | ForEach-Object { $_.TotalSize() } | Measure-Object -Sum).Sum
    }

    [uint64] TotalSize() {
        return $this.HeaderSize() + $this.SpritesSize()
    }

    [void] Dump([ColorPalette] $palette) {
        [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

        #  Write-Host " ==> Write-Host Sprite Count: $($this.sprites.Length)"

        $spriteIndex = 0
        foreach ($sprite in $this.sprites) {
            if ($sprite.width -eq 0 -or $sprite.height -eq 0) {
                continue
            }

            # Write-Host "`nSprite size ($($sprite.width)x$($sprite.height)) with center ($($sprite.centerX),$($sprite.centerY))`n-----------------"
            # Write-Host "d_coord`t d_off`t c_off`t c_length`tmath"
            $bmp = New-Object System.Drawing.Bitmap($sprite.width, $sprite.height)

            $drawOffset = 0
            foreach($chunk in $sprite.chunks) {
                # $oldDrawOffset = $drawOffset
                if ($chunk.drawOffset -ge 0) {
                    $drawOffset += $chunk.drawOffset

                    # Print
                    # $x = $drawOffset % $sprite.width
                    # # $y = [math]::Floor($drawOffset / $sprite.width)
                    # Write-Host "($x,$y)`t $drawOffset`t  $($chunk.drawOffset)`t  $($chunk.data.length)`t    $drawOffset = $oldDrawOffset + $($chunk.drawOffset)"
                }
                else {
                    $drawOffset += $sprite.width + $chunk.drawOffset + 1

                    # print
                    # $x = $drawOffset % $sprite.width
                    # $y = [math]::Floor($drawOffset / $sprite.width)
                    # Write-Host "($x,$y)`t  $drawOffset`t  $($chunk.drawOffset)`t  $($chunk.data.length)`t    $drawOffset = $oldDrawOffset + $($sprite.width) + $($chunk.drawOffset) + 1"
                }

                $chunkStartY = [math]::Floor($drawOffset / $sprite.width)
                for($i=0; $i -lt $chunk.chunkLength -and $chunk.chunkLength -ne 0xffff; $i++) {
                    $x = $drawOffset % $sprite.width
                    $y = [math]::Floor($drawOffset / $sprite.width)

                    # Sanity check
                    if ($chunkStartY -ne $y) {
                        throw "y=$chunkStartY changed to $y in middle of chunk with drawoffset of $($chunk.drawOffset) $i $($chunk.chunkLength)"
                    }

                    $bmp.SetPixel($x, $y, $palette.Get($chunk.GetByte($i)))

                    $drawOffset++
                    $chunkStartY = $y
                }
            }

            $fileName = Split-Path $this.archivePath -Leaf

            $directoryPath = Split-Path $this.archivePath -Parent

            $outFilePath = "$directoryPath\$fileName.$($spriteIndex).bmp"
            Write-Host "Writing file $outFilePath"
            $bmp.Save($outFilePath)
            $spriteIndex++
        }
    }
}

[string[]] $Global:failedEntries = @()
class ColorPalette {
    [string] $archivePath
    [System.Drawing.Color[]] $map


    ColorPalette([string]$archivePath) {
        # Check that the archive exists.
        if (!(Test-Path $archivePath -PathType Leaf)) {
            throw "'$archivePath' not found!"
        }

        $this.archivePath = $archivePath

        $this.map = New-Object System.Drawing.Color[] 256

        # Read the entire file as a byte array
        $archiveData = Get-Content -Path $archivePath -Encoding Byte -Raw

        for ($i = 0; $i -lt 256; $i++) {
            $r = $archiveData[32 + $i*3]
            $g = $archiveData[32 + $i*3+1]
            $b = $archiveData[32 + $i*3+2]
            $this.map[$i] = [System.Drawing.Color]::FromArgb(255, $r, $g, $b)

            # $style = [System.Globalization.NumberStyles]::HexNumber
            # Write-Host "$($r.ToString("X2")) $($g.ToString("X2")) $($b.ToString("X2")) "
        }
    }

    [System.Drawing.Color] Get([byte]$index) {
        return $this.map[$index]
    }

    [void] DumpAllSprites() {

        $directoryPath = Split-Path $this.archivePath -Parent

        # Retrieve all files, then filter for specific extensions
        $files = Get-ChildItem -Path $directoryPath -File | Where-Object {
            $_.Extension -match "\.(SPB|SP0|SP1|DSB|DS0|DS1)$"
        }

        # Iterate over each SPB file
        foreach ($file in $files) {
            # Process the sprite bank here
            Write-Host "Processing file: $($file.FullName)"

            try {
                # Create a new SpriteBank object for each SPB file
                $spriteBank = [SpriteBank]::New($file.FullName)

                Write-Host "Dumping spritebank: $($file.FullName)"
                #
                $spriteBank.Dump($this)
            } catch {
                Write-Host "Error: $($_.Exception.Message)" -Foreground "Red"
                Write-Host $_.ScriptStackTrace -Foreground "DarkGray"
                $Global:failedEntries += $file.FullName
            }
        }
    }
}

try {
    # Restore any backups
    [PatchTool]::RestoreBackups()

    # Fixes the display of 'ghost.exe' in the taskbar. Any variation of "Ghost" cannot be used as a class name in modern
    # windows as it will cause the window to not display in the windows taskbar. We can get around the issue by inserting
    # a non-printable character for <DEL> (0x7F) after the class name.
    [PatchTool]::PatchBytes("ghost.exe",
        @([Byte]0x00) + [Text.Encoding]::UTF8.GetBytes("GHOST") + [Byte]0x00,
        @([Byte]0x00) + [Text.Encoding]::UTF8.GetBytes("GHOST") + [Byte]0x7F)

    # Fixes the incorrect spelling of San Francisco in 'sanfran.exe'.
    [PatchTool]::PatchBytes("sanfran.exe",
        @([Byte]0x00) + [Text.Encoding]::UTF8.GetBytes("San Fransisco") + [Byte]0x00,
        @([Byte]0x00) + [Text.Encoding]::UTF8.GetBytes("San Francisco") + [Byte]0x00)

    # Fixes the corrupt pause graphics in Golf's 'GF_G1024.BNK' that cause crashing.
    [PatchTool]::BNKReplace("GF_G800.BNK:GF_LPAUS.SPB", "GF_G1024.BNK:GF_LPAUS.SPB")

    # Fixes the corrupt pause graphics in Roller Coaster's 'RC_G1024.BNK' that cause crashing.
    [PatchTool]::BNKReplace("RC_G800.BNK:RC_LPAUS.SPB", "RC_G1024.BNK:RC_LPAUS.SPB")

    # Fixes the corrupt pause graphics in Saturn's 'SA_G1024.BNK' that cause crashing.
    [PatchTool]::BNKReplace("SA_G800.BNK:SA_LPAUS.SPB", "SA_G1024.BNK:SA_LPAUS.SPB")

    # Fixes the corrupt pause graphics in Zodiac's 'ZO_G1024.BNK' that cause crashing.
    [PatchTool]::BNKReplace("ZO_G800.BNK:ZO_LPAUS.SPB", "ZO_G1024.BNK:ZO_LPAUS.SPB")

    # Fixes missing music in 'SATURN.BNK' that causes crashing.
    [PatchTool]::BNKAdd("SATELITE.BNK:IT_M_MIS.ADP", "SATURN.BNK:SA_M_MIS.ADP")

    # Fixes the file count in Project Zero's 'PZ_G1024.BNK' caused by the UPG1024.exe patch.
    [PatchTool]::PatchBytes("PZ_G1024.BNK",
        (0x57, 0x69, 0x6C, 0x64, 0x66, 0x69, 0x72, 0x65, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x33, 0x39, 0x00, 0x00),
        (0x57, 0x69, 0x6C, 0x64, 0x66, 0x69, 0x72, 0x65, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x39, 0x00, 0x00, 0x00),
        $true <# Ignoring missing match #>)

    # Fixes missing flippers in ProjectZero's 'PZ_G1024.BNK' using flippers extracted from Devil's Island Pinball.
    $entry_LFBR_DSB = [BNKWrappedEntry]::New("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", 100877, 1).Unwrap()
    $entry_LFBR_DS0 = [BNKWrappedEntry]::New("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", 18019, 1).Unwrap()
    $entry_LFTL_DSB = [BNKWrappedEntry]::New("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", 103411, 1).Unwrap()
    $entry_LFTL_DS0 = [BNKWrappedEntry]::New("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", 29538, 1).Unwrap()
    [PatchTool]::BNKAdd($entry_LFBR_DSB, "PZ_G1024.BNK:PZ_LFBR.DSB", $true <# Force replace #>)
    [PatchTool]::BNKAdd($entry_LFBR_DS0, "PZ_G1024.BNK:PZ_LFBR.DS0", $true <# Force replace #>)
    [PatchTool]::BNKAdd($entry_LFBR_DS0, "PZ_G1024.BNK:PZ_LFBR.DS1", $true <# Force replace #>)
    [PatchTool]::BNKAdd($entry_LFTL_DSB, "PZ_G1024.BNK:PZ_LFTL.DSB", $true <# Force replace #>)
    [PatchTool]::BNKAdd($entry_LFTL_DS0, "PZ_G1024.BNK:PZ_LFTL.DS0", $true <# Force replace #>)
    [PatchTool]::BNKAdd($entry_LFTL_DS0, "PZ_G1024.BNK:PZ_LFTL.DS1", $true <# Force replace #>)
    #[PatchTool]::BNKRemove("PZ_G1024.BNK:PZ_LFBRA.DS0", $true <# Ignoring missing file #>)
}
catch [Exception] {
    Write-Host "Error: $($_.Exception.Message)" -Foreground "Red"
    Write-Host $_.ScriptStackTrace -Foreground "DarkGray"
    exit 1
}
