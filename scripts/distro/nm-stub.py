#!/usr/bin/env python3
# nm-stub.py - Stub de org.freedesktop.NetworkManager para proot.
# - Cliente libnm valido (g-c-c no aborta).
# - Wi-Fi simulada: un dispositivo wlan0 + un AP "SubstrateOS" para que
#   GNOME Shell muestre el tile de Wi-Fi en Quick Settings.
import os
from gi.repository import Gio, GLib

ADDR = 'unix:path=' + os.environ.get('RT_SYSTEM_BUS', '/tmp/rt-dex/system-bus49')
MGR_PATH = '/org/freedesktop/NetworkManager'
SET_PATH = '/org/freedesktop/NetworkManager/Settings'
CON_PATH = '/org/freedesktop/NetworkManager/Settings/1'
DEV_PATH = '/org/freedesktop/NetworkManager/Devices/1'
AP_PATH = '/org/freedesktop/NetworkManager/AccessPoint/1'
AC_PATH = '/org/freedesktop/NetworkManager/ActiveConnection/1'
CON_UUID = '6f3a4f3e-1b2c-4d5e-8f90-123456789abc'

XML = """<node>
 <interface name='org.freedesktop.NetworkManager'>
  <method name='GetDevices'><arg type='ao' direction='out'/></method>
  <method name='GetAllDevices'><arg type='ao' direction='out'/></method>
  <method name='GetPermissions'><arg type='a{ss}' direction='out'/></method>
  <method name='Enable'><arg type='b' direction='in'/></method>
  <method name='Sleep'><arg type='b' direction='in'/></method>
  <method name='CheckConnectivity'><arg type='u' direction='out'/></method>
  <method name='Reload'/>
  <method name='SetLogging'><arg type='s' direction='in'/><arg type='s' direction='in'/></method>
  <method name='ActivateConnection'>
    <arg type='o' direction='in'/><arg type='o' direction='in'/><arg type='o' direction='in'/>
    <arg type='o' direction='out'/></method>
  <method name='AddAndActivateConnection'>
    <arg type='a{sa{sv}}' direction='in'/><arg type='o' direction='in'/><arg type='o' direction='in'/>
    <arg type='o' direction='out'/><arg type='o' direction='out'/></method>
  <property name='Devices' type='ao' access='read'/>
  <property name='AllDevices' type='ao' access='read'/>
  <property name='Checkpoints' type='ao' access='read'/>
  <property name='ActiveConnections' type='ao' access='read'/>
  <property name='PrimaryConnection' type='o' access='read'/>
  <property name='PrimaryConnectionType' type='s' access='read'/>
  <property name='ActivatingConnection' type='o' access='read'/>
  <property name='Startup' type='b' access='read'/>
  <property name='State' type='u' access='read'/>
  <property name='Metered' type='u' access='read'/>
  <property name='Connectivity' type='u' access='read'/>
  <property name='NetworkingEnabled' type='b' access='read'/>
  <property name='WirelessEnabled' type='b' access='read'/>
  <property name='WirelessHardwareEnabled' type='b' access='read'/>
  <property name='WwanEnabled' type='b' access='read'/>
  <property name='WwanHardwareEnabled' type='b' access='read'/>
  <property name='Version' type='s' access='read'/>
  <signal name='StateChanged'><arg type='u'/></signal>
  <signal name='DeviceAdded'><arg type='o'/></signal>
  <signal name='DeviceRemoved'><arg type='o'/></signal>
 </interface>
 <interface name='org.freedesktop.NetworkManager.Settings'>
  <method name='GetConnections'><arg type='ao' direction='out'/></method>
  <method name='ListConnections'><arg type='ao' direction='out'/></method>
  <method name='ReloadConnections'><arg type='b' direction='out'/></method>
  <property name='Connections' type='ao' access='read'/>
  <property name='Hostname' type='s' access='read'/>
  <property name='CanModify' type='b' access='read'/>
 </interface>
</node>"""

