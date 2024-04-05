/mob/living/carbon/alien/humanoid/tgmc
	name = "placeholder tgmc_alien name"
	icon = 'modular_ss220/aliens_tgmc/icons/big_xenos.dmi'
	custom_pixel_x_offset = -16 //All of the xeno sprites are 64x64, and we want them to be level with the tile they are on, much like oversized quirk users
	mob_size = MOB_SIZE_LARGE
	layer = LARGE_MOB_LAYER //above most mobs, but below speechbubbles
	large = 1
	maptext_height = 64
	maptext_width = 64
	pressure_resistance = 200

	/// Holds the ability for quick resting without using the ic panel, and without editing xeno huds
	var/datum/action/cooldown/alien/skyrat/sleepytime/rest_button
	/// What icon file update_held_items will look for when making inhands for xenos
	var/alt_inhands_file = 'modular_ss220/aliens_tgmc/icons/big_xenos.dmi'
	/// Setting this will give a xeno generic_evolve set to evolve them into this type
	var/next_evolution
	/// Holds the ability for evolving into whatever type next_evolution is set to
	var/datum/action/cooldown/alien/skyrat/generic_evolve/evolve_ability
	/// Keeps track of if a xeno has evolved recently, if so then we prevent them from evolving until that time is up
	var/has_evolved_recently = FALSE
	/// How long xenos should be unable to evolve after recently evolving
	var/evolution_cooldown_time = 90 SECONDS
	/// Determines if a xeno is unable to use abilities
	var/unable_to_use_abilities = FALSE
	/// Pixel X shifting of the on fire overlay
	var/on_fire_pixel_x = 16
	/// Pixel Y shifting of the on fire overlay
	var/on_fire_pixel_y = 16

/mob/living/carbon/alien/humanoid/tgmc/Initialize(mapload)
	. = ..()
	pixel_x = custom_pixel_x_offset
	real_name = "alien [caste] [rand(100, 999)]"

	rest_button = new()
	rest_button.Grant(src)

	if(next_evolution)
		evlove_ability = new()
		evolve_ability.Grant(src)

	ADD_TRAIT(src, TRAIT_XENO_HEAL_AURA, TRAIT_XENO_INNATE)

/mob/living/carbon/alien/humanoid/tgmc/Destroy()
	QDEL_NULL(rest_button)
	QDEL_NULL(evolve_ability)
	. = ..()

/mob/living/carbon/alien/humanoid/tgmc/update_icons()
	overlays.Cut()
	for(var/image/I in overlays_standing)
		overlays += I

	if(stat == DEAD)
		//If we mostly took damage from fire
		if(getFireLoss() > 125)
			icon_state = "alien[caste]_husked"
			pixel_y = 0
		else
			icon_state = "alien[caste]_dead"
			pixel_y = 0

	else if(stat == UNCONSCIOUS || IsWeakened())
		icon_state = "alien[caste]_unconscious"
		pixel_y = 0
	else if(leap_on_click)
		icon_state = "alien[caste]_pounce"

	else if(IS_HORIZONTAL(src))
		icon_state = "alien[caste]_sleep"
	else
		icon_state = "alien[caste]"

	if(leaping)
		if(alt_icon == initial(alt_icon))
			var/old_icon = icon
			icon = alt_icon
			alt_icon = old_icon
		icon_state = "alien[caste]_leap"
		pixel_x = -32
		pixel_y = -32
	else
		if(alt_icon != initial(alt_icon))
			var/old_icon = icon
			icon = alt_icon
			alt_icon = old_icon
		pixel_x = get_standard_pixel_x_offset()
		pixel_y = get_standard_pixel_y_offset()

/mob/living/carbon/alien/humanoid/tgmc/on_lying_down(new_lying_angle)
	. = ..()
	set_lying_angle(0)

/mob/living/carbon/alien/humanoid/tgmc/on_standing_up()
	. = ..()
	update_icons()

/// Called when a larva or xeno evolves, adds a configurable timer on evolving again to the xeno
/mob/living/carbon/alien/humanoid/tgmc/proc/has_just_evolved()
	if(has_evolved_recently)
		return
	has_evolved_recently = TRUE
	addtimer(CALLBACK(src, PROC_REF(can_evolve_once_again)), evolution_cooldown_time)

/// Allows xenos to evolve again if they are currently unable to
/mob/living/carbon/alien/humanoid/tgmc/proc/can_evolve_once_again()
	if(!has_evolved_recently)
		return
	has_evolved_recently = FALSE

/obj/effect/proc_holder/spell/alien_spell/tgmc
	action_icon = 'modular_ss220/aliens_tgmc/icons/xeno_actions.dmi'
	/// Some xeno abilities block other abilities from being used, this allows them to get around that in cases where it is needed
	// var/can_be_used_always = FALSE // TODO: DO WE EVEN NEED IT?

/obj/effect/proc_holder/spell/alien_spell/tgmc/rest_button
	name = "Rest"
	desc = "Sometimes even murder aliens need to have a little lie down."
	action_icon_state = "sleepytime"

/obj/effect/proc_holder/spell/alien_spell/tgmc/rest_button/cast(list/targets, mob/user)
	var/mob/living/carbon/alien = owner
	if(!isalien(alien))
		return FALSE
	if()
