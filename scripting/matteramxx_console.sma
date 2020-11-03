#include <amxmodx>
#include <amxmisc>
#include <orpheu>
#include <matteramxx>
#include <celltrie>
#include <cellarray>
#include <regex>

#define MATTERAMXX_CONSOLE_OBEY_FILE "matteramxx_rcon_accounts.ini"

#define SERVER_RESPONSE_LENGTH 5120

#define CVARLIST_TRIES 6 //cannot be more than 6, inclusive, starts from 0

#define IP_REGEX "((?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){2})((?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]))"

#define CVARQUERY_FORMAT "^"%s^" is ^"%s^"^n"
#define STATS_FORMAT "CPU   In    Out   Uptime  Users   FPS    Players^n%s^n"

#define MATTERAMXX_PLUGIN_NAME "MatterAMXX RCON"
#define MATTERAMXX_PLUGIN_AUTHOR "Gabe Iggy"
#define MATTERAMXX_PLUGIN_VERSION "1.5"

#pragma semicolon 1

new g_iPluginFlags;

new g_cvarEnabled;
new g_cvarDontIgnoreObeyTo;
new g_cvarPrefix;
new g_cvarHideCvars;
new g_cvarHideIPs;
new g_cvarCodeBlock;

new g_sResponseMessage[SERVER_RESPONSE_LENGTH];
new g_iProtectedArraySize = 0;

new Trie:g_iTrieObeyTo;
new Array:g_iProtectedCvars;

new Regex:g_rPattern;

new OrpheuHook:g_iHandlePrintf;

new const g_sDangerousCommands[][] = { 
        "cmdlist",      //server crashes
        "cvarlist",     //server crashes
        "amxx cvars",   //string truncates, plugin crashes
        "amxx cmds",    //string truncates, plugin crashes
        "amxx list",    //string may truncate, plugin crashes
        "meta cvars",   //string truncates, plugin crashes
        "meta cmds",    //string truncates, plugin crashes
        "meta list",    //string may truncate, plugin crashes
        "changelevel",  //server crashes
        "restart",      //server crashes
        "quit",         //server crashes
        "map",          //server crashes
        "version"       //server crashes
    };

public plugin_init()
{
    register_plugin(MATTERAMXX_PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_matter_rcon_enable", "1");
    g_cvarDontIgnoreObeyTo = register_cvar("amx_matter_rcon_dont_ignore_list", "1"); //DANGEROUS!!
    g_cvarPrefix = register_cvar("amx_matter_rcon_prefix", "!rcon ");
    g_cvarHideCvars = register_cvar("amx_matter_rcon_hide_cvars", "1");
    g_cvarHideIPs = register_cvar("amx_matter_rcon_hide_ips", "1");
    g_cvarCodeBlock = register_cvar("amx_matter_rcon_code_block", "1");

    register_dictionary("admincmd.txt");
    register_dictionary("matteramxx.txt");

    register_cvar("amx_matter_rcon_bridge_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);
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
                server_print("[MatterAMXX RCON Debug] Plugin is enabled.");

            if(get_pcvar_bool(g_cvarDontIgnoreObeyTo))
            {
                g_iTrieObeyTo = TrieCreate();

                new sFilename[128];
                new sConfigDir[64];
                get_configsdir(sConfigDir, charsmax(sConfigDir));
                formatex(sFilename, charsmax(sFilename), "%s/%s", sConfigDir, MATTERAMXX_CONSOLE_OBEY_FILE);
                if(!load_masters(sFilename))
                    set_fail_state("Unable to open Master Accounts file.");
            }

            if(get_pcvar_bool(g_cvarHideCvars))
            {
                g_iProtectedCvars = ArrayCreate(64);
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[MatterAMXX RCON Debug] Creating array with size %d.", ArraySize(g_iProtectedCvars));
                server_cmd("cvarlist log");
                server_exec();

                // some games, like ricochet, start from cvarlist01.txt instead of cvarlist00.txt, we need to retry until we get the correct file
                new sFilename[16];
                new x = 0;
                formatex(sFilename, charsmax(sFilename), "cvarlist0%d.txt", x);
                while(!file_exists(sFilename) && x <= CVARLIST_TRIES)
                    formatex(sFilename, charsmax(sFilename), "cvarlist0%d.txt", ++x);
                read_cvars(sFilename);
                unlink(sFilename);
            }

            if(get_pcvar_bool(g_cvarHideIPs))
                g_rPattern = regex_compile_ex(IP_REGEX);

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX RCON Debug] Finished plugin_cfg()");
        }
        else
            set_fail_state("This plugin requires MatterAMXX to be loaded.");
    }
    else
        pause("ad");
}

