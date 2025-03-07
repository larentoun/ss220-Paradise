/mob/living/simple_animal
	name = "animal"
	icon = 'icons/mob/animal.dmi'
	health = 20
	maxHealth = 20
	gender = PLURAL //placeholder

	universal_understand = 1
	universal_speak = 0
	status_flags = CANPUSH

	var/icon_living = ""
	var/icon_dead = ""
	var/icon_resting = ""
	var/icon_gib = null	//We only try to show a gibbing animation if this exists.
	var/flip_on_death = FALSE //Flip the sprite upside down on death. Mostly here for things lacking custom dead sprites.

	var/list/speak = list()
	var/speak_chance = 0
	var/list/emote_hear = list()	//Hearable emotes
	var/list/emote_see = list()		//Unlike speak_emote, the list of things in this variable only show by themselves with no spoken text. IE: Ian barks, Ian yaps
	tts_seed = "Kleiner"
	var/list/talk_sound = null //The sound played when talk

	var/turns_per_move = 1
	var/turns_since_move = 0
	var/stop_automated_movement = 0 //Use this to temporarely stop random movement or to if you write special movement code for animals.
	var/wander = 1	// Does the mob wander around when idle?
	var/stop_automated_movement_when_pulled = 1 //When set to 1 this stops the animal from moving when someone is pulling it.

	//Interaction
	var/response_help   = "pokes"
	var/response_disarm = "shoves"
	var/response_harm   = "hits"
	var/harm_intent_damage = 3
	var/force_threshold = 0 //Minimum force required to deal any damage

	/// Was this mob spawned by xenobiology magic? Used for mobcapping.
	var/xenobiology_spawned = FALSE

	//Temperature effect
	var/minbodytemp = 250
	var/maxbodytemp = 350
	/// Amount of damage applied if animal's body temperature is higher than maxbodytemp
	var/heat_damage_per_tick = 2
	/// Same as heat_damage_per_tick, only if the bodytemperature it's lower than minbodytemp
	var/cold_damage_per_tick = 2
	/// If the mob can catch fire
	var/can_be_on_fire = FALSE
	/// Damage the mob will take if it is on fire
	var/fire_damage = 2

	//Healable by medical stacks? Defaults to yes.
	var/healable = 1

	//Atmos effect - Yes, you can make creatures that require plasma or co2 to survive. N2O is a trace gas and handled separately, hence why it isn't here. It'd be hard to add it. Hard and me don't mix (Yes, yes make all the dick jokes you want with that.) - Errorage
	var/list/atmos_requirements = list("min_oxy" = 5, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 1, "min_co2" = 0, "max_co2" = 5, "min_n2" = 0, "max_n2" = 0) //Leaving something at 0 means it's off - has no maximum
	var/unsuitable_atmos_damage = 2	//This damage is taken when atmos doesn't fit all the requirements above

	//LETTING SIMPLE ANIMALS ATTACK? WHAT COULD GO WRONG. Defaults to zero so Ian can still be cuddly
	var/melee_damage_lower = 0
	var/melee_damage_upper = 0
	var/obj_damage = 0 //how much damage this simple animal does to objects, if any
	var/armour_penetration = 0 //How much armour they ignore, as a flat reduction from the targets armour value
	var/melee_damage_type = BRUTE //Damage type of a simple mob's melee attack, should it do damage.
	var/list/damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 1, CLONE = 1, STAMINA = 0, OXY = 1) // 1 for full damage , 0 for none , -1 for 1:1 heal from that source
	var/attacktext = "атакует"
	var/attack_sound = null
	var/friendly = "утыкается носом в" //If the mob does no damage with it's attack
	var/environment_smash = ENVIRONMENT_SMASH_NONE //Set to 1 to allow breaking of crates,lockers,racks,tables; 2 for walls; 3 for Rwalls

	var/speed = 1 //LETS SEE IF I CAN SET SPEEDS FOR SIMPLE MOBS WITHOUT DESTROYING EVERYTHING. Higher speed is slower, negative speed is faster
	var/can_hide = FALSE
	/// Allows a mob to pass unbolted doors while hidden
	var/pass_door_while_hidden = FALSE

	var/obj/item/clothing/accessory/petcollar/pcollar = null
	var/collar_type //if the mob has collar sprites, define them.
	var/unique_pet = FALSE // if the mob can be renamed
	var/can_collar = FALSE // can add collar to mob or not

	//Hot simple_animal baby making vars
	var/list/childtype = null
	var/next_scan_time = 0
	var/animal_species //Sorry, no spider+corgi buttbabies.

	var/buffed = 0 //In the event that you want to have a buffing effect on the mob, but don't want it to stack with other effects, any outside force that applies a buff to a simple mob should at least set this to 1, so we have something to check against
	var/gold_core_spawnable = NO_SPAWN //If the mob can be spawned with a gold slime core. HOSTILE_SPAWN are spawned with plasma, FRIENDLY_SPAWN are spawned with blood

	var/mob/living/carbon/human/master_commander = null //holding var for determining who own/controls a sentient simple animal (for sentience potions).

	var/datum/component/spawner/nest

	var/sentience_type = SENTIENCE_ORGANIC // Sentience type, for slime potions

	var/list/loot = list() //list of things spawned at mob's loc when it dies
	var/del_on_death = 0 //causes mob to be deleted on death, useful for mobs that spawn lootable corpses
	/// See [/proc/genderize_decode] for more info.
	var/deathmessage = ""
	var/death_sound = null //The sound played on death
	var/list/damaged_sound = null

	var/allow_movement_on_non_turfs = FALSE

	var/attacked_sound = "punch"

	var/AIStatus = AI_ON //The Status of our AI, can be set to AI_ON (On, usual processing), AI_IDLE (Will not process, but will return to AI_ON if an enemy comes near), AI_OFF (Off, Not processing ever)
	var/can_have_ai = TRUE //once we have become sentient, we can never go back

	var/shouldwakeup = FALSE //convenience var for forcibly waking up an idling AI on next check.

	///Domestication.
	var/tame = FALSE
	///What the mob eats, typically used for taming or animal husbandry.
	var/list/food_type
	///Starting success chance for taming.
	var/tame_chance
	///Added success chance after every failed tame attempt.
	var/bonus_tame_chance

	var/my_z // I don't want to confuse this with client registered_z
	///What kind of footstep this mob should have. Null if it shouldn't have any.
	var/footstep_type

