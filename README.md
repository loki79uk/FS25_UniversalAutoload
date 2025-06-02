# FS25_UniversalAutoload
---------------------------------------------------
Please get the latest release from https://github.com/loki79uk/FS25_UniversalAutoload/releases
---------------------------------------------------

**READ THIS FIRST**

- If you already have a vehicle on a savegame before adding UAL, then you either need to save the settings from the shop UAL menu OR you can purchase another copy of the same vehicle to create the setting.  In either case, you must then restart the save game you want to use.  Note that you can do this in any savegame, the act of buying it will create a global default for the vehicle.
- The configuration file is updated/saved (in mod settings) when you BUY a vehicle **OR** when you apply changes to a vehicle in the workshop. Changes applied from the workshop will apply only to the edited vehicle for that session, but will become the default for all vehicles of the same type after the next restart.
- In multiplayer games all clients can edit vehicles when they buy one, but the configuration is saved ON THE SERVER only.  So the server default will be set by the last player to adjust it.  As with single player, individual vehicle settings will persist for the rest of that game until the server is restarted, after that the default is applied to all vehicles of the same type.

If you are having issues with a vehicle not loading pallets at all then there are a few things to check
- If you cant load LOGS then check that the logs are too long for you trailer.  Make the zone longer or cut the logs shorter.
- If you do not see a loading zone with the debug display (shift-ctrl-F12) then the most likely thing is that the entry for that vehicle is corrupted in your mod settings file.  Try deleting the file completely (a new one will be created), or manually delete the entry for the vehicle you are having trouble with in a text editor.
- It is also possible you simply don't have the trailer selected/active in game.  Press "G" to cycle the selected implement from your tractor/truck.

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
KNOWN ISSUES:
- Existing trailers on a savegame will not get autoload added (until restart with valid settings)
