#!/usr/bin/env python3
# upower-stub.py - substituye /usr/libexec/upowerd en SubstrateOS.
# Sirve org.freedesktop.UPower con la bateria real del telefono leida de
# `termux-battery-status` cada 60 s (no hay /sys/class/power_supply en proot).
import json
import subprocess
import sys
import time

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS_NAME = "org.freedesktop.UPower"
OBJ_PATH = "/org/freedesktop/UPower"
DEV_DISPLAY = "/org/freedesktop/UPower/devices/DisplayDevice"
DEV_BAT0 = "/org/freedesktop/UPower/devices/battery_BAT0"
IFACE = "org.freedesktop.UPower.Device"
UP_IFACE = "org.freedesktop.UPower"

STATE = {"CHARGING": 1, "DISCHARGING": 2, "NOT_CHARGING": 3, "FULL": 4}
LEVEL = {"UNKNOWN": 0, "LOW": 1, "CRITICAL": 2, "NORMAL": 3, "HIGH": 4}


def read_battery():
    exe = "/data/data/com.termux/files/usr/bin/termux-battery-status"
    for cmd in (exe, "termux-battery-status"):
        try:
            out = subprocess.check_output([cmd], timeout=10, text=True)
            return json.loads(out)
        except FileNotFoundError:
            continue
        except Exception as exc:  # noqa: BLE001
            print("battery read failed (%s): %r" % (cmd, exc), flush=True)
            return {}
    print("termux-battery-status no disponible", flush=True)
    return {}


class Device(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)
        self.props = {
            "NativePath": dbus.String("BAT0"),
            "Vendor": dbus.String("Samsung"),
            "Model": dbus.String("S25"),
            "Serial": dbus.String(""),
            "UpdateTime": dbus.UInt64(0),
            "Type": dbus.UInt32(2),  # battery
            "PowerSupply": dbus.Boolean(True),
            "HasHistory": dbus.Boolean(False),
            "HasStatistics": dbus.Boolean(False),
            "Online": dbus.Boolean(False),
            "Energy": dbus.Double(0.0),
            "EnergyEmpty": dbus.Double(0.0),
            "EnergyFull": dbus.Double(0.0),
            "EnergyFullDesign": dbus.Double(0.0),
            "EnergyRate": dbus.Double(0.0),
            "Voltage": dbus.Double(0.0),
            "ChargeCycles": dbus.Int32(0),
            "Luminosity": dbus.Double(0.0),
            "TimeToEmpty": dbus.Int64(0),
            "TimeToFull": dbus.Int64(0),
            "Percentage": dbus.Double(0.0),
            "Temperature": dbus.Double(0.0),
            "IsPresent": dbus.Boolean(True),
            "State": dbus.UInt32(0),
            "IsRechargeable": dbus.Boolean(True),
            "Capacity": dbus.Double(100.0),
            "Technology": dbus.UInt32(2),  # lithium-ion
            "WarningLevel": dbus.UInt32(LEVEL["NORMAL"]),
            "BatteryLevel": dbus.UInt32(LEVEL["NORMAL"]),
            "IconName": dbus.String("battery-missing-symbolic"),
        }

    def update(self, data, on_battery):
        if not data:
            return []
        pct = float(data.get("percentage", 0))
        st = STATE.get(str(data.get("status", "UNKNOWN")).upper(), 0)
        plugged = str(data.get("plugged", "UNPLUGGED")).upper() != "UNPLUGGED"
        if st == 4 or (plugged and pct >= 100):
            icon = "battery-full-charged-symbolic"
        elif plugged:
            icon = "battery-%s-charging-symbolic" % _bucket(pct)
        else:
            icon = "battery-%s-symbolic" % _bucket(pct)
        changed = {}
        cap_wh = 15.6  # capacidad nominal aprox. (4.0 Ah * 3.9 V)
        cur_a = abs(float(data.get("current_average", data.get("current", 0)) or 0)) / 1e6
        volt = float(data.get("voltage", 0) or 0) / 1000.0
        power = cur_a * volt if volt else 0.0
        if st == 1 and power > 0.1:
            ttf = int(max(0.0, cap_wh * (100.0 - pct) / 100.0 / power) * 3600)
            tte = 0
        elif st == 2 and power > 0.1:
            tte = int(max(0.0, cap_wh * pct / 100.0 / power) * 3600)
            ttf = 0
        else:
            tte = ttf = 0
        new = {
            "Percentage": dbus.Double(pct),
            "State": dbus.UInt32(st),
            "IsPresent": dbus.Boolean(bool(data.get("present", True))),
            "Online": dbus.Boolean(plugged),
            "Voltage": dbus.Double(volt),
            "Temperature": dbus.Double(float(data.get("temperature", 0) or 0)),
            "Energy": dbus.Double(cap_wh * pct / 100.0),
            "EnergyFull": dbus.Double(cap_wh),
            "EnergyFullDesign": dbus.Double(cap_wh),
            "EnergyRate": dbus.Double(round(power, 3)),
            "TimeToEmpty": dbus.Int64(tte),
            "TimeToFull": dbus.Int64(ttf),
            "UpdateTime": dbus.UInt64(int(time.time())),
            "IconName": dbus.String(icon),
            "WarningLevel": dbus.UInt32(
                LEVEL["CRITICAL"] if pct <= 5 else LEVEL["LOW"] if pct <= 15 else LEVEL["NORMAL"]
            ),
            "BatteryLevel": dbus.UInt32(
                0 if pct >= 99 else 2 if pct <= 5 else 1 if pct <= 15 else 3 if pct <= 75 else 4
            ),
        }
        for key, value in new.items():
            if str(self.props.get(key)) != str(value):
                self.props[key] = value
                changed[key] = value
        if changed:
            self.PropertiesChanged(IFACE, changed, [])
        return list(changed)

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        if prop not in self.props:
            raise dbus.exceptions.DBusException(
                "org.freedesktop.DBus.Error.InvalidArgs", "No such property %s" % prop
            )
        return self.props[prop]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return dbus.Dictionary(self.props, signature="sv")

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ssv")
    def Set(self, interface, prop, value):
        self.props[prop] = value

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    @dbus.service.method(IFACE)
    def Refresh(self):
        pass


