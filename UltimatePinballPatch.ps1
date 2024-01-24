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
    static [uint32] ReadUInt32([byte[]]$data, [uint32]$offset) {
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
    static [byte[]] ReadByteArray([byte[]]$data, [uint32]$offset, [uint32]$size) {
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

    .PARAMETER sourceEntry
        The source entry in the format "SourceArchivePath:SourceEntryName".

    .PARAMETER destinationEntry
        The destination entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKAdd([string]$sourceEntry, [string]$destinationEntry) {
        # Split the source and destination entries into their respective paths and names.
        $sourceArchivePath, $sourceEntryName = $sourceEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationEntry -split ':'

        # Display the process of adding an entry in the console.
        Write-Host "- Adding entry " -NoNewLine
        Write-Host "$sourceArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$sourceEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Load the source and destination archives.
            $sourceArchive = [BNKArchive]::Load($sourceArchivePath)
            $entry = $sourceArchive.CloneEntry($sourceEntryName)

            # Update the name of the cloned entry.
            $entry.ChangeName($destinationEntryName)

            # Add the cloned entry to the destination archive and save it.
            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.AddEntry($entry)
            $destinationArchive.Save()
        }
    }

    <#
    .SYNOPSIS
        Removes an entry from a BNK archive.

    .DESCRIPTION
        Performs a backup of the archive before removing the specified entry, then saves the changes to the archive.

    .PARAMETER archivePath
        The path of the BNK archive from which an entry is to be removed.

    .PARAMETER entryName
        The name of the entry to be removed.
    #>
    static [void] BNKRemove([string]$archivePath, [string]$entryName) {
        # Display the process of removing an entry in the console.
        Write-Host "- Removing entry " -NoNewLine
        Write-Host "$archivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$entryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        # Perform a backup before modifying the archive.
        if ([PatchTool]::BackupFile($archivePath)) {
            # Load the archive, remove the specified entry, and save the changes.
            $archive = [BNKArchive]::Load($archivePath)
            $archive.RemoveEntry($entryName)
            $archive.Save()
        }
    }

    <#
    .SYNOPSIS
        Replaces an entry in a BNK archive with another entry.

    .DESCRIPTION
        Performs a backup of the destination archive before replacing. Loads both source and destination archives,
        clones the specified entry from the source, replaces the corresponding entry in the destination, and saves the
        changes.

    .PARAMETER sourceEntry
        The source entry in the format "SourceArchivePath:SourceEntryName".

    .PARAMETER destinationEntry
        The destination entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKReplace([string]$sourceEntry, [string]$destinationEntry) {
        # Split the source and destination entries into their respective paths and names.
        $sourceArchivePath, $sourceEntryName = $sourceEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationEntry -split ':'

        # Display the process of replacing an entry in the console.
        Write-Host "- Replacing entry " -NoNewLine
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
            # Load the source and destination archives.
            $sourceArchive = [BNKArchive]::Load($sourceArchivePath)
            $entry = $sourceArchive.CloneEntry($sourceEntryName)

            # Replace the entry in the destination archive with the cloned entry and save it.
            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.ReplaceEntry($destinationEntryName, $entry)
            $destinationArchive.Save()
        }
    }

    <#
    .SYNOPSIS
        Performs a byte patching operation on a file.

    .DESCRIPTION
        Creates a backup of the file before patching. Searches for a specific byte sequence and replaces it with another.
        Throws an error if the sequence is not found.

    .PARAMETER filePath
        The file to be patched.

    .PARAMETER searchBytes
        The byte sequence to search for in the file.

    .PARAMETER replaceBytes
        The byte sequence to replace the found sequence with.
    #>
    static [void] PatchBytes([string]$filePath, [byte[]]$searchBytes, [byte[]]$replaceBytes) {

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

            if (-not $found) {
                throw "No matching sequence found in '$filePath'. No changes made."
            }
        }
    }

    <#
    .SYNOPSIS
        Backs up a file to a specific directory.

    .DESCRIPTION
        Checks if the file exists and backs it up to the 'PatchBackups' directory.
        Throws an exception if the backup file already exists.

    .PARAMETER fileName
        The name of the file to be backed up.

    .OUTPUTS
        Boolean
        Returns True if the backup is successful, False otherwise.
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
                throw "Backup file '$backupFilePath' already exists."
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
    This class encapsulates the details and data of a single entry within a BNK archive. It includes properties
    for the entry's data, name, uncompressed size, and compression state.
