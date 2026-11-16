
import asyncio

from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method
from dbus_next import DBusError, BusType


AGENT_PATH = "/org/moonforge/bluetooth/agent"


class BluetoothAgent(ServiceInterface):
    def __init__(self):
        super().__init__("org.bluez.Agent1")

    @method()
    def AuthorizeService(self, device: "o", uuid: "s") -> "":
        print(f"Automatically authorized service: {uuid}")

    @method()
    def RequestAuthorization(self, device: "o") -> "":
        print(f"Automatically authorized device: {device}")

    @method()
    def Release(self) -> "":
        print("Bluetooth agent released")

    @method()
    def Cancel(self) -> "":
        print("Bluetooth authorization cancelled")

    @method()
    def RequestConfirmation(self, device: "o", passkey: "u") -> "":
        raise DBusError(
            "org.bluez.Error.Rejected",
            "Passkey confirmation is not automatically accepted"
        )

    @method()
    def RequestPinCode(self, device: "o") -> "s":
        raise DBusError("org.bluez.Error.Rejected", "PIN entry required")

    @method()
    def RequestPasskey(self, device: "o") -> "u":
        raise DBusError("org.bluez.Error.Rejected", "Passkey entry required")

    @method()
    def DisplayPinCode(self, device: "o", pincode: "s") -> "":
        print(f"Bluetooth PIN: {pincode}")

    @method()
    def DisplayPasskey(
        self, device: "o", passkey: "u", entered: "q"
    ) -> "":
        print(f"Bluetooth passkey: {passkey}")


async def main():
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()

    agent = BluetoothAgent()
    bus.export(AGENT_PATH, agent)

    introspection = await bus.introspect("org.bluez", "/org/bluez")
    proxy = bus.get_proxy_object(
        "org.bluez", "/org/bluez", introspection
    )
    manager = proxy.get_interface("org.bluez.AgentManager1")

    await manager.call_register_agent(AGENT_PATH, "NoInputNoOutput")
    await manager.call_request_default_agent(AGENT_PATH)

    print("Moonforge Bluetooth agent is running")

    try:
        await asyncio.get_running_loop().create_future()
    finally:
        await manager.call_unregister_agent(AGENT_PATH)
        bus.disconnect()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Moonforge Bluetooth agent stopped")