DEV_XML = """<node>
 <interface name='org.freedesktop.NetworkManager.Device'>
  <method name='Disconnect'/>
  <method name='Delete'/>
  <method name='Reapply'>
    <arg type='a{sa{sv}}' direction='in'/>
    <arg type='t' direction='in'/>
    <arg type='u' direction='in'/>
  </method>
  <method name='GetAppliedConnection'>
    <arg type='u' direction='in'/>
    <arg type='a{sa{sv}}' direction='out'/>
    <arg type='t' direction='out'/>
  </method>
  <property name='Udi' type='s' access='read'/>
  <property name='Interface' type='s' access='read'/>
  <property name='IpInterface' type='s' access='read'/>
  <property name='Driver' type='s' access='read'/>
  <property name='DriverVersion' type='s' access='read'/>
  <property name='FirmwareMissing' type='b' access='read'/>
  <property name='NmPluginMissing' type='b' access='read'/>
  <property name='DeviceType' type='u' access='read'/>
  <property name='AvailableConnections' type='ao' access='read'/>
  <property name='State' type='u' access='read'/>
  <property name='StateReason' type='(uu)' access='read'/>
  <property name='ActiveConnection' type='o' access='read'/>
  <property name='Ip4Config' type='o' access='read'/>
  <property name='Dhcp4Config' type='o' access='read'/>
  <property name='Ip6Config' type='o' access='read'/>
  <property name='Dhcp6Config' type='o' access='read'/>
  <property name='Managed' type='b' access='read'/>
  <property name='Autoconnect' type='b' access='read'/>
  <property name='Metered' type='u' access='read'/>
  <property name='LldpNeighbors' type='aa{sv}' access='read'/>
  <property name='Real' type='b' access='read'/>
  <property name='Mtu' type='u' access='read'/>
  <property name='PhysicalPortId' type='s' access='read'/>
 </interface>
 <interface name='org.freedesktop.NetworkManager.Device.Wireless'>
  <method name='GetAccessPoints'><arg type='ao' direction='out'/></method>
  <method name='GetAllAccessPoints'><arg type='ao' direction='out'/></method>
  <method name='RequestScan'><arg type='a{sv}' direction='in'/></method>
  <property name='HwAddress' type='s' access='read'/>
  <property name='PermHwAddress' type='s' access='read'/>
  <property name='Mode' type='u' access='read'/>
  <property name='Bitrate' type='u' access='read'/>
  <property name='AccessPoints' type='ao' access='read'/>
  <property name='ActiveAccessPoint' type='o' access='read'/>
  <property name='WirelessCapabilities' type='u' access='read'/>
  <property name='LastScan' type='x' access='read'/>
 </interface>
</node>"""

AP_XML = """<node>
 <interface name='org.freedesktop.NetworkManager.AccessPoint'>
  <property name='Flags' type='u' access='read'/>
  <property name='WpaFlags' type='u' access='read'/>
  <property name='RsnFlags' type='u' access='read'/>
  <property name='Ssid' type='ay' access='read'/>
  <property name='Frequency' type='u' access='read'/>
  <property name='HwAddress' type='s' access='read'/>
  <property name='Mode' type='u' access='read'/>
  <property name='MaxBitrate' type='u' access='read'/>
  <property name='Strength' type='y' access='read'/>
  <property name='LastSeen' type='i' access='read'/>
 </interface>
</node>"""

AC_XML = """<node>
 <interface name='org.freedesktop.NetworkManager.Connection.Active'>
  <property name='Connection' type='o' access='read'/>
  <property name='SpecificObject' type='o' access='read'/>
  <property name='Id' type='s' access='read'/>
  <property name='Uuid' type='s' access='read'/>
  <property name='Type' type='s' access='read'/>
  <property name='Devices' type='ao' access='read'/>
  <property name='State' type='u' access='read'/>
  <property name='StateFlags' type='u' access='read'/>
  <property name='Default' type='b' access='read'/>
  <property name='Ip4Config' type='o' access='read'/>
  <property name='Dhcp4Config' type='o' access='read'/>
  <property name='Ip6Config' type='o' access='read'/>
  <property name='Dhcp6Config' type='o' access='read'/>
  <property name='Vpn' type='b' access='read'/>
  <property name='Master' type='o' access='read'/>
  <property name='Controller' type='o' access='read'/>
  <property name='Ports' type='ao' access='read'/>
 </interface>
</node>"""

CONN_XML = """<node>
 <interface name='org.freedesktop.NetworkManager.Settings.Connection'>
  <method name='GetSettings'><arg type='a{sa{sv}}' direction='out'/></method>
  <method name='GetSecrets'><arg type='s' direction='in'/><arg type='a{sa{sv}}' direction='out'/></method>
  <method name='Update'><arg type='a{sa{sv}}' direction='in'/></method>
  <method name='Update2'><arg type='a{sa{sv}}' direction='in'/><arg type='u' direction='in'/><arg type='a{sv}' direction='out'/></method>
  <method name='Delete'/>
  <method name='Save'/>
  <property name='Unsaved' type='b' access='read'/>
  <property name='Flags' type='u' access='read'/>
  <property name='Filename' type='s' access='read'/>
  <signal name='Updated'/>
  <signal name='Removed'/>
 </interface>
</node>"""

