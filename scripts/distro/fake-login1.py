#!/usr/bin/env python3
# Stub ampliado de org.freedesktop.login1 para GNOME Shell 49 / mutter 49 en proot.
# - Manager.Can* => "no"; acciones => no-op; Inhibit => NotSupported.
# - Manager.GetSession/GetSessionByPID => objeto Session falso (Type=x11, State=active).
# - Session.Seat => seat0; Seat.SwitchTo => no-op.
# Complementa /run/systemd/sessions/<id> (sd_session_is_active).
import os
from gi.repository import Gio, GLib

ADDR = 'unix:path=' + os.environ.get('RT_SYSTEM_BUS', '/tmp/rt-dex/system-bus')
SESSION_ID = os.environ.get('LOGIN1_STUB_SESSION_ID', 'substrate')
SESSION_PATH = '/org/freedesktop/login1/session/substrate'
SEAT_ID = 'seat0'
SEAT_PATH = '/org/freedesktop/login1/seat/seat0'

MANAGER_XML = """<node>
 <interface name='org.freedesktop.login1.Manager'>
  <method name='CanPowerOff'><arg type='s' direction='out'/></method>
  <method name='CanReboot'><arg type='s' direction='out'/></method>
  <method name='CanHalt'><arg type='s' direction='out'/></method>
  <method name='CanSuspend'><arg type='s' direction='out'/></method>
  <method name='CanHibernate'><arg type='s' direction='out'/></method>
  <method name='CanHybridSleep'><arg type='s' direction='out'/></method>
  <method name='CanSuspendThenHibernate'><arg type='s' direction='out'/></method>
  <method name='PowerOff'><arg type='b' direction='in'/></method>
  <method name='Reboot'><arg type='b' direction='in'/></method>
  <method name='Halt'><arg type='b' direction='in'/></method>
  <method name='Suspend'/><method name='Hibernate'/>
  <method name='HybridSleep'/><method name='SuspendThenHibernate'/>
  <method name='LockSession'><arg type='s' direction='in'/></method>
  <method name='UnlockSession'><arg type='s' direction='in'/></method>
  <method name='LockSessions'/><method name='UnlockSessions'/>
  <method name='SetRebootParameter'><arg type='s' direction='in'/></method>
  <method name='SetRebootToFirmwareSetup'><arg type='b' direction='in'/></method>
  <method name='GetSession'><arg type='s' direction='in'/><arg type='o' direction='out'/></method>
  <method name='GetSessionByPID'><arg type='u' direction='in'/><arg type='o' direction='out'/></method>
  <method name='GetSeat'><arg type='s' direction='in'/><arg type='o' direction='out'/></method>
  <method name='GetUser'><arg type='u' direction='in'/><arg type='o' direction='out'/></method>
  <method name='GetUserByPID'><arg type='u' direction='in'/><arg type='o' direction='out'/></method>
  <method name='ListUsers'><arg type='a(uso)' direction='out'/></method>
  <method name='ListSessions'><arg type='a(susssou)' direction='out'/></method>
  <method name='ListSeats'><arg type='a(so)' direction='out'/></method>
  <method name='ListInhibitors'><arg type='a(ssssuu)' direction='out'/></method>
  <method name='Inhibit'><arg type='s' direction='in'/><arg type='s' direction='in'/>
    <arg type='s' direction='in'/><arg type='s' direction='in'/><arg type='h' direction='out'/></method>
  <signal name='PrepareForSleep'><arg type='b'/></signal>
 </interface></node>"""

SESSION_XML = """<node>
 <interface name='org.freedesktop.login1.Session'>
  <method name='Terminate'/><method name='Activate'/>
  <method name='Lock'/><method name='Unlock'/>
  <method name='SetIdleHint'><arg type='b' direction='in'/></method>
  <method name='TakeControl'><arg type='b' direction='in'/></method>
  <method name='ReleaseControl'/>
  <method name='SetBrightness'><arg type='s' direction='in'/><arg type='u' direction='in'/></method>
  <method name='Kill'><arg type='s' direction='in'/><arg type='i' direction='in'/></method>
  <property name='Id' type='s' access='read'/>
  <property name='User' type='(uo)' access='read'/>
  <property name='Name' type='s' access='read'/>
  <property name='Timestamp' type='t' access='read'/>
  <property name='TimestampMonotonic' type='t' access='read'/>
  <property name='Service' type='s' access='read'/>
  <property name='Desktop' type='s' access='read'/>
  <property name='Scope' type='s' access='read'/>
  <property name='Leader' type='u' access='read'/>
  <property name='Audit' type='u' access='read'/>
  <property name='Type' type='s' access='read'/>
  <property name='Class' type='s' access='read'/>
  <property name='Active' type='b' access='read'/>
  <property name='State' type='s' access='read'/>
  <property name='Seat' type='(so)' access='read'/>
  <property name='TTY' type='s' access='read'/>
  <property name='Display' type='s' access='read'/>
  <property name='Remote' type='b' access='read'/>
  <property name='RemoteHost' type='s' access='read'/>
  <property name='VTNr' type='u' access='read'/>
  <property name='IdleHint' type='b' access='read'/>
  <property name='IdleSinceHint' type='t' access='read'/>
  <property name='IdleSinceHintMonotonic' type='t' access='read'/>
 </interface></node>"""

