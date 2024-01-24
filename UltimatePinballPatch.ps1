# Provides static utility methods for reading various data types from a byte array.
# These methods facilitate the extraction of different data types required for processing BNK file contents.
class PatchTool {

    # Extracts a 32-bit unsigned integer from a byte array at a specific offset.
    # Arguments:
    #   $data - The byte array from which to read.
    #   $offset - The position in the byte array to begin reading.
    # Returns a 32-bit integer read from the specified position in the byte array.
    static [uint32]ReadUInt32([byte[]]$data, [uint32]$offset) {
        # Extracts a 4-byte segment from the byte array starting at the given offset
        # Converts this 4-byte segment to a 32-bit integer
        return [BitConverter]::ToUInt32($data[$offset..($offset + 3)], 0)
    }

    # Extracts a segment of a byte array starting from a specified offset.
    # Arguments:
    #   $data - The byte array from which to extract a segment.
    #   $offset - The position in the byte array to begin the segment.
    #   $size - The length of the byte segment to extract.
    # Returns a byte array containing the extracted segment.
    static [byte[]]ReadByteArray([byte[]]$data, [uint32]$offset, [uint32]$size) {
        # Extracts a segment of the byte array starting at $offset and ending at $offset + $size
        # The -1 adjusts the range to be inclusive of the start and exclusive of the end
        return $data[$offset..($offset + $size - 1)]
    }

    # Reads a string from a byte array, stopping at the first null byte.
    # This method is useful for extracting null-terminated strings from binary data.
    # Arguments:
    #   $data - The byte array containing the string data.
    # Returns a string extracted from the byte array, truncated at the first null byte.
    static [string]ReadString([byte[]]$data) {
        # Finds the position of the first null byte in the array
        $nullPos = [Array]::IndexOf($data, [byte]0)
        # Determines the length of the string data; if no null byte is found, uses the full length of the array
        $actualLength = if ($nullPos -ne -1) { $nullPos } else { $data.Length }
        # Extracts the byte array segment representing the string and converts it to a .NET String
        $nameData = $data[0..($actualLength - 1)]
        return [System.Text.Encoding]::UTF8.GetString($nameData).Trim()
    }

