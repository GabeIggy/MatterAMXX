// ** COMPILER OPTIONS **

// enable if you want to use HamSandwich (recommended)
// disable if you want to use DeathMsg, for example
// in games that do not have HamSandwich support
#define USE_HAMSANDWICH 1

// enable if you want to use extended string buffers, 
// most of the time you won't need it, but you may 
// enable it if you have problems with messages.
// note that this will cause this plugin to be more heavy
#define USE_EXTENDED_BUFFER 0

// ** COMPILER OPTIONS END HERE **

#if USE_EXTENDED_BUFFER > 0
    #pragma dynamic 65536
#else
    #pragma dynamic 32768
#endif

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <regex>

#if USE_HAMSANDWICH > 0
    #include <hamsandwich>
#endif

#include <grip>

#if USE_EXTENDED_BUFFER > 0
    #define INCOMING_BUFFER_LENGTH 10240
    #define TARGET_URL_LENGTH 2048
    #define MESSAGE_LENGTH 1024
    #define BASE_URL_LENGTH 512
    #define JSON_PARAMETER_LENGTH 512
    #define TOKEN_LENGTH 128
#else
    #define INCOMING_BUFFER_LENGTH 5120
    #define TARGET_URL_LENGTH 1024
    #define MESSAGE_LENGTH 512
    #define BASE_URL_LENGTH 256
    #define JSON_PARAMETER_LENGTH 256
    #define TOKEN_LENGTH 64
#endif

#if AMXX_VERSION_NUM < 183
    #define MAX_PLAYERS 32
    #define MAX_NAME_LENGTH 32
#endif

#define REGEX_STEAMID_PATTERN "^^STEAM_(0|1):(0|1):\d+$"

#define MATTERAMXX_PLUGIN_NAME "MatterAMXX"
#define MATTERAMXX_PLUGIN_AUTHOR "Gabe Iggy"
#define MATTERAMXX_PLUGIN_VERSION "1.4"

#pragma semicolon 1

new g_cvarEnabled;
new g_cvarSystemAvatarUrl;
new g_cvarAutogenAvatarUrl;
new g_cvarAvatarUrl;
new g_cvarBridgeUrl;
new g_cvarBridgeGateway;
new g_cvarToken;
new g_cvarIncoming;
new g_cvarIncoming_Chat_DisplayProtocol;
new g_cvarIncoming_Chat_RefreshTime;
new g_cvarOutgoing;
new g_cvarOutgoing_SystemUsername;
new g_cvarOutgoing_Chat;
new g_cvarOutgoing_Chat_Team;
new g_cvarOutgoing_Chat_SpamFil;
new g_cvarOutgoing_Chat_ZeroifyAtSign;
new g_cvarOutgoing_Kills;
new g_cvarOutgoing_Join;
new g_cvarOutgoing_Join_Delay;
new g_cvarOutgoing_Quit;
new g_cvarOutgoing_Quit_IgnoreIntermission;
new g_cvarOutgoing_JoinQuit_ShowCount;
new g_cvarOutgoing_StripColors;
new g_cvarOutgoing_DisplayMap;
new g_cvarRetry_Delay;
new GripRequestCancellation:g_gripIncomingHandle;
new GripRequestCancellation:g_gripOutgoingHandle;
new GripRequestOptions:g_gIncomingHeader;
new GripRequestOptions:g_gOutgoingHeader;

new g_sIncomingUri[BASE_URL_LENGTH];
new g_sOutgoingUri[BASE_URL_LENGTH];
new g_sBridgeUrl[BASE_URL_LENGTH];
new g_sAvatarUrl[BASE_URL_LENGTH];
new g_sAutogenAvatarUrl[BASE_URL_LENGTH];
new g_sSystemAvatarUrl[BASE_URL_LENGTH];
new g_sSystemName[MAX_NAME_LENGTH];
new g_sGateway[MAX_NAME_LENGTH];
new g_sGamename[MAX_NAME_LENGTH];