public plugin_end()
{
    OrpheuUnregisterHook(g_iHandlePrintf);
    TrieDestroy(g_iTrieObeyTo);
    ArrayDestroy(g_iProtectedCvars);
}

public bool:load_masters(const filePath[])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Trying to read file %s", filePath);
    static file, sUsername[32], sProtocol[32], line[100], iCnt;
    if((file = fopen(filePath, "r")))
    {
        iCnt = 0;
        while (!feof(file))
        {
            fgets(file, line, charsmax(line));
            trim(line);

            if (line[0] && line[0] != ';')
            {
                split(line, sUsername, charsmax(sUsername), sProtocol, charsmax(sProtocol), "§");
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[MatterAMXX RCON Debug] Found master: %s (%s)", sUsername, sProtocol);
                TrieSetString(g_iTrieObeyTo, sUsername, sProtocol);
                iCnt++;
            }
        }
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX RCON Debug] Loaded %d master accounts.", iCnt);
        fclose(file);
        return true;
    }
    else 
    {
        log_amx("[MatterAMXX RCON] Can't open master accounts file.");
        return false;
    }
}

public bool:read_cvars(const filePath[])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Trying to read file %s", filePath);
    static file, line[100];
    if((file = fopen(filePath, "r")))
    {
        while (!feof(file))
        {
            fgets(file, line, charsmax(line));
            trim(line);

            if(line[0])
            {
                new sCvar[64];
                split_string(line, " ", sCvar, charsmax(sCvar));
                new iCvarPointer = get_cvar_pointer(sCvar);
                if(iCvarPointer != 0 && get_pcvar_flags(iCvarPointer) & FCVAR_PROTECTED)
                {
                    if(g_iPluginFlags & AMX_FLAG_DEBUG)
                        server_print("[MatterAMXX RCON Debug] Found a protected cvar: %s", sCvar);
                    ArrayPushString(g_iProtectedCvars, sCvar);
                }
            }
        }

        g_iProtectedArraySize = ArraySize(g_iProtectedCvars);
        fclose(file);
        return true;
    }
    else 
    {
        log_amx("[MatterAMXX RCON] Can't open cvarlist file.");
        return false;
    }
}

