/////////////////////////////////////////////////////////////////////////////
// Script made by CzechMate
// https://steamcommunity.com/id/CzechMateID/
/////////////////////////////////////////////////////////////////////////////

// Path to custom jack model,
// model REQUIRES a bone named "weapon_bone"
// in order to be displayed correctly
local CUSTOM_JACK_MODEL = "models/passtime/ball/passtime_ball_skull.mdl"

// Alternative world model to be displayed,
// leave null or "" to use the same model
// as CUSTOM_JACK_MODEL
local JACK_MODEL_ALT = "models/props_mvm/mvm_human_skull.mdl"

// Scale of the model
local JACK_MODEL_SCALE = 1.3

// Don't change anything below this line
/////////////////////////////////////////////////////////////////////////////

PrecacheModel(CUSTOM_JACK_MODEL)
JackModelIndex <- GetModelIndex(CUSTOM_JACK_MODEL)
PASS_TIME_JACK <- null
MAX_WEAPONS <- 8

if (JACK_MODEL_ALT == null || JACK_MODEL_ALT == "")
{
	JACK_MODEL_ALT = CUSTOM_JACK_MODEL
	PrecacheModel(JACK_MODEL_ALT)
}

function jack_think()
{
	// As far I am aware, there can be only
	// one working passtime_ball entity at a time
	local passtime_ball = Entities.FindByClassname(null, "passtime_ball")
	if (passtime_ball == null || !passtime_ball.IsValid())
		return
	
	if (PASS_TIME_JACK != null && PASS_TIME_JACK.IsValid())
	{
		local scope = passtime_ball.GetScriptScope()
		local ball_prop = scope.ball_prop
		if (ball_prop == null || !ball_prop.IsValid())
			return

		if (NetProps.GetPropInt(passtime_ball, "m_iCollisionCount") == 0)
			ball_prop.SetForwardVector(passtime_ball.GetAbsVelocity())
		else
			ball_prop.SetAbsAngles(passtime_ball.GetAbsAngles())
	} 
	else 
	{
		passtime_ball.ValidateScriptScope()
		local scope = passtime_ball.GetScriptScope()

		passtime_ball.SetModelScale(JACK_MODEL_SCALE, 0.0)
		passtime_ball.SetModelSimple(JACK_MODEL_ALT)
		hideModel(passtime_ball)

		local ball_prop = SpawnEntityFromTable("prop_dynamic",
		{
			model = JACK_MODEL_ALT,
			modelscale = JACK_MODEL_SCALE,
			origin = passtime_ball.GetOrigin(),
		})

		ball_prop.AcceptInput("SetParent", "!activator", passtime_ball, passtime_ball)

		scope.ball_prop <- ball_prop
		PASS_TIME_JACK = passtime_ball
	}

	return -1
}

function CollectEventsInScope(events)
{
	local events_id = UniqueString()
	getroottable()[events_id] <- events
	local events_table = getroottable()[events_id]
	foreach (name, callback in events) events_table[name] = callback.bindenv(this)
	local cleanup_user_func, cleanup_event = "OnGameEvent_scorestats_accumulated_update"
	if (cleanup_event in events) cleanup_user_func = events[cleanup_event].bindenv(this)
	events_table[cleanup_event] <- function(params)
	{
		if (cleanup_user_func) cleanup_user_func(params)
		delete getroottable()[events_id]
	} __CollectGameEventCallbacks(events_table)
}