/mob/living/simple_animal/Initialize(mapload)
	. = ..()
	GLOB.simple_animals[AIStatus] += src
	if(gender == PLURAL)
		gender = pick(MALE, FEMALE)
	if(!real_name)
		real_name = name
	if(!loc)
		stack_trace("Simple animal being instantiated in nullspace")
	update_simplemob_varspeed()
	verbs -= /mob/verb/observe
	if(can_hide)
		var/datum/action/innate/hide/hide = new()
		hide.Grant(src)
	if(pcollar)
		pcollar = new(src)
		regenerate_icons()
	if(footstep_type)
		AddComponent(/datum/component/footstep, footstep_type)

/mob/living/simple_animal/Destroy()
	QDEL_NULL(pcollar)
	master_commander = null
	GLOB.simple_animals[AIStatus] -= src
	if(SSnpcpool.state == SS_PAUSED && LAZYLEN(SSnpcpool.currentrun))
		SSnpcpool.currentrun -= src

	if(nest)
		nest.spawned_mobs -= src
		nest = null

	var/turf/T = get_turf(src)
	if (T && AIStatus == AI_Z_OFF)
		SSidlenpcpool.idle_mobs_by_zlevel[T.z] -= src

	return ..()

/mob/living/simple_animal/attackby(obj/item/O, mob/user, params)
	if(!is_type_in_list(O, food_type))
		..()
		return
	else
		user.visible_message("<span class='notice'>[user] hand-feeds [O] to [src].</span>", "<span class='notice'>You hand-feed [O] to [src].</span>")
		qdel(O)
		if(tame)
			return
		if(prob(tame_chance)) //note: lack of feedback message is deliberate, keep them guessing!
			tame = TRUE
			tamed(user)
		else
			tame_chance += bonus_tame_chance

