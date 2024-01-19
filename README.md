# ValuSoft Ultimate Pinball & Ultimate Pinball Gold Patches

Repository containing patches for [Ultimate Pinball (2002)](https://www.mobygames.com/game/45793/ultimate-pinball) and [Ultimate Pinball Gold (2003)](http://pc.gamespy.com/pc/ultimate-pinball-gold/) from [ValuSoft](https://www.mobygames.com/company/1828/valusoft-inc/).

<img src="https://github.com/snaphat/ValuSoftUltimatePinball/assets/5836001/c98be146-e893-4772-ae35-50518f513947" width="256" /> &emsp;
<img src="https://github.com/snaphat/ValuSoftUltimatePinball/assets/5836001/630dca07-f206-4372-b488-b940026f6063" width="256" />

# Patches

The following patches should be applied  <ins>**after**</ins> the binary patches from the [ValuSoftUltimatePinballBinaryPatches](https://github.com/snaphat/ValuSoftUltimatePinballBinaryPatches) repository.

To Apply all patches at once use the included [_ApplyAllPatches.bat](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_ApplyAllPatches.bat).

## Ghost Name Patch
- Patch files
  - [_GhostNamePatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_GhostNamePatch.ps1)

Fixes the display of `ghost.exe` in the taskbar. Any variation of "Ghost" cannot be used as a class name in modern windows as it will cause the window to not display in the windows taskbar. We can get around the issue by inserting a non-printable character for \<DEL\> (0x7F) after the class name.

## San Francisco Name Patch
- Patch files
  - [_SanFranNamePatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_SanFranNamePatch.ps1)

Fixes the incorrect spelling of San Francisco in `sanfran.exe`.

## Project Zero File Count Patch
- Patch files
  - [_ProjectZeroFileCountPatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_ProjectZeroFileCountPatch)

Fixes an incorrect file count issue in `PZ_G1024.BNK` caused by a bug in the UPG1024 patch from the [ValuSoftUltimatePinballBinaryPatches](https://github.com/snaphat/ValuSoftUltimatePinballBinaryPatches) repository.

## Golf Pause Patch
- Patch files
  - [_GolfPausePatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_GolfPausePatch.ps1) (run this one)
  - [_BNKTools.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_BNKTools.ps1)

Fixes a crash when the game is paused in the 1024x768 table by adding missing pause graphics to `GF_G1024.BNK`.

## Roller Coaster Pause Patch
- Patch files
  - [_RCoasterPausePatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_RCoasterPausePatch.ps1) (run this one)
  - [_BNKTools.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_BNKTools.ps1)

Fixes a crash when the game is paused in the 1024x768 table by adding missing pause graphics to `RC_G1024.BNK`.

## Saturn Pause Patch
- Patch files
  - [_SaturnPausePatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_SaturnPausePatch.ps1) (run this one)
  - [_BNKTools.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_BNKTools.ps1)

Fixes a crash when the game is paused in the 1024x768 table by adding missing pause graphics to `SA_G1024.BNK`.

## Zodiac Pause Patch
- Patch files
  - [_ZodiacPausePatch.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_ZodiacPausePatch.ps1) (run this one)
  - [_BNKTools.ps1](https://raw.githubusercontent.com/snaphat/ValuSoftUltimatePinballPatches/main/_BNKTools.ps1)

Fixes a crash when the game is paused in the 1024x768 table by adding missing pause graphics to `ZO_G1024.BNK`.