new g_sLastMessages[MAX_PLAYERS+1][MESSAGE_LENGTH];
new g_bUserConnected[MAX_PLAYERS+1];

new g_bUserAuthenticated[MAX_PLAYERS+1];

new bool:g_bJoinDelayDone = false;
new bool:g_bIsIntermission = false;

new g_iPrintMessageForward; 

new Float:g_fRetryDelay;
new Float:g_fQueryDelay;

new g_iPluginFlags;

new Regex:g_rAuthid_pattern;

new const sHexTable[] = "0123456789ABCDEF";

public plugin_init()
{
    new sServername[MAX_NAME_LENGTH];
    get_modname(g_sGamename, charsmax(g_sGamename));
    get_cvar_string("hostname", sServername, charsmax(sServername));

    register_plugin(MATTERAMXX_PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_matter_enable", "1");
    g_cvarSystemAvatarUrl = register_cvar("amx_matter_system_avatar", "", FCVAR_PROTECTED);
    g_cvarAutogenAvatarUrl = register_cvar("amx_matter_autogenerate_avatar", "", FCVAR_PROTECTED); //https://robohash.org/%s.png?set=set4
    g_cvarAvatarUrl = register_cvar("amx_matter_player_avatar", "", FCVAR_PROTECTED); //http://localhost/avatars/get_avatar.php?steamid=%s
    g_cvarBridgeUrl = register_cvar("amx_matter_bridge_url", "http://localhost:1337", FCVAR_PROTECTED);
    g_cvarBridgeGateway = register_cvar("amx_matter_bridge_gateway", g_sGamename, FCVAR_PROTECTED);
    g_cvarToken = register_cvar("amx_matter_bridge_token", "", FCVAR_PROTECTED);
    g_cvarIncoming = register_cvar("amx_matter_bridge_incoming", "1");
    g_cvarIncoming_Chat_DisplayProtocol = register_cvar("amx_matter_bridge_incoming_chat_protocol", "0");
    g_cvarIncoming_Chat_RefreshTime = register_cvar("amx_matter_incoming_update_time", "3.0");
    g_cvarOutgoing = register_cvar("amx_matter_bridge_outgoing", "1");
    g_cvarOutgoing_SystemUsername = register_cvar("amx_matter_bridge_outgoing_system_username", sServername);
    g_cvarOutgoing_Chat = register_cvar("amx_matter_bridge_outgoing_chat", "1");
    g_cvarOutgoing_Chat_Team = register_cvar("amx_matter_bridge_outgoing_chat_team", "1");
    g_cvarOutgoing_Chat_SpamFil = register_cvar("amx_matter_bridge_outgoing_chat_no_repeat", "1");
    g_cvarOutgoing_Chat_ZeroifyAtSign = register_cvar("amx_matter_bridge_outgoing_chat_zwsp_at", "1");
    g_cvarOutgoing_Kills = register_cvar("amx_matter_bridge_outgoing_kills", "1");
    g_cvarOutgoing_Join = register_cvar("amx_matter_bridge_outgoing_join", "1");
    g_cvarOutgoing_Join_Delay = register_cvar("amx_matter_bridge_outgoing_join_delay", "15.0");
    g_cvarOutgoing_Quit = register_cvar("amx_matter_bridge_outgoing_quit", "1");
    g_cvarOutgoing_Quit_IgnoreIntermission = register_cvar("amx_matter_bridge_outgoing_quit_ignore_intermission", "0");
    g_cvarOutgoing_StripColors = register_cvar("amx_matter_bridge_outgoing_strip_colors", "1");
    g_cvarOutgoing_DisplayMap = register_cvar("amx_matter_bridge_outgoing_display_map", "1");
    g_cvarOutgoing_JoinQuit_ShowCount = register_cvar("amx_matter_bridge_outgoing_joinquit_count", "1");
    g_cvarRetry_Delay = register_cvar("amx_matter_bridge_retry_delay", "3.0");

    register_dictionary("matteramxx.txt");

    //TS doesn't support rendering % 
    if(is_running("ts"))
        register_dictionary("matteramxx_old.txt");

    register_cvar("amx_matter_bridge_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);
}

public plugin_cfg()
{
    if(get_pcvar_num(g_cvarEnabled))
    {
        new sToken[TOKEN_LENGTH];
        get_pcvar_string(g_cvarBridgeUrl, g_sBridgeUrl, charsmax(g_sBridgeUrl));
        get_pcvar_string(g_cvarToken, sToken, charsmax(sToken));
        if(get_pcvar_bool(g_cvarOutgoing))
        {
            g_gOutgoingHeader = grip_create_default_options();
            grip_options_add_header(g_gOutgoingHeader, "Content-Type", "application/json");

            get_pcvar_string(g_cvarSystemAvatarUrl, g_sSystemAvatarUrl, charsmax(g_sSystemAvatarUrl));

            if(strlen(sToken) > 0)
            {
                new sTokenHeader[JSON_PARAMETER_LENGTH];
                formatex(sTokenHeader, charsmax(sTokenHeader), "Bearer %s", sToken);
                grip_options_add_header(g_gOutgoingHeader, "Authorization", sTokenHeader);
            }

            get_pcvar_string(g_cvarBridgeGateway, g_sGateway, charsmax(g_sGateway));
            get_pcvar_string(g_cvarOutgoing_SystemUsername, g_sSystemName, charsmax(g_sSystemName));
            
            formatex(g_sOutgoingUri, charsmax(g_sOutgoingUri), "%s/api/message", g_sBridgeUrl);
            
            if(get_pcvar_bool(g_cvarOutgoing_Chat))
            {
                register_clcmd("say", "say_message");
                if(get_pcvar_bool(g_cvarOutgoing_Chat_Team))
                    register_clcmd("say_team", "say_message");
                    
                g_rAuthid_pattern = regex_compile(REGEX_STEAMID_PATTERN);
                get_pcvar_string(g_cvarAvatarUrl, g_sAvatarUrl, charsmax(g_sAvatarUrl)); 
                get_pcvar_string(g_cvarAutogenAvatarUrl, g_sAutogenAvatarUrl, charsmax(g_sAutogenAvatarUrl)); 
            }

            if(get_pcvar_bool(g_cvarOutgoing_Kills))
            {
#if USE_HAMSANDWICH > 0
                new const b_isTFC = equali(g_sGamename, "tfc"); //tag mismatch if bool:
                RegisterHam(b_isTFC ? Ham_TFC_Killed : Ham_Killed, "player", b_isTFC ? "player_killed_tfc" : "player_killed", true);
#else 
                register_event("DeathMsg", "player_killed_ev", "a");
#endif
            }
            if(get_pcvar_float(g_cvarOutgoing_Join_Delay) > 0)
                set_task(get_pcvar_float(g_cvarOutgoing_Join_Delay), "join_delay_done");
            else
            {
                if(get_pcvar_bool(g_cvarOutgoing_DisplayMap))
                {
                    new sMapName[32], sMessage[MESSAGE_LENGTH];
                    get_mapname(sMapName, charsmax(sMapName));
                    formatex(sMessage, charsmax(sMessage), "* Map changed to %s", sMapName);
                    send_message_custom(sMessage, g_sSystemName, g_sSystemAvatarUrl);
                }
                g_bJoinDelayDone = true;
            }

            if(!get_pcvar_bool(g_cvarOutgoing_Quit_IgnoreIntermission))
                register_message(SVC_INTERMISSION, "map_end");
        }
        
        if(get_pcvar_bool(g_cvarIncoming))
        {
            formatex(g_sIncomingUri, charsmax(g_sIncomingUri), "%s/api/messages", g_sBridgeUrl);
       
            g_gIncomingHeader = grip_create_default_options();

            if(strlen(sToken) > 0)
            {
                new sTokenHeader[JSON_PARAMETER_LENGTH];
                formatex(sTokenHeader, charsmax(sTokenHeader), "Bearer %s", sToken);
                grip_options_add_header(g_gIncomingHeader, "Authorization", sTokenHeader);
            }

            g_fRetryDelay = get_pcvar_float(g_cvarRetry_Delay);
            g_fQueryDelay = get_pcvar_float(g_cvarIncoming_Chat_RefreshTime);

            g_iPrintMessageForward = CreateMultiForward("matteramxx_print_message", ET_STOP, FP_STRING, FP_STRING, FP_STRING);

            set_task(g_fQueryDelay, "connect_api");
        }

        g_iPluginFlags = plugin_flags();
    }
    else
        pause("ad");
}

public plugin_end()
{
    if(grip_is_request_active(g_gripIncomingHandle))
        grip_cancel_request(g_gripIncomingHandle);
    if(grip_is_request_active(g_gripOutgoingHandle))
        grip_cancel_request(g_gripOutgoingHandle);

    DestroyForward(g_iPrintMessageForward);
}

public join_delay_done()
{
    g_bJoinDelayDone = true;
    if(get_pcvar_bool(g_cvarOutgoing_DisplayMap) && get_playersnum_ex(GetPlayers_IncludeConnecting) > 0)
    {
        new sMapName[32], sMessage[MESSAGE_LENGTH];
        get_mapname(sMapName, charsmax(sMapName));
        formatex(sMessage, charsmax(sMessage), "* Map changed to %s", sMapName);
        send_message_custom(sMessage, g_sSystemName, g_sSystemAvatarUrl);
    }
}

public map_end()
{
    g_bIsIntermission = true;
}

public connect_api()
{
    g_gripIncomingHandle = grip_request(g_sIncomingUri, Empty_GripBody, GripRequestTypeGet, "incoming_message", g_gIncomingHeader);
}

public retry_connection()
{
    server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_RETRYING", floatround(g_fRetryDelay));
    set_task(g_fRetryDelay, "connect_api");
}

public incoming_message()
{
    if(grip_get_response_state() != GripResponseStateSuccessful)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_CONN_FAILED");
        retry_connection();
    }
    new sIncomingMessage[INCOMING_BUFFER_LENGTH], sJsonError[MESSAGE_LENGTH], GripJSONValue:gJson;

    grip_get_response_body_string(sIncomingMessage, charsmax(sIncomingMessage));

    replace_all(sIncomingMessage, charsmax(sIncomingMessage), "^%", ""); 

    gJson = grip_json_parse_string(sIncomingMessage, sJsonError, charsmax(sJsonError));

    if (strlen(sJsonError) > 0)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_INVALID");
        set_task(g_fQueryDelay, "connect_api");
        return;
    }

    if(grip_json_get_type(gJson) == GripJSONObject)
    {
        new sErrorMessage[INCOMING_BUFFER_LENGTH];
        grip_json_object_get_string(gJson, "message", sErrorMessage, charsmax(sErrorMessage));
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_ERROR", sErrorMessage);
        grip_destroy_json_value(gJson);
        set_fail_state(sErrorMessage);
        return;
    }

    for(new x = 0; x < grip_json_array_get_count(gJson); x++)
    {
        new sMessageBody[MESSAGE_LENGTH], sUsername[MAX_NAME_LENGTH];
        new GripJSONValue:jCurrentMessage = grip_json_array_get_value(gJson, x);
        grip_json_object_get_string(jCurrentMessage, "text", sMessageBody, charsmax(sMessageBody));
        grip_json_object_get_string(jCurrentMessage, "username", sUsername, charsmax(sUsername));

        new sProtocol[MAX_NAME_LENGTH], sTemp[MAX_NAME_LENGTH];
        switch(get_pcvar_num(g_cvarIncoming_Chat_DisplayProtocol))
        {
            case 1:
                grip_json_object_get_string(jCurrentMessage, "protocol", sTemp, charsmax(sTemp));
            case 2:
                grip_json_object_get_string(jCurrentMessage, "label", sTemp, charsmax(sTemp));
        }
        copy(sProtocol, charsmax(sProtocol), sTemp);
        print_message(sMessageBody, sUsername, sProtocol);
        grip_destroy_json_value(jCurrentMessage);
    }

    grip_destroy_json_value(gJson);

    set_task(g_fQueryDelay, "connect_api");
}