CollectEventsInScope
({
	OnGameEvent_post_inventory_application = function(params)
	{
		local player = GetPlayerFromUserID(params.userid)
		if (player == null || !player.IsValid())
			return
		
		if (!player.IsEFlagSet(1048576)) // EFL_IS_BEING_LIFTED_BY_BARNACLE
		{
			player.ValidateScriptScope()
			local scope = player.GetScriptScope()
			scope.fpWearable <- null
			scope.tpWearable <- null
			scope.gun <- null

			player.AddEFlags(1048576)
		}

		local scope = player.GetScriptScope()
		local wearable = scope.fpWearable
		if (wearable != null && wearable.IsValid())
			wearable.Destroy()
		wearable = scope.tpWearable
		if (wearable != null && wearable.IsValid())
			wearable.Destroy()

		for (local i = 0; i < MAX_WEAPONS; i++)
		{
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null)
				continue
			if (weapon.GetClassname() == "tf_weapon_passtime_gun")
				scope.gun <- weapon
		}

		local weapon = scope.gun
		NetProps.SetPropBool(weapon, "m_bBeingRepurposedForTaunt", true)
		for (local i = 0; i < 4; i++)
  			NetProps.SetPropIntArray(weapon, "m_nModelIndexOverrides", JackModelIndex, i)

		setWorldModel(player, JackModelIndex)
		setViewdModel(player, CUSTOM_JACK_MODEL)

		scope.fpWearable.DisableDraw()
		scope.tpWearable.DisableDraw()
	}

	// When a player gets a neutral ball
	OnGameEvent_pass_get = function(params)
	{
		local player = EntIndexToHScript(params.owner)
		if (player == null || !player.IsValid())
			return
		
		local scope = player.GetScriptScope()
		scope.fpWearable.EnableDraw()
		scope.tpWearable.EnableDraw()

		local ball_prop = PASS_TIME_JACK.GetScriptScope().ball_prop
		if (ball_prop != null || ball_prop.IsValid())
			hideModel(ball_prop)
	}

	// When a player looses the ball
	OnGameEvent_pass_free = function(params)
	{
		local player = EntIndexToHScript(params.owner)
		if (player == null || !player.IsValid())
			return

		local scope = player.GetScriptScope()
		scope.fpWearable.DisableDraw()
		scope.tpWearable.DisableDraw()

		local ball_prop = PASS_TIME_JACK.GetScriptScope().ball_prop
		if (ball_prop != null || ball_prop.IsValid())
			showModel(ball_prop)
	}

	// When a player catches the ball that was thrown by another player
	OnGameEvent_pass_pass_caught = function(params)
	{
		local player_catcher = PlayerInstanceFromIndex(params.catcher)
		local player_passer = PlayerInstanceFromIndex(params.passer)

		if (player_catcher == null || !player_catcher.IsValid())
			return
		if (player_passer == null || !player_passer.IsValid())
			return

		local scope = player_catcher.GetScriptScope()
		scope.fpWearable.EnableDraw()
		scope.tpWearable.EnableDraw()

		local ball_prop = PASS_TIME_JACK.GetScriptScope().ball_prop
		if (ball_prop != null || ball_prop.IsValid())
			hideModel(ball_prop)
	}

	// When a player melee steals the ball from another player
	OnGameEvent_pass_ball_stolen = function(params)
	{
		local player_attacker = EntIndexToHScript(params.attacker)
		local player_victim = EntIndexToHScript(params.victim)
		if (player_victim == null || !player_victim.IsValid())
			return
		if (player_attacker == null || !player_attacker.IsValid())
			return

		local scope = player_attacker.GetScriptScope()
		scope.fpWearable.EnableDraw()
		scope.tpWearable.EnableDraw()

		local ball_prop = PASS_TIME_JACK.GetScriptScope().ball_prop
		if (ball_prop != null || ball_prop.IsValid())
			hideModel(ball_prop)
	}
})

function setWorldModel(entity, modelIndex)
{
	local scope = entity.GetScriptScope()
	local tpWearable = Entities.CreateByClassname("tf_wearable")
	tpWearable.Teleport(true, entity.GetOrigin(), true, entity.GetAbsAngles(), false, Vector())
	NetProps.SetPropInt(tpWearable, "m_nModelIndex", JackModelIndex)
	NetProps.SetPropBool(tpWearable, "m_bValidatedAttachedEntity", true)
	NetProps.SetPropBool(tpWearable, "m_AttributeManager.m_Item.m_bInitialized", true)
	NetProps.SetPropEntity(tpWearable, "m_hOwnerEntity", entity)
	tpWearable.SetOwner(entity)
	for (local i = 0; i < 4; i++)
		NetProps.SetPropIntArray(tpWearable, "m_nModelIndexOverrides", JackModelIndex, i)
	tpWearable.DispatchSpawn()
	EntFireByHandle(tpWearable, "SetParent", "!activator", 0.0, entity, entity)
	NetProps.SetPropInt(tpWearable, "m_fEffects", 129) // EF_BONEMERGE|EF_BONEMERGE_FASTCULL
	scope.tpWearable <- tpWearable
}

function setViewdModel(entity, model)
{
	local scope = entity.GetScriptScope()
	local viewModel = SpawnEntityFromTable("tf_wearable_vm", { })
	NetProps.SetPropInt(viewModel, "m_nModelIndex", JackModelIndex)
	NetProps.SetPropBool(viewModel, "m_bValidatedAttachedEntity", true)
	NetProps.SetPropBool(viewModel, "m_bForcePurgeFixedupStrings", true)
	for (local i = 0; i < 4; i++)
		NetProps.SetPropIntArray(viewModel, "m_nModelIndexOverrides", JackModelIndex, i)
	entity.EquipWearableViewModel(viewModel)
	scope.fpWearable <- viewModel
}

function hideModel(entity)
{
	NetProps.SetPropInt(entity, "m_nRenderMode", 1)
	NetProps.SetPropInt(entity, "m_clrRender", 1)
}

function showModel(entity)
{
	NetProps.SetPropInt(entity, "m_nRenderMode", 0)
	NetProps.SetPropInt(entity, "m_clrRender", 0xFFFFFFFF)
}