def _bucket(pct):
    if pct >= 96:
        return "full"
    if pct >= 80:
        return "good"
    if pct >= 60:
        return "medium"
    if pct >= 40:
        return "low"
    if pct >= 20:
        return "caution"
    return "empty"


class Manager(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, OBJ_PATH)
        self.props = {
            "DaemonVersion": dbus.String("1.91.1-substrate"),
            "OnBattery": dbus.Boolean(False),
            "LidIsClosed": dbus.Boolean(False),
            "LidIsPresent": dbus.Boolean(False),
            "CriticalAction": dbus.String("PowerOff"),
        }

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return self.props[prop]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return dbus.Dictionary(self.props, signature="sv")

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ssv")
    def Set(self, interface, prop, value):
        self.props[prop] = value

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    @dbus.service.method(UP_IFACE, out_signature="ao")
    def EnumerateDevices(self):
        return dbus.Array([dbus.ObjectPath(DEV_DISPLAY), dbus.ObjectPath(DEV_BAT0)], signature="o")

    @dbus.service.method(UP_IFACE, out_signature="o")
    def GetDisplayDevice(self):
        return dbus.ObjectPath(DEV_DISPLAY)

    @dbus.service.method(UP_IFACE, out_signature="s")
    def GetCriticalAction(self):
        return dbus.String("PowerOff")

    @dbus.service.method(UP_IFACE)
    def Suspend(self):
        pass

    @dbus.service.method(UP_IFACE)
    def Hibernate(self):
        pass

    @dbus.service.signal(UP_IFACE, signature="o")
    def DeviceAdded(self, path):
        pass

    @dbus.service.signal(UP_IFACE, signature="o")
    def DeviceRemoved(self, path):
        pass

    @dbus.service.signal(UP_IFACE)
    def Changed(self):
        pass


FULL = {
    "NativePath": dbus.String(""),
    "Vendor": dbus.String("Samsung"),
    "Model": dbus.String("S25"),
    "Serial": dbus.String(""),
    "UpdateTime": dbus.UInt64(0),
    "Type": dbus.UInt32(2),
    "PowerSupply": dbus.Boolean(True),
    "HasHistory": dbus.Boolean(False),
    "HasStatistics": dbus.Boolean(False),
    "Online": dbus.Boolean(False),
    "Energy": dbus.Double(0.0),
    "EnergyEmpty": dbus.Double(0.0),
    "EnergyFull": dbus.Double(0.0),
    "EnergyFullDesign": dbus.Double(0.0),
    "EnergyRate": dbus.Double(0.0),
    "Voltage": dbus.Double(0.0),
    "ChargeCycles": dbus.Int32(0),
    "Luminosity": dbus.Double(0.0),
    "TimeToEmpty": dbus.Int64(0),
    "TimeToFull": dbus.Int64(0),
    "Percentage": dbus.Double(0.0),
    "Temperature": dbus.Double(0.0),
    "IsPresent": dbus.Boolean(True),
    "State": dbus.UInt32(0),
    "IsRechargeable": dbus.Boolean(True),
    "Capacity": dbus.Double(100.0),
    "Technology": dbus.UInt32(2),
    "WarningLevel": dbus.UInt32(3),
    "BatteryLevel": dbus.UInt32(3),
    "IconName": dbus.String("battery-missing-symbolic"),
}


class FullDevice(Device):
    def __init__(self, bus, path):
        dbus.service.Object.__init__(self, bus, path)
        self.props = dict(FULL)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    name = dbus.service.BusName(BUS_NAME, bus, do_not_queue=True)
    manager = Manager(bus)
    display = Device(bus, DEV_DISPLAY)
    bat0 = FullDevice(bus, DEV_BAT0)
    loop = GLib.MainLoop()

    def poll():
        data = read_battery()
        on_battery = str(data.get("plugged", "")).upper() == "UNPLUGGED"
        if on_battery != bool(manager.props["OnBattery"]):
            manager.props["OnBattery"] = dbus.Boolean(on_battery)
            manager.PropertiesChanged(UP_IFACE, {"OnBattery": dbus.Boolean(on_battery)}, [])
        manager.Changed()
        display.update(data, on_battery)
        bat0.update(data, on_battery)
        return True

    poll()
    GLib.timeout_add_seconds(60, poll)
    print("upower-stub listo: %s" % BUS_NAME, flush=True)
    try:
        loop.run()
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
