/*
	Global associative list for caching humanoid icons.
	Index format m or f, followed by a string of 0 and 1 to represent bodyparts followed by husk hulk skeleton 1 or 0.
	TODO: Proper documentation
	icon_key is [species.race_key][g][husk][hulk][skeleton][s_tone]
*/
GLOBAL_LIST_EMPTY(human_icon_cache)

	///////////////////////
	//UPDATE_ICONS SYSTEM//
	///////////////////////
/*
Calling this  a system is perhaps a bit trumped up. It is essentially update_clothing dismantled into its
core parts. The key difference is that when we generate overlays we do not generate either lying or standing
versions. Instead, we generate both and store them in two fixed-length lists, both using the same list-index
(The indexes are in update_icons.dm): Each list for humans is (at the time of writing) of length 19.
This will hopefully be reduced as the system is refined.

	var/overlays_lying[19]			//For the lying down stance
	var/overlays_standing[19]		//For the standing stance

When we call update_icons, the 'lying' variable is checked and then the appropriate list is assigned to our overlays!
That in itself uses a tiny bit more memory (no more than all the ridiculous lists the game has already mind you).

On the other-hand, it should be very CPU cheap in comparison to the old system.
In the old system, we updated all our overlays every life() call, even if we were standing still inside a crate!
or dead!. 25ish overlays, all generated from scratch every second for every xeno/human/monkey and then applied.
More often than not update_clothing was being called a few times in addition to that! CPU was not the only issue,
all those icons had to be sent to every client. So really the cost was extremely cumulative. To the point where
update_clothing would frequently appear in the top 10 most CPU intensive procs during profiling.

Another feature of this new system is that our lists are indexed. This means we can update specific overlays!
So we only regenerate icons when we need them to be updated! This is the main saving for this system.

In practice this means that:
	everytime you fall over, we just switch between precompiled lists. Which is fast and cheap.
	Everytime you do something minor like take a pen out of your pocket, we only update the in-hand overlay
	etc...


There are several things that need to be remembered:

>	Whenever we do something that should cause an overlay to update (which doesn't use standard procs
	( i.e. you do something like l_hand = /obj/item/something new(src) )
	You will need to call the relevant update_inv_* proc:
		update_inv_head()
		update_inv_wear_suit()
		update_inv_gloves()
		update_inv_shoes()
		update_inv_w_uniform()
		update_inv_glasse()
		update_inv_l_hand()
		update_inv_r_hand()
		update_inv_belt()
		update_inv_wear_id()
		update_inv_ears()
		update_inv_s_store()
		update_inv_pockets()
		update_inv_back()
		update_inv_handcuffed()
		update_inv_wear_mask()

	All of these are named after the variable they update from. They are defined at the mob/ level like
	update_clothing was, so you won't cause undefined proc runtimes with usr.update_inv_wear_id() if the usr is a
	slime etc. Instead, it'll just return without doing any work. So no harm in calling it for slimes and such.


>	There are also these special cases:
		update_mutations()	//handles updating your appearance for certain mutations.  e.g TK head-glows
		update_mutantrace()	//handles updating your appearance after setting the mutantrace var
		UpdateDamageIcon()	//handles damage overlays for brute/burn damage //(will rename this when I geta round to it)
		update_body()	//Handles updating your mob's icon to reflect their gender/race/complexion etc
		update_hair()	//Handles updating your hair overlay (used to be update_face, but mouth and
																			...eyes were merged into update_body)

>	All of these procs update our overlays_lying and overlays_standing, and then call update_icons() by default.
	If you wish to update several overlays at once, you can set the argument to 0 to disable the update and call
	it manually:
		e.g.
		update_inv_head()
		update_inv_l_hand()
		update_inv_r_hand()		//<---calls update_icons()

	or equivillantly:
		update_inv_head()
		update_inv_l_hand()
		update_inv_r_hand()
		update_icons()

>	If you need to update all overlays you can use regenerate_icons(). it works exactly like update_clothing used to.

>	I reimplimented an old unused variable which was in the code called (coincidentally) var/update_icon
	It can be used as another method of triggering regenerate_icons(). It's basically a flag that when set to non-zero
	will call regenerate_icons() at the next life() call and then reset itself to 0.
	The idea behind it is icons are regenerated only once, even if multiple events requested it.

This system is confusing and is still a WIP. It's primary goal is speeding up the controls of the game whilst
reducing processing costs. So please bear with me while I iron out the kinks. It will be worth it, I promise.
If I can eventually free var/lying stuff from the life() process altogether, stuns/death/status stuff
will become less affected by lag-spikes and will be instantaneous! :3

If you have any questions/constructive-comments/bugs-to-report/or have a massivly devestated butt...
Please contact me on #coderbus IRC. ~Carn x
*/

/mob/living/carbon/human
	var/list/overlays_standing[TOTAL_LAYERS]
	var/previous_damage_appearance // store what the body last looked like, so we only have to update it if something changed
	var/icon/skeleton


/mob/living/carbon/human/proc/apply_overlay(cache_index)
	if((. = overlays_standing[cache_index]))
		add_overlay(.)
		SEND_SIGNAL(src, COMSIG_HUMAN_APPLY_OVERLAY)

/mob/living/carbon/human/proc/remove_overlay(cache_index)
	var/I = overlays_standing[cache_index]
	if(I)
		cut_overlay(I)
		overlays_standing[cache_index] = null


GLOBAL_LIST_EMPTY(damage_icon_parts)

//DAMAGE OVERLAYS
//constructs damage icon for each organ from mask * damage field and saves it in our overlays_ lists
/mob/living/carbon/human/UpdateDamageIcon()
	// first check whether something actually changed about damage appearance
	var/damage_appearance = ""

	for(var/obj/item/organ/external/bodypart as anything in bodyparts)
		damage_appearance += bodypart.damage_state

	if(damage_appearance == previous_damage_appearance)
		// nothing to do here
		return

	previous_damage_appearance = damage_appearance

	remove_overlay(H_DAMAGE_LAYER)
	var/mutable_appearance/damage_overlay = mutable_appearance(dna.species.damage_overlays, "00", layer = -H_DAMAGE_LAYER)
	overlays_standing[H_DAMAGE_LAYER] = damage_overlay

	// blend the individual damage states with our icons
	for(var/obj/item/organ/external/bodypart as anything in bodyparts)
		bodypart.update_state()
		if(bodypart.damage_state == "00")
			continue

		var/icon/DI
		var/cache_index = "[bodypart.damage_state]/[bodypart.icon_name]/[dna.species.blood_color]/[dna.species.name]"

		if(GLOB.damage_icon_parts[cache_index] == null)
			DI = new /icon(dna.species.damage_overlays, bodypart.damage_state)			// the damage icon for whole human
			DI.Blend(new /icon(dna.species.damage_mask, bodypart.icon_name), ICON_MULTIPLY)	// mask with this organ's pixels
			DI.Blend(dna.species.blood_color, ICON_MULTIPLY)
			GLOB.damage_icon_parts[cache_index] = DI
		else
			DI = GLOB.damage_icon_parts[cache_index]
		damage_overlay.overlays += DI

	apply_overlay(H_DAMAGE_LAYER)