#>
class BNKEntry {
    [byte[]]$data
    [byte[]]$name
    [uint32]$uncompressedSize
    [uint32]$isCompressed

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
        Extracts and assigns properties of a BNK file entry from the archive data based on a given offset.
        It calculates the starting point of the entry's data within the archive and reads the corresponding bytes.

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
        Creates a deep copy of the current BNKEntry object.

    .DESCRIPTION
        The cloned entry will have the same data, name, uncompressedSize, and isCompressed properties.
    #>
    [BNKEntry]Clone() {
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
    [void] ChangeName([string]$newName) {
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
}

<#
.SYNOPSIS
    Represents a BNK archive.

.DESCRIPTION
    This class encapsulates the data and functionality for working with BNK files. It includes methods for loading
    and saving archives, adding, removing, and replacing entries.
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
        Clones an entry from the archive.

    .DESCRIPTION
        Creates a deep copy of an entry from the archive based on its name. Throws an error if no entry with
        the specified name is found.

    .PARAMETER name
        The name of the entry to clone.
    #>
    [BNKEntry] CloneEntry([string]$name) {
        foreach ($entry in $this.entries) {
            if ([PatchTool]::ReadString($entry.name) -eq $name) {
                # Create and return a deep copy of the found entry
                return $entry.Clone()
            }
        }

        # Throw an error if no entry with the matching name is found
        throw "Entry with name '$name' not found in the archive."
    }

    <#
    .SYNOPSIS
        Adds a cloned BNKEntry to the archive.

    .DESCRIPTION
        Adds a cloned BNKEntry to the archive and updates all entry offsets. This ensures that the added entry
        is independent of any external modifications.

    .PARAMETER newEntry
        The BNKEntry object to be cloned and added to the archive.
    #>
    [void] AddEntry([BNKEntry]$newEntry) {
        # Perform validations
        if ($null -eq $newEntry) {
            throw "New entry is null and cannot be added."
        }

        if ($newEntry.data.Length -eq 0) {
            throw "New entry has no data."
        }

        # Check for duplicate entry names
        $newEntryName = [PatchTool]::ReadString($newEntry.name)
        foreach ($entry in $this.entries) {
            if ([PatchTool]::ReadString($entry.name) -eq $newEntryName) {
                throw "An entry with the name '$newEntryName' already exists."
            }
        }

        # Clone the new entry and add it to the entries array
        # This approach ensures that the entry within the archive is a distinct object
        $this.entries += $newEntry.Clone()
    }

    <#
    .SYNOPSIS
        Removes a BNKEntry from the archive by its name.

    .DESCRIPTION
        Removes an entry from the archive based on the specified name.

    .PARAMETER name
        The name of the entry to remove.
    #>
    [void] RemoveEntry([string]$name) {
        # Check if the entry exists
        $entryExists = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -eq $name }
        if (-not $entryExists) {
            throw "Entry with name '$name' not found."
        }

        # Remove the entry with the specified name
        $this.entries = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -ne $name }
    }

    <#
    .SYNOPSIS
        Replaces an existing entry in the archive.

    .DESCRIPTION
        Replaces an existing entry with a provided BNKEntry, while retaining the original name.
        This method updates the data of an entry without changing its identity within the archive.

    .PARAMETER entryName
        The name of the entry to be replaced.

    .PARAMETER newEntry
        The new BNKEntry object to replace the existing entry.
    #>
    [void] ReplaceEntry([string]$entryName, [BNKEntry]$newEntry) {
        # Validate that the new entry is not null
        if ($null -eq $newEntry) {
            throw "New entry is null and cannot be used for replacement."
        }

        # Find the index of the entry to be replaced based on the provided name
        $indexToReplace = -1
        for ($i = 0; $i -lt $this.entries.Length; $i++) {
            if ([PatchTool]::ReadString($this.entries[$i].name) -eq $entryName) {
                $indexToReplace = $i
                break
            }
        }

        # Throw an error if the specified entry is not found in the archive
        if ($indexToReplace -eq -1) {
            throw "Entry with name '$entryName' not found."
        }

        # Clone the new entry to ensure independence and retain the original name of the entry
        $clone = $newEntry.Clone()
        $clone.name = $this.entries[$indexToReplace].name

        # Replace the old entry with the cloned new entry
        $this.entries[$indexToReplace] = $clone
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
