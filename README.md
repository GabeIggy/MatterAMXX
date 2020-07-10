
![](https://forums.alliedmods.net/image-proxy/29634d69f9657c78959c33f2b40e4ead3fb76dc6/68747470733a2f2f692e696d6775722e636f6d2f494478794c556b2e706e67)
# MatterAMXX
Powered by Matterbridge, MatterAMXX is a plugin for AMXX that allows simple bridging between your game servers, Mattermost, IRC, XMPP, Gitter, Slack, Discord, Telegram, and more.  
  
![](https://forums.alliedmods.net/image-proxy/0d6f7b0bf8a787250a699a1560f519e37797c159/68747470733a2f2f692e696d6775722e636f6d2f725164567549782e706e67)
  
## Description
  
Using Matterbridge API, this plugin allows you to bridge your game server with a Matterbridge installation, relaying messages from/to a growing number of protocols.  
  
You can also bridge multiple servers together so the players can chat between each one.  
  
  
## Protocols natively supported in Matterbridge

- Mattermost
- IRC
- XMPP
- Gitter
- Slack
- Discord
- Telegram
- Rocket.chat
- Matrix
- Steam ([Bugged](https://github.com/42wim/matterbridge/issues/457) [for](https://github.com/Philipp15b/go-steam/issues/94) [now](https://github.com/SteamRE/SteamKit/issues/561))
- Twitch
- Ssh-chat
- WhatsApp
- Zulip
- Keybase

  
### Tested Protocols

- Discord
- Matrix
- Telegram

  
## Dependencies
  
This plugin requires the following to work:

- **[GoldSrc Rest In Pawn (gRIP)](https://forums.alliedmods.net/showthread.php?t=315567)**
- **[A working Matterbridge installation](https://github.com/42wim/matterbridge/wiki/How-to-create-your-config)**

  
## Supported Games
This plugin is supposed to be mod agnostic. All official games should work out of the box

- Half-Life
- Counter-Strike
- Condition Zero
- Opposing Force
- Ricochet
- Day of Defeat
- Team Fortress Classic
- Deathmatch Classic

  
Kill feed feature will also work in mods where a proper hamdata.ini table is provided

- The Specialists
- Sven Co-op

  
  
### Tested Games

- Half-Life
- Ricochet
- Sven Co-op
- The Specialists

  
## Installation Instructions

- Download all requirements, plus the .sma file.
- Place include files in the /scripting/includes directory.
- Compile the plugin and install the newly generated .amxx file. (Remember to install the latest version of GRIP in your server)

  
## Setting up MatterAMXX
  
This quickstart guide assumes you already have a working Matterbridge installation.  
  
Open your `matterbridge.toml` file and add the following lines:  

```
[api.myserver]
BindAddress="0.0.0.0:1337"
Token="verysecrettoken"
Buffer=1000
RemoteNickFormat="{NICK}"
```

Where "myserver" is goes the name of the relay, you can put anything.  
  
Find your gateway where you want to relay the messages.  

```
[[gateway]]  
name="cstrike"  
enable=true  
  
[[gateway.inout]]  
account="discord.mydiscord"  
channel="general"  
  
[[gateway.inout]]  
account="api.myserver"  
channel="api"
```

Where `cstrike` is goes the gateway name. By default is the mod's gamedir (`cstrike` for Counter-Strike, `valve` for Half-Life, etc) but you can change it using cvars, you can add more `gateway.inout` entries depending on how many protocols do you want to relay messages.  
  
  
## Avatar Spoofing
  
It's possible to set up avatars for each user on protocols that support it. Unfortunately, due to limitations of AMXX and the GRIP module, user info from the Steam API can't be retrieved because it gets truncated.  
  
However, you can host the included PHP script to query for avatars to be used in this plugin, you just need a Steam API Key that you can obtain from the [Steam Web API website](https://steamcommunity.com/dev).  
  
This will also cache each avatar and they will be deleted after a while.  
  
Remember to create the `/avatars` folder! The script won't do it for you.  
  
## API
  
The API allows other plugins to use MatterAMXX features. Just include the `matteramxx.inc` file in your plugin and it should work immediately.  
  
Remember that the plugin requires the latest version of MatterAMXX to be running in the server.  
  
## Console Variables 

- **amx_matter_enable**
    - Enables the plugin.
    - Default: `1`
- **amx_matter_bridge_url**
    - URL and port where the bridge is located.
    - Default: `http://localhost:1337`
- **amx_matter_system_avatar**
    - URL pointing to a picture that will be used as avatar image in system messages. (In protocols that support it)
    - Default: `[empty string]`
- **amx_matter_autogenerate_avatar**
    - URL pointing to a picture that will be used as avatar image in unauthenticated player messages. (In protocols that support it)
    - This will mostly affect LAN servers, ID_PENDING cases, cases where Steam might be down and other specific cases.
    - This is generated on the user's nickname, so you must provide a link to Gravatar, Identicons, etc.
    - Default: `[empty string]`
- **amx_matter_player_avatar**
    - URL pointing to a picture that will be used as avatar image in player messages. (In protocols that support it)
    - Note that this is dynamic based on the user's Steam ID64, if it can't be retrieved the message won't have any avatar.
    - Upload the PHP file I provided to your file server and use it in this cvar like `http://localhost/avatars/get_avatar.php?steamid=%s`.
    - See "Avatar Spoofing" for more information.
    - Default: `[empty string]`
- **amx_matter_bridge_gateway**
    - Gateway name to connect.
    - Default: `[varies, depends on the game]`
- **amx_matter_bridge_token**
    - String token to authenticate, it's recommended that you set it up, but it will accept any connection by default.
    - Default: `[empty string]`
- **amx_matter_bridge_incoming**
    - Enables incoming messages (protocols to server).
    - Default: `1`
- **amx_matter_incoming_update_time**
    - Specifies how many seconds it has to wait before querying new incoming messages.
    - Performance wise is tricky, lower values mean the messages will be queried instantly, while higher values will wait and bring all messages at once, both cases may cause overhead. Experiment and see what's ideal for your server.
    - No effect if `amx_matter_bridge_incoming` is `0`.
    - Default: `3.0`
- **amx_matter_bridge_outgoing**
    - Enables outgoing messages (server to protocols).
    - Default: `1`
- **amx_matter_bridge_outgoing_display_map**
    - Display the current map at the start of every session.
    - Default: `1`
- **amx_matter_bridge_outgoing_strip_colors**
    - Strip color codes from player names.
    - It will only affect Half-Life and Adrenaline Gamer.
        - No effect in other games.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `1`
- **amx_matter_bridge_outgoing_system_username**
    - Name of the "user" when relying system messages.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `[your server name]`
- **amx_matter_bridge_outgoing_chat**
    - Transmit chat messages.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `1`
- **amx_matter_bridge_outgoing_chat_no_repeat**
    - Implement basic anti-spam filter. Useful for preventing taunt binds from sending multiple times.
    - No effect if `amx_matter_bridge_outgoing_chat` is `0`.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `1`
- **amx_matter_bridge_outgoing_kills**
    - Transmit kill feed.
    - It's recommended that you to turn it off on heavy activity servers (Like CSDM/Half-Life servers with tons of players)
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default `1`
- **amx_matter_bridge_outgoing_join**
    - Transmit when people join the server.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `1`
- **amx_matter_bridge_outgoing_join_delay**
    - Specify how many seconds the server has to wait before sending Join messages..
    - No effect if `amx_matter_bridge_outgoing_join` is `0`.
    - Default: `30.0`
- **amx_matter_bridge_outgoing_quit**
    - Transmit when people leave the server.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `1`
- **amx_matter_bridge_outgoing_quit_ignore_intermission**
    - Specify if the server shouldn't send quit messages if the server reached the intermission state.
    - No effect if `amx_matter_bridge_outgoing_quit` is `0`.
    - Default: `0`
- **amx_matter_bridge_outgoing_joinquit_count**
    - Display playercount on each Join/Quit message.
    - No effect if both `amx_matter_bridge_outgoing_quit` and `amx_matter_bridge_outgoing_join` are `0`.
    - Default: `1`
- **amx_matter_bridge_retry_delay**
    - In seconds, how long the server has wait before retrying a connection when it was interrupted.
    - No effect if `amx_matter_bridge_outgoing` is `0`.
    - Default: `3.0`
  
# Credits

- 42wim  
    _Main developer of Matterbridge._
- Michael Wieland  
    _His MatterBukkit plugin for Minecraft inspired me to create this._
- Th3-822  
    _Helped me finding some bugs._