//BASE MOB SPRITE
/mob/living/carbon/human/proc/update_body(rebuild_base = FALSE)
	remove_overlay(LIMBS_LAYER) // So we don't get the old species' sprite splatted on top of the new one's
	remove_overlay(UNDERWEAR_LAYER)

	var/husk_color_mod = rgb(96, 88, 80)
	var/hulk_color_mod = rgb(48, 224, 40)

	var/husk = (HUSK in mutations)
	var/hulk = (HULK in mutations)
	var/skeleton = (SKELETON in mutations)

	if(dna.species && dna.species.bodyflags & HAS_ICON_SKIN_TONE)
		dna.species.updatespeciescolor(src)

	//CACHING: Generate an index key from visible bodyparts.
	//0 = destroyed, 1 = normal, 2 = robotic, 3 = necrotic.
	//Create a new, blank icon for our mob to use.
	if(stand_icon)
		qdel(stand_icon)

	update_misc_effects()
	stand_icon = new (dna.species.icon_template ? dna.species.icon_template : 'icons/mob/human.dmi', "blank")
	var/list/standing = list()
	var/icon_key = generate_icon_render_key()

	var/mutable_appearance/base
	if(GLOB.human_icon_cache[icon_key] && !rebuild_base)
		base = GLOB.human_icon_cache[icon_key]
		standing += base
	else
		var/icon/base_icon
		//BEGIN CACHED ICON GENERATION.
		var/obj/item/organ/external/chest = get_organ(BODY_ZONE_CHEST)
		if(chest) //I hate it.
			base_icon = chest.get_icon(skeleton)

		for(var/obj/item/organ/external/part as anything in bodyparts)
			if(part.limb_zone == BODY_ZONE_TAIL || part.limb_zone == BODY_ZONE_WING)
				continue
			var/icon/temp = part.get_icon(skeleton)
			//That part makes left and right legs drawn topmost and lowermost when human looks WEST or EAST
			//And no change in rendering for other parts (they icon_position is 0, so goes to 'else' part)
			if(part.icon_position & (LEFT | RIGHT))
				var/icon/temp2 = new('icons/mob/human.dmi',"blank")
				temp2.Insert(new/icon(temp,dir=NORTH),dir=NORTH)
				temp2.Insert(new/icon(temp,dir=SOUTH),dir=SOUTH)
				if(!(part.icon_position & LEFT))
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)
				if(!(part.icon_position & RIGHT))
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)
				base_icon.Blend(temp2, ICON_OVERLAY)
				if(part.icon_position & LEFT)
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)
				if(part.icon_position & RIGHT)
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)
				base_icon.Blend(temp2, ICON_UNDERLAY)
			else
				base_icon.Blend(temp, ICON_OVERLAY)

		if(!skeleton)
			if(isgolem(src))
				var/datum/species/golem/G = src.dna.species
				if(G.golem_colour)
					base_icon.ColorTone(G.golem_colour)
			if(husk)
				base_icon.ColorTone(husk_color_mod)
			else if(hulk)
				var/list/tone = ReadRGB(hulk_color_mod)
				base_icon.MapColors(rgb(tone[1],0,0),rgb(0,tone[2],0),rgb(0,0,tone[3]))

		//Handle husk overlay.
		if(husk && ("overlay_husk" in icon_states(chest.icobase)))
			var/icon/mask = new(base_icon)
			var/icon/husk_over = new(chest.icobase,"overlay_husk")
			mask.MapColors(0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,0)
			husk_over.Blend(mask, ICON_ADD)
			base_icon.Blend(husk_over, ICON_OVERLAY)

		var/mutable_appearance/new_base = mutable_appearance(base_icon, layer = -LIMBS_LAYER)
		GLOB.human_icon_cache[icon_key] = new_base
		standing += new_base

		//END CACHED ICON GENERATION.

	overlays_standing[LIMBS_LAYER] = standing
	apply_overlay(LIMBS_LAYER)

	//Underwear
	var/icon/underwear_standing = new /icon('icons/mob/clothing/underwear.dmi', "nude")
	if(underwear && dna.species.clothing_flags & HAS_UNDERWEAR)
		var/datum/sprite_accessory/underwear/U = GLOB.underwear_list[underwear]
		if(U)
			var/u_icon = U.sprite_sheets && (dna.species.name in U.sprite_sheets) ? U.sprite_sheets[dna.species.name] : U.icon //Species-fit the undergarment.
			var/icon/underwear_icon = new (u_icon, "uw_[U.icon_state]_s")
			if(U.allow_change_color)
				underwear_icon.Blend(color_underwear, ICON_MULTIPLY)
			underwear_standing.Blend(underwear_icon, ICON_OVERLAY)

	if(undershirt && dna.species.clothing_flags & HAS_UNDERSHIRT)
		var/datum/sprite_accessory/undershirt/U2 = GLOB.undershirt_list[undershirt]
		if(U2)
			var/u2_icon = U2.sprite_sheets && (dna.species.name in U2.sprite_sheets) ? U2.sprite_sheets[dna.species.name] : U2.icon
			var/icon/undershirt_icon = new(u2_icon, "us_[U2.icon_state]_s")
			if(U2.allow_change_color)
				undershirt_icon.Blend(color_undershirt, ICON_MULTIPLY)
			underwear_standing.Blend(undershirt_icon, ICON_OVERLAY)

	if(socks && dna.species.clothing_flags & HAS_SOCKS)
		var/datum/sprite_accessory/socks/U3 = GLOB.socks_list[socks]
		if(U3)
			var/u3_icon = U3.sprite_sheets && (dna.species.name in U3.sprite_sheets) ? U3.sprite_sheets[dna.species.name] : U3.icon
			underwear_standing.Blend(new /icon(u3_icon, "sk_[U3.icon_state]_s"), ICON_OVERLAY)

	if(underwear_standing)
		overlays_standing[UNDERWEAR_LAYER] = mutable_appearance(underwear_standing, layer = -UNDERWEAR_LAYER)
	apply_overlay(UNDERWEAR_LAYER)

	//wings
	update_wing_layer()
	//tail
	update_tail_layer()
	update_int_organs()
	//head accessory
	update_head_accessory()
	//markings
	update_markings()
	//hair
	update_hair()
	update_fhair()


//MARKINGS OVERLAY
/mob/living/carbon/human/proc/update_markings()
	//Reset our markings.
	remove_overlay(MARKINGS_LAYER)

	//Base icon.
	var/icon/markings_standing = icon("icon" = 'icons/mob/clothing/body_accessory.dmi', "icon_state" = "accessory_none_s")

	//Body markings.
	var/obj/item/organ/external/chest/chest_organ = get_organ(BODY_ZONE_CHEST)
	if(chest_organ && m_styles["body"])
		var/body_marking = m_styles["body"]
		var/datum/sprite_accessory/body_marking_style = GLOB.marking_styles_list[body_marking]
		if(body_marking_style && body_marking_style.species_allowed && (dna.species.name in body_marking_style.species_allowed))
			var/icon/b_marking_s = icon("icon" = body_marking_style.icon, "icon_state" = "[body_marking_style.icon_state]_s")
			if(body_marking_style.do_colouration)
				b_marking_s.Blend(m_colours["body"], ICON_ADD)
			markings_standing.Blend(b_marking_s, ICON_OVERLAY)
	//Head markings.
	var/obj/item/organ/external/head/head_organ = get_organ(BODY_ZONE_HEAD)
	if(head_organ && m_styles["head"]) //If the head is destroyed, forget the head markings. This prevents floating optical markings on decapitated IPCs, for example.
		var/head_marking = m_styles["head"]
		var/datum/sprite_accessory/head_marking_style = GLOB.marking_styles_list[head_marking]
		if(head_marking_style && head_marking_style.species_allowed && (head_organ.dna.species.name in head_marking_style.species_allowed))
			var/icon/h_marking_s = icon("icon" = head_marking_style.icon, "icon_state" = "[head_marking_style.icon_state]_s")
			if(head_marking_style.do_colouration)
				h_marking_s.Blend(m_colours["head"], ICON_ADD)
			markings_standing.Blend(h_marking_s, ICON_OVERLAY)

	overlays_standing[MARKINGS_LAYER] = mutable_appearance(markings_standing, layer = -MARKINGS_LAYER)
	apply_overlay(MARKINGS_LAYER)


//HEAD ACCESSORY OVERLAY
/mob/living/carbon/human/proc/update_head_accessory()
	//Reset our head accessory
	remove_overlay(HEAD_ACCESSORY_LAYER)
	remove_overlay(HEAD_ACC_OVER_LAYER)

	var/obj/item/organ/external/head/head_organ = get_organ(BODY_ZONE_HEAD)
	if(!head_organ || !head_organ.dna || !head_organ.ha_style)
		return

	//masks and helmets can obscure our head accessory
	if((head && (head.flags_inv & HIDEHAIR)) || (wear_mask && (wear_mask.flags_inv & HIDEHAIR)))
		return

	var/datum/sprite_accessory/head_accessory/head_accessory = GLOB.head_accessory_styles_list[head_organ.ha_style]
	if(!head_accessory || !(head_accessory.species_allowed && (head_organ.dna.species.name in head_accessory.species_allowed)))
		return

	//base icons
	var/icon/head_accessory_standing = icon('icons/mob/clothing/body_accessory.dmi', "accessory_none_s")
	var/icon/head_accessory_s = icon(head_accessory.icon, "[head_accessory.icon_state]_s")
	if(head_accessory.do_colouration)
		head_accessory_s.Blend(head_organ.headacc_colour, ICON_ADD)
	//head_accessory_standing.Blend(head_accessory_s, ICON_OVERLAY)
	//Having it this way preserves animations. Useful for animated antennae.
	head_accessory_standing = head_accessory_s

	if(head_accessory.over_hair) //Select which layer to use based on the properties of the head accessory style.
		overlays_standing[HEAD_ACC_OVER_LAYER] = mutable_appearance(head_accessory_standing, layer = -HEAD_ACC_OVER_LAYER)
		apply_overlay(HEAD_ACC_OVER_LAYER)
	else
		overlays_standing[HEAD_ACCESSORY_LAYER] = mutable_appearance(head_accessory_standing, layer = -HEAD_ACCESSORY_LAYER)
		apply_overlay(HEAD_ACCESSORY_LAYER)


