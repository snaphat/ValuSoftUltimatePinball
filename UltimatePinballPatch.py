import os
import glob
import shutil
import traceback
from struct import pack
from PIL import Image
from colorama import Fore, Back, Style

class PatchTool:

    cached_source_archives = {}
    cached_destination_archives = {}

    @staticmethod
    def read_int16(data, offset):
        """
        Reads a 16-bit signed integer from a byte array at a specific offset.

        Extracts a 2-byte segment from the byte array starting at the given offset and converts it to a 16-bit signed
        integer.

        Parameters:
            data (bytes): The byte array from which to read.
            offset (int): The position in the byte array to begin reading.

        Returns:
            int: A 16-bit signed integer.
        """
        # Extracts a 2-byte segment from the byte array starting at the given offset
        # Converts this 2-byte segment to a 16-bit integer
        return int.from_bytes(data[offset:offset+2], byteorder='little', signed=True)

    @staticmethod
    def read_uint16(data, offset):
        """
        Reads a 16-bit unsigned integer from a byte array at a specific offset.

        Extracts a 2-byte segment from the byte array starting at the given offset and converts it to a 16-bit unsigned
        integer.

        Parameters:
            data (bytes): The byte array from which to read.
            offset (int): The position in the byte array to begin reading.

        Returns:
            int: A 16-bit unsigned integer.
        """
        # Extracts a 2-byte segment from the byte array starting at the given offset
        # Converts this 2-byte segment to a 16-bit integer
        return int.from_bytes(data[offset:offset+2], byteorder='little', signed=False)

    @staticmethod
    def read_int32(data, offset):
        """
        Reads a 32-bit signed integer from a byte array at a specific offset.

        Extracts a 4-byte segment from the byte array starting at the given offset and converts it to a 32-bit signed
        integer.

        Parameters:
            data (bytes): The byte array from which to read.
            offset (int): The position in the byte array to begin reading.

        Returns:
            int: A 32-bit signed integer.
        """
        # Extracts a 4-byte segment from the byte array starting at the given offset
        # Converts this 4-byte segment to a 32-bit integer
        return int.from_bytes(data[offset:offset+4], byteorder='little', signed=True)

    @staticmethod
    def read_uint32(data, offset):
        """
        Reads a 32-bit unsigned integer from a byte array at a specific offset.

        Extracts a 4-byte segment from the byte array starting at the given offset and converts it to a 32-bit unsigned
        integer.

        Parameters:
            data (bytes): The byte array from which to read.
            offset (int): The position in the byte array to begin reading.

        Returns:
            int: A 32-bit unsigned integer.
        """
        # Extracts a 4-byte segment from the byte array starting at the given offset
        # Converts this 4-byte segment to a 32-bit integer
        return int.from_bytes(data[offset:offset+4], byteorder='little', signed=False)

    @staticmethod
    def read_byte_array(data, offset, size):
        """
        Extracts a segment of a byte array starting from a specified offset.

        Returns a byte array containing the extracted segment, starting at the specified offset and spanning the given
        size.

        Parameters:
            data (bytes): The byte array to extract the segment from.
            offset (int): The starting position of the segment in the byte array.
            size (int): The length of the byte segment to extract.

        Returns:
            bytes: The specified segment of the byte array.
        """
        # Extracts a segment of the byte array starting at offset and ending at offset + size (exclusive)
        return data[offset:offset+size]

    @staticmethod
    def read_string(data):
        """
        Reads a string from a byte array, stopping at the first null byte.

        Extracts a string from the byte array, truncated at the first null byte, using UTF-8 encoding.

        Parameters:
            data (bytes): The byte array containing the string data.

        Returns:
            str: A string extracted from the byte array.
        """
        # Finds the position of the first null byte in the array
        if (null_pos := data.find(0)) != -1:
            # Extracts the byte array segment representing the string
            data = data[:null_pos]

        # Converts it to a Python string
        return data.decode('utf-8').strip()

    @staticmethod
    def bnk_add(*args):
        """
        Adds an entry from one BNK archive to another.

        Performs a backup of the destination archive before adding. It loads both source and destination archives,
        clones the specified entry from the source, adds it to the destination, and then saves the changes.

        Parameters:
        *args: A variable argument list containing either:
            (sourceArchivePathAndEntry: str, destinationArchivePathAndEntry: str):
            The source archive path and entry in the format "SourceArchivePath:SourceEntryName" and
            the destination archive path and entry in the format "DestinationArchivePath:DestinationEntryName".
            (entry: BNKEntry, destinationArchivePathAndEntry: str):
            The BNKEntry object to add to the archive, and the destination archive path and entry in the format
            "DestinationArchivePath:DestinationEntryName".
            (sourceArchivePathAndEntry: str, destinationArchivePathAndEntry: str, forceReplace: bool):
            The source archive path and entry, the destination archive path and entry, and a boolean indicating
            whether to force replace the destination entry if it exists.
            (entry: BNKEntry, destinationArchivePathAndEntry: str, forceReplace: bool):
            The BNKEntry object to add to the archive, the destination archive path and entry, and a boolean indicating
            whether to force replace the destination entry if it exists.

        Raises:
        ValueError: If the arguments provided do not match the expected formats.
        """
        # Validate the number of arguments
        if len(args) not in [2, 3]:
            raise ValueError("Invalid number of arguments provided for BNKAdd function")

        if isinstance(args[0], str):
            source_archive_path, source_entry = args[0].split(":")
            destination_archive_path, destination_entry = args[1].split(":")
            force_replace = args[2] if len(args) == 3 else False

            # Display the process of adding an entry in the console.
            print(f"- Copying entry {Fore.YELLOW}{source_archive_path}{Style.RESET_ALL}" +
                  f":{Fore.CYAN}{source_entry}{Style.RESET_ALL}" +
                  f" -> {Fore.YELLOW}{destination_archive_path}{Style.RESET_ALL}" +
                  f":{Fore.CYAN}{destination_entry}{Style.RESET_ALL}.")

            # Perform a backup before modifying the destination archive.
            if PatchTool.backup_file(destination_archive_path):
                # Load the source archive and cache it or grab the cached copy.
                source_archive = PatchTool.cached_source_archives.get(source_archive_path)
                if source_archive is None:
                    source_archive = BNKArchive(source_archive_path)
                    PatchTool.cached_source_archives[source_archive] = source_archive

                # Load the destination archive and cache it or grab the cached copy.
                destination_archive = PatchTool.cached_destination_archives.get(destination_archive_path)
                if destination_archive is None:
                    destination_archive = BNKArchive(destination_archive_path)
                    PatchTool.cached_destination_archives[destination_archive] = destination_archive

                # Grab the source entry.
                entry = source_archive.get_entry(source_entry)

        elif isinstance(args[0], BNKEntry):
            entry = args[0]
            destination_archive_path, destination_entry = args[1].split(":")
            force_replace = args[2] if len(args) == 3 else False

            # Display the process of adding an entry in the console.
            print(f"- Copying entry {Fore.MAGENTA}Internal{Style.RESET_ALL}" +
                  f":{Fore.CYAN}{PatchTool.ReadString(entry.name)}{Style.RESET_ALL}" +
                  f" -> {Fore.YELLOW}{destination_archive_path}{Style.RESET_ALL}" +
                  f":{Fore.CYAN}{destination_entry}{Style.RESET_ALL}.")

        # Perform a backup before modifying the destination archive.
        if PatchTool.backup_file(destination_archive_path):
            # Load the destination archive and cache it or grab the cached copy.
            destination_archive = PatchTool.cached_destination_archives.get(destination_archive_path)
            if destination_archive is None:
                destination_archive = BNKArchive(destination_archive_path)
                PatchTool.cached_destination_archives[destination_archive] = destination_archive

            # Add the entry to the destination archive and save it.
            destination_archive.add_entry(destination_entry, entry, force_replace)
            destination_archive.save()

    @staticmethod
    def bnk_replace(*args):
        """
        Replaces an entry in a BNK archive with another entry.

        Parameters:
        *args: A variable argument list that can be:
            (source_archive_path_and_entry: str, destination_archive_path_and_entry: str):
            The source and destination archive paths and entries in the format "SourceArchivePath:SourceEntryName"
            and "DestinationArchivePath:DestinationEntryName" respectively.
            (entry: BNKEntry, destination_archive_path_and_entry: str):
            A BNKEntry object and the destination archive path and entry name in the format
            "DestinationArchivePath:DestinationEntryName".

        Raises:
        ValueError: If the arguments provided do not match the expected formats or if the data extraction from
        archive data fails due to invalid offsets or sizes.
        """
        if len(args) < 2:
            raise ValueError("Insufficient arguments.")

        # Handle BNKReplace from archive paths and entry names
        if isinstance(args[0], str) and isinstance(args[1], str):
            source_archive_path_and_entry, destination_archive_path_and_entry = args
            source_archive_path, source_entry_name = source_archive_path_and_entry.split(':')
            destination_archive_path, destination_entry_name = destination_archive_path_and_entry.split(':')

            # Display the process of replacing an entry in the console
            print(f"- Copying entry {Fore.YELLOW}{source_archive_path}{Style.RESET_ALL}" +
                f":{Fore.CYAN}{source_entry_name}{Style.RESET_ALL}" +
                f" -> {Fore.YELLOW}{destination_archive_path}{Style.RESET_ALL}" +
                f":{Fore.CYAN}{destination_entry_name}{Style.RESET_ALL}.")

            # Perform a backup before modifying the destination archive
            if PatchTool.backup_file(destination_archive_path):
                # Load the source archive and cache it or grab the cached copy
                source_archive = PatchTool.cached_source_archives.get(source_archive_path)
                if source_archive is None:
                    source_archive = BNKArchive(source_archive_path)
                    PatchTool.cached_source_archives[source_archive_path] = source_archive

                # Load the destination archive and cache it or grab the cached copy
                destination_archive = PatchTool.cached_destination_archives.get(destination_archive_path)
                if destination_archive is None:
                    destination_archive = BNKArchive(destination_archive_path)
                    PatchTool.cached_destination_archives[destination_archive_path] = destination_archive

                # Grab the source entry
                entry = source_archive.get_entry(source_entry_name)

        # Handle BNKReplace from BNKEntry and destination archive path and entry name
        elif isinstance(args[0], BNKEntry) and isinstance(args[1], str):
            entry, destination_archive_path_and_entry = args
            destination_archive_path, destination_entry_name = destination_archive_path_and_entry.split(':')

            # Display the process of replacing an entry in the console
            print(f"- Copying entry {Fore.MAGENTA}Internal{Style.RESET_ALL}" +
                  f":{Fore.CYAN}{PatchTool.read_string(entry.name)}{Style.RESET_ALL}" +
                  f" -> {Fore.YELLOW}{destination_archive_path}{Style.RESET_ALL}" +
                  f":{Fore.CYAN}{destination_entry_name}{Style.RESET_ALL}.")

        else:
            raise ValueError("Invalid argument types.")

        # Perform a backup before modifying the destination archive
        if PatchTool.backup_file(destination_archive_path):
            # Load the destination archive and cache it or grab the cached copy
            destination_archive = PatchTool.cached_destination_archives.get(destination_archive_path)
            if destination_archive is None:
                destination_archive = BNKArchive.load(destination_archive_path)
                PatchTool.cached_destination_archives[destination_archive_path] = destination_archive

            # Replace the entry in the destination archive with the entry and save it
            destination_archive.replace_entry(destination_entry_name, entry)
            destination_archive.save()


    @staticmethod
    def bnk_remove(archive_path_and_entry, ignore_not_found):
        """
        Removes an entry from a BNK archive after performing a backup.

        Parameters:
            archive_path_and_entry (str): The archive path and entry in the format "ArchivePath:EntryName".
            ignore_not_found (bool): Ignores errors from the entry not being found.
        """
        # Split the entry into path and name
        archive_path, entry_name = archive_path_and_entry.split(':')

        # Display the process of removing an entry in the console
        print(f"- Deleting entry {Fore.YELLOW}{archive_path}{Style.RESET_ALL}" +
              f":{Fore.CYAN}{entry_name}{Style.RESET_ALL}.")

        # Perform a backup before modifying the archive
        if PatchTool.backup_file(archive_path):
            # Load the destination archive and cache it or grab the cached copy
            archive = PatchTool.cached_archives.get(archive_path)
            if archive is None:
                archive = BNKArchive.load(archive_path)  # Assuming a load method exists
                PatchTool.cached_archives[archive_path] = archive

            # Remove the specified entry, and save the changes
            archive.remove_entry(entry_name, ignore_not_found)
            archive.save()


    @staticmethod
    def patch_bytes(filePath, searchBytes, replaceBytes, ignoreNotFound=False):
        """
        Performs a byte patching operation on a file.

        Creates a backup of the file before patching. Searches for a specific byte sequence and replaces it with
        another. Throws an error if the sequence is not found and ignoreNotFound is set to false.

        Parameters:
            filePath (str): The file to be patched.
            searchBytes (bytes): The byte sequence to search for in the file.
            replaceBytes (bytes): The byte sequence to replace the found sequence with.
            ignoreNotFound (bool): Ignores errors from the match not being found.
        """
        if PatchTool.backup_file(filePath):
            # Read the file bytes
            with open(filePath, "rb") as file:
                fileContent = bytearray(file.read())

            # Search and replace the byte sequence
            found = False
            for i in range(len(fileContent) - len(searchBytes) + 1):
                if fileContent[i:i+len(searchBytes)] == searchBytes:
                    fileContent[i:i+len(replaceBytes)] = replaceBytes

                    # Write the modified bytes back to the file
                    with open(filePath, "wb") as file:
                        file.write(fileContent)

                    print(f"- Binary patching {Fore.YELLOW}{filePath}{Style.RESET_ALL}.")
                    found = True
                    break

            if not found and not ignoreNotFound:
                raise Exception(f"No matching sequence found in '{Fore.YELLOW}{filePath}{Style.RESET_ALL}" +
                                f"'. No changes made.")


    @staticmethod
    def backup_file(fileName):
        """
        Backs up a file to a specific directory.

        Checks if the file exists and backs it up to the 'PatchBackups' directory. Does nothing if the backup already
        exists.

        Parameters:
            fileName (str): The name of the file to be backed up.

        Returns:
            bool: True if the backup is successful or already exists, False otherwise.
        """
        # Check if the file exists
        if os.path.exists(fileName):
            # Create the PatchBackups directory if it doesn't exist
            backupDir = "PatchBackups"
            if not os.path.exists(backupDir):
                os.makedirs(backupDir)

            backupFilePath = os.path.join(backupDir, os.path.basename(fileName))

            # Check if the backup file already exists
            if os.path.exists(backupFilePath):
                return True

            # Copy the file to the backup directory
            shutil.copy(fileName, backupFilePath)
            return True
        else:
            return False

    @staticmethod
    def restore_backups():
        """
        Restores backup files to their original location.

        Moves files from the 'PatchBackups' directory back to their original location, overwriting existing files if
        necessary.
        """
        # Check if the PatchBackups directory exists
        backupDir = "PatchBackups"
        if not os.path.exists(backupDir):
            print("No backup directory found.")
            return

        # Get all backup files in the directory
        backupFiles = os.listdir(backupDir)

        if len(backupFiles) > 0:
            print("- Restoring backups.")

        # Iterate through each backup file and move it to the original location
        for file in backupFiles:
            backupFilePath = os.path.join(backupDir, file)

            # Move the backup file to the original location, overwriting if necessary
            shutil.move(backupFilePath, file)

    @staticmethod
    def extract_all_bnk_files():
        for file_path in glob.glob("*.BNK"):
            print(f"- Extracting files from BNK archive: {Fore.YELLOW}{file_path}{Style.RESET_ALL}")
            bnk_archive = BNKArchive(file_path)
            bnk_archive.dump()