OM_XML = """<node>
 <interface name='org.freedesktop.DBus.ObjectManager'>
  <method name='GetManagedObjects'>
   <arg type='a{oa{sa{sv}}}' direction='out'/>
  </method>
  <signal name='InterfacesAdded'>
   <arg type='o'/><arg type='a{sa{sv}}'/>
  </signal>
  <signal name='InterfacesRemoved'>
   <arg type='o'/><arg type='as'/>
  </signal>
 </interface>
</node>"""

OM_PATH = '/org/freedesktop'

PROPS = {
    'Devices': GLib.Variant('ao', [DEV_PATH]),
    'AllDevices': GLib.Variant('ao', [DEV_PATH]),
    'Checkpoints': GLib.Variant('ao', []),
    'ActiveConnections': GLib.Variant('ao', [AC_PATH]),
    'PrimaryConnection': GLib.Variant('o', AC_PATH),
    'PrimaryConnectionType': GLib.Variant('s', '802-11-wireless'),
    'ActivatingConnection': GLib.Variant('o', '/'),
    'Startup': GLib.Variant('b', False),
    'State': GLib.Variant('u', 70),            # NM_STATE_CONNECTED_GLOBAL
    'Metered': GLib.Variant('u', 0),
    'Connectivity': GLib.Variant('u', 4),      # NM_CONNECTIVITY_FULL
    'NetworkingEnabled': GLib.Variant('b', True),
    'WirelessEnabled': GLib.Variant('b', True),
    'WirelessHardwareEnabled': GLib.Variant('b', True),
    'WwanEnabled': GLib.Variant('b', False),
    'WwanHardwareEnabled': GLib.Variant('b', False),
    'Version': GLib.Variant('s', '1.54.3'),
}
SET_PROPS = {
    'Connections': GLib.Variant('ao', [CON_PATH]),
    'Hostname': GLib.Variant('s', 'localhost'),
    'CanModify': GLib.Variant('b', False),
}
DEV_PROPS = {
    'Udi': GLib.Variant('s', '/sys/devices/virtual/net/wlan0'),
    'Interface': GLib.Variant('s', 'wlan0'),
    'IpInterface': GLib.Variant('s', 'wlan0'),
    'Driver': GLib.Variant('s', 'stub'),
    'DriverVersion': GLib.Variant('s', '1.0'),
    'FirmwareMissing': GLib.Variant('b', False),
    'NmPluginMissing': GLib.Variant('b', False),
    'DeviceType': GLib.Variant('u', 2),        # NM_DEVICE_TYPE_WIFI
    'AvailableConnections': GLib.Variant('ao', [CON_PATH]),
    'State': GLib.Variant('u', 100),           # NM_DEVICE_STATE_ACTIVATED
    'StateReason': GLib.Variant('(uu)', (100, 0)),
    'ActiveConnection': GLib.Variant('o', AC_PATH),
    'Ip4Config': GLib.Variant('o', '/'),
    'Dhcp4Config': GLib.Variant('o', '/'),
    'Ip6Config': GLib.Variant('o', '/'),
    'Dhcp6Config': GLib.Variant('o', '/'),
    'Managed': GLib.Variant('b', True),
    'Autoconnect': GLib.Variant('b', True),
    'Metered': GLib.Variant('u', 0),
    'LldpNeighbors': GLib.Variant('aa{sv}', []),
    'Real': GLib.Variant('b', True),
    'Mtu': GLib.Variant('u', 1500),
    'PhysicalPortId': GLib.Variant('s', ''),
}
WIFI_PROPS = {
    'HwAddress': GLib.Variant('s', '02:00:00:00:00:00'),
    'PermHwAddress': GLib.Variant('s', '02:00:00:00:00:00'),
    'Mode': GLib.Variant('u', 2),
    'Bitrate': GLib.Variant('u', 5400),
    'AccessPoints': GLib.Variant('ao', [AP_PATH]),
    'ActiveAccessPoint': GLib.Variant('o', AP_PATH),
    'WirelessCapabilities': GLib.Variant('u', 0xFF),
    'LastScan': GLib.Variant('x', 0),
}
AP_PROPS = {
    'Flags': GLib.Variant('u', 0),
    'WpaFlags': GLib.Variant('u', 0),
    'RsnFlags': GLib.Variant('u', 0),
    'Ssid': GLib.Variant('ay', b'SubstrateOS'),
    'Frequency': GLib.Variant('u', 2412),
    'HwAddress': GLib.Variant('s', '02:00:00:00:00:01'),
    'Mode': GLib.Variant('u', 2),
    'MaxBitrate': GLib.Variant('u', 5400),
    'Strength': GLib.Variant('y', 82),
    'LastSeen': GLib.Variant('i', 0),
}