//HAIR OVERLAY
/mob/living/carbon/human/proc/update_hair()
	//Reset our hair
	remove_overlay(HAIR_LAYER)

	var/obj/item/organ/external/head/head_organ = get_organ(BODY_ZONE_HEAD)
	if(!head_organ || !head_organ.dna || !head_organ.h_style)
		return

	//masks and helmets can obscure our hair, unless we're a synthetic
	if((head && (head.flags_inv & (HIDEHAIR|HIDEHEADHAIR))) || (wear_mask && (wear_mask.flags_inv & (HIDEHAIR|HIDEHEADHAIR))))
		return

	var/datum/sprite_accessory/hair/hair = GLOB.hair_styles_full_list[head_organ.h_style]
	if(!hair || !((hair.species_allowed && (head_organ.dna.species.name in hair.species_allowed)) || (head_organ.dna.species.bodyflags & ALL_RPARTS)))
		return

	//base icons
	var/mutable_appearance/MA = new()
	MA.appearance_flags = KEEP_TOGETHER
	MA.layer = -HAIR_LAYER

	// Base hair
	var/mutable_appearance/img_hair = mutable_appearance(hair.icon, "[hair.icon_state]_s")
	if(head_organ.dna.species.name == SPECIES_SLIMEPERSON)
		img_hair.color = COLOR_MATRIX_OVERLAY("[skin_colour]A0")
	else if(hair.do_colouration)
		img_hair.color = COLOR_MATRIX_ADD(head_organ.hair_colour)
	MA.overlays += img_hair

	// Gradient
	var/datum/sprite_accessory/hair_gradient/gradient = GLOB.hair_gradients_list[head_organ.h_grad_style]
	if(gradient)
		var/icon/icn_alpha_mask = icon(gradient.icon, gradient.icon_state)
		var/icon/icn_gradient = icon(gradient.icon, "full")
		var/list/icn_color = ReadRGB(head_organ.h_grad_colour)
		icn_gradient.MapColors(rgb(icn_color[1], 0, 0), rgb(0, icn_color[2], 0), rgb(0, 0, icn_color[3]))
		icn_gradient.ChangeOpacity(head_organ.h_grad_alpha / 200)
		icn_gradient.AddAlphaMask(icn_alpha_mask)
		icn_gradient.Shift(EAST, head_organ.h_grad_offset_x)
		icn_gradient.Shift(NORTH, head_organ.h_grad_offset_y)
		icn_gradient.AddAlphaMask(icon(hair.icon, "[hair.icon_state]_s"))
		MA.overlays += icn_gradient

	// Secondary style
	if(hair.secondary_theme)
		var/mutable_appearance/img_secondary = mutable_appearance(hair.icon, "[hair.icon_state]_[hair.secondary_theme]_s")
		if(!hair.no_sec_colour)
			img_secondary.color = COLOR_MATRIX_ADD(head_organ.sec_hair_colour)
		MA.overlays += img_secondary

	overlays_standing[HAIR_LAYER] = MA
	apply_overlay(HAIR_LAYER)


//FACIAL HAIR OVERLAY
/mob/living/carbon/human/proc/update_fhair()
	//Reset our facial hair
	remove_overlay(FHAIR_LAYER)
	remove_overlay(FHAIR_OVER_LAYER)

	var/obj/item/organ/external/head/head_organ = get_organ(BODY_ZONE_HEAD)
	if(!head_organ || !head_organ.dna || !head_organ.f_style)
		return

	//masks and helmets can obscure our facial hair, unless we're a synthetic
	if((head && (head.flags_inv & (HIDEHAIR|HIDEFACIALHAIR))) || (wear_mask && (wear_mask.flags_inv & (HIDEHAIR|HIDEFACIALHAIR))))
		return

	var/datum/sprite_accessory/facial_hair/facial_hair = GLOB.facial_hair_styles_list[head_organ.f_style]
	//If the head's species is in the list of allowed species for the hairstyle, or the head's species is one flagged to have bodies comprised wholly of cybernetics...
	if(!facial_hair || !((facial_hair.species_allowed && (head_organ.dna.species.name in facial_hair.species_allowed)) || (head_organ.dna.species.bodyflags & ALL_RPARTS)))
		return

	//base icons
	var/icon/face_standing = icon('icons/mob/human_face.dmi', "bald_s")

	var/icon/facial_s = icon(facial_hair.icon, "[facial_hair.icon_state]_s")
	if(head_organ.dna.species.name == SPECIES_SLIMEPERSON) // I am el worstos
		facial_s.Blend("[skin_colour]A0", ICON_AND)
	else if(facial_hair.do_colouration)
		facial_s.Blend(head_organ.facial_colour, ICON_ADD)

	if(facial_hair.secondary_theme)
		var/icon/facial_secondary_s = icon(facial_hair.icon, "[facial_hair.icon_state]_[facial_hair.secondary_theme]_s")
		if(!facial_hair.no_sec_colour)
			facial_secondary_s.Blend(head_organ.sec_facial_colour, ICON_ADD)
		facial_s.Blend(facial_secondary_s, ICON_OVERLAY)

	face_standing.Blend(facial_s, ICON_OVERLAY)

	if(facial_hair.over_hair) //Select which layer to use based on the properties of the facial hair style.
		overlays_standing[FHAIR_OVER_LAYER] = mutable_appearance(face_standing, layer = -FHAIR_OVER_LAYER)
		apply_overlay(FHAIR_OVER_LAYER)
	else
		overlays_standing[FHAIR_LAYER] = mutable_appearance(face_standing, layer = -FHAIR_LAYER)
		apply_overlay(FHAIR_LAYER)


/mob/living/carbon/human/update_mutations()
	remove_overlay(MUTATIONS_LAYER)
	var/mutable_appearance/standing = mutable_appearance(issmall(src) ? 'icons/mob/clothing/species/monkey/genetics.dmi' : 'icons/effects/genetics.dmi', layer = -MUTATIONS_LAYER)
	var/add_image = FALSE
	var/g = "m"
	if(gender == FEMALE)
		g = "f"
	// DNA2 - Drawing underlays.
	for(var/datum/dna/gene/gene in GLOB.dna_genes)
		if(!gene.block)
			continue
		if(gene.is_active(src))
			var/underlay = gene.OnDrawUnderlays(src, g)
			if(underlay)
				standing.underlays += underlay
				add_image = TRUE

	if(HAS_TRAIT(src, TRAIT_LASEREYES))
		standing.overlays += "lasereyes_s"
		add_image = TRUE

	if((COLDRES in mutations) && (HEATRES in mutations))
		standing.underlays -= "cold_s"
		standing.underlays -= "fire_s"
		standing.underlays += "coldfire_s"

	if(add_image)
		overlays_standing[MUTATIONS_LAYER] = standing
	apply_overlay(MUTATIONS_LAYER)

/mob/living/carbon/human/proc/update_mutantrace(update_hair = TRUE)
//BS12 EDIT
	var/skel = (SKELETON in mutations)
	if(skel)
		skeleton = 'icons/mob/human_races/r_skeleton.dmi'
	else
		skeleton = null

	if(update_hair)
		update_hair()
		update_fhair()


/mob/living/carbon/human/update_fire()
	remove_overlay(FIRE_LAYER)
	if(on_fire)
		if(!overlays_standing[FIRE_LAYER])
			overlays_standing[FIRE_LAYER] = mutable_appearance(FIRE_DMI, icon_state = "Standing", layer = -FIRE_LAYER)
	apply_overlay(FIRE_LAYER)

/* --------------------------------------- */
//For legacy support.
/mob/living/carbon/human/regenerate_icons()
	if(HAS_TRAIT(src, TRAIT_NO_TRANSFORM))
		return
	cut_overlays()
	update_mutantrace(update_hair = FALSE)
	force_update_limbs(update_body = FALSE)
	update_eyes(update_body = FALSE)
	update_body(rebuild_base = TRUE) //Update the body and force limb icon regeneration.
	update_mutations()
	update_inv_w_uniform()
	update_inv_wear_id()
	update_inv_gloves()
	update_inv_neck()
	update_inv_glasses()
	update_inv_ears()
	update_inv_shoes()
	update_inv_s_store()
	update_inv_wear_mask()
	update_inv_head()
	update_inv_belt()
	update_inv_back()
	update_inv_wear_suit()
	update_inv_r_hand()
	update_inv_l_hand()
	update_inv_handcuffed()
	update_inv_legcuffed()
	update_inv_pockets()
	update_inv_wear_pda()
	UpdateDamageIcon()
	if(blocks_emissive)
		add_overlay(get_emissive_block())
	update_halo_layer()
	update_fire()
	SEND_SIGNAL(src, COMSIG_HUMAN_REGENERATE_ICONS)



/* --------------------------------------- */
//vvvvvv UPDATE_INV PROCS vvvvvv

