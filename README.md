# ValuSoft Ultimate Pinball & Ultimate Pinball Gold Patches

Repository containing patches for [Ultimate Pinball (2002)](https://www.mobygames.com/game/45793/ultimate-pinball) and [Ultimate Pinball Gold (2003)](http://pc.gamespy.com/pc/ultimate-pinball-gold/) from [ValuSoft](https://www.mobygames.com/company/1828/valusoft-inc/).

<img src="https://github.com/snaphat/ValuSoftUltimatePinball/assets/5836001/c98be146-e893-4772-ae35-50518f513947" width="256" /> &emsp;
<img src="https://github.com/snaphat/ValuSoftUltimatePinball/assets/5836001/630dca07-f206-4372-b488-b940026f6063" width="256" />


# _GhostNamePatch.ps1  
Fixes the display of `ghost.exe` in the taskbar. Any variation of "Ghost" cannot be used as a class name in modern windows as it will cause the window to not display in the windows taskbar. We can get around the issue by inserting a non-printable character for \<DEL\> (0x7F) after the class name.

# _SanFranNamePatch.ps1
Fixes the incorrect spelling of San Francisco in `sanfran.exe`.
