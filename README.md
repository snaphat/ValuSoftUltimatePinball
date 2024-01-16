# ValuSoft Ultimate Pinball & Ultimate Pinball Gold Patches

Repository containing patches for [Ultimate Pinball (2002)](https://www.mobygames.com/game/45793/ultimate-pinball) and [Ultimate Pinball Gold (2003)](http://pc.gamespy.com/pc/ultimate-pinball-gold/) from [ValuSoft](https://www.mobygames.com/company/1828/valusoft-inc/).

# _GhostNamePatch.ps1  
Fixes the display of `ghost.exe` in the taskbar. Any variation of "Ghost" cannot be used as a class name in modern windows as it will cause the window to not display in the windows taskbar. We can get around the issue by inserting a non-printable character for \<DEL\> (0x7F) after the class name.

# _SanFranNamePatch.ps1
Fixes the incorrect spelling of San Francisco in `sanfran.exe`.
