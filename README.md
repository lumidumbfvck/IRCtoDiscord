# AdiIRC -> Discord Rich Presence

Minimal Rich Presence bridge for Windows + AdiIRC.

It shows:

    IRC
    YourNick

    Network
    #channel1 • #channel2

No WHOIS, hostmask, real name, user counts, or message contents are sent.

## 1. Create a Discord application

Open the Discord Developer Portal and create an application. Copy its Application ID.

Put the ID into `config.json`:

    {
      "clientId": "123456789012345678"
    }

The rest of the defaults can stay unchanged.

## 2. Start Discord

The normal Discord desktop client must be running.

## 3. Start the bridge

Double-click `Start-AdiIRC-Discord-RPC.cmd`.

The window is hidden. To troubleshoot, use `Start-AdiIRC-Discord-RPC-Visible.cmd` instead.

## 4. Load the AdiIRC script

In AdiIRC:

    Tools -> Edit Scripts

or press Alt+R.

Create/load a remote script containing `AdiIRC-Discord-RPC.mrc`.

You can also load it from the AdiIRC edit box with:

    /load -rs "C:\path\to\AdiIRC-Discord-RPC.mrc"

After loading, the script connects to the local helper.

## 5. Expected presence

For example:

    IRC
    April

    Libera.Chat: #linux • #adiirc
    OFTC: #debian

The presence updates when you connect/disconnect, join/part, get kicked, change nick, or reconnect.

## Troubleshooting

### Nothing appears in Discord

1. Make sure Discord desktop is running.
2. Check that `clientId` is set in `config.json`.
3. Run `Start-AdiIRC-Discord-RPC-Visible.cmd` and look for errors.
4. Reload the AdiIRC script.

### AdiIRC says the socket cannot connect

Make sure the PowerShell helper is running. It listens only on `127.0.0.1:48921`.

### Channels show under the wrong network

The script uses AdiIRC's channel/network metadata. If a particular bouncer setup reports unusual network names, the visible name will follow whatever AdiIRC reports.

## Notes

- Windows PowerShell is included with Windows 10/11; no Python or .NET SDK is required.
- The helper only listens on localhost.
- The AdiIRC script sends only your nick and joined channel/network names.
- Rich Presence is associated with the Discord application ID you create.