public print_message(const sMessage[], sUsername[MAX_NAME_LENGTH], sProtocol[MAX_NAME_LENGTH])
{
    new iReturnVal = 0;
    new sMessageNew[MESSAGE_LENGTH];
    //copy(sMessageNew, MESSAGE_LENGTH, sMessage);
    ExecuteForward(g_iPrintMessageForward, iReturnVal, sMessage, sUsername, sProtocol);
    switch(iReturnVal)
    {
        case 0:
        {
            if(strlen(sUsername) == 0)
                copy(sUsername, charsmax(sUsername), g_sSystemName);
            if(strlen(sProtocol) == 0)
                copy(sProtocol, charsmax(sProtocol), g_sGamename);
            formatex(sMessageNew, charsmax(sMessageNew), (cstrike_running()) ? "^4(%s) %s^1: %s" : "(%s) %s: %s", sProtocol, sUsername, sMessage);
            server_print(sMessageNew);
            if(cstrike_running())
                client_print_color(0, print_team_red, sMessageNew);
            else
                client_print(0, print_chat, sMessageNew);
        }
        case 1:
        {
            server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_API_SUPERCEDED", sMessage);
        }
    }  
}

public say_message(id)
{
    new sMessage[MESSAGE_LENGTH], sUserName[MAX_NAME_LENGTH], sSteamId[MAX_NAME_LENGTH];
    read_args(sMessage, charsmax(sMessage));

    replace_all(sMessage, charsmax(sMessage), "^"", "");

    if(get_pcvar_bool(g_cvarOutgoing_Chat_ZeroifyAtSign))
        replace_all(sMessage, charsmax(sMessage), "@", "@​");

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX Debug] Message ^"%s^" was sent.", sMessage);

    if (strlen(sMessage) == 0 || (get_pcvar_bool(g_cvarOutgoing_Chat_SpamFil) && equal(sMessage, g_sLastMessages[id])))
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[MatterAMXX Debug] First condition of say_message returned false, returning.");
            server_print("[MatterAMXX Debug] (Message length was %i)", strlen(sMessage));
        }
        return PLUGIN_CONTINUE;
    }

    if(get_pcvar_bool(g_cvarOutgoing_Chat_SpamFil))
        g_sLastMessages[id] = sMessage;

    new GripJSONValue:gJson = grip_json_init_object();

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX Debug] Preparing gJson object.");
    
    if(id)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX Debug] id is %i.", id);
        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(id, sUserName, charsmax(sUserName));
        else
            get_user_name(id, sUserName, charsmax(sUserName));

        get_user_info(id, "*sid", sSteamId, charsmax(sSteamId));

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[MatterAMXX Debug] Fullname is %s.", sUserName);
            server_print("[MatterAMXX Debug] Steam ID is %s.", sSteamId);
        }

        if (strlen(sSteamId) > 0)
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX Debug] Steam ID is from a player.");
            new sAvatarUrlFull[TARGET_URL_LENGTH];
            if(g_bUserAuthenticated[id])
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[MatterAMXX Debug] User is authenticated.");
                if (strlen(g_sAvatarUrl) > 0)
                    formatex(sAvatarUrlFull, charsmax(sAvatarUrlFull), g_sAvatarUrl, sSteamId);
            }
            else
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[MatterAMXX Debug] User not is authenticated.");
                if (strlen(g_sAutogenAvatarUrl) > 0)
                {
                    new sEncodedName[MAX_NAME_LENGTH];
                    urlencode(sUserName, sEncodedName, charsmax(sEncodedName));
                    formatex(sAvatarUrlFull, charsmax(sAvatarUrlFull), g_sAutogenAvatarUrl, sEncodedName);
                }
            }

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX Debug] Resulting avatar URL is %s.", sAvatarUrlFull);

            if(strlen(sAvatarUrlFull) > 0)
            {
                grip_json_object_set_string(gJson, "avatar", sAvatarUrlFull);
            }
        }
        else if(strlen(g_sSystemAvatarUrl) > 0)
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX Debug] The server sent this message.");
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
        }
    }

    grip_json_object_set_string(gJson, "text", sMessage);
    grip_json_object_set_string(gJson, "username", (id) ? sUserName : g_sSystemName);

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX Debug] I'm going to send the message.");
    send_message_rest(gJson);

    return PLUGIN_CONTINUE;
}

