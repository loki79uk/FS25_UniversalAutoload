# FS25_UniversalAutoload
---------------------------------------------------
DEVELOPMENT RELEASE - Please test and leave any bug reports or feedback.

Please get the latest from https://github.com/loki79uk/FS25_UniversalAutoload/releases

** PLEASE STOP using the disgusting third-party download sites **

_I have asked them to remove my mods but have not had a single response.._

---------------------------------------------------

**READ THIS FIRST**

There seems to be a lot of confusion around how the settings are saved and loaded:
- If you already have a vehicle on a savegame before adding UAL, then you ned to purchase another copy of the same vehicle to create the setting, and then restart the save game you want to use. You can buy it in any savegame, just the act of buying it will create a global default for that vehicle.
- The configuration file is updated/saved (in mod settings) when you BUY a vehicle **or** when you apply changes to a vehicle in the workshop. I have now enabled the "apply" config button for all UAL vehicles in the workshop, so other changes are no longer necessary BUT changing other options will still reset the autoload settings.  I am open to suggestions if this automatic behaviour is better or worse than adding a button to "apply" the new settings (we might forget to press that).
- In multiplayer games all clients can edit vehicles when they buy one, but the configuration is saved ON THE SERVER only.  So the server default will be set by the last player to adjust it.  Invividual vehicle settings should persist for the rest of that game until the server is restarted, after that the default is applied to all.  I need to design a better system with permissions or possibly an option to load from your own local settings, although it could get really confusing if you share vehicles on a server.

If you are having issues with a vehicle not loading pallets at all then there are a few things to check
- If you cant load LOGS then the chances are the logs are too long for you trailer.  Make the zone longer or cut the logs shorter.
- If you do not see a loading zone with the debug display (shift-ctrl-F12) then the most likely thing is that the entry for that vehicle is corrupted in your mod settings file.  Try deleting the file completely, or look for the vehicle you are having trouble with and delete the entry for that one.
- There is an issue saving configurations when the game installation path has wide chars in the path (unicode/non-ascii) e.g. Russian or chinese characters.  When this happens, you will get the issue of loading volume not showing up at all.  I don't fuly understand the cause, but I will work out a solution.
- It is also possible you simply don't have the trailer selected/active in game.  Press "G" to cycle the selected implement from your tractor/truck.

---------------------------------------------------
SUMMARY:
- Single player is working as it should for BALES, PALLETS, BIG-BAGS and LOGS
- Multiplayer loads without crashing so far BUT I have only done basic testing. **USE AT YOUR OWN RISK**
- Any new vehicles will get autoload after purchasing in the shop (see below)
- Any valid vehicles in a savegame will load settings if available

---------------------------------------------------
NEW FEATURES:
- All pallets, big-bags and bales supported by default
- Automatic detection of trailer loading zones (in shop)
- UI to adjust size of loading zone in shop before purchase
- No external configuration files required!!

---------------------------------------------------
TO CONFIGURE LOADING ZONES:
- Use middle mouse click in the shop to activate editing
- Right click drag to move individual faces
- ALT-right click drag to move opposing faces (**use this for width**)
- SHIFT-right click drag to move the whole zone
- CTRL with any of the above for fine control
- SHIFT-CTRL middle mouse click to auto-calculate the zone from scratch (if you mess up)
- Configuration can be edited in mod settings XML (if you know what you are doing)

---------------------------------------------------
PLANNED FEATURES:
- Menu for global settings
- Show debugging display in multiplayer

---------------------------------------------------
KNOWN ISSUES:
- Existing trailers on a savegame will not get autoload added (until restart with valid settings)
