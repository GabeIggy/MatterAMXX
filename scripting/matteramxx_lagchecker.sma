#include <amxmodx>
#include <orpheu>
#include <matteramxx>

#define MATTERAMXX_PLUGIN_PLUGIN "MatterAMXX Lag Checker"
#define MATTERAMXX_PLUGIN_AUTHOR "Gabe Iggy"
#define MATTERAMXX_PLUGIN_VERSION "1.5"

#pragma semicolon 1

new g_cvarEnabled;
new g_cvarCpuThreshold;
new g_cvarFpsThreshold;
new g_cvarToPing;
new g_sStats[MESSAGE_LENGTH];

new g_iPluginFlags;
new g_bRestartScheduled = false;

public plugin_init()
{
    register_plugin(MATTERAMXX_PLUGIN_PLUGIN, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    register_clcmd("say", "say_message");
    register_clcmd("say_team", "say_message");

    g_cvarEnabled = register_cvar("amx_matter_lagchecker_enabled", "1");
    g_cvarToPing = register_cvar("amx_matter_lagchecker_ping_this_person", "");
    g_cvarCpuThreshold = register_cvar("amx_matter_lagchecker_cpu_threshold", "75");
    g_cvarFpsThreshold = register_cvar("amx_matter_lagchecker_fps_threshold", "30");

    register_dictionary("matteramxx.txt");
}

public plugin_cfg()
{
    if(get_pcvar_num(g_cvarEnabled))
    {
        new iMasterPluginIndex = is_plugin_loaded("MatterAMXX");
        if(iMasterPluginIndex > -1)
        {
            g_iPluginFlags = plugin_flags();
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
            {
                server_print("[MatterAMXX Lag Checker Debug] Plugin is enabled.");
                server_print("[MatterAMXX Lag Checker Debug] Finished plugin_cfg()");
            }
        }
        else
            set_fail_state("This plugin requires MatterAMXX to be loaded.");
    }
    else
        pause("ad");
}

public say_message(id)
{
    new sMessage[MESSAGE_LENGTH];
    read_args(sMessage, charsmax(sMessage));

    if (strlen(sMessage) == 0)
        return PLUGIN_CONTINUE;

    if(id)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX Lag Checker Debug] Message is: %s", sMessage);

        if(containi(sMessage, "lag") != -1)
        {
            if(g_bRestartScheduled)
                client_print(0, print_chat, "* %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_RESTART_SCHEDULE");
            else
                set_task(2.0, "execute_lag"); //fixes SZ_GetSpace: tried to write to an uninitialized sizebuf_t: ???
        }
    }

    return PLUGIN_CONTINUE;
}

public execute_lag()
{
    g_sStats = "";
    new OrpheuHook:handlePrintf = OrpheuRegisterHook(OrpheuGetFunction("Con_Printf"), "Con_Printf");

    server_cmd("stats");
    server_exec();
    
    OrpheuUnregisterHook(handlePrintf);

    const tokensN  = 7;
    const tokenLen = 19;
    
    static tokens[tokensN][tokenLen + 1];

    for (new i = 0; i < tokensN; i++)
    {
        trim(g_sStats);
        strtok(g_sStats, tokens[i], tokenLen, g_sStats, charsmax( g_sStats ), ' '); 
    }

    new Float:cpu = str_to_float(tokens[0]);
    new Float:fps = str_to_float(tokens[5]);

    new Float:ideal_sys_ticrate = get_cvar_num("sys_ticrate")*0.90;
    server_print("[MatterAMXX Lag Checker Debug] Ideal ticrate is: %s", floatround(ideal_sys_ticrate));
    new fps_percent = floatround((fps/ideal_sys_ticrate)*100);

    server_print("[MatterAMXX Lag Checker Debug] Server is running at %s%% of desired cpu", fps_percent);

    new s_matterMessage[MESSAGE_LENGTH];

    if(floatround(cpu) > get_pcvar_num(g_cvarCpuThreshold) || fps_percent < get_pcvar_num(g_cvarFpsThreshold))
    {
        client_print(0, print_chat, "* %L %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(cpu), floatround(fps), LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_RESTART_SCHEDULE");
        new s_toPing[MAX_NAME_LENGTH];
        get_pcvar_string(g_cvarToPing, s_toPing, charsmax(s_toPing));
        formatex(s_matterMessage, charsmax(s_matterMessage), "%s %L %L", s_toPing, LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(cpu), floatround(fps), LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_NOTIF");
        matteramxx_send_message(s_matterMessage, _, _, true);
        register_message(SVC_INTERMISSION, "map_end");
        g_bRestartScheduled = true;
    }
    else
    {
        formatex(s_matterMessage, charsmax(s_matterMessage), "* %L", LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(cpu), floatround(fps));
        client_print(0, print_chat, "* %L %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(cpu), floatround(fps), LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STFU");
        matteramxx_send_message(s_matterMessage, _, _, true);
    }
}

public OrpheuHookReturn:Con_Printf(const a[], const message[])
{
    copy(g_sStats, charsmax(g_sStats), message);
    return OrpheuSupercede;
}

public map_end()
{
    server_cmd("quit");
    server_exec();
}