public player_killed_ev()
{
    new idattacker = read_data(1);
    new id = read_data(2);

    player_killed(id, idattacker);
}

public player_killed_tfc(id, idinflictor, idattacker)
{
    player_killed(id, idattacker);
}

public player_killed(id, idattacker)
{
    new sUserName[MAX_NAME_LENGTH], sAttackerName[MAX_NAME_LENGTH], sMessage[MESSAGE_LENGTH];
    
    if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
        get_colorless_name(id, sUserName, charsmax(sUserName));
    else
        get_user_name(id, sUserName, charsmax(sUserName));

    if(is_user_connected(idattacker))
    {
        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(idattacker, sAttackerName, charsmax(sAttackerName));
        else
            get_user_name(idattacker, sAttackerName, charsmax(sAttackerName));
    }
    else
        pev(idattacker, pev_classname, sAttackerName, charsmax(sAttackerName));

    replace_all(sUserName, charsmax(sUserName), "^"", "");
    replace_all(sAttackerName, charsmax(sAttackerName), "^"", ""); 

    formatex(sMessage, charsmax(sMessage), "%s got killed by %s!", sUserName, sAttackerName);

    new GripJSONValue:gJson = grip_json_init_object();

    grip_json_object_set_string(gJson, "text", sMessage);
    grip_json_object_set_string(gJson, "username", g_sSystemName);
    if(strlen(g_sSystemAvatarUrl) > 0)
        grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);

    send_message_rest(gJson);
}

public send_message_custom(const sMessage[], const sUsername[], const sAvatar[])
{
    new GripJSONValue:gJson = grip_json_init_object();

    grip_json_object_set_string(gJson, "text", sMessage);
    grip_json_object_set_string(gJson, "username", strlen(sUsername) > 0 ? sUsername : g_sSystemName);
    grip_json_object_set_string(gJson, "avatar", strlen(sAvatar) > 0 ? sAvatar : g_sSystemAvatarUrl);

    send_message_rest(gJson);
}

public send_message_rest(GripJSONValue:gJson)
{
    grip_json_object_set_string(gJson, "gateway", g_sGateway);
    grip_json_object_set_string(gJson, "protocol", g_sGamename);

    new GripBody:gPayload = grip_body_from_json(gJson);

    g_gripOutgoingHandle = grip_request(g_sOutgoingUri, gPayload, GripRequestTypePost, "outgoing_message", g_gOutgoingHeader);

    grip_destroy_body(gPayload);
    grip_destroy_json_value(gJson);
}

public outgoing_message()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
    {
        server_print("[MatterAMXX Debug] I sent the message. Response State is %d", grip_get_response_state());
        new sResponse[INCOMING_BUFFER_LENGTH];
        grip_get_response_body_string(sResponse, charsmax(sResponse));
        server_print("[MatterAMXX Debug] Server said: %s", sResponse);
    }

    if(grip_get_response_state() != GripResponseStateSuccessful)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_MSG_FAILED"); //why?
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            new sIncomingMessage[MESSAGE_LENGTH];
            grip_get_response_body_string(sIncomingMessage, charsmax(sIncomingMessage));
            server_print(sIncomingMessage);
        }
    }
}