AC_PROPS = {
    'Connection': GLib.Variant('o', CON_PATH),
    'SpecificObject': GLib.Variant('o', DEV_PATH),
    'Id': GLib.Variant('s', 'SubstrateOS'),
    'Uuid': GLib.Variant('s', CON_UUID),
    'Type': GLib.Variant('s', '802-11-wireless'),
    'Devices': GLib.Variant('ao', [DEV_PATH]),
    'State': GLib.Variant('u', 2),             # NM_ACTIVE_CONNECTION_STATE_ACTIVATED
    'StateFlags': GLib.Variant('u', 0),
    'Default': GLib.Variant('b', True),
    'Ip4Config': GLib.Variant('o', '/'),
    'Dhcp4Config': GLib.Variant('o', '/'),
    'Ip6Config': GLib.Variant('o', '/'),
    'Dhcp6Config': GLib.Variant('o', '/'),
    'Vpn': GLib.Variant('b', False),
    'Master': GLib.Variant('o', '/'),
    'Controller': GLib.Variant('o', '/'),
    'Ports': GLib.Variant('ao', []),
}
CONN_PROPS = {
    'Unsaved': GLib.Variant('b', False),
    'Flags': GLib.Variant('u', 0),
    'Filename': GLib.Variant('s', ''),
}
CONN_SETTINGS = {
    'connection': {
        'id': GLib.Variant('s', 'SubstrateOS'),
        'uuid': GLib.Variant('s', CON_UUID),
        'type': GLib.Variant('s', '802-11-wireless'),
        'autoconnect': GLib.Variant('b', True),
        'permissions': GLib.Variant('as', []),
        'timestamp': GLib.Variant('t', 0),
    },
    '802-11-wireless': {
        'ssid': GLib.Variant('ay', b'SubstrateOS'),
        'mode': GLib.Variant('s', 'infrastructure'),
    },
    'ipv4': {'method': GLib.Variant('s', 'auto')},
    'ipv6': {'method': GLib.Variant('s', 'auto')},
}

# Arbol que devuelve org.freedesktop.DBus.ObjectManager.GetManagedObjects
MANAGED = {
    MGR_PATH: {'org.freedesktop.NetworkManager': PROPS},
    SET_PATH: {'org.freedesktop.NetworkManager.Settings': SET_PROPS},
    CON_PATH: {'org.freedesktop.NetworkManager.Settings.Connection': CONN_PROPS},
    DEV_PATH: {
        'org.freedesktop.NetworkManager.Device': DEV_PROPS,
        'org.freedesktop.NetworkManager.Device.Wireless': WIFI_PROPS,
    },
    AP_PATH: {'org.freedesktop.NetworkManager.AccessPoint': AP_PROPS},
    AC_PATH: {'org.freedesktop.NetworkManager.Connection.Active': AC_PROPS},
}


def on_call(conn, sender, path, iface, method, params, inv, ud=None):
    if iface == 'org.freedesktop.DBus.ObjectManager':
        if method == 'GetManagedObjects':
            inv.return_value(GLib.Variant('(a{oa{sa{sv}}})', (MANAGED,)))
        else:
            inv.return_value(None)
        return
    if iface == 'org.freedesktop.NetworkManager':
        if method in ('GetDevices', 'GetAllDevices'):
            inv.return_value(GLib.Variant('(ao)', ([DEV_PATH],)))
        elif method == 'GetPermissions':
            inv.return_value(GLib.Variant('(a{ss})', ({},)))
        elif method == 'CheckConnectivity':
            inv.return_value(GLib.Variant('(u)', (4,)))
        elif method == 'ActivateConnection':
            inv.return_value(GLib.Variant('(o)', (AC_PATH,)))
        elif method == 'AddAndActivateConnection':
            inv.return_value(GLib.Variant('(oo)', (AC_PATH, CON_PATH)))
        else:
            inv.return_value(None)
    elif iface == 'org.freedesktop.NetworkManager.Settings':
        if method in ('GetConnections', 'ListConnections'):
            inv.return_value(GLib.Variant('(ao)', ([CON_PATH],)))
        elif method == 'ReloadConnections':
            inv.return_value(GLib.Variant('(b)', (True,)))
        else:
            inv.return_value(None)
    elif iface == 'org.freedesktop.NetworkManager.Settings.Connection':
        if method in ('GetSettings', 'GetSecrets'):
            inv.return_value(GLib.Variant('(a{sa{sv}})', (CONN_SETTINGS,)))
        elif method == 'Update2':
            inv.return_value(GLib.Variant('(a{sv})', ({},)))
        else:
            inv.return_value(None)
    elif iface == 'org.freedesktop.NetworkManager.Device':
        if method == 'GetAppliedConnection':
            inv.return_value(GLib.Variant('(a{sa{sv}}t)', (CONN_SETTINGS, 0)))
        else:
            inv.return_value(None)
    elif iface == 'org.freedesktop.NetworkManager.Device.Wireless':
        if method in ('GetAccessPoints', 'GetAllAccessPoints'):
            inv.return_value(GLib.Variant('(ao)', ([AP_PATH],)))
        else:
            inv.return_value(None)
    else:
        inv.return_value(None)