/mob/living/carbon/human/update_inv_w_uniform()
	remove_overlay(UNIFORM_LAYER)
	remove_overlay(OVER_SHOES_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_CLOTH_INNER) + 1]
		inv?.update_icon()

	if(istype(w_uniform, /obj/item/clothing/under))
		if(client && hud_used && hud_used.hud_shown)
			if(hud_used.inventory_shown)			//if the inventory is open ...
				w_uniform.screen_loc = ui_iclothing //...draw the item in the inventory screen
			client.screen += w_uniform				//Either way, add the item to the HUD

		var/t_color = w_uniform.item_color
		if(!t_color)
			t_color = icon_state

		var/mutable_appearance/standing = mutable_appearance(w_uniform.onmob_sheets[ITEM_SLOT_CLOTH_INNER_STRING], "[t_color]_s", layer = -UNIFORM_LAYER)


		if(w_uniform.sprite_sheets && w_uniform.sprite_sheets[dna.species.name])
			standing.icon = w_uniform.sprite_sheets[dna.species.name]

		if(w_uniform.blood_DNA)
			var/image/bloodsies	= image("icon" = dna.species.blood_mask, "icon_state" = "uniformblood")
			bloodsies.color = w_uniform.blood_color
			standing.overlays += bloodsies

		if(w_uniform.accessories.len)	//WE CHECKED THE TYPE ABOVE. THIS REALLY SHOULD BE FINE. // oh my god kys whoever made this if statement jfc :gun:
			for(var/obj/item/clothing/accessory/A in w_uniform:accessories)
				var/tie_color = A.item_color
				if(!tie_color)
					tie_color = A.icon_state
				if(A.sprite_sheets && A.sprite_sheets[dna.species.name])
					standing.overlays += image("icon" = A.sprite_sheets[dna.species.name], "icon_state" = "[A.icon_state]")
				else
					standing.overlays += image("icon" = A.onmob_sheets[ITEM_SLOT_ACCESSORY_STRING], "icon_state" = "[tie_color]")
		standing.alpha = w_uniform.alpha
		standing.color = w_uniform.color
		if(w_uniform.over_shoes) //Select which layer to use based on the properties of the hair style. Hair styles with hair that don't overhang the arms of the glasses should have glasses_over set to a positive value.
			standing.layer = -OVER_SHOES_LAYER
			overlays_standing[OVER_SHOES_LAYER] = standing
			apply_overlay(OVER_SHOES_LAYER)
		else
			overlays_standing[UNIFORM_LAYER] = standing
			apply_overlay(UNIFORM_LAYER)


	// Saved for history .\_/.

	/*else if(!dna.species.nojumpsuit)
		var/list/uniform_slots = list()
		var/obj/item/organ/external/L = get_organ(BODY_ZONE_L_LEG)
		if(!(L?.status & ORGAN_ROBOT))
			uniform_slots += l_store
		var/obj/item/organ/external/R = get_organ(BODY_ZONE_R_LEG)
		if(!(R?.status & ORGAN_ROBOT))
			uniform_slots += r_store
		var/obj/item/organ/external/C = get_organ(BODY_ZONE_CHEST)
		if(!(C?.status & ORGAN_ROBOT))
			uniform_slots += wear_id
			uniform_slots += wear_pda
			uniform_slots += belt

		// Automatically drop anything in store / id / belt if you're not wearing a uniform.	//CHECK IF NECESARRY
		for(var/obj/item/thing in uniform_slots)												// whoever made this
			if(thing)																			// you're a piece of fucking garbage
				unEquip(thing)																	// why the fuck would you goddamn do this motherfucking shit
				if(client)																		// INVENTORY CODE IN FUCKING ICON CODE
					client.screen -= thing														// WHAT THE FUCKING FUCK BAY GODDAMNIT
																								// **I FUCKING HATE YOU AAAAAAAAAA**
				if(thing)																		//
					thing.forceMove(drop_location())											//
					thing.dropped(src)															//
					thing.layer = initial(thing.layer)
					thing.plane = initial(thing.plane)*/

/mob/living/carbon/human/update_inv_wear_id()
	remove_overlay(ID_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_ID) + 1]
		inv?.update_icon()

	if(wear_id)
		if(client && hud_used && hud_used.hud_shown)
			wear_id.screen_loc = ui_id
			client.screen += wear_id

		if(w_uniform?.displays_id)
			overlays_standing[ID_LAYER]	= mutable_appearance(wear_id.onmob_sheets[ITEM_SLOT_ID_STRING], "id", layer = -ID_LAYER)
	apply_overlay(ID_LAYER)

/mob/living/carbon/human/update_inv_gloves()
	remove_overlay(GLOVES_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_GLOVES) + 1]
		inv?.update_icon()

	if(gloves)
		if(client && hud_used && hud_used.hud_shown)
			if(hud_used.inventory_shown)			//if the inventory is open ...
				gloves.screen_loc = ui_gloves		//...draw the item in the inventory screen
			client.screen += gloves					//Either way, add the item to the HUD

		var/t_state = gloves.item_state
		if(!t_state)	t_state = gloves.icon_state

		var/mutable_appearance/standing
		if(gloves.sprite_sheets && gloves.sprite_sheets[dna.species.name])
			standing = mutable_appearance(gloves.sprite_sheets[dna.species.name], "[t_state]", layer = -GLOVES_LAYER)
		else
			standing = mutable_appearance(gloves.onmob_sheets[ITEM_SLOT_GLOVES_STRING], "[t_state]", layer = -GLOVES_LAYER)

		if(gloves.blood_DNA)
			var/image/bloodsies	= image("icon" = dna.species.blood_mask, "icon_state" = "bloodyhands")
			bloodsies.color = gloves.blood_color
			standing.overlays += bloodsies
		overlays_standing[GLOVES_LAYER]	= standing
	else
		if(blood_DNA)
			var/mutable_appearance/bloodsies = mutable_appearance(dna.species.blood_mask, "bloodyhands", layer = -GLOVES_LAYER)
			bloodsies.color = hand_blood_color
			overlays_standing[GLOVES_LAYER]	= bloodsies
		else if(HAS_TRAIT(src, CLOCK_HANDS))
			var/mutable_appearance/flashies = mutable_appearance(dna.species.blood_mask, "clockedhands", layer = -GLOVES_LAYER)
			flashies.color = CLOCK_COLOR
			overlays_standing[GLOVES_LAYER]	= flashies
	apply_overlay(GLOVES_LAYER)


/mob/living/carbon/human/update_inv_glasses()
	remove_overlay(GLASSES_LAYER)
	remove_overlay(GLASSES_OVER_LAYER)
	remove_overlay(OVER_MASK_LAYER)
	remove_overlay(OVER_HEAD_LAYER)

	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_EYES) + 1]
		inv?.update_icon()

	if(glasses)
		var/mutable_appearance/new_glasses
		var/obj/item/organ/external/head/head_organ = get_organ(BODY_ZONE_HEAD)
		if(client && hud_used && hud_used.hud_shown)
			if(hud_used.inventory_shown)			//if the inventory is open ...
				glasses.screen_loc = ui_glasses		//...draw the item in the inventory screen
			client.screen += glasses				//Either way, add the item to the HUD

		if(glasses.sprite_sheets && glasses.sprite_sheets[head_organ.dna.species.name])
			new_glasses = mutable_appearance(glasses.sprite_sheets[head_organ.dna.species.name], "[glasses.icon_state]", layer = -GLASSES_LAYER)
		else
			new_glasses = mutable_appearance(glasses.onmob_sheets[ITEM_SLOT_EYES_STRING], "[glasses.icon_state]", layer = -GLASSES_LAYER)

		new_glasses.alpha = glasses.alpha
		new_glasses.color = glasses.color

		var/datum/sprite_accessory/hair/hair_style = GLOB.hair_styles_full_list[head_organ.h_style]
		var/obj/item/clothing/glasses/G = glasses
		if(head && !(head.flags_cover & HEADCOVERSEYES) && G.over_hat && istype(G))
			new_glasses.layer = -OVER_HEAD_LAYER
			overlays_standing[OVER_HEAD_LAYER] = new_glasses
			apply_overlay(OVER_HEAD_LAYER)
		else if(istype(G) && G.over_mask) //If the user's used the 'wear over mask' verb on the glasses.
			new_glasses.layer = -OVER_MASK_LAYER
			overlays_standing[OVER_MASK_LAYER] = new_glasses
			apply_overlay(OVER_MASK_LAYER)
		else if(hair_style && hair_style.glasses_over) //Select which layer to use based on the properties of the hair style. Hair styles with hair that don't overhang the arms of the glasses should have glasses_over set to a positive value.
			new_glasses.layer = -GLASSES_OVER_LAYER
			overlays_standing[GLASSES_OVER_LAYER] = new_glasses
			apply_overlay(GLASSES_OVER_LAYER)
		else
			overlays_standing[GLASSES_LAYER] = new_glasses
			apply_overlay(GLASSES_LAYER)

	update_misc_effects()

/mob/living/carbon/human/update_inv_ears()
	remove_overlay(EARS_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_EAR_LEFT) + 1]
		inv?.update_icon()
		inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_EAR_RIGHT) + 1]
		inv?.update_icon()

	if(l_ear || r_ear)
		if(l_ear)
			if(client && hud_used && hud_used.hud_shown)
				if(hud_used.inventory_shown)			//if the inventory is open ...
					l_ear.screen_loc = ui_l_ear			//...draw the item in the inventory screen
				client.screen += l_ear					//Either way, add the item to the HUD

			var/t_type = l_ear.item_state
			if(!t_type)
				t_type = l_ear.icon_state
			if(l_ear.sprite_sheets && l_ear.sprite_sheets[dna.species.name])
				overlays_standing[EARS_LAYER] = mutable_appearance(l_ear.sprite_sheets[dna.species.name], "[t_type]", layer = -EARS_LAYER)
			else
				overlays_standing[EARS_LAYER] = mutable_appearance(l_ear.onmob_sheets[ITEM_SLOT_EAR_LEFT_STRING], "[t_type]", layer = -EARS_LAYER)

		if(r_ear)
			if(client && hud_used && hud_used.hud_shown)
				if(hud_used.inventory_shown)			//if the inventory is open ...
					r_ear.screen_loc = ui_r_ear			//...draw the item in the inventory screen
				client.screen += r_ear					//Either way, add the item to the HUD

			var/t_type = r_ear.item_state
			if(!t_type)
				t_type = r_ear.icon_state
			if(r_ear.sprite_sheets && r_ear.sprite_sheets[dna.species.name])
				overlays_standing[EARS_LAYER] = mutable_appearance(r_ear.sprite_sheets[dna.species.name], "[t_type]", layer = -EARS_LAYER)
			else
				overlays_standing[EARS_LAYER] = mutable_appearance(r_ear.onmob_sheets[ITEM_SLOT_EAR_RIGHT_STRING], "[t_type]", layer = -EARS_LAYER)
	apply_overlay(EARS_LAYER)

