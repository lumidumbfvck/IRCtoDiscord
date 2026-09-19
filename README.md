# IRCtoDiscord

**AdiIRC-specific** version.

Your Discord presence will look roughly like:

```text
IRC
Nick

Example.Chat: #linux • #adiirc
OFTC: #debian
```

It automatically updates when you:

* Join a channel
* Part a channel
* Get kicked
* Change nick
* Connect/disconnect from a network
* Reconnect
* Have multiple IRC networks open simultaneously

It deliberately **does not transmit WHOIS information, hostname, IP, real name, messages, user counts, or anything else**.

The AdiIRC side uses its built-in scripting and socket facilities, which are documented by AdiIRC. 
### Setup

1. **Create a Discord application** in the Discord Developer Portal and copy its Application ID. Discord's documentation confirms that a Discord application is what identifies the Rich Presence activity.

2. Extract the ZIP.

3. Open:

```text
config.json
```

and replace:

```text
PASTE_YOUR_DISCORD_APPLICATION_ID_HERE
```

with your application's ID.

4. Start:

```text
Start-AdiIRC-Discord-RPC.cmd
```

5. In AdiIRC, press **Alt+R** to open the script editor and load:

```text
AdiIRC-Discord-RPC.mrc
```

You can also use:

```text
/load -rs "C:\path\to\AdiIRC-Discord-RPC.mrc"
```

AdiIRC officially supports loading remote `.mrc` scripts this way. 
6. Reload/reconnect AdiIRC.

The bridge listens only on `127.0.0.1`, so nothing is exposed to your network.


[1]: https://dev.adiirc.com/projects/adiirc/wiki/Scripting?utm_source=chatgpt.com "Scripting - AdiIRC - AdiIRC Support/Bugs/Feature Requests"
[2]: https://discord.com/developers/docs/social-sdk/getting_started.html?utm_source=chatgpt.com "Getting Started | Discord Social SDK"
[3]: https://wiki.adiirc.com/projects/adiirc/wiki/Scripting_Scripts?utm_source=chatgpt.com "Scripting Scripts - AdiIRC - AdiIRC Support/Bugs/Feature Requests"
[4]: https://discord.com/developers/docs/social-sdk/classdiscordpp_1_1Activity.html?utm_source=chatgpt.com "discordpp::Activity Class Reference | Discord Social SDK"