class BNKEntry:
    """
    Represents an entry in a BNK file.

    This class encapsulates the details and data of a single entry within a BNK archive. It includes properties for the
    entry's data, name, uncompressed size, and compression state.
    """

    def __init__(self, *args):
        """
        Overloaded constructor for BNKEntry object.

        Parameters:
            *args: A variable argument list that can be:
                ():
                    Creates and returns an empty, uninitialized BNKEntry (default constructor).
                (archiveData: bytes, entryOffset: int):
                    Initializes a BNKEntry object from archive data by extracting and assigning properties of a BNK file
                    entry from the archive data based on a given offset. Assumes `archiveData` is a byte sequence
                    representing the archive's data and `entryOffset` is an integer specifying the entry's offset within
                    the archive.
                (wrappedEntry: BNKWrappedEntry):
                    Converts a BNKWrappedEntry back into a BNKEntry by decoding the Base64 encoded data and name from
                    the BNKWrappedEntry and sets them along with the uncompressedSize and isCompressed properties to
                    create a new BNKEntry object.

        Raises:
            ValueError: If the arguments provided do not match the expected formats or if the data extraction from
            archive data fails due to invalid offsets or sizes.
        """
        if len(args) == 0:
            # Default constructor creates and returns an empty, uninitialized BNKEntry.
            self.data = None
            self.name = None
            self.uncompressedSize = None
            self.isCompressed = None
        elif len(args) == 2 and isinstance(args[0], (bytes, bytearray)) and isinstance(args[1], int):
            archiveData, entryOffset = args
            # Read the name (32 bytes) of the entry from the archive data at the specified entry offset
            self.name = PatchTool.read_byte_array(archiveData, entryOffset, 32)

            # Read various integer values (each 4 bytes long) immediately following the name
            offsetFromEnd = PatchTool.read_uint32(archiveData, entryOffset + 32)
            compressedSize = PatchTool.read_uint32(archiveData, entryOffset + 36)
            self.uncompressedSize = PatchTool.read_uint32(archiveData, entryOffset + 40)
            self.isCompressed = (bool)(PatchTool.read_uint32(archiveData, entryOffset + 44))

            # Calculate the start position of the entry's data based on its offset from the end of the file
            dataStart = len(archiveData) - offsetFromEnd
            # Extract the data segment based on the calculated start position and compressed size
            self.data = PatchTool.read_byte_array(archiveData, dataStart, compressedSize)

            # Additional validation to ensure the offset and size do not exceed the archive data boundaries
            if dataStart < 0 or dataStart + compressedSize > len(archiveData):
                raise ValueError(f"Invalid offset for file entry '{PatchTool.read_string(self.name)}'")
        elif len(args) == 1 and isinstance(args[0], BNKWrappedEntry):
            entry = args[0]

            # Converts a BNKWrappedEntry back into a BNKEntry by decoding the Base64 encoded data and name
            self.data = base64.b64decode(entry.data)
            self.name = base64.b64decode(entry.name)
            self.uncompressedSize = entry.uncompressedSize
            self.isCompressed = entry.isCompressed
        else:
            raise ValueError("Invalid constructor arguments")

    def wrap(self):
        """
        Wraps the current BNKEntry object into a BNKWrappedEntry object.

        Encodes the current BNKEntry object's data and name into Base64 and creates a new BNKWrappedEntry object with
        these encoded values along with the uncompressedSize and isCompressed properties.

        Returns:
            BNKWrappedEntry: A BNKWrappedEntry object representing the wrapped version of the current BNKEntry.
        """
        return BNKWrappedEntry(self)

    def clone(self):
        """
        Creates a deep copy of the current BNKEntry object.

        The cloned entry will have the same data, name, uncompressedSize, and isCompressed properties.

        Returns:
            BNKEntry: A clone of this object.
        """
        # Create a new BNKEntry object for the clone
        clone = BNKEntry()

        # Perform a deep copy of the data byte array
        clone.data = self.data[:] if self.data else None

        # Perform a deep copy of the name byte array
        clone.name = self.name[:] if self.name else None

        # Copy the compression-related properties as they are
        clone.uncompressedSize = self.uncompressedSize
        clone.isCompressed = self.isCompressed

        # Return the cloned BNKEntry object
        return clone

    def rename(self, newName):
        """
        Changes the name of the entry.

        Sets a new name for the entry. Throws an exception if the new name exceeds the 32-byte limit.

        Parameters:
            newName (str): The new name to set for the entry.
        """
        # Convert the string to a byte array (UTF8 encoding)
        newNameBytes = newName.encode('utf-8')

        # Check if the byte array exceeds 32 bytes
        if len(newNameBytes) > 32:
            raise ValueError("New name exceeds the maximum allowed length of 32 bytes.")

        # Calculate the number of padding bytes needed
        paddingLength = 32 - len(newNameBytes)

        # Concatenate the newNameBytes with the padding bytes
        paddedNameBytes = newNameBytes + bytes(paddingLength)

        # Assign the padded byte array to the name
        self.name = paddedNameBytes

    def decompress(self):
        """
        Decompresses the entry's data if it is compressed.

        Implements a custom decompression algorithm based on control bytes and reference offsets within the data itself.
        This method updates the instance's `data` and `isCompressed` flag upon completion.
        """
        if not self.isCompressed:
            return  # Data is not compressed; no action needed.

        decompressed_data = bytearray()
        dest_buffer = bytearray(4096)  # Circular buffer for back-references
        buffer_pointer = 0xFEE  # Initial buffer pointer, specific to decompression logic

        i = 0
        while i < len(self.data):
            control_byte = self.data[i]
            i += 1

            for bit in range(8):
                if i >= len(self.data):
                    break  # End of data reached

                if control_byte & (1 << bit):
                    # Literal byte copy operation
                    byte = self.data[i]
                    i += 1
                    decompressed_data.append(byte)
                    dest_buffer[buffer_pointer] = byte
                    buffer_pointer = (buffer_pointer + 1) & 0xFFF
                else:
                    # Back-reference copy operation
                    if i + 1 >= len(self.data):
                        break  # Prevent buffer overrun

                    offset = ((self.data[i + 1] & 0xF0) << 4) | self.data[i]
                    length = (self.data[i + 1] & 0x0F) + 3
                    i += 2

                    for j in range(length):
                        byte = dest_buffer[(offset + j) & 0xFFF]
                        decompressed_data.append(byte)
                        dest_buffer[buffer_pointer] = byte
                        buffer_pointer = (buffer_pointer + 1) & 0xFFF

        self.data = bytes(decompressed_data)
        self.isCompressed = False  # Mark as decompressed

        # Make sure the decompressed size matches the expected size
        if len(self.data) != self.uncompressedSize:
            raise Exception(f"Error: Decompression size does not match expected size {len(self.data)}"
            f" != {self.uncompressedSize}")


