from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]


EVENT_CASES = (
    ("PlayerTriggerEvent.lua", "PlayerTriggerEvent", "updatePlayerTriggerState", "vehicle, 7, true"),
    ("RaiseActiveEvent.lua", "RaiseActiveEvent", "forceRaiseActive", "vehicle, true"),
    ("ResetLoadingEvent.lua", "ResetLoadingEvent", "resetLoadingState", "vehicle"),
    (
        "SetCollectionModeEvent.lua",
        "SetCollectionModeEvent",
        "setAutoCollectionMode",
        "vehicle, true",
    ),
    ("SetContainerTypeEvent.lua", "SetContainerTypeEvent", "setContainerTypeIndex", "vehicle, 2"),
    ("SetFilterEvent.lua", "SetFilterEvent", "setLoadingFilter", "vehicle, true"),
    (
        "SetHorizontalLoadingEvent.lua",
        "SetHorizontalLoadingEvent",
        "setHorizontalLoading",
        "vehicle, true",
    ),
    ("SetLoadsideEvent.lua", "SetLoadsideEvent", "setCurrentLoadside", 'vehicle, "left"'),
    ("SetMaterialTypeEvent.lua", "SetMaterialTypeEvent", "setMaterialTypeIndex", "vehicle, 2"),
    ("SetTipsideEvent.lua", "SetTipsideEvent", "setCurrentTipside", 'vehicle, "left"'),
    ("StartLoadingEvent.lua", "StartLoadingEvent", "startLoading", "vehicle, true"),
    ("StopLoadingEvent.lua", "StopLoadingEvent", "stopLoading", "vehicle, true"),
    ("UnloadingEvent.lua", "StartUnloadingEvent", "startUnloading", "vehicle, true"),
)


@unittest.skipUnless(shutil.which("lua5.1"), "lua5.1 is required")
class MultiplayerEventRelayTests(unittest.TestCase):
    def test_client_requests_are_relayed_to_other_clients(self) -> None:
        for filename, event_name, mutation_name, constructor_args in EVENT_CASES:
            with self.subTest(event=event_name):
                event_path = REPOSITORY / "events" / filename
                script = f"""
UniversalAutoload = {{}}
Event = {{}}

function Class(classTable, baseClass)
    return {{__index = classTable}}
end

function Event.new(metaTable)
    return setmetatable({{}}, metaTable)
end

function InitEventClass(classTable, name)
end

local mutationCalls = 0
local mutationArguments = nil
UniversalAutoload.{mutation_name} = function(...)
    mutationCalls = mutationCalls + 1
    mutationArguments = {{...}}
end

local vehicle = {{
    synchronized = true,
    getIsSynchronized = function(self)
        return self.synchronized
    end
}}

local clientConnection = {{
    getIsServer = function(self)
        return false
    end
}}

local serverConnection = {{
    getIsServer = function(self)
        return true
    end
}}

local broadcastCalls = 0
local relayedEvent = nil
local excludedConnection = nil
local relatedObject = nil
local sendLocal = nil
g_server = {{
    broadcastEvent = function(self, event, localDelivery, excluded, object)
        broadcastCalls = broadcastCalls + 1
        relayedEvent = event
        sendLocal = localDelivery
        excludedConnection = excluded
        relatedObject = object
    end
}}

dofile({event_path.as_posix()!r})

local event = UniversalAutoload.{event_name}.new({constructor_args})
event:run(clientConnection)

assert(mutationCalls == 1, "the server should apply the request once")
assert(mutationArguments[1] == vehicle, "the request should target the decoded vehicle")
assert(mutationArguments[#mutationArguments] == true, "the relayed mutation should suppress another send")
assert(broadcastCalls == 1, "the server should relay a client request")
assert(relayedEvent == event, "the server should relay the accepted event")
assert(sendLocal == false, "the server should not run the accepted event twice")
assert(excludedConnection == clientConnection, "the requesting client already applied the change")
assert(relatedObject == vehicle, "the relay should use the vehicle for network relevance")

event:run(serverConnection)
assert(mutationCalls == 2, "a server event should still be applied by a client")
assert(broadcastCalls == 1, "a client must not relay an event received from the server")

vehicle.synchronized = false
event:run(clientConnection)
assert(mutationCalls == 2, "an unsynchronized vehicle should be ignored")
assert(broadcastCalls == 1, "an invalid request should not be relayed")
"""
                result = subprocess.run(
                    ["lua5.1", "-"],
                    input=script,
                    text=True,
                    capture_output=True,
                    cwd=REPOSITORY,
                    check=False,
                )
                self.assertEqual(
                    result.returncode,
                    0,
                    msg=f"{event_name} relay contract failed:\n{result.stderr}",
                )


if __name__ == "__main__":
    unittest.main()
