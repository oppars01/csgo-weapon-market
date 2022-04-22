#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <csgoturkiye>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "Weapon Market", 
	author = "oppa", 
	description = "It is used to return purchased weapons and get their money.", 
	version = "1.0", 
	url = "csgo-turkiye.com"
};

ConVar cv_time = null, cv_rate = null, cv_type = null, cv_zone = null, cv_bans = null;
int i_time, i_type, i_round_start;
float f_rate;
bool b_zone;
char s_bans[512];


public void OnPluginStart(){
	LoadTranslations("csgotr_weapon_market.phrases.txt");
	cv_time = CreateConVar("cv_weapon_market_time", "0", "Indicates for how many seconds there can be a sale of weapons.\n-1 : Infinite\n0 : During the weapon purchase period(buytime).\n1>= : For the specified seconds.");
	cv_rate = CreateConVar("cv_weapon_market_rate", "0.5", "Rate of sale relative to the original price of the gun.", 0, true, 0.0, true, 1.0);	
	cv_type = CreateConVar("cv_weapon_market_type", "2", "What weapons can be sold.\n0 : All\n1 : Team\n2 : Just Your Own Weapon", 0, true, 0.0, true, 2.0);
	cv_zone = CreateConVar("cv_weapon_market_zone", "1", "To be used only in the purchasing region(buyzone).\n0 : Close\n1 : Open", 0, true, 0.0, true, 1.0);
	cv_bans = CreateConVar("cv_weapon_market_bans", "", "You can write the weapons that are prohibited for sale by putting a space between them. You don't need to type 'weapon_' or 'item_'. For example, for 'weapon_awp2 type 'awp'.");	
	AutoExecConfig(true, "weapon_market", "CSGO_Turkiye");
	CvarLoad();
	RegConsoleCmd("sm_weaponmarket", WeaponMarket, "The player opens the weapon sale menu.");
	HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart(){
    CvarLoad();
}

public void CvarLoad(){
	i_time = GetConVarInt(cv_time);
	f_rate = GetConVarFloat(cv_rate);
	i_type = GetConVarInt(cv_type);
	b_zone = GetConVarBool(cv_zone);
	GetConVarString(cv_bans, s_bans, sizeof(s_bans));
	i_round_start = GetTime();
	HookConVarChange(cv_time, OnCvarChanged);
	HookConVarChange(cv_rate, OnCvarChanged);
	HookConVarChange(cv_type, OnCvarChanged); 
	HookConVarChange(cv_zone, OnCvarChanged);
	HookConVarChange(cv_bans, OnCvarChanged);
}

public void OnCvarChanged(Handle convar, const char[] oldVal, const char[] newVal){
	if(convar == cv_time) i_time = GetConVarInt(convar);
	else if(convar == cv_rate) f_rate = GetConVarFloat(convar);
	else if(convar == cv_type) i_type = GetConVarInt(convar);
	else if(convar == cv_zone) b_zone = GetConVarBool(convar);
	else if(convar == cv_bans) GetConVarString(convar, s_bans, sizeof(s_bans));
}

public void Event_RoundStart(Handle event, const char[] Name, bool dontbroadcast){
	i_round_start = GetTime();
}

public Action WeaponMarket(int client,int args){
	if(ClientControl(client)){
		bool b_status = false;
		char s_temp[255];
		Menu menu = new Menu(WeaponMarketMainMenuCallbach);
		menu.SetTitle("%t", "Weapon Market Main Menu Title");
		for(int i = 0; i <= 5; i++){
			int i_weapon = GetPlayerWeaponSlot(client, i);
			if (i_weapon != -1 && IsValidEntity(i_weapon)){
				char s_class_name[64];
				GetEntityClassname(i_weapon, s_class_name, sizeof(s_class_name));
				if(BanQuery(s_class_name)){
					int i_owner = Steam32IDToClient(GetEntProp(i_weapon, Prop_Send, "m_OriginalOwnerXuidLow"));
					if( i_type == 0 || (i_owner != -1 && (i_type == 0 || i_owner == client || (i_type == 1 && (GetClientTeam(client) == GetClientTeam(i_owner)))))){
						int i_real_price = CS_GetWeaponPrice(client, CS_AliasToWeaponID(s_class_name), true);
						if(i_real_price > 0){
							b_status = true;
							int i_offer = RoundToFloor( i_real_price * f_rate);
							if(i_offer < 1) i_offer = 1;
							if(i_offer > i_real_price) i_offer = i_real_price;
							ReplaceString(s_class_name, sizeof(s_class_name), "weapon_", "");
							ReplaceString(s_class_name, sizeof(s_class_name), "item_", "");
							for(int j = 0; j <= strlen(s_class_name); j++) s_class_name[j] = CharToUpper(s_class_name[j]);
							Format(s_temp, sizeof(s_temp), "%t", "Weapon Market Main Menu Item" , s_class_name, i_real_price, i_offer);
							IntToString(i_weapon, s_class_name, sizeof(s_class_name));
							menu.AddItem(s_class_name, s_temp);
						}					
					}	
				}
			}
		}
		if(b_status == false){
			Format(s_temp, sizeof(s_temp), "%t", "Empty Weapon Market Main Menu"); 
			menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
		}
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int WeaponMarketMainMenuCallbach(Menu menu, MenuAction action, int client, int param2){
    if (action == MenuAction_Select){
        if(ClientControl(client)){
			char s_weapon_id[32];
			menu.GetItem(param2, s_weapon_id, sizeof(s_weapon_id));
			int i_weapon = StringToInt(s_weapon_id);
			if (i_weapon != -1 && IsValidEntity(i_weapon)){
				if(SlotControl(client, i_weapon)){
					char s_class_name[64];
					GetEntityClassname(i_weapon, s_class_name, sizeof(s_class_name));
					if(BanQuery(s_class_name)){
						int i_owner = Steam32IDToClient(GetEntProp(i_weapon, Prop_Send, "m_OriginalOwnerXuidLow"));
						if( i_type == 0 || (i_owner != -1 && (i_owner == client || (i_type == 1 && (GetClientTeam(client) == GetClientTeam(i_owner)))))){
							int i_real_price = CS_GetWeaponPrice(client, CS_AliasToWeaponID(s_class_name), true);
							if(i_real_price > 0){
								int i_offer = RoundToFloor( i_real_price * f_rate);
								if(i_offer < 1) i_offer = 1;
								if(i_offer > i_real_price) i_offer = i_real_price;
								ReplaceString(s_class_name, sizeof(s_class_name), "weapon_", "");
								ReplaceString(s_class_name, sizeof(s_class_name), "item_", "");
								for(int i = 0; i <= strlen(s_class_name); i++)s_class_name[i] = CharToUpper(s_class_name[i]);
								int i_max_money = FindConVar("mp_maxmoney").IntValue;
								int i_client_money = GetEntProp(client, Prop_Send, "m_iAccount");
								int i_new_money = i_client_money + i_offer;
								SetEntProp(client, Prop_Send, "m_iAccount", (i_new_money >= i_max_money ? i_max_money : i_new_money));
								RemovePlayerItem(client, i_weapon);
								RemoveEdict(i_weapon);							
								CPrintToChat(client, "%t", "Weapon Market Succes", s_class_name, i_real_price, i_offer);
								if(i_new_money >= i_max_money) CPrintToChat(client, "%t", "Max Money Info");
							} else CPrintToChat(client, "%t", "Real Price Message");
						} else CPrintToChat(client, "%t", (i_type == 1 ? "Type Message 1" : "Type Message 2"));
					} else CPrintToChat(client, "%t", "Ban Message");
				}else CPrintToChat(client, "%t", "Slot Message");
			}
		}
    }
    else if (action == MenuAction_End) delete menu;
}

public bool ClientControl(int client){
	bool b_client = false;
	if(client != 0){
		if(IsValidClient(client)){
			if(IsPlayerAlive(client)){
				if (GetClientTeam(client) > 1){
					if(i_time == -1 || (i_time == 0 && GetTime() < i_round_start + FindConVar("mp_buytime").IntValue) || GetTime() < i_round_start + i_time){
						if(!b_zone || GetEntProp(client, Prop_Send, "m_bInBuyZone")) b_client = true;
						else CPrintToChat(client, "%t", "Zone Message");
					}else CPrintToChat(client, "%t", "Time Message", (i_time == 0 ? FindConVar("mp_buytime").IntValue : i_time));
				}else CPrintToChat(client, "%t", "Team Message");
			}else CPrintToChat(client, "%t", "Alive Message");
		}
	}else PrintToServer("%t", "Console Message");
	return b_client;
}

public int Steam32IDToClient(int steam_32_id){
	if(steam_32_id > 0)
		for(int client = 1; client <= MaxClients; client++)
			if(IsValidClient(client))
				if(steam_32_id == GetSteamAccountID(client)) return client;
	return -1;
}

public bool BanQuery(char class_name[64]){
	ReplaceString(class_name, sizeof(class_name), "weapon_", "");
	ReplaceString(class_name, sizeof(class_name), "item_", "");
	if(StrContains(class_name, s_bans) >= 0 ) return true;
	return false; 
}

public bool SlotControl(int client, int weapon){
	for(int i = 0; i <= 5; i++){
		int i_weapon = GetPlayerWeaponSlot(client, i);
		if (i_weapon != -1 && IsValidEntity(i_weapon) && i_weapon == weapon) return true;
	}	
	return false;
}