class BNKWrappedEntry:
    """
    Represents a wrapped version of a BNKEntry object with Base64 encoded data.

    BNKWrappedEntry encodes BNKEntry object data and names into Base64. It retains the original entry properties and
    supports conversion back to BNKEntry.
    """

    def __init__(self, *args):
        """
        Overloaded constructor for BNKWrappedEntry class.

        Parameters:
            *args: A variable argument list that can be:
                (entry: BNKEntry):
                    Initializes a new instance from a BNKEntry object by converting its data
                    and name to Base64 encoded strings, and retains its uncompressedSize and isCompressed properties.
                (data: str, name: str, uncompressedSize: int, isCompressed: int):
                    Initializes a BNKWrappedEntry object using provided Base64 encoded data and name, along with
                    uncompressedSize and isCompressed values.

        Raises:
            ValueError: If the arguments provided do not match the expected formats.
        """
        if len(args) == 1 and isinstance(args[0], BNKEntry):
            entry = args[0]
            self.data = base64.b64encode(entry.data).decode('utf-8')
            self.name = base64.b64encode(entry.name).decode('utf-8')
            self.uncompressedSize = entry.uncompressedSize
            self.isCompressed = entry.isCompressed
        elif len(args) == 4 and isinstance(args[0], str) and isinstance(args[1], str) and \
                                isinstance(args[2], int) and isinstance(args[3], int):
            self.data, self.name, self.uncompressedSize, self.isCompressed = args
        else:
            raise ValueError("Invalid arguments for BNKWrappedEntry constructor")

    def unwrap(self):
        """
        Converts the wrapped entry back into a BNKEntry object.

        This method decodes the Base64 encoded data and name in the BNKWrappedEntry object and returns a new BNKEntry
        object with these properties.

        Returns:
            BNKEntry: A BNKEntry object reconstructed from the BNKWrappedEntry.
        """
        return BNKEntry(self)

    def print(self):
        """
        Outputs a Python command that can recreate the current BNKWrappedEntry object.

        This method generates and prints a Python command line that can be used to recreate the current
        BNKWrappedEntry object. Useful for debugging or logging the state of the object.
        """
        print(f'entry = BNKWrappedEntry("{self.data}", "{self.name}", {self.uncompressedSize}, {self.isCompressed}' +
              f').unwrap()')