/mob/living/carbon/human/update_inv_shoes()
	remove_overlay(SHOES_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_FEET) + 1]
		inv?.update_icon()

	if(shoes)
		if(client && hud_used && hud_used.hud_shown)
			if(hud_used.inventory_shown)			//if the inventory is open ...
				shoes.screen_loc = ui_shoes			//...draw the item in the inventory screen
			client.screen += shoes					//Either way, add the item to the HUD

		if(!wear_suit || !(wear_suit.flags_inv & HIDESHOES))
			var/mutable_appearance/standing
			if(shoes.sprite_sheets && shoes.sprite_sheets[dna.species.name])
				standing = mutable_appearance(shoes.sprite_sheets[dna.species.name], "[shoes.icon_state]", layer = -SHOES_LAYER)
			else
				standing = mutable_appearance(shoes.onmob_sheets[ITEM_SLOT_FEET_STRING], "[shoes.icon_state]", layer = -SHOES_LAYER)


			if(shoes.blood_DNA)
				var/image/bloodsies = image("icon" = dna.species.blood_mask, "icon_state" = "shoeblood")
				bloodsies.color = shoes.blood_color
				standing.overlays += bloodsies
			standing.alpha = shoes.alpha
			standing.color = shoes.color
			overlays_standing[SHOES_LAYER] = standing
	else
		if(feet_blood_DNA)
			var/mutable_appearance/bloodsies = mutable_appearance(dna.species.blood_mask, "shoeblood", layer = -SHOES_LAYER)
			bloodsies.color = feet_blood_color
			overlays_standing[SHOES_LAYER] = bloodsies
	apply_overlay(SHOES_LAYER)

/mob/living/carbon/human/update_inv_s_store()
	remove_overlay(SUIT_STORE_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_SUITSTORE) + 1]
		inv?.update_icon()

	if(s_store)
		if(client && hud_used && hud_used.hud_shown)
			s_store.screen_loc = ui_sstore1
			client.screen += s_store

		var/t_state = s_store.item_state
		if(!t_state)
			t_state = s_store.icon_state
		overlays_standing[SUIT_STORE_LAYER] = mutable_appearance(s_store.onmob_sheets[ITEM_SLOT_SUITSTORE_STRING], "[t_state]", layer = -SUIT_STORE_LAYER)
		s_store.screen_loc = ui_sstore1		//TODO
	apply_overlay(SUIT_STORE_LAYER)

/mob/living/carbon/human/update_inv_head()
	..()
	remove_overlay(HEAD_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_HEAD) + 1]
		inv?.update_icon()

	if(head)
		var/mutable_appearance/standing
		if(head.sprite_sheets && head.sprite_sheets[dna.species.name])
			standing = mutable_appearance(head.sprite_sheets[dna.species.name], "[head.icon_state]", layer = -HEAD_LAYER)
		else
			standing = mutable_appearance(head.onmob_sheets[ITEM_SLOT_HEAD_STRING], "[head.icon_state]", layer = -HEAD_LAYER)

		if(head.blood_DNA)
			var/image/bloodsies = image("icon" = dna.species.blood_mask, "icon_state" = "helmetblood")
			bloodsies.color = head.blood_color
			standing.overlays += bloodsies
		standing.alpha = head.alpha
		standing.color = head.color
		overlays_standing[HEAD_LAYER] = standing
	apply_overlay(HEAD_LAYER)

/mob/living/carbon/human/update_inv_belt()
	remove_overlay(BELT_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_BELT) + 1]
		inv?.update_icon()

	if(belt)
		if(hud_used?.hud_shown && belt)
			client.screen += belt
			belt.screen_loc = ui_belt

		var/t_state = belt.item_state
		if(!t_state)
			t_state = belt.icon_state

		if(belt.sprite_sheets && belt.sprite_sheets[dna.species.name])
			overlays_standing[BELT_LAYER] = mutable_appearance(belt.sprite_sheets[dna.species.name], "[t_state]", layer = -BELT_LAYER)
		else
			overlays_standing[BELT_LAYER] = mutable_appearance(belt.onmob_sheets[ITEM_SLOT_BELT_STRING], "[t_state]", layer = -BELT_LAYER)
	apply_overlay(BELT_LAYER)

/mob/living/carbon/human/update_inv_wear_suit()
	remove_overlay(SUIT_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_CLOTH_OUTER) + 1]
		inv?.update_icon()

	if(istype(wear_suit, /obj/item/clothing/suit))
		if(client && hud_used && hud_used.hud_shown)
			if(hud_used.inventory_shown)					//if the inventory is open ...
				wear_suit.screen_loc = ui_oclothing	//TODO	//...draw the item in the inventory screen
			client.screen += wear_suit						//Either way, add the item to the HUD

		var/mutable_appearance/standing
		if(wear_suit.sprite_sheets && wear_suit.sprite_sheets[dna.species.name])
			standing = mutable_appearance(wear_suit.sprite_sheets[dna.species.name], "[wear_suit.icon_state]", layer = -SUIT_LAYER)
		else
			standing = mutable_appearance(wear_suit.onmob_sheets[ITEM_SLOT_CLOTH_OUTER_STRING], "[wear_suit.icon_state]", layer = -SUIT_LAYER)

		if(wear_suit.breakouttime)
			drop_l_hand()
			drop_r_hand()

		if(wear_suit.blood_DNA)
			var/obj/item/clothing/suit/S = wear_suit
			var/image/bloodsies = image("icon" = dna.species.blood_mask, "icon_state" = "[S.blood_overlay_type]blood")
			bloodsies.color = wear_suit.blood_color
			standing.overlays += bloodsies


		var/special_overlays = wear_suit.special_overlays()
		if(special_overlays)
			standing.overlays += special_overlays

		standing.alpha = wear_suit.alpha
		standing.color = wear_suit.color
		overlays_standing[SUIT_LAYER] = standing

	apply_overlay(SUIT_LAYER)
	update_tail_layer()
	update_wing_layer()
	update_collar()

/mob/living/carbon/human/update_inv_pockets()
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_POCKET_LEFT) + 1]
		inv?.update_icon()
		inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_POCKET_RIGHT) + 1]
		inv?.update_icon()

		if(hud_used.hud_shown)
			if(l_store)
				client.screen += l_store
				l_store.screen_loc = ui_storage1

			if(r_store)
				client.screen += r_store
				r_store.screen_loc = ui_storage2

/mob/living/carbon/human/update_inv_wear_pda()
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_PDA) + 1]
		inv?.update_icon()

		if(wear_pda)
			client.screen += wear_pda
			wear_pda.screen_loc = ui_pda

/mob/living/carbon/human/update_inv_wear_mask()
	..()
	remove_overlay(FACEMASK_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_MASK) + 1]
		inv?.update_icon()

	if((istype(wear_mask, /obj/item/clothing/mask) || istype(wear_mask, /obj/item/clothing/accessory)))
		if(!(ITEM_SLOT_MASK & check_obscured_slots()))
			var/obj/item/organ/external/head/head_organ = get_organ(BODY_ZONE_HEAD)
			if(!head_organ)
				return // Nothing to update here
			var/datum/sprite_accessory/alt_heads/alternate_head
			if(head_organ.alt_head && head_organ.alt_head != "None")
				alternate_head = GLOB.alt_heads_list[head_organ.alt_head]

			var/mutable_appearance/standing
			var/icon/mask_icon = new(wear_mask.icon)
			if(wear_mask.sprite_sheets && wear_mask.sprite_sheets[dna.species.name])
				mask_icon = new(wear_mask.sprite_sheets[dna.species.name])
				standing = mutable_appearance(wear_mask.sprite_sheets[dna.species.name], "[wear_mask.icon_state][(alternate_head && ("[wear_mask.icon_state]_[alternate_head.suffix]" in mask_icon.IconStates())) ? "_[alternate_head.suffix]" : ""]", layer = -FACEMASK_LAYER)
			else
				standing = mutable_appearance(wear_mask.onmob_sheets[ITEM_SLOT_MASK_STRING], "[wear_mask.icon_state][(alternate_head && ("[wear_mask.icon_state]_[alternate_head.suffix]" in mask_icon.IconStates())) ? "_[alternate_head.suffix]" : ""]", layer = -FACEMASK_LAYER)

			if(!istype(wear_mask, /obj/item/clothing/mask/cigarette) && wear_mask.blood_DNA)
				var/image/bloodsies = image("icon" = dna.species.blood_mask, "icon_state" = "maskblood")
				bloodsies.color = wear_mask.blood_color
				standing.overlays += bloodsies

			standing.alpha = wear_mask.alpha
			standing.color = wear_mask.color
			overlays_standing[FACEMASK_LAYER] = standing
	apply_overlay(FACEMASK_LAYER)