///Extra effects to add when the mob is tamed, such as adding a riding or whatever.
/mob/living/simple_animal/proc/tamed(whomst)
	return

/mob/living/simple_animal/handle_atom_del(atom/A)
	if(A == pcollar)
		pcollar = null
	return ..()

/mob/living/simple_animal/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		. += "<span class='deadsay'>Upon closer examination, [p_they()] appear[p_s()] to be dead.</span>"
		return
	if(IsSleeping())
		. += "<span class='notice'>Upon closer examination, [p_they()] appear[p_s()] to be asleep.</span>"

/mob/living/simple_animal/updatehealth(reason = "none given", should_log = FALSE)
	..()
	health = clamp(health, 0, maxHealth)
	med_hud_set_health()

/mob/living/simple_animal/StartResting(updating = 1)
	..()
	if(icon_resting && stat != DEAD)
		icon_state = icon_resting
		if(collar_type)
			collar_type = "[initial(collar_type)]_rest"
			regenerate_icons()

/mob/living/simple_animal/StopResting(updating = 1)
	..()
	if(icon_resting && stat != DEAD)
		icon_state = icon_living
		if(collar_type)
			collar_type = "[initial(collar_type)]"
			regenerate_icons()

/mob/living/simple_animal/update_stat(reason = "none given", should_log = FALSE)
	if(status_flags & GODMODE)
		return ..()
	if(stat != DEAD)
		if(health <= 0)
			death()
		else
			WakeUp()
	..()

/mob/living/simple_animal/proc/handle_automated_action()
	set waitfor = FALSE
	return

/mob/living/simple_animal/proc/handle_automated_movement()
	set waitfor = FALSE
	if(!stop_automated_movement && wander)
		if((isturf(loc) || allow_movement_on_non_turfs) && !resting && !buckled && canmove)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if(turns_since_move >= turns_per_move)
				if(!(stop_automated_movement_when_pulled && pulledby)) //Soma animals don't move when pulled
					var/anydir = pick(GLOB.cardinal)
					if(Process_Spacemove(anydir))
						Move(get_step(src,anydir), anydir, cached_multiplicative_slowdown)
						turns_since_move = 0
			return 1