class BNKArchive:
    """
    Represents a BNK archive.

    This class encapsulates the data and functionality for working with BNK files. It includes methods for loading and
    saving archives, adding, removing, and replacing entries.
    """

    def __init__(self, archivePath):
        """
        Constructor to initialize BNKArchive from a file path.

        Reads the BNK file data from the given path and parses it into entries and footer.

        Parameters:
            archivePath (str): The file path of the BNK file to be processed.
        """
        # Check that the archive exists.
        if not os.path.isfile(archivePath):
            raise Exception(f"'{archivePath}' not found!")

        self.archivePath = archivePath
        self.entries = []  # Initialize the entries list as empty

        # Read the entire file as a byte array
        with open(archivePath, "rb") as file:
            archiveData = file.read()

        # Calculate the start position of the footer data, assuming the footer is 18 bytes from the end
        footerStart = len(archiveData) - 18

        # Extract the header (14 bytes)
        header = PatchTool.read_byte_array(archiveData, footerStart, 14)

        # Extract the file count (4 bytes)
        fileCount = PatchTool.read_uint32(archiveData, footerStart + 14)

        # Validate the header to ensure it matches the expected format
        if header != b"Wildfire\0\0\0\0\x01\0":
            raise Exception("Error: Invalid archive format")

        # Calculate the starting offset for entries in the archive
        entryOffset = len(archiveData) - 18 - (fileCount * 48)  # 48 bytes per directory entry

        # Extract each entry from the archive data
        for i in range(fileCount):
            # Create a new BNKEntry from the archive data at the current offset
            entry = BNKEntry(archiveData, entryOffset)
            # Append the entry to the entries list
            self.entries.append(entry)
            # Move to the next entry's offset
            entryOffset += 48

    def has_entry(self, name):
        """
        Checks if an entry exists in the archive.

        Determines if the archive contains an entry with a specific name. This method performs a case-insensitive
        comparison to check for the presence of an entry.

        Parameters:
            name (str): The name of the entry to search for in the archive.

        Returns:
            bool: True if the entry exists in the archive, False otherwise.
        """
        for entry in self.entries:
            # Perform a case-insensitive comparison of the entry's name with the provided name
            if PatchTool.read_string(entry.name).casefold() == name.casefold():
                return True

        # Return false if no entry with the specified name is found
        return False

    def get_entry(self, name):
        """
        Gets an entry from the archive.

        Returns a reference to the entry from the archive based on its name. Returns None if the entry is not found.

        Parameters:
            name (str): The name of the entry to retrieve.

        Returns:
            BNKEntry: A reference to the entry object if found, otherwise None.
        """
        for entry in self.entries:
            # Perform a case-insensitive comparison of the entry's name with the provided name
            if PatchTool.read_string(entry.name).casefold() == name.casefold():
                return entry

        # Return None if no entry with the specified name is found
        return None

    def clone_entry(self, name):
        """
        Clones an entry from the archive.

        Creates a deep copy of an entry from the archive based on its name. If the entry is not found, returns None.

        Parameters:
            name (str): The name of the entry to clone.

        Returns:
            BNKEntry: A deep copy of the entry object if found, otherwise None.
        """
        return found_entry.clone() if (found_entry := self.get_entry(name)) else None

    def add_entry(self, *args):
        """
        Adds a new entry to the archive or replaces an existing one, based on the provided arguments.

        Parameters:
            *args: A variable argument list that can be:
                (entry: BNKEntry):
                     Adds the entry with its own name.
                (entry: BNKEntry, force_replace: bool):
                     Adds or replaces the entry with its own name based on force_replace.
                (entry_name: str, entry: BNKEntry):
                     Adds the entry with a specified name.
                (entry_name: str, entry: BNKEntry, force_replace: bool):
                     Adds or replaces the entry with a specified name based on force_replace.

        Raises:
            ValueError: For various conditions such as entry name conflicts without force replacement, missing entry
                        data, etc.
        """
        # Check arguments and determine the logic to use
        if len(args) == 1 and isinstance(args[0], BNKEntry):
            entry_name, entry, force_replace = args[0].name, args[0], False
        elif len(args) == 2 and isinstance(args[0], BNKEntry) and isinstance(args[1], bool):
            entry_name, entry, force_replace = args[0].name, args[0], args[1]
        elif len(args) == 2 and isinstance(args[0], str) and isinstance(args[1], BNKEntry):
            entry_name, entry, force_replace = args[0], args[1], False
        elif len(args) == 3 and isinstance(args[0], str) and isinstance(args[1], BNKEntry) and \
             isinstance(args[2], bool):
            entry_name, entry, force_replace = args[0], args[1], args[2]
        else:
            raise ValueError("Invalid argument combination for add_entry.")

        # Common validation and logic for adding or replacing entries
        if not entry_name:
            raise ValueError("Entry name cannot be null or empty.")
        if not entry:
            raise ValueError("Entry cannot be null.")
        if len(entry.data) == 0:
            raise ValueError("Entry cannot contain zero length data.")

        # Check for duplicate entry names
        if (found_entry := self.get_entry(entry_name)):
            if not force_replace:
                raise ValueError(f"An entry with the name '{entry_name}' already exists.")
            else:
                # Replace existing entry's data and properties
                found_entry.data = entry.data[:]
                found_entry.uncompressedSize = entry.uncompressedSize
                found_entry.isCompressed = entry.isCompressed
        else:
            # Clone and potentially rename the new entry for independence
            clone = entry.clone()
            if entry.name != entry_name:
                clone.rename(entry_name)

            # Add the new entry
            self.entries.append(clone)


    def replace_entry(self, *args):
        """
        Replaces an existing entry in the archive, allowing for replacement specified either by an entry object or by
        both an entry's name and the entry object.

        Parameters:
            *args: A variable argument list that can be:
                (entry: BNKEntry):
                    Replaces the entry with its own name in the BNKEntry object.
                (entry_name: str, entry: BNKEntry):
                    Replaces the entry specified by the entry_name with the properties of the BNKEntry object.

        Raises:
            ValueError: If the specified entry is not found in the archive, or if other validation checks fail (such as
                        null entry name, null entry, or zero length data).
        """
        # Check arguments and determine the logic to use
        if len(args) == 1 and isinstance(args[0], BNKEntry):
            entry = args[0]
            entry_name = entry.name
        elif len(args) == 2 and isinstance(args[0], str) and isinstance(args[1], BNKEntry):
            entry_name, entry = args
        else:
            raise ValueError("Invalid arguments for replace_entry.")

        # Common validation and logic for replacing entries
        if not entry_name:
            raise ValueError("Entry name cannot be null or empty.")
        if not entry:
            raise ValueError("Entry cannot be null.")
        if len(entry.data) == 0:
            raise ValueError("Entry cannot contain zero length data.")

        # Find the index of the entry to be replaced based on the provided name
        if (found_entry := self.get_entry(entry_name)) is None:
            raise ValueError(f"Entry with name '{entry_name}' not found.")

        # Replace the found entry's data and properties
        found_entry.data = entry.data[:]
        found_entry.uncompressedSize = entry.uncompressedSize
        found_entry.isCompressed = entry.isCompressed

    def remove_entry(self, name, ignore_not_found=False):
        """
        Removes an existing entry in the archive.

        This method searches for an entry by name and removes it if found. If the entry is not found, the behavior
        depends on the ignore_not_found flag.

        Parameters:
        - name (str): The name of the entry to remove. Must not be None.
        - ignore_not_found (bool, optional): If True, no error is raised if the entry is not found. Defaults to False.

        Raises:
        - ValueError: If name is None, or if the entry is not found and ignore_not_found is False.
        """
        # Validation
        if name is None:
            raise ValueError("Name cannot be null.")

        # Attempt to find the entry by name with a default value of None if not found
        entry_to_remove = next((entry for entry in self.entries if entry.name == name), None)

        if entry_to_remove:
            self.entries.remove(entry_to_remove)
        elif not ignore_not_found:
            raise ValueError(f"Entry with name '{name}' not found.")

    def save(self, file_name=None):
        """
        Saves the BNKArchive to a file. If no file name is provided, saves to the original file path.

        Parameters:
        - file_name (str, optional): The file name to save the archive to. If None, uses the archive's original path.
        """
        if file_name is None:
            file_name = self.archivePath

        # Validate file name
        if not file_name:
            raise ValueError("File name cannot be empty.")

        # Sort entries before saving
        self.entries.sort(key=lambda entry: entry.name)

        # Open a file for writing
        with open(file_name, 'wb') as file_stream:
            offset_from_end = len(self.entries) * 48 + 18  # Add directory and footer sizes

            # Write each entry's data to the file stream
            for entry in self.entries:
                file_stream.write(entry.data)
                offset_from_end += len(entry.data)

            # Write metadata for each entry
            for entry in self.entries:
                if len(entry.name) != 32:
                    raise ValueError(f"Error Saving: Entry name '{entry.name}' must be exactly 32 bytes when encoded.")

                file_stream.write(entry.name)
                file_stream.write(pack('<I', offset_from_end))  # Unsigned int, little-endian
                file_stream.write(pack('<I', len(entry.data)))
                file_stream.write(pack('<I', entry.uncompressedSize))
                file_stream.write(pack('<I', int(entry.isCompressed)))
                offset_from_end -= len(entry.data)

            # Write the footer information
            footer = b"Wildfire\x00\x00\x00\x00\x01\x00" + pack('<I', len(self.entries))
            file_stream.write(footer)

    def dump(self):
        # Create the PatchBackups directory if it doesn't exist
        bnk_dump_dir = "BNKDump"
        bnk_sub_dump_dir = os.path.join(bnk_dump_dir, os.path.basename(self.archivePath))

        if not os.path.exists(bnk_dump_dir):
            os.makedirs(bnk_dump_dir)
        if not os.path.exists(bnk_sub_dump_dir):
            os.makedirs(bnk_sub_dump_dir)

        for entry in self.entries:
            entry.decompress()

            extracted_filename = os.path.join(bnk_sub_dump_dir, PatchTool.read_string(entry.name))
            with open(extracted_filename, 'wb') as extracted_file:
               extracted_file.write(entry.data)