/mob/living/carbon/human/update_inv_neck()
	remove_overlay(NECK_LAYER)
	if(client && hud_used)
		var/obj/screen/inventory/inv = hud_used.inv_slots[TOBITSHIFT(ITEM_SLOT_NECK) + 1]
		inv?.update_icon()

	if(neck)
		if(client && hud_used?.hud_shown)
			if(hud_used.inventory_shown)
				neck.screen_loc = ui_neck
			client.screen += neck

		var/mutable_appearance/standing
		if(neck.sprite_sheets && neck.sprite_sheets[dna.species.name])
			standing = mutable_appearance(neck.sprite_sheets[dna.species.name], "[neck.icon_state]", layer = -NECK_LAYER)
		else
			standing = mutable_appearance(neck.onmob_sheets[ITEM_SLOT_NECK_STRING], "[neck.icon_state]", layer = -NECK_LAYER)
		standing.alpha = neck.alpha
		standing.color = neck.color
		overlays_standing[NECK_LAYER] = standing
	apply_overlay(NECK_LAYER)

/mob/living/carbon/human/update_inv_back()
	..()
	remove_overlay(BACK_LAYER)
	if(back)
		//determine the icon to use
		var/mutable_appearance/standing

		if(back.sprite_sheets && back.sprite_sheets[dna.species.name])
			standing = mutable_appearance(back.sprite_sheets[dna.species.name], "[back.icon_state]", layer = -BACK_LAYER)
		else
			standing = mutable_appearance(back.onmob_sheets[ITEM_SLOT_BACK_STRING], "[back.icon_state]", layer = -BACK_LAYER)

		//create the image
		standing.alpha = back.alpha
		standing.color = back.color
		overlays_standing[BACK_LAYER] = standing
	apply_overlay(BACK_LAYER)

/mob/living/carbon/human/update_inv_handcuffed()
	remove_overlay(HANDCUFF_LAYER)
	if(handcuffed)
		overlays_standing[HANDCUFF_LAYER] = mutable_appearance(handcuffed.onmob_sheets[ITEM_SLOT_HANDCUFFED_STRING], "[handcuffed.item_state]_hands", layer = -HANDCUFF_LAYER)
	apply_overlay(HANDCUFF_LAYER)

/mob/living/carbon/human/update_inv_legcuffed()
	remove_overlay(LEGCUFF_LAYER)
	if(legcuffed)
		overlays_standing[LEGCUFF_LAYER] = mutable_appearance(legcuffed.onmob_sheets[ITEM_SLOT_LEGCUFFED_STRING], "[legcuffed.item_state]_legs", layer = -LEGCUFF_LAYER)
	apply_overlay(LEGCUFF_LAYER)


/mob/living/carbon/human/update_inv_r_hand()
	..()
	remove_overlay(R_HAND_LAYER)
	if(r_hand)
		var/t_state = r_hand.item_state
		if(!t_state)
			t_state = r_hand.icon_state

		var/mutable_appearance/standing
		if(r_hand.sprite_sheets_inhand && r_hand.sprite_sheets_inhand[dna.species.name])
			t_state = "[t_state]_r"
			standing = mutable_appearance(r_hand.sprite_sheets_inhand[dna.species.name], "[t_state]", layer = -R_HAND_LAYER)
		else
			standing = mutable_appearance(r_hand.righthand_file, "[t_state]", layer = -R_HAND_LAYER)
			standing = center_image(standing, r_hand.inhand_x_dimension, r_hand.inhand_y_dimension)
		standing.color = r_hand.color
		standing.alpha = r_hand.alpha
		overlays_standing[R_HAND_LAYER] = standing
	apply_overlay(R_HAND_LAYER)


/mob/living/carbon/human/update_inv_l_hand()
	..()
	remove_overlay(L_HAND_LAYER)
	if(l_hand)
		var/t_state = l_hand.item_state
		if(!t_state)
			t_state = l_hand.icon_state

		var/mutable_appearance/standing
		if(l_hand.sprite_sheets_inhand && l_hand.sprite_sheets_inhand[dna.species.name])
			t_state = "[t_state]_l"
			standing = mutable_appearance(l_hand.sprite_sheets_inhand[dna.species.name], "[t_state]", layer = -L_HAND_LAYER)
		else
			standing = mutable_appearance(l_hand.lefthand_file, "[t_state]", layer = -L_HAND_LAYER)
			standing = center_image(standing, l_hand.inhand_x_dimension, l_hand.inhand_y_dimension)
		standing.color = l_hand.color
		standing.alpha = l_hand.alpha
		overlays_standing[L_HAND_LAYER] = standing
	apply_overlay(L_HAND_LAYER)

//human HUD updates for items in our inventory

//update whether our head item appears on our hud.
/mob/living/carbon/human/update_hud_head(obj/item/I)
	if(client && hud_used && hud_used.hud_shown)
		if(hud_used.inventory_shown)
			I.screen_loc = ui_head
		client.screen += I

//update whether our mask item appears on our hud.
/mob/living/carbon/human/update_hud_wear_mask(obj/item/I)
	if(client && hud_used && hud_used.hud_shown)
		if(hud_used.inventory_shown)
			I.screen_loc = ui_mask
		client.screen += I

//update whether our back item appears on our hud.
/mob/living/carbon/human/update_hud_back(obj/item/I)
	if(client && hud_used && hud_used.hud_shown)
		I.screen_loc = ui_back
		client.screen += I

/mob/living/carbon/human/proc/update_wing_layer()
	remove_overlay(WING_UNDERLIMBS_LAYER)
	remove_overlay(WING_LAYER)

	var/obj/item/organ/external/wing/bodypart_wing = get_organ(BODY_ZONE_WING)
	if(!bodypart_wing)
		return
	if(!istype(bodypart_wing.body_accessory, /datum/body_accessory/wing))
		if(dna.species.optional_body_accessory)
			return
		else
			bodypart_wing.body_accessory = GLOB.body_accessory_by_name[dna.species.default_bodyacc]

	var/icon/accessory_s = new/icon("icon" = bodypart_wing.body_accessory.icon, "icon_state" = bodypart_wing.body_accessory.icon_state)
	var/mutable_appearance/wings = mutable_appearance(bodypart_wing.body_accessory.icon, bodypart_wing.body_accessory.icon_state, layer = -WING_LAYER)
	wings.pixel_x = bodypart_wing.body_accessory.pixel_x_offset
	wings.pixel_y = bodypart_wing.body_accessory.pixel_y_offset
	overlays_standing[WING_LAYER] = wings

	if(bodypart_wing.body_accessory.has_behind)
		var/mutable_appearance/under_wing = mutable_appearance(bodypart_wing.body_accessory.icon, "[bodypart_wing.body_accessory.icon_state]_BEHIND", layer = -WING_UNDERLIMBS_LAYER)
		under_wing.pixel_x = bodypart_wing.body_accessory.pixel_x_offset
		under_wing.pixel_y = bodypart_wing.body_accessory.pixel_y_offset
		overlays_standing[WING_UNDERLIMBS_LAYER] = under_wing
		var/icon/tempicon = new/icon(accessory_s,dir=NORTH)
		tempicon.Flip(SOUTH)
		accessory_s.Insert(tempicon,dir=SOUTH)
		bodypart_wing.force_icon = accessory_s
		bodypart_wing.icon_name = null

	bodypart_wing.get_icon()
	apply_overlay(WING_UNDERLIMBS_LAYER)
	apply_overlay(WING_LAYER)

