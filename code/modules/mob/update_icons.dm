//Most of these are defined at this level to reduce on checks elsewhere in the code.
//Having them here also makes for a nice reference list of the various overlay-updating procs available

/mob/proc/regenerate_icons()		//TODO: phase this out completely if possible
	return

/mob/proc/update_icons()
	return

/mob/proc/update_inv_handcuffed()
	return

/mob/proc/update_inv_legcuffed()
	return

/mob/proc/update_inv_back()
	return

/mob/proc/update_inv_l_hand()
	return

/mob/proc/update_inv_r_hand()
	return

/mob/proc/update_inv_hands()
	update_inv_l_hand()
	update_inv_r_hand()

/mob/proc/update_inv_wear_mask()
	return

/mob/proc/wear_mask_update(obj/item/clothing/mask, toggle_off = TRUE)
	return

/mob/proc/update_inv_wear_suit()
	return

/mob/proc/wear_suit_update()
		return

/mob/proc/update_inv_w_uniform()
	return

/mob/proc/update_inv_belt()
	return

/mob/proc/update_inv_head()
	return

/mob/proc/update_head(obj/item/I, forced, toggle_off = FALSE)
	return

/mob/proc/update_inv_gloves()
	return

/mob/proc/update_inv_neck()
	return

/mob/proc/update_mutations()
	return

/mob/proc/update_inv_wear_id()
	return

/mob/proc/update_inv_shoes()
	return

/mob/proc/update_inv_glasses()
	return

/mob/proc/wear_glasses_update(obj/item/clothing/glasses/our_glasses)
	return

/mob/proc/update_inv_s_store()
	return

/mob/proc/update_inv_pockets()
	return

/mob/proc/update_inv_wear_pda()
	return

/mob/proc/update_inv_ears()
	return

/mob/proc/update_transform()
	return