class SpriteChunk:
    def __init__(self, archive_data, offset):
        self.archive_data = archive_data
        self.draw_offset = PatchTool.read_int16(archive_data, offset)
        self.chunk_length = PatchTool.read_uint16(archive_data, offset + 2)
        offset += 4

        if self.chunk_length == 0x0:
            # raise Exception("Sprite Chunk Length of zero not allowed (@ file offset {})".format(offset - 2))
            self.chunk_offset = 0
        elif self.chunk_length != 0xFFFF:
            self.chunk_offset = offset
        else:
            self.chunk_offset = 0
            # self.data = archive_data[offset:offset+self.chunk_length]

    def get_byte(self, index):
        return self.archive_data[self.chunk_offset + index]

    def total_size(self):
        if self.chunk_offset != 0:
            return 4 + self.chunk_length
        else:
            return 4

class Sprite:
    def __init__(self, archive_data, offset):
        self.chunks = []  # Initialize the chunks list as empty

        self.width = PatchTool.read_uint32(archive_data, offset)
        self.height = PatchTool.read_uint32(archive_data, offset + 4)
        self.center_x = PatchTool.read_uint32(archive_data, offset + 8)
        self.center_y = PatchTool.read_uint32(archive_data, offset + 12)
        sprite_length = PatchTool.read_uint32(archive_data, offset + 16)
        offset += self.header_size()

        sprite_end = offset + sprite_length
        while offset < sprite_end:
            chunk = SpriteChunk(archive_data, offset)
            self.chunks.append(chunk)
            offset += chunk.total_size()

        if sprite_length != self.chunks_size():
            raise Exception(f"Sprite Length does not match decoded sprite length in file ({sprite_length}" +
                            f" != {self.chunks_size()})")

    def header_size(self):
        return 4 * 5

    def chunks_size(self):
        return sum(chunk.total_size() for chunk in self.chunks)

    def total_size(self):
        return self.header_size() + self.chunks_size()