/mob/living/carbon/human/proc/update_tail_layer()
	remove_overlay(TAIL_UNDERLIMBS_LAYER) // SEW direction icons, overlayed by LIMBS_LAYER.
	remove_overlay(TAIL_LAYER) /* This will be one of two things:
							If the species' tail is overlapped by limbs, this will be only the N direction icon so tails
							can still appear on the outside of uniforms and such.
							Otherwise, since the user's tail isn't overlapped by limbs, it will be a full icon with all directions. */

	var/obj/item/organ/external/tail/bodypart_tail = get_organ(BODY_ZONE_TAIL)
	if(!bodypart_tail) // No tail - no overlay!
		return

	var/icon/tail_marking_icon
	var/datum/sprite_accessory/body_markings/tail/tail_marking_style
	if(bodypart_tail.m_styles["tail"] != "None" && (bodypart_tail.dna.species.bodyflags & HAS_TAIL_MARKINGS))
		var/tail_marking = bodypart_tail.m_styles["tail"]
		tail_marking_style = GLOB.marking_styles_list[tail_marking]
		tail_marking_icon = new/icon("icon" = tail_marking_style.icon, "icon_state" = "[tail_marking_style.icon_state]_s")
		tail_marking_icon.Blend(bodypart_tail.m_colours["tail"], ICON_ADD)


	if(bodypart_tail.body_accessory)
		if(bodypart_tail.body_accessory.try_restrictions(src))
			var/icon/accessory_s = new/icon("icon" = bodypart_tail.body_accessory.icon, "icon_state" = bodypart_tail.body_accessory.icon_state)
			if(bodypart_tail.dna.species.bodyflags & HAS_SKIN_COLOR)
				if(!(bodypart_tail.dna.species.bodyflags & HAS_ICON_SKIN_TONE))
					accessory_s.Blend(bodypart_tail.s_col, bodypart_tail.body_accessory.blend_mode)
			if(tail_marking_icon && (bodypart_tail.body_accessory.name in tail_marking_style.tails_allowed))
				accessory_s.Blend(tail_marking_icon, ICON_OVERLAY)
			if(istype(bodypart_tail.body_accessory, /datum/body_accessory/tail) && bodypart_tail.dna.species.bodyflags & TAIL_OVERLAPPED) // If the player has a species whose tail is overlapped by limbs... (having a non-tail body accessory like the snake body will override this)
				// Gives the underlimbs layer SEW direction icons since it's overlayed by limbs and just about everything else anyway.
				var/icon/under = new/icon("icon" = 'icons/mob/clothing/body_accessory.dmi', "icon_state" = "accessory_none_s")
				under.Insert(new/icon(accessory_s, dir=SOUTH), dir=SOUTH)
				under.Insert(new/icon(accessory_s, dir=EAST), dir=EAST)
				under.Insert(new/icon(accessory_s, dir=WEST), dir=WEST)

				var/mutable_appearance/underlimbs = mutable_appearance(under, layer = -TAIL_UNDERLIMBS_LAYER)
				underlimbs.pixel_x = bodypart_tail.body_accessory.pixel_x_offset
				underlimbs.pixel_y = bodypart_tail.body_accessory.pixel_y_offset
				overlays_standing[TAIL_UNDERLIMBS_LAYER] = underlimbs

				// Creates a blank icon, and copies accessory_s' north direction sprite into it
				// before passing that to the tail layer that overlays uniforms and such.
				var/icon/over = new/icon("icon" = 'icons/mob/clothing/body_accessory.dmi', "icon_state" = "accessory_none_s")
				over.Insert(new/icon(accessory_s, dir=NORTH), dir=NORTH)

				var/mutable_appearance/tail = mutable_appearance(over, layer = -TAIL_LAYER)
				tail.pixel_x = bodypart_tail.body_accessory.pixel_x_offset
				tail.pixel_y = bodypart_tail.body_accessory.pixel_y_offset
				overlays_standing[TAIL_LAYER] = tail
			else // Otherwise, since the user's tail isn't overlapped by limbs, go ahead and use default icon generation.
				var/mutable_appearance/tail = mutable_appearance(accessory_s, layer = -TAIL_LAYER)
				tail.pixel_x = bodypart_tail.body_accessory.pixel_x_offset
				tail.pixel_y = bodypart_tail.body_accessory.pixel_y_offset
				overlays_standing[TAIL_LAYER] = tail

			var/icon/tempicon = new/icon(accessory_s,dir=NORTH)
			tempicon.Flip(SOUTH)
			accessory_s.Insert(tempicon,dir=SOUTH)
			bodypart_tail.force_icon = accessory_s
			bodypart_tail.icon_name = null

	else
		if(!wear_suit || !(wear_suit.flags_inv & HIDETAIL))
			var/icon/tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_s")
			switch(tail)
				if("voxtail_azu") //Azure Vox.
					tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_azu_s")
				if("voxtail_emrl") //Emerald Vox.
					tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_emrl_s")
				if("voxtail_gry") //Grey Vox.
					tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_gry_s")
				if("voxtail_brn") //Brown Vox.
					tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_brn_s")
				if("voxtail_dgrn") //Dark Green Vox.
					tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_dgrn_s")
				else  //Default behaviour
					tail_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_s")
			if(bodypart_tail.dna.species.bodyflags & HAS_SKIN_COLOR)
				if(!(bodypart_tail.dna.species.bodyflags & HAS_ICON_SKIN_TONE))
					tail_s.Blend(bodypart_tail.s_col, ICON_ADD)
			if(tail_marking_icon && !tail_marking_style.tails_allowed)
				tail_s.Blend(tail_marking_icon, ICON_OVERLAY)
			if(istype(bodypart_tail.body_accessory, /datum/body_accessory/tail) && bodypart_tail.dna.species.bodyflags & TAIL_OVERLAPPED) // If the player has a species whose tail is overlapped by limbs... (having a non-tail body accessory like the snake body will override this)
				// Gives the underlimbs layer SEW direction icons since it's overlayed by limbs and just about everything else anyway.
				var/icon/under = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "blank")
				under.Insert(new/icon(tail_s, dir=SOUTH), dir=SOUTH)
				under.Insert(new/icon(tail_s, dir=EAST), dir=EAST)
				under.Insert(new/icon(tail_s, dir=WEST), dir=WEST)

				overlays_standing[TAIL_UNDERLIMBS_LAYER] = mutable_appearance(under, layer = -TAIL_UNDERLIMBS_LAYER)

				// Creates a blank icon, and copies accessory_s' north direction sprite into it before passing that to the tail layer that overlays uniforms and such.
				var/icon/over = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "blank")
				over.Insert(new/icon(tail_s, dir=NORTH), dir=NORTH)

				overlays_standing[TAIL_LAYER] = mutable_appearance(over, layer = -TAIL_LAYER)
			else // Otherwise, since the user's tail isn't overlapped by limbs, go ahead and use default icon generation.
				overlays_standing[TAIL_LAYER] = mutable_appearance(tail_s, layer = -TAIL_LAYER)

			var/icon/tempicon = new/icon(tail_s,dir=NORTH)
			tempicon.Flip(SOUTH)
			tail_s.Insert(tempicon,dir=SOUTH)
			bodypart_tail.force_icon = tail_s
			bodypart_tail.icon_name = null
	bodypart_tail.get_icon()
	apply_overlay(TAIL_LAYER)
	apply_overlay(TAIL_UNDERLIMBS_LAYER)

/mob/living/carbon/human/proc/start_tail_wagging()
	remove_overlay(TAIL_UNDERLIMBS_LAYER) // SEW direction icons, overlayed by LIMBS_LAYER.
	remove_overlay(TAIL_LAYER) /* This will be one of two things:
							If the species' tail is overlapped by limbs, this will be only the N direction icon so tails
							can still appear on the outside of uniforms and such.
							Otherwise, since the user's tail isn't overlapped by limbs, it will be a full icon with all directions. */

	var/obj/item/organ/external/tail/bodypart_tail = get_organ(BODY_ZONE_TAIL)
	if(!bodypart_tail) // No tail - no overlay!
		return

	var/icon/tail_marking_icon
	var/datum/sprite_accessory/body_markings/tail/tail_marking_style
	if(bodypart_tail.m_styles["tail"] != "None" && (bodypart_tail.dna.species.bodyflags & HAS_TAIL_MARKINGS))
		var/tail_marking = bodypart_tail.m_styles["tail"]
		tail_marking_style = GLOB.marking_styles_list[tail_marking]
		tail_marking_icon = new/icon("icon" = tail_marking_style.icon, "icon_state" = "[tail_marking_style.icon_state]w_s")
		tail_marking_icon.Blend(bodypart_tail.m_colours["tail"], ICON_ADD)

	if(bodypart_tail.body_accessory)
		var/icon/accessory_s = new/icon("icon" = bodypart_tail.body_accessory.get_animated_icon(), "icon_state" = bodypart_tail.body_accessory.get_animated_icon_state())
		if(bodypart_tail.dna.species.bodyflags & HAS_SKIN_COLOR)
			if(!(bodypart_tail.dna.species.bodyflags & HAS_ICON_SKIN_TONE))
				accessory_s.Blend(bodypart_tail.s_col, bodypart_tail.body_accessory.blend_mode)
		if(tail_marking_icon && (bodypart_tail.body_accessory.name in tail_marking_style.tails_allowed))
			accessory_s.Blend(tail_marking_icon, ICON_OVERLAY)
		if(istype(bodypart_tail.body_accessory, /datum/body_accessory/tail) && bodypart_tail.dna.species.bodyflags & TAIL_OVERLAPPED) // If the player has a species whose tail is overlapped by limbs... (having a non-tail body accessory like the snake body will override this)
			// Gives the underlimbs layer SEW direction icons since it's overlayed by limbs and just about everything else anyway.
			var/icon/under = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.name]_tail_delay")
			under.Insert(new/icon(accessory_s, dir=SOUTH), dir=SOUTH)
			under.Insert(new/icon(accessory_s, dir=EAST), dir=EAST)
			under.Insert(new/icon(accessory_s, dir=WEST), dir=WEST)

			var/mutable_appearance/underlimbs = mutable_appearance(under, layer = -TAIL_UNDERLIMBS_LAYER)
			underlimbs.pixel_x = bodypart_tail.body_accessory.pixel_x_offset
			underlimbs.pixel_y = bodypart_tail.body_accessory.pixel_y_offset
			overlays_standing[TAIL_UNDERLIMBS_LAYER] = underlimbs

			// Creates a blank icon, and copies accessory_s' north direction sprite into it before passing that to the tail layer that overlays uniforms and such.
			var/icon/over = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.name]_tail_delay")
			over.Insert(new/icon(accessory_s, dir=NORTH), dir=NORTH)

			var/mutable_appearance/tail = mutable_appearance(over, layer = -TAIL_LAYER)
			tail.pixel_x = bodypart_tail.body_accessory.pixel_x_offset
			tail.pixel_y = bodypart_tail.body_accessory.pixel_y_offset
			overlays_standing[TAIL_LAYER] = tail
		else // Otherwise, since the user's tail isn't overlapped by limbs, go ahead and use default icon generation.
			var/mutable_appearance/tail = mutable_appearance(accessory_s, layer = -TAIL_LAYER)
			tail.pixel_x = bodypart_tail.body_accessory.pixel_x_offset
			tail.pixel_y = bodypart_tail.body_accessory.pixel_y_offset
			overlays_standing[TAIL_LAYER] = tail

	else
		var/icon/tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]w_s")
		switch(tail)
			if("voxtail_azu") //Azure Vox.
				tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_azuw_s")
			if("voxtail_emrl") //Emerald Vox.
				tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_emrlw_s")
			if("voxtail_gry") //Grey Vox.
				tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_gryw_s")
			if("voxtail_brn") //Brown Vox.
				tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_brnw_s")
			if("voxtail_dgrn") //Dark Green Vox.
				tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]_dgrnw_s")
			else  //Default behaviour
				tailw_s = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.tail]w_s")
		if(bodypart_tail.dna.species.bodyflags & HAS_SKIN_COLOR)
			if(!(bodypart_tail.dna.species.bodyflags & HAS_ICON_SKIN_TONE))
				tailw_s.Blend(bodypart_tail.s_col, ICON_ADD)
		if(tail_marking_icon && !tail_marking_style.tails_allowed)
			tailw_s.Blend(tail_marking_icon, ICON_OVERLAY)
		if(istype(bodypart_tail.body_accessory, /datum/body_accessory/tail) && bodypart_tail.dna.species.bodyflags & TAIL_OVERLAPPED) // If the player has a species whose tail is overlapped by limbs... (having a non-tail body accessory like the snake body will override this)
			// Gives the underlimbs layer SEW direction icons since it's overlayed by limbs and just about everything else anyway.
			var/icon/under = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.name]_tail_delay")
			under.Insert(new/icon(tailw_s, dir=SOUTH), dir=SOUTH)
			under.Insert(new/icon(tailw_s, dir=EAST), dir=EAST)
			under.Insert(new/icon(tailw_s, dir=WEST), dir=WEST)

			overlays_standing[TAIL_UNDERLIMBS_LAYER] = mutable_appearance(under, layer = -TAIL_UNDERLIMBS_LAYER)

			// Creates a blank icon, and copies accessory_s' north direction sprite into it before passing that to the tail layer that overlays uniforms and such.
			var/icon/over = new/icon("icon" = 'icons/effects/species.dmi', "icon_state" = "[bodypart_tail.dna.species.name]_tail_delay")
			over.Insert(new/icon(tailw_s, dir=NORTH), dir=NORTH)

			overlays_standing[TAIL_LAYER] = mutable_appearance(over, layer = -TAIL_LAYER)
		else // Otherwise, since the user's tail isn't overlapped by limbs, go ahead and use default icon generation.
			overlays_standing[TAIL_LAYER] = mutable_appearance(tailw_s, layer = -TAIL_LAYER)
	apply_overlay(TAIL_LAYER)
	apply_overlay(TAIL_UNDERLIMBS_LAYER)