public matteramxx_print_message(message[MESSAGE_LENGTH], username[MAX_NAME_LENGTH], protocol[MAX_NAME_LENGTH], userid[MAX_NAME_LENGTH])
{
    if(equali(protocol, "api"))
        return MATTER_IGNORE; //we should not catch commands coming from any game server or integration
    
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Message arrived %s", message);
    trim(message);
    new sPrefix[32];
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Comparing if it has the prefix %s", sPrefix);
    if(equal(message, sPrefix, get_pcvar_string(g_cvarPrefix, sPrefix, charsmax(sPrefix))))
    {
        g_sResponseMessage = get_pcvar_bool(g_cvarCodeBlock) ? "```" : "";
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX RCON Debug] It is a valid prefix, checking if user is authorized.");

        new sTrieProtocol[MAX_NAME_LENGTH];
        if(!get_pcvar_bool(g_cvarDontIgnoreObeyTo) || (TrieGetString(g_iTrieObeyTo, userid, sTrieProtocol, charsmax(sTrieProtocol)) && equali(sTrieProtocol, protocol)))
        {
            replace_all(message, charsmax(message), sPrefix, "");
            trim(message);
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX RCON Debug] I'm setting the hook and executing %s on the game console.", message);

            if(containi(message,";") != -1) //command injection
                return reject_command(message);

            for(new i; i < sizeof g_sDangerousCommands; i++)
            {
                if(containi(message, g_sDangerousCommands[i]) == 0)
                    return reject_command(message);
            }

            g_iHandlePrintf = OrpheuRegisterHook(OrpheuGetFunction("Con_Printf"), "rcon_response");
            server_cmd(message);
            server_exec();
            OrpheuUnregisterHook(g_iHandlePrintf);

            if(get_pcvar_bool(g_cvarHideCvars))
                hide_protected(g_sResponseMessage, charsmax(g_sResponseMessage));

            if(get_pcvar_bool(g_cvarHideIPs))
                regex_replace(g_rPattern, g_sResponseMessage, charsmax(g_sResponseMessage), "$1XXX.XXX");

            if(get_pcvar_bool(g_cvarCodeBlock))
                add(g_sResponseMessage, charsmax(g_sResponseMessage), "```");
            else
                replace_all(g_sResponseMessage, charsmax(g_sResponseMessage), "^"", "\^"");
                
            matteramxx_send_message(g_sResponseMessage, _, _, true);
        }
        else
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX RCON Debug] %s (%s)'s (ID:%s) command got rejected.", username, userid, protocol);
            formatex(g_sResponseMessage, charsmax(g_sResponseMessage), "* %L", LANG_SERVER, random(101) > 99 ? "MATTERAMXX_PLUGIN_RCON_UNAUTHORIZED" : "MATTERAMXX_PLUGIN_RCON_HAL", username);
            matteramxx_send_message(g_sResponseMessage, _, _, true);
        }
        return MATTER_SUPERCEDE;
    }
    return MATTER_IGNORE;
}

public reject_command(const message[])
{
    formatex(g_sResponseMessage, charsmax(g_sResponseMessage), "* %L", LANG_SERVER, "MATTERAMXX_PLUGIN_RCON_NO_OUTPUT");
    matteramxx_send_message(g_sResponseMessage, _, _, true);
    server_cmd(message);
    return MATTER_SUPERCEDE;
}


public OrpheuHookReturn:rcon_response(const format[], const message[])
{
    // we need to unhook on each print to avoid a severe hook loop on error or debug
    OrpheuUnregisterHook(g_iHandlePrintf);

    // orpheu/pawn doesn't support variadic values so we have to improvise
    if(equal(CVARQUERY_FORMAT, format))
    {
        new cvarValue[64], message2[128];
        get_cvar_string(message, cvarValue, charsmax(cvarValue));
        formatex(message2, charsmax(message2), format, message, cvarValue);
        add(g_sResponseMessage, charsmax(g_sResponseMessage), message2);
    }
    else if(equal(STATS_FORMAT, format))
    {
        new message2[512];
        formatex(message2, charsmax(message2), format, message);
        add(g_sResponseMessage, charsmax(g_sResponseMessage), message2);
    }
    else
        add(g_sResponseMessage, charsmax(g_sResponseMessage), message);

    g_iHandlePrintf = OrpheuRegisterHook(OrpheuGetFunction("Con_Printf"), "rcon_response");
    return OrpheuSupercede;
}

public hide_protected(string[], size)
{
    for(new x=0; x < g_iProtectedArraySize;x++)
    {
        new sCvar[64];
        ArrayGetString(g_iProtectedCvars, x, sCvar, charsmax(sCvar));
        if(containi(string, sCvar) > -1)
        {
            // cvar found, that means the value should (not always) be output
            new sCvarValue[128]; 
            if(get_pcvar_string(get_cvar_pointer(sCvar), sCvarValue, charsmax(sCvarValue)) > 0)
            {
                new sProtected[32];
                formatex(sProtected, charsmax(sProtected), get_pcvar_bool(g_cvarCodeBlock) ? "*** %L ***" : "\*\*\* %L \*\*\*", LANG_SERVER, "PROTECTED");
                replace_all(string, size, sCvarValue, sProtected);
            }
        }
    }
}