class SpriteBank:
    def __init__(self, archive_path):
        # Check that the archive exists
        if not os.path.isfile(archive_path):
            raise Exception(f"'{archive_path}' not found!")

        self.archive_path = archive_path
        self.sprites = []  # Initialize the sprites list as empty

        # Read the entire file as a byte array
        with open(archive_path, 'rb') as file:
            archive_data = file.read()

        sprite_count = self.read_uint32(archive_data, 0)

        offset = self.header_size()

        for i in range(sprite_count):
            if offset == len(archive_data):
                break
            sprite = Sprite(archive_data, offset)
            self.sprites.append(sprite)
            offset += sprite.total_size()

        if len(archive_data) != self.total_size():
            raise Exception(f"SpriteBank Length does not match file size ({len(archive_data)} != {self.total_size()})")

    def header_size(self):
        return 4

    def sprites_size(self):
        return sum(sprite.total_size() for sprite in self.sprites)

    def total_size(self):
        return self.header_size() + self.sprites_size()

    @staticmethod
    def read_uint32(data, offset):
        # Assuming data is a bytes-like object
        return int.from_bytes(data[offset:offset+4], byteorder='little', signed=False)

    def dump(self, palette):
        sprite_index = 0
        for sprite in self.sprites:
            if sprite.width == 0 or sprite.height == 0:
                continue

            # Create a new image for each sprite with a transparent background
            img = Image.new('RGBA', (sprite.width, sprite.height), (0, 0, 0, 0))
            draw_offset = 0

            for chunk in sprite.chunks:
                if chunk.draw_offset >= 0:
                    draw_offset += chunk.draw_offset
                else:
                    draw_offset += sprite.width + chunk.draw_offset + 1

                if chunk.chunk_length == 0xFFFF:
                    continue

                chunk_start_y = draw_offset // sprite.width
                for i in range(min(chunk.chunk_length, 0xFFFF)):
                    x = draw_offset % sprite.width
                    y = draw_offset // sprite.width

                    if chunk_start_y != y:
                        raise Exception(f"y={chunk_start_y} changed to {y}" +
                                        f" in middle of chunk with drawoffset of {chunk.draw_offset} {i}" +
                                        f" {chunk.chunk_length}")

                    color = palette.get_color(chunk.get_byte(i)) # Assuming palette.get() returns an (R,G,B,A) tuple
                    # print(color)
                    img.putpixel((x, y), color)

                    draw_offset += 1

            # Generate output file path
            directory_path, file_name = os.path.split(self.archive_path)
            # Using PNG to support transparency
            out_file_path = os.path.join(directory_path, f"{file_name}.{sprite_index}.png")
            print(f"Writing file {out_file_path}")
            img.save(out_file_path)
            sprite_index += 1