public client_authorized(id)
{
    new authid[32];
    get_user_authid(id, authid, charsmax(authid));
    if(is_valid_authid(authid))
        g_bUserAuthenticated[id] = 1;
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
    g_bUserAuthenticated[id] = 0;
    if(!g_bIsIntermission && get_pcvar_bool(g_cvarOutgoing_Quit) && !is_user_bot(id) && g_bUserConnected[id])
    {
        new sUserName[MAX_NAME_LENGTH], sMessage[MESSAGE_LENGTH];
        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(id, sUserName, charsmax(sUserName));
        else
            get_user_name(id, sUserName, charsmax(sUserName));
        replace_all(sUserName, charsmax(sUserName), "^"", "");

        if(get_pcvar_bool(g_cvarOutgoing_JoinQuit_ShowCount))
            formatex(sMessage, charsmax(sMessage), "%s has left the game. [%d/%d]", sUserName, get_playersnum_ex(GetPlayers_ExcludeBots)-1, get_maxplayers());
        else
            formatex(sMessage, charsmax(sMessage), "%s has left the game.", sUserName);
        g_bUserConnected[id] = false;
        
        new GripJSONValue:gJson = grip_json_init_object();
        grip_json_object_set_string(gJson, "text", sMessage);
        grip_json_object_set_string(gJson, "username", g_sSystemName);
        if(strlen(g_sSystemAvatarUrl) > 0)
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);

        send_message_rest(gJson);
    }
}