/mob/living/carbon/human/proc/stop_tail_wagging()
	remove_overlay(TAIL_UNDERLIMBS_LAYER)
	remove_overlay(TAIL_LAYER)
	update_tail_layer() //just trigger a full update for normal stationary sprites

/mob/living/carbon/human/proc/update_int_organs()
	remove_overlay(INTORGAN_LAYER)

	var/list/standing = list()
	for(var/obj/item/organ/internal/organ as anything in internal_organs)
		var/render = organ.render()
		if(render)
			standing += render

	overlays_standing[INTORGAN_LAYER] = standing
	apply_overlay(INTORGAN_LAYER)

/mob/living/carbon/human/handle_transform_change()
	..()
	update_tail_layer()
	update_wing_layer()

//Adds a collar overlay above the helmet layer if the suit has one
//	Suit needs an identically named sprite in icons/mob/clothing/collar.dmi
//  For suits with sprite_sheets, an identically named sprite needs to exist in a file like this icons/mob/clothing/species/[species_name_here]/collar.dmi.
/mob/living/carbon/human/proc/update_collar()
	remove_overlay(COLLAR_LAYER)
	var/icon/C = null
	var/mutable_appearance/standing = null

	if(wear_suit)
		C = new(wear_suit.onmob_sheets[ITEM_SLOT_COLLAR_STRING])
		if(wear_suit.sprite_sheets && wear_suit.sprite_sheets[dna.species.name])
			var/icon_path = "[wear_suit.sprite_sheets[dna.species.name]]"
			icon_path = "[copytext(icon_path, 1, findtext(icon_path, "/suit.dmi"))]/collar.dmi" //If this file doesn't exist, the end result is that COLLAR_LAYER will be unchanged (empty).
			if(fexists(icon_path)) //Just ensuring the nonexistance of a file with the above path won't cause a runtime.
				var/icon/icon_file = new(icon_path)
				if(wear_suit.icon_state in icon_file.IconStates())
					standing = mutable_appearance(icon_file, "[wear_suit.icon_state]", layer = -COLLAR_LAYER)
		else
			if(wear_suit.icon_state in C.IconStates())
				standing = mutable_appearance(C, "[wear_suit.icon_state]", layer = -COLLAR_LAYER)

		overlays_standing[COLLAR_LAYER]	= standing
	apply_overlay(COLLAR_LAYER)

/mob/living/carbon/human/proc/update_misc_effects()
	remove_overlay(MISC_LAYER)

	//Begin appending miscellaneous effects.
	if(eyes_shine())
		overlays_standing[MISC_LAYER] = get_eye_shine() //Image layer is specified in get_eye_shine() proc as LIGHTING_LAYER + 1.

	apply_overlay(MISC_LAYER)

/mob/living/carbon/human/proc/update_halo_layer()
	remove_overlay(HALO_LAYER)

	if(iscultist(src) && SSticker.mode.cult_ascendant)
		var/istate = pick("halo1", "halo2", "halo3", "halo4", "halo5", "halo6")
		var/mutable_appearance/new_halo_overlay = mutable_appearance('icons/effects/32x64.dmi', istate, -HALO_LAYER)
		new_halo_overlay.appearance_flags |= RESET_TRANSFORM
		overlays_standing[HALO_LAYER] = new_halo_overlay
	else if(isclocker(src) && SSticker.mode.crew_reveal)
		var/mutable_appearance/new_halo_overlay = mutable_appearance('icons/effects/32x64.dmi', "haloclock", -HALO_LAYER)
		new_halo_overlay.appearance_flags |= RESET_TRANSFORM
		overlays_standing[HALO_LAYER] = new_halo_overlay

	apply_overlay(HALO_LAYER)


/mob/living/carbon/human/admin_Freeze(client/admin, skip_overlays = TRUE, mech = null)
	if(..())
		overlays_standing[FROZEN_LAYER] = mutable_appearance(frozen, layer = -FROZEN_LAYER)
		apply_overlay(FROZEN_LAYER)
	else
		remove_overlay(FROZEN_LAYER)

/mob/living/carbon/human/proc/force_update_limbs(update_body = TRUE)
	for(var/obj/item/organ/external/bodypart as anything in bodyparts)
		bodypart.sync_colour_to_human(src)
	if(update_body)
		update_body()

/mob/living/carbon/human/proc/get_overlays_copy(list/unwantedLayers)
	var/list/out = new
	for(var/i=1;i<=TOTAL_LAYERS;i++)
		if(overlays_standing[i])
			if(i in unwantedLayers)
				continue
			out += overlays_standing[i]
	return out

/mob/living/carbon/human/proc/generate_icon_render_key()
	var/husk = (HUSK in mutations)
	var/hulk = (HULK in mutations)
	var/skeleton = (SKELETON in mutations)
	var/g = dna.GetUITriState(DNA_UI_GENDER)
	if(g == DNA_GENDER_PLURAL)
		g = DNA_GENDER_FEMALE

	. = ""

	var/obj/item/organ/internal/eyes/eyes = get_int_organ(/obj/item/organ/internal/eyes)
	if(eyes)
		. += "[eyes.eye_colour]"
	else
		. += "#000000"

	if(lip_color && (LIPS in dna.species.species_traits))
		. += "[lip_color]"
	else
		. += "#000000"

	for(var/limb_zone in dna.species.has_limbs)
		var/obj/item/organ/external/part = bodyparts_by_name[limb_zone]
		if(isnull(part))
			. += "0"
		else if(part.is_robotic())
			. += "2[part.model ? "-[part.model]" : ""]"
		else if(part.is_dead())
			. += "3"
		else
			. += "1"

		if(part)
			var/datum/species/S = GLOB.all_species[part.dna.species.name]
			. += "[S.race_key]"
			. += "[part.dna.GetUIValue(DNA_UI_SKIN_TONE)]"
			. += "[g]"
			if(part.s_col)
				. += "[part.s_col]"
			if(part.s_tone)
				. += "[part.s_tone]"

	. = "[.][!!husk][!!hulk][!!skeleton]"