def get_prop(conn, sender, path, iface, prop, ud=None):
    if iface == 'org.freedesktop.NetworkManager':
        return PROPS.get(prop)
    if iface == 'org.freedesktop.NetworkManager.Settings':
        return SET_PROPS.get(prop)
    if iface == 'org.freedesktop.NetworkManager.Device':
        return DEV_PROPS.get(prop)
    if iface == 'org.freedesktop.NetworkManager.Device.Wireless':
        return WIFI_PROPS.get(prop)
    if iface == 'org.freedesktop.NetworkManager.AccessPoint':
        return AP_PROPS.get(prop)
    if iface == 'org.freedesktop.NetworkManager.Settings.Connection':
        return CONN_PROPS.get(prop)
    if iface == 'org.freedesktop.NetworkManager.Connection.Active':
        return AC_PROPS.get(prop)
    return None


conn = Gio.DBusConnection.new_for_address_sync(
    ADDR,
    Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT |
    Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
    None, None)
node = Gio.DBusNodeInfo.new_for_xml(XML)
mgr_iface = [i for i in node.interfaces if i.name.endswith('NetworkManager')][0]
set_iface = [i for i in node.interfaces if i.name.endswith('Settings')][0]
dev_node = Gio.DBusNodeInfo.new_for_xml(DEV_XML)
dev_iface = [i for i in dev_node.interfaces if i.name == 'org.freedesktop.NetworkManager.Device'][0]
wifi_iface = [i for i in dev_node.interfaces if i.name == 'org.freedesktop.NetworkManager.Device.Wireless'][0]
ap_node = Gio.DBusNodeInfo.new_for_xml(AP_XML)
ap_iface = ap_node.interfaces[0]
ac_node = Gio.DBusNodeInfo.new_for_xml(AC_XML)
ac_iface = ac_node.interfaces[0]
con_node = Gio.DBusNodeInfo.new_for_xml(CONN_XML)
con_iface = con_node.interfaces[0]
om_node = Gio.DBusNodeInfo.new_for_xml(OM_XML)
om_iface = om_node.interfaces[0]
conn.register_object(MGR_PATH, mgr_iface, on_call, get_prop, None)
conn.register_object(SET_PATH, set_iface, on_call, get_prop, None)
conn.register_object(CON_PATH, con_iface, on_call, get_prop, None)
conn.register_object(DEV_PATH, dev_iface, on_call, get_prop, None)
conn.register_object(DEV_PATH, wifi_iface, on_call, get_prop, None)
conn.register_object(AP_PATH, ap_iface, on_call, get_prop, None)
conn.register_object(AC_PATH, ac_iface, on_call, get_prop, None)
conn.register_object(OM_PATH, om_iface, on_call, get_prop, None)
r = conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                   'org.freedesktop.DBus', 'RequestName',
                   GLib.Variant('(su)', ('org.freedesktop.NetworkManager', 4)),
                   GLib.VariantType('(u)'), Gio.DBusCallFlags.NONE, -1, None)
print('nm-stub RequestName ->', r.unpack()[0], flush=True)
# Avisar a clientes ya conectados (p.ej. gnome-shell) del nuevo dispositivo.
try:
    conn.emit_signal(None, MGR_PATH, 'org.freedesktop.NetworkManager',
                     'DeviceAdded', GLib.Variant('(o)', (DEV_PATH,)))
except Exception as e:
    print('nm-stub DeviceAdded warn:', e, flush=True)
GLib.MainLoop().run()