# At the module level
failed_entries = []

class ColorPalette:
    def __init__(self, archive_path):
        # Check that the archive exists
        if not os.path.isfile(archive_path):
            raise Exception(f"'{archive_path}' not found!")

        self.archive_path = archive_path
        self.map = [None] * 256  # Initialize color map with placeholders

        # Read the entire file as a byte array
        with open(archive_path, 'rb') as file:
            archive_data = file.read()

        for i in range(256):
            base_index = 32 + i * 3
            r = archive_data[base_index]
            g = archive_data[base_index + 1]
            b = archive_data[base_index + 2]
            self.map[i] = (r, g, b)  # Store as an RGB tuple

    def get_color(self, index):
        return self.map[index]

    def dump_all_sprites(self):
        directory_path = os.path.dirname(self.archive_path)

        # Define the extensions of sprite files to process
        extensions = ['.SPB', '.SP0', '.SP1', '.DSB', '.DS0', '.DS1']
        # Create a pattern that matches any of the specified extensions
        file_patterns = [os.path.join(directory_path, f"*{ext}") for ext in extensions]

        for pattern in file_patterns:
            for file_path in glob.glob(pattern):
                print(f"Processing file: {file_path}")
                try:
                    sprite_bank = SpriteBank(file_path)
                    sprite_bank.dump(self)
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
                    failed_entries.append(file_path)