/mob/living/simple_animal/proc/handle_automated_speech(override)
	set waitfor = FALSE
	if(speak_chance)
		if(prob(speak_chance) || override)
			if(speak && speak.len)
				if((emote_hear && emote_hear.len) || (emote_see && emote_see.len))
					var/length = speak.len
					if(emote_hear && emote_hear.len)
						length += emote_hear.len
					if(emote_see && emote_see.len)
						length += emote_see.len
					var/randomValue = rand(1,length)
					if(randomValue <= speak.len)
						say(pick(speak))
					else
						randomValue -= speak.len
						if(emote_see && randomValue <= emote_see.len)
							custom_emote(EMOTE_VISIBLE, pick(emote_see))
						else
							custom_emote(EMOTE_AUDIBLE, pick(emote_hear))
				else
					say(pick(speak))
			else
				if(!(emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					custom_emote(EMOTE_VISIBLE, pick(emote_see))
				if((emote_hear && emote_hear.len) && !(emote_see && emote_see.len))
					custom_emote(EMOTE_AUDIBLE, pick(emote_hear))
				if((emote_hear && emote_hear.len) && (emote_see && emote_see.len))
					var/length = emote_hear.len + emote_see.len
					var/pick = rand(1,length)
					if(pick <= emote_see.len)
						custom_emote(EMOTE_VISIBLE, pick(emote_see))
					else
						custom_emote(EMOTE_AUDIBLE, pick(emote_hear))


/mob/living/simple_animal/handle_environment(datum/gas_mixture/environment)
	var/atmos_suitable = TRUE

	var/areatemp = get_temperature(environment)

	if(abs(areatemp - bodytemperature) > 5 && !(BREATHLESS in mutations))
		var/diff = areatemp - bodytemperature
		diff = diff / 5
		adjust_bodytemperature(diff)

	var/tox = environment.toxins
	var/oxy = environment.oxygen
	var/n2 = environment.nitrogen
	var/co2 = environment.carbon_dioxide

	if(atmos_requirements["min_oxy"] && oxy < atmos_requirements["min_oxy"])
		atmos_suitable = FALSE
		throw_alert("not_enough_oxy", /obj/screen/alert/not_enough_oxy)
	else if(atmos_requirements["max_oxy"] && oxy > atmos_requirements["max_oxy"])
		atmos_suitable = FALSE
		throw_alert("too_much_oxy", /obj/screen/alert/too_much_oxy)
	else
		clear_alert("not_enough_oxy")
		clear_alert("too_much_oxy")

	if(atmos_requirements["min_tox"] && tox < atmos_requirements["min_tox"])
		atmos_suitable = FALSE
		throw_alert("not_enough_tox", /obj/screen/alert/not_enough_tox)
	else if(atmos_requirements["max_tox"] && tox > atmos_requirements["max_tox"])
		atmos_suitable = FALSE
		throw_alert("too_much_tox", /obj/screen/alert/too_much_tox)
	else
		clear_alert("too_much_tox")
		clear_alert("not_enough_tox")

	if(atmos_requirements["min_n2"] && n2 < atmos_requirements["min_n2"])
		atmos_suitable = FALSE
	else if(atmos_requirements["max_n2"] && n2 > atmos_requirements["max_n2"])
		atmos_suitable = FALSE

	if(atmos_requirements["min_co2"] && co2 < atmos_requirements["min_co2"])
		atmos_suitable = FALSE
	else if(atmos_requirements["max_co2"] && co2 > atmos_requirements["max_co2"])
		atmos_suitable = FALSE

	if(!atmos_suitable)
		adjustHealth(unsuitable_atmos_damage)

	handle_temperature_damage()


/mob/living/simple_animal/proc/handle_temperature_damage()
	if(bodytemperature < minbodytemp)
		adjustHealth(cold_damage_per_tick)
	else if(bodytemperature > maxbodytemp)
		adjustHealth(heat_damage_per_tick)


/mob/living/simple_animal/gib()
	if(icon_gib)
		flick(icon_gib, src)
	if(butcher_results)
		var/atom/Tsec = drop_location()
		for(var/path in butcher_results)
			for(var/i in 1 to butcher_results[path])
				new path(Tsec)
	if(pcollar)
		pcollar.forceMove(drop_location())
		pcollar = null
	..()


/mob/living/simple_animal/say_quote(message)
	var/verb = "says"

	if(speak_emote.len)
		verb = pick(speak_emote)

	return verb


/mob/living/simple_animal/proc/set_varspeed(var_value)
	speed = var_value
	update_simplemob_varspeed()


/mob/living/simple_animal/proc/update_simplemob_varspeed()
	if(speed == 0)
		remove_movespeed_modifier(/datum/movespeed_modifier/simplemob_varspeed)
	add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/simplemob_varspeed, multiplicative_slowdown = speed)



/mob/living/simple_animal/Stat()
	..()
	if(statpanel("Status"))
		stat(null, "Health: [round((health / maxHealth) * 100)]%")
		return TRUE

/mob/living/simple_animal/proc/drop_loot()
	if(loot.len)
		for(var/i in loot)
			new i(loc)


/mob/living/simple_animal/death(gibbed)
	// Only execute the below if we successfully died
	. = ..()
	if(!.)
		return FALSE
	if(nest)
		nest.spawned_mobs -= src
		nest = null
	drop_loot()
	if(!gibbed)
		if(death_sound)
			playsound(get_turf(src),death_sound, 200, 1)
		if(deathmessage)
			visible_message(span_danger("\The [src] [genderize_decode(src, deathmessage)]"))
		else if(!del_on_death)
			visible_message(span_danger("\The [src] stops moving..."))
	if(xenobiology_spawned)
		SSmobs.xenobiology_mobs--
	if(del_on_death)
		//Prevent infinite loops if the mob Destroy() is overridden in such
		//a manner as to cause a call to death() again
		del_on_death = FALSE
		ghostize()
		qdel(src)
	else
		health = 0
		icon_state = icon_dead
		if(flip_on_death)
			transform = transform.Turn(180)
		ADD_TRAIT(src, TRAIT_UNDENSE, SIMPLE_MOB_DEATH_TRAIT)
		if(collar_type)
			collar_type = "[initial(collar_type)]_dead"
		regenerate_icons()

/mob/living/simple_animal/proc/CanAttack(atom/the_target)
	if(see_invisible < the_target.invisibility)
		return FALSE
	if(ismob(the_target))
		var/mob/M = the_target
		if(M.status_flags & GODMODE)
			return FALSE
	if(isliving(the_target))
		var/mob/living/L = the_target
		if(L.stat != CONSCIOUS)
			return FALSE
		if(L.incorporeal_move)
			return FALSE
	if(ismecha(the_target))
		var/obj/mecha/M = the_target
		if(M.occupant)
			return FALSE
	if(isspacepod(the_target))
		var/obj/spacepod/S = the_target
		if(S.pilot)
			return FALSE
	return TRUE

/mob/living/simple_animal/handle_fire()
	if(!can_be_on_fire)
		return FALSE
	. = ..()
	if(!.)
		return
	adjustFireLoss(fire_damage) // Slowly start dying from being on fire

/mob/living/simple_animal/IgniteMob()
	if(!can_be_on_fire)
		return FALSE
	return ..()

/mob/living/simple_animal/ExtinguishMob()
	if(!can_be_on_fire)
		return
	return ..()


/mob/living/simple_animal/update_fire()
	if(!can_be_on_fire)
		return
	var/static/simple_mob_fire_olay = mutable_appearance('icons/mob/OnFire.dmi', "Generic_mob_burning")
	cut_overlay(simple_mob_fire_olay)
	if(on_fire)
		add_overlay(simple_mob_fire_olay)


/mob/living/simple_animal/revive()
	..()
	density = initial(density)
	health = maxHealth
	icon = initial(icon)
	icon_state = icon_living
	REMOVE_TRAIT(src, TRAIT_UNDENSE, SIMPLE_MOB_DEATH_TRAIT)
	update_canmove()
	if(collar_type)
		collar_type = "[initial(collar_type)]"
		regenerate_icons()

/mob/living/simple_animal/proc/check_if_child(mob/possible_child)
	for(var/childpath in childtype)
		if (istype(possible_child, childpath))
			return TRUE
	return FALSE

/mob/living/simple_animal/proc/make_babies() // <3 <3 <3
	if(gender != FEMALE || stat || next_scan_time > world.time || !childtype || !animal_species || !SSticker.IsRoundInProgress())
		return FALSE

	if (check_if_child(src)) // Children aren't fertile enough
		return FALSE
	next_scan_time = world.time + 400

	var/alone = TRUE
	var/mob/living/simple_animal/partner
	var/children = 0

	for(var/mob/M in oview(7, src))
		if(M.stat != CONSCIOUS) //Check if it's conscious FIRST.
			continue
		else if(check_if_child(M)) //Check for children SECOND.
			children++
		else if(istype(M, animal_species))
			if(M.ckey)
				continue
			else if(!check_if_child(M) && M.gender == MALE) //Better safe than sorry ;_;
				partner = M
		else if(isliving(M) && !faction_check_mob(M)) //shyness check. we're not shy in front of things that share a faction with us.
			return //we never mate when not alone, so just abort early

	if(alone && partner && children < 3)
		var/childspawn = pickweight(childtype)
		var/turf/target = get_turf(loc)
		if(target)
			return new childspawn(target)

/mob/living/simple_animal/show_inv(mob/user)
	if(!can_collar)
		return

	user.set_machine(src)
	var/dat = {"<meta charset="UTF-8"><table><tr><td><B>Collar:</B></td><td><A href='?src=[UID()];item=[ITEM_SLOT_NECK]'>[(pcollar && !(pcollar.item_flags & ABSTRACT)) ? pcollar : "<font color=grey>Empty</font>"]</A></td></tr></table>"}
	dat += "<A href='?src=[user.UID()];mach_close=mob\ref[src]'>Close</A>"

	var/datum/browser/popup = new(user, "mob\ref[src]", "[src]", 440, 250)
	popup.set_content(dat)
	popup.open()

/mob/living/simple_animal/get_item_by_slot(slot_id)
	switch(slot_id)
		if(ITEM_SLOT_NECK)
			return pcollar
	. = ..()

/mob/living/simple_animal/can_equip(obj/item/I, slot, disable_warning = FALSE, bypass_equip_delay_self = FALSE, bypass_obscured = FALSE, bypass_incapacitated = FALSE)
	// . = ..() // Do not call parent. We do not want animals using their hand slots.
	switch(slot)
		if(ITEM_SLOT_NECK)
			if(pcollar)
				return FALSE
			if(!can_collar)
				return FALSE
			if(!istype(I, /obj/item/clothing/accessory/petcollar))
				return FALSE
			return TRUE


/mob/living/simple_animal/equip_to_slot(obj/item/I, slot, initial)
	if(!istype(I))
		return FALSE

	if(!slot)
		return FALSE

	. = TRUE

	I.pixel_x = initial(I.pixel_x)
	I.pixel_y = initial(I.pixel_y)
	I.layer = ABOVE_HUD_LAYER
	I.plane = ABOVE_HUD_PLANE
	I.forceMove(src)

	switch(slot)
		if(ITEM_SLOT_NECK)
			add_collar(I)


/mob/living/simple_animal/do_unEquip(obj/item/I, force = FALSE, atom/newloc, no_move = FALSE, invdrop = TRUE, silent = FALSE)
	. = ..()
	if(!. || !I)
		return .

	if(I == pcollar)
		pcollar = null
		if(!QDELETED(src))
			regenerate_icons()


/mob/living/simple_animal/get_access()
	. = ..()
	if(pcollar)
		. |= pcollar.GetAccess()

/mob/living/simple_animal/update_canmove(delay_action_updates = 0)
	if(IsParalyzed() || IsStunned() || IsWeakened() || stat || resting)
		drop_r_hand()
		drop_l_hand()
		canmove = FALSE
	else if(buckled)
		canmove = FALSE
	else
		canmove = TRUE
	if(!canmove)
		walk(src, 0) //stop mid walk

	update_transform()
	if(!delay_action_updates)
		update_action_buttons_icon()
	return canmove

/mob/living/simple_animal/update_transform()
	var/matrix/ntransform = matrix(transform) //aka transform.Copy()
	var/changed = FALSE

	if(resize != RESIZE_DEFAULT_SIZE)
		changed = TRUE
		ntransform.Scale(resize)
		resize = RESIZE_DEFAULT_SIZE

	if(!changed)
		return

	SEND_SIGNAL(src, COMSIG_PAUSE_FLOATING_ANIM, 0.3 SECONDS)
	animate(src, transform = ntransform, time = UPDATE_TRANSFORM_ANIMATION_TIME, easing = EASE_IN|EASE_OUT)


/mob/living/simple_animal/proc/sentience_act() //Called when a simple animal gains sentience via gold slime potion
	toggle_ai(AI_OFF)
	can_have_ai = FALSE

/mob/living/simple_animal/grant_death_vision()
	sight |= SEE_TURFS
	sight |= SEE_MOBS
	sight |= SEE_OBJS
	nightvision = 8
	see_invisible = SEE_INVISIBLE_OBSERVER
	sync_lighting_plane_alpha()

/mob/living/simple_animal/update_sight()
	if(!client)
		return

	if(stat == DEAD)
		grant_death_vision()
		return

	see_invisible = initial(see_invisible)
	nightvision = initial(nightvision)
	sight = initial(sight)

	if(client.eye != src)
		var/atom/A = client.eye
		if(A.update_remote_sight(src)) //returns 1 if we override all other sight updates.
			return

	SEND_SIGNAL(src, COMSIG_MOB_UPDATE_SIGHT)
	overlay_fullscreen("see_through_darkness", /obj/screen/fullscreen/see_through_darkness)
	sync_lighting_plane_alpha()

/mob/living/simple_animal/proc/toggle_ai(togglestatus)
	if(!can_have_ai && (togglestatus != AI_OFF))
		return
	if(AIStatus != togglestatus)
		if(togglestatus > 0 && togglestatus < 5)
			if(togglestatus == AI_Z_OFF || AIStatus == AI_Z_OFF)
				var/turf/T = get_turf(src)
				if(AIStatus == AI_Z_OFF)
					SSidlenpcpool.idle_mobs_by_zlevel[T.z] -= src
				else
					SSidlenpcpool.idle_mobs_by_zlevel[T.z] += src
			GLOB.simple_animals[AIStatus] -= src
			GLOB.simple_animals[togglestatus] += src
			AIStatus = togglestatus
		else
			stack_trace("Something attempted to set simple animals AI to an invalid state: [togglestatus]")

/mob/living/simple_animal/proc/consider_wakeup()
	if(pulledby || shouldwakeup)
		toggle_ai(AI_ON)


/mob/living/simple_animal/onTransitZ(old_z, new_z)
	..()
	if(AIStatus == AI_Z_OFF)
		SSidlenpcpool.idle_mobs_by_zlevel[old_z] -= src
		toggle_ai(initial(AIStatus))


/mob/living/simple_animal/proc/add_collar(obj/item/clothing/accessory/petcollar/P, mob/user)
	if(!istype(P) || QDELETED(P) || pcollar)
		return FALSE
	if(user && !user.drop_transfer_item_to_loc(P, src))
		return FALSE
	pcollar = P
	regenerate_icons()
	if(user)
		to_chat(user, span_notice("You put [P] around [src]'s neck."))
	if(P.tagname && !unique_pet)
		name = P.tagname
		real_name = P.tagname
	P.equipped(src)
	return TRUE


/mob/living/simple_animal/regenerate_icons()
	cut_overlays()
	if(pcollar && collar_type)
		add_overlay("[collar_type]collar")
		add_overlay("[collar_type]tag")

	if(blocks_emissive)
		add_overlay(get_emissive_block())

/mob/living/simple_animal/Login()
	..()
	walk(src, 0) // if mob is moving under ai control, then stop AI movement


/mob/living/simple_animal/say(message, verb = "says", sanitize = TRUE, ignore_speech_problems = FALSE, ignore_atmospherics = FALSE, ignore_languages = FALSE)
	. = ..()
	if(. && length(talk_sound))
		playsound(src, pick(talk_sound), 75, TRUE)


/mob/living/simple_animal/attacked_by(obj/item/I, mob/living/user)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/attack_hand(mob/living/carbon/human/M)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/attack_animal(mob/living/simple_animal/M)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/attack_alien(mob/living/carbon/alien/humanoid/M)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/attack_larva(mob/living/carbon/alien/larva/L)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/attack_slime(mob/living/simple_animal/slime/M)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/attack_robot(mob/living/user)
	. = ..()
	if(. && length(src.damaged_sound))
		playsound(src, pick(src.damaged_sound), 40, 1)

/mob/living/simple_animal/start_pulling(atom/movable/AM, force = pull_force, show_message = FALSE)
	if(pull_constraint(AM, show_message))
		return ..()

/mob/living/simple_animal/proc/pull_constraint(atom/movable/AM, show_message = FALSE)
	return TRUE