public client_putinserver(id)
{
    if(g_bJoinDelayDone && get_pcvar_bool(g_cvarOutgoing_Join) && !is_user_bot(id))
    {
        new sUserName[MAX_NAME_LENGTH], sMessage[MESSAGE_LENGTH];

        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(id, sUserName, charsmax(sUserName));
        else
            get_user_name(id, sUserName, charsmax(sUserName));

        replace_all(sUserName, charsmax(sUserName), "^"", "");

        if(get_pcvar_bool(g_cvarOutgoing_JoinQuit_ShowCount))
            formatex(sMessage, charsmax(sMessage), "%s joined the game. [%d/%d]", sUserName, get_playersnum_ex(GetPlayers_ExcludeBots), get_maxplayers());
        else
            formatex(sMessage, charsmax(sMessage), "%s joined the game.", sUserName);
        
        g_bUserConnected[id] = true;
        g_sLastMessages[id] = "";
        
        new GripJSONValue:gJson = grip_json_init_object();
        grip_json_object_set_string(gJson, "text", sMessage);
        grip_json_object_set_string(gJson, "username", g_sSystemName);
        if(strlen(g_sSystemAvatarUrl) > 0)
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);

        send_message_rest(gJson);
    }
}

//thanks to YaLTeR
stock get_colorless_name(id, name[], len)
{
	get_user_name(id, name, len);

	// Clear out color codes
	new i, j;
	new const hat[3] = "^^";
	while (name[i])
	{
		if (name[i] == hat[0] && name[i + 1] >= '0' && name[i + 1] <= '9')
		{
			i++;
		}
		else
		{
			if (j != i)
				name[j] = name[i];
			j++;
		}
		i++;
	}
	name[j] = 0;
}

//thanks to Th3-822
stock urlencode(const sString[], sResult[], len)
{
    new from, c, to;

    while (from < len)
    {
        c = sString[from++];
        if (c == 0)
        {
            sResult[to++] = c;
            break;
        }
        else if (c == ' ')
        {
            sResult[to++] = '_';
        }
        else if (!(0 <= c <= 255))
        { // UTF-8 Fix (Doesn't encode put .)
            sResult[to++] = '_';
        }
        else if ((c < '0' && c != '-' && c != '.') ||
                (c < 'A' && c > '9') ||
                (c > 'Z' && c < 'a' && c != '_') ||
                (c > 'z'))
        {
            if ((to + 3) > len)
            {
                sResult[to] = 0;
                break;
            }
            // UTF-8 Fix - Need to check real c values.
            /* if (c < 0) c = 256 + c; */
            sResult[to++] = '_';
            sResult[to++] = sHexTable[c >> 4];
            sResult[to++] = sHexTable[c & 15];
        }
        else
        {
            sResult[to++] = c;
        }
    }
}

stock is_valid_authid(authid[]) 
{
    return regex_match_c(authid, g_rAuthid_pattern) > 0;
}