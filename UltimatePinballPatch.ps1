# Set ErrorActionPreference to "Stop"
$ErrorActionPreference = "Stop"

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

    .PARAMETER sourceArchivePathAndEntry
        The source archive path and entry in the format "SourceArchivePath:SourceEntryName".

    .PARAMETER destinationArchivePathAndEntry
        The destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
    #>
    static [void] BNKAdd([string]$sourceArchivePathAndEntry, [string]$destinationArchivePathAndEntry) {
        # Split the source and destination entries into their respective paths and names.
        $sourceArchivePath, $sourceEntryName = $sourceArchivePathAndEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

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
            $entry = $sourceArchive.GetEntry($sourceEntryName)

            # Add the cloned entry to the destination archive and save it.
            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.AddEntry($destinationEntryName, $entry)
            $destinationArchive.Save()
        }
    }

    static [void] BNKAdd([BNKEntry]$entry, [string]$destinationEntry) {
        # Split the destination entry into path and name.
        $destinationArchivePath, $destinationEntryName = $destinationEntry -split ':'

        # Display the process of adding an entry in the console.
        Write-Host "- Adding entry " -NoNewLine
        Write-Host "$([PatchTool]::ReadString($entry.name))" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan -NoNewLine
        Write-Host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Add the entry to the destination archive and save it.
            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.AddEntry($destinationEntryName, $entry)
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
        # Split the source and destination entries into their respective paths and names.
        $sourceArchivePath, $sourceEntryName = $sourceArchivePathAndEntry -split ':'
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

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
            $entry = $sourceArchive.GetEntry($sourceEntryName)

            # Replace the entry in the destination archive with the cloned entry and save it.
            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
            $destinationArchive.ReplaceEntry($destinationEntryName, $entry)
            $destinationArchive.Save()
        }
    }

    static [void] BNKReplace([BNKEntry]$entry, [string]$destinationArchivePathAndEntry) {
        # Split the destination entry into path and name.
        $destinationArchivePath, $destinationEntryName = $destinationArchivePathAndEntry -split ':'

        # Display the process of replacing an entry in the console.
        Write-Host "- Replacing entry " -NoNewLine
        Write-Host "$([PatchTool]::ReadString($entry.name))" -ForeGroundColor cyan -NoNewLine
        Write-Host " -> " -ForeGroundColor green -NoNewLine
        Write-Host "$destinationArchivePath" -ForeGroundColor yellow -NoNewLine
        Write-Host ":" -NoNewLine
        Write-Host "$destinationEntryName" -ForeGroundColor cyan  -NoNewLine
        Write-host "."

        # Perform a backup before modifying the destination archive.
        if ([PatchTool]::BackupFile($destinationArchivePath)) {
            # Replace the entry in the destination archive with the entry and save it.
            $destinationArchive = [BNKArchive]::Load($destinationArchivePath)
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

    .PARAMETER entryName
        The name of the entry to be removed.
    #>
    static [void] BNKRemove([string]$archivePathAndEntry) {
        # Split the entry into path and name.
        $archivePath, $entryName = $archivePathAndEntry -split ':'

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
        if($null -ne $foundEntries) { return $foundEntries[0] } else { return $null }
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
        if ($null -eq $entry) {
            throw "New entry is null and cannot be added."
        }
        if ($entry.data.Length -eq 0) {
            throw "New entry has no data and cannot be added."
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
        if ($null -eq $entry) {
            throw "New entry is null and cannot be used for replacement."
        }
        if ($entry.data.Length -eq 0) {
            throw "New entry has no data and cannot be used for replacement."
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
        Removes an entry from the archive, identified by the passed-in name.

    .PARAMETER name
        The name of the entry to remove.
    #>
    [void] RemoveEntry([string]$name) {
        # Attempt to remove the entry with the specified name
        $originalCount = $this.entries.Count
        $this.entries = $this.entries | Where-Object { [PatchTool]::ReadString($_.name) -ine $name }

        # Check if any entry was removed
        if ($this.entries.Count -eq $originalCount) {
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