USER_XML = """<node>
 <interface name='org.freedesktop.login1.User'>
  <method name='Terminate'/><method name='Kill'/>
  <method name='GetDisplay'><arg type='so' direction='out'/></method>
  <property name='UID' type='u' access='read'/>
  <property name='GID' type='u' access='read'/>
  <property name='Name' type='s' access='read'/>
  <property name='Timestamp' type='t' access='read'/>
  <property name='TimestampMonotonic' type='t' access='read'/>
  <property name='RuntimePath' type='s' access='read'/>
  <property name='Service' type='s' access='read'/>
  <property name='Slice' type='s' access='read'/>
  <property name='Display' type='(so)' access='read'/>
  <property name='State' type='s' access='read'/>
  <property name='Linger' type='b' access='read'/>
  <property name='IdleHint' type='b' access='read'/>
  <property name='IdleSinceHint' type='t' access='read'/>
  <property name='IdleSinceHintMonotonic' type='t' access='read'/>
 </interface></node>"""

SEAT_XML = """<node>
 <interface name='org.freedesktop.login1.Seat'>
  <method name='SwitchTo'><arg type='u' direction='in'/></method>
  <method name='SwitchToNext'/><method name='SwitchToPrevious'/>
  <method name='TerminateSession'><arg type='s' direction='in'/></method>
  <method name='ActivateSession'><arg type='s' direction='in'/></method>
  <property name='Id' type='s' access='read'/>
  <property name='ActiveSession' type='(so)' access='read'/>
  <property name='CanMultiSession' type='b' access='read'/>
  <property name='CanTTY' type='b' access='read'/>
  <property name='CanGraphical' type='b' access='read'/>
  <property name='IdleHint' type='b' access='read'/>
  <property name='IdleSinceHint' type='t' access='read'/>
  <property name='IdleSinceHintMonotonic' type='t' access='read'/>
 </interface></node>"""

CAN = {'CanPowerOff', 'CanReboot', 'CanHalt', 'CanSuspend', 'CanHibernate',
       'CanHybridSleep', 'CanSuspendThenHibernate'}

SESSION_PROPS = {
    'Id': GLib.Variant('s', SESSION_ID),
    'User': GLib.Variant('(uo)', (0, '/org/freedesktop/login1/user/_0')),
    'Name': GLib.Variant('s', 'root'),
    'Timestamp': GLib.Variant('t', 0),
    'TimestampMonotonic': GLib.Variant('t', 0),
    'Service': GLib.Variant('s', ''),
    'Desktop': GLib.Variant('s', 'GNOME'),
    'Scope': GLib.Variant('s', ''),
    'Leader': GLib.Variant('u', os.getpid()),
    'Audit': GLib.Variant('u', 0),
    'Type': GLib.Variant('s', 'x11'),
    'Class': GLib.Variant('s', 'user'),
    'Active': GLib.Variant('b', True),
    'State': GLib.Variant('s', 'active'),
    'Seat': GLib.Variant('(so)', (SEAT_ID, SEAT_PATH)),
    'TTY': GLib.Variant('s', ''),
    'Display': GLib.Variant('s', ':0'),
    'Remote': GLib.Variant('b', False),
    'RemoteHost': GLib.Variant('s', ''),
    'VTNr': GLib.Variant('u', 0),
    'IdleHint': GLib.Variant('b', False),
    'IdleSinceHint': GLib.Variant('t', 0),
    'IdleSinceHintMonotonic': GLib.Variant('t', 0),
}