    # Adds an entry in one BNK archive with an entry from another BNK archive.
    # The method performs a backup of the destination archive before making changes.
    # It then loads both the source and destination archives, clones the specified entry from the source archive,
    # Adds the corresponding entry in the destination archive with the clone, and finally saves the changes.
    # Parameters:
    #   $sourceEntry - String in the format "SourceArchivePath:SourceEntryName",
    #                  where SourceArchivePath is the path of the source archive and
    #                  SourceEntryName is the name of the entry in the source archive to clone.
    #   $destinationEntry - String in the format "DestinationArchivePath:DestinationEntryName",
    #                where DestinationArchivePath is the path of the destination archive and
    #                DestinationEntryName is the name of the entry in the destination archive to be added.
    static [void]BNKAdd([string]$sourceEntry, [string]$destinationEntry) {
        $sourceArchivePath, $sourceEntryName = $sourceEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationEntry -split ':'

        Write-Host "- Adding entry " -NoNewLine
        Write-Host "$sourceArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$sourceEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            $sourceArchive = [BNKArchive]::Load($sourceArchivePath)
            $entry = $sourceArchive.CloneEntry($sourceEntryName)

            # Name of new entry
            $entry.ChangeName($destinationEntryName)

            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.AddEntry($entry)
            $destinationArchive.Save()
        }
    }

    # Removes an entry from a BNK archive.
    # The method performs a backup of the destination archive before making changes.
    # It then loads the specified archive, removes the specified entry, and saves the changes to the archive.
    # Parameters:
    #   $archivePath - Path of the BNK archive from which an entry is to be removed.
    #   $entryName - Name of the entry to be removed from the archive.
    static [void]BNKRemove([string]$archivePath, [string]$entryName) {
        Write-Host "- Removing entry " -NoNewLine
        Write-Host "$archivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$entryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        if ([PatchTool]::BackupFile($archivePath)) {
            $archive = [BNKArchive]::Load($archivePath)
            $archive.RemoveEntry($entryName)
            $archive.Save()
        }
    }

    # Replaces an entry in one BNK archive with an entry from another BNK archive.
    # The method performs a backup of the destination archive before making changes.
    # It then loads both the source and destination archives, clones the specified entry from the source archive,
    # replaces the corresponding entry in the destination archive with the clone, and finally saves the changes.
    # Parameters:
    #   $sourceEntry - String in the format "SourceArchivePath:SourceEntryName",
    #                  where SourceArchivePath is the path of the source archive and
    #                  SourceEntryName is the name of the entry in the source archive to clone.
    #   $destinationEntry - String in the format "DestinationArchivePath:DestinationEntryName",
    #                where DestinationArchivePath is the path of the destination archive and
    #                DestinationEntryName is the name of the entry in the destination archive to be replaced.
    static [void]BNKReplace([string]$sourceEntry, [string]$destinationEntry) {
        $sourceArchivePath, $sourceEntryName = $sourceEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationEntry -split ':'

        Write-Host "- Replacing entry " -NoNewLine
        Write-Host "$sourceArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$sourceEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan  -NoNewLine
        Write-host "."

        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            $sourceArchive = [BNKArchive]::Load($sourceArchivePath)
            $entry = $sourceArchive.CloneEntry($sourceEntryName)

            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.ReplaceEntry($destinationEntryName, $entry)
            $destinationArchive.Save()
        }
    }

    # Performs a byte patching operation on a file after creating a backup.
    # Throws an error if the backup fails or if no matching sequence is found.
    # Arguments:
    #   $filePath - The name of the file to be patched.
    #   $searchBytes - The byte sequence to search for in the file.
    #   $replaceBytes - The byte sequence to replace the found sequence with.
    static [void]PatchBytes([string]$filePath, [byte[]]$searchBytes, [byte[]]$replaceBytes) {

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

    # Backs up a file to the PatchBackups folder.
    # Returns True if the backup is successful, or False if the file to back up does not exist.
    # Throws an exception if the backup file already exists.
    # Arguments:
    #   $fileName - The name of the file to be backed up.
    static [bool]BackupFile([string]$fileName) {
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

    # Restores any backup files from the PatchBackups folder to their original location.
    # This method will overwrite any existing files in the original location.
    static [void]RestoreBackups() {
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

# Represents an entry in a BNK file.
# This class encapsulates the details and data of a single entry within a BNK archive.
class BNKEntry {
    [byte[]]$data
    [byte[]]$name
    [uint32]$uncompressedSize
    [uint32]$isCompressed

    # Default Constructor for a BNKEntry object.
    # Returns an empty uninitialized BNKEntry.
    BNKEntry() {}

    # Constructor for initializing a BNKEntry object.
    # Extracts and assigns properties of a BNK file entry from the archive data based on a given offset.
    # Arguments:
    #   $archiveData - The complete byte array of the BNK file.
    #   $entryOffset - The offset in the byte array where this entry's data begins.
    # The constructor extracts the entry's name, sizes, compression state, and the data itself.
    # It calculates the starting point of the entry's data within the archive and reads the corresponding bytes.
    # It throws an exception if the calculated start offset is outside the bounds of the archive data.
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

    # Creates a deep copy of the current BNKEntry object.
    # The cloned entry will have the same data, name, uncompressedSize, and isCompressed properties.
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

    # Changes the name of the entry.
    # Arguments:
    #   $newName - The new name to set for the entry.
    # The method throws an exception if the new name exceeds the 32-byte limit.
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

# Represents a BNK archive. This class encapsulates the data and functionality for working with BNK files.
class BNKArchive {
    [string] $archivePath
    [BNKEntry[]] $entries

    # Constructor to initialize BNKArchive from a file path.
    # Reads the BNK file data from the given path and parses it into entries and footer.
    # Arguments:
    #   $archivePath - The file path of the BNK file to be processed.
    # The constructor reads the entire file as a byte array and extracts individual entries and the footer.
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

    # Static method to load a BNKArchive from a specified file path.
    # This method creates and returns a new instance of the BNKArchive class based on the provided archive path.
    # Arguments:
    #   $archivePath - The file path of the BNK archive to be loaded.
    # Returns:
    #   An instance of the BNKArchive class initialized with the data from the specified file path.
    static [BNKArchive] Load([string]$archivePath) {
        # Create a new instance of BNKArchive using the provided file path and return it
        return [BNKArchive]::new($archivePath)
    }

    # Clones a deep copy of an entry from the archive based on its name.
    # The cloned entry will have the same data, name, uncompressedSize, and isCompressed properties.
    # Arguments:
    #   $name - The name of the entry to clone.
    # Returns a deep copy of the BNKEntry object with the specified name.
    # Throws an error if no entry with the specified name is found.
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

    # Adds a cloned BNKEntry to the archive and updates all entry offsets.
    # This ensures that the added entry is independent of any external modifications.
    # Arguments:
    #   $newEntry - The BNKEntry object to be cloned and added to the archive.
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

    # Removes a BNKEntry from the archive by its name.
    # Arguments:
    #   $name - The name of the entry to remove.
    [void] RemoveEntry([string]$name) {
        # Check if the entry exists
        $entryExists = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -eq $name }
        if (-not $entryExists) {
            throw "Entry with name '$name' not found."
        }

        # Remove the entry with the specified name
        $this.entries = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -ne $name }
    }

    # Replaces an existing entry with a provided BNKEntry, while retaining the original name.
    # This method is used to update the data of an entry without changing its identity within the archive.
    # Arguments:
    #   $entryName - The name of the entry to be replaced.
    #   $newEntry - The new BNKEntry object to replace the existing entry.
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

    # Saves the BNKArchive to a file.
    # Writes the contents of the archive, including all entries and the footer, to a file.
    [void] Save() {
        $this.Save($this.archivePath)
    }

    # Saves the BNKArchive to a file.
    # Writes the contents of the archive, including all entries and the footer, to a file.
    # Arguments:
    #   $fileName - The file name to save the archive to.
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