try:
    # PatchTool.extract_all_bnk_files()

    # Restore any backups
    PatchTool.restore_backups()

    # Fixes the display of 'ghost.exe' in the taskbar.
    PatchTool.patch_bytes("ghost.exe",
                          b"\0GHOST\0",
                          b"\0GHOST\x7F")

    # Fixes the incorrect spelling of San Francisco in 'sanfran.exe'.
    PatchTool.patch_bytes("sanfran.exe",
                          b"\0San Fransisco\0",
                          b"\0San Francisco\0")

    # Fixes the corrupt pause graphics in Golf's 'GF_G1024.BNK' that cause crashing.
    PatchTool.bnk_replace("GF_G800.BNK:GF_LPAUS.SPB", "GF_G1024.BNK:GF_LPAUS.SPB")

    # Fixes the corrupt pause graphics in Roller Coaster's 'RC_G1024.BNK' that cause crashing.
    PatchTool.bnk_replace("RC_G800.BNK:RC_LPAUS.SPB", "RC_G1024.BNK:RC_LPAUS.SPB")

    # Fixes the corrupt pause graphics in Saturn's 'SA_G1024.BNK' that cause crashing.
    PatchTool.bnk_replace("SA_G800.BNK:SA_LPAUS.SPB", "SA_G1024.BNK:SA_LPAUS.SPB")

    # Fixes the corrupt pause graphics in Zodiac's 'ZO_G1024.BNK' that cause crashing.
    PatchTool.bnk_replace("ZO_G800.BNK:ZO_LPAUS.SPB", "ZO_G1024.BNK:ZO_LPAUS.SPB")

    # Fixes missing music in 'SATURN.BNK' that causes crashing.
    PatchTool.bnk_add("SATELITE.BNK:IT_M_MIS.ADP", "SATURN.BNK:SA_M_MIS.ADP")

    # Fixes the file count in Project Zero's 'PZ_G1024.BNK' caused by the UPG1024.exe patch.
    PatchTool.patch_bytes("PZ_G1024.BNK",
                          b"\x57\x69\x6C\x64\x66\x69\x72\x65\x00\x00\x00\x00\x01\x00\x33\x39\x00\x00",
                          b"\x57\x69\x6C\x64\x66\x69\x72\x65\x00\x00\x00\x00\x01\x00\x39\x00\x00\x00",
                          True)  # Ignoring missing match
except Exception as e:
    print(f"Error: {Fore.RED}{e}{Style.RESET_ALL}")
    print(f"{Fore.WHITE}{Style.DIM}{traceback.format_exc()}{Style.RESET_ALL}")
    exit(1)