SEAT_PROPS = {
    'Id': GLib.Variant('s', SEAT_ID),
    'ActiveSession': GLib.Variant('(so)', (SESSION_ID, SESSION_PATH)),
    'CanMultiSession': GLib.Variant('b', False),
    'CanTTY': GLib.Variant('b', False),
    'CanGraphical': GLib.Variant('b', True),
    'IdleHint': GLib.Variant('b', False),
    'IdleSinceHint': GLib.Variant('t', 0),
    'IdleSinceHintMonotonic': GLib.Variant('t', 0),
}


USER_PATH = '/org/freedesktop/login1/user/_0'
USER_PROPS = {
    'UID': GLib.Variant('u', 0),
    'GID': GLib.Variant('u', 0),
    'Name': GLib.Variant('s', 'root'),
    'Timestamp': GLib.Variant('t', 0),
    'TimestampMonotonic': GLib.Variant('t', 0),
    'RuntimePath': GLib.Variant('s', '/run/user/0'),
    'Service': GLib.Variant('s', ''),
    'Slice': GLib.Variant('s', 'user-0.slice'),
    'Display': GLib.Variant('(so)', (SESSION_ID, SESSION_PATH)),
    'State': GLib.Variant('s', 'active'),
    'Linger': GLib.Variant('b', False),
    'IdleHint': GLib.Variant('b', False),
    'IdleSinceHint': GLib.Variant('t', 0),
    'IdleSinceHintMonotonic': GLib.Variant('t', 0),
}

def on_manager(conn, sender, path, iface, method, params, inv, ud=None):
    if method in CAN:
        inv.return_value(GLib.Variant('(s)', ('no',)))
    elif method in ('GetSession', 'GetSessionByPID'):
        inv.return_value(GLib.Variant('(o)', (SESSION_PATH,)))
    elif method == 'GetSeat':
        inv.return_value(GLib.Variant('(o)', (SEAT_PATH,)))
    elif method in ('GetUser', 'GetUserByPID'):
        inv.return_value(GLib.Variant('(o)', (USER_PATH,)))
    elif method == 'ListUsers':
        inv.return_value(GLib.Variant('(a(uso))', ([(0, 'root', USER_PATH)],)))
    elif method == 'ListSessions':
        inv.return_value(GLib.Variant('(a(susssou))', ([],)))
    elif method == 'ListSeats':
        inv.return_value(GLib.Variant('(a(so))', ([],)))
    elif method == 'ListInhibitors':
        inv.return_value(GLib.Variant('(a(ssssuu))', ([],)))
    elif method == 'Inhibit':
        inv.return_dbus_error('org.freedesktop.DBus.Error.NotSupported',
                              'stub login1: Inhibit no soportado')
    else:
        inv.return_value(None)


def on_session(conn, sender, path, iface, method, params, inv, ud=None):
    inv.return_value(None)


def on_user(conn, sender, path, iface, method, params, inv, ud=None):
    if method == 'GetDisplay':
        inv.return_value(GLib.Variant('(so)', (SESSION_ID, SESSION_PATH)))
    else:
        inv.return_value(None)


def on_seat(conn, sender, path, iface, method, params, inv, ud=None):
    inv.return_value(None)


def get_prop(conn, sender, path, iface, prop, ud=None):
    if iface == 'org.freedesktop.login1.Session':
        return SESSION_PROPS.get(prop)
    if iface == 'org.freedesktop.login1.Seat':
        return SEAT_PROPS.get(prop)
    if iface == 'org.freedesktop.login1.User':
        return USER_PROPS.get(prop)
    return None


conn = Gio.DBusConnection.new_for_address_sync(
    ADDR,
    Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT |
    Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
    None, None)
mgr_iface = Gio.DBusNodeInfo.new_for_xml(MANAGER_XML).interfaces[0]
sess_iface = Gio.DBusNodeInfo.new_for_xml(SESSION_XML).interfaces[0]
seat_iface = Gio.DBusNodeInfo.new_for_xml(SEAT_XML).interfaces[0]
user_iface = Gio.DBusNodeInfo.new_for_xml(USER_XML).interfaces[0]
conn.register_object('/org/freedesktop/login1', mgr_iface, on_manager, get_prop, None)
conn.register_object(SESSION_PATH, sess_iface, on_session, get_prop, None)
conn.register_object(SEAT_PATH, seat_iface, on_seat, get_prop, None)
conn.register_object(USER_PATH, user_iface, on_user, get_prop, None)
r = conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                   'org.freedesktop.DBus', 'RequestName',
                   GLib.Variant('(su)', ('org.freedesktop.login1', 4)),
                   GLib.VariantType('(u)'), Gio.DBusCallFlags.NONE, -1, None)
print('login1-stub RequestName ->', r.unpack()[0], flush=True)
GLib.MainLoop().run()
