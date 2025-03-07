/mob
	var/suiciding = FALSE


/mob/living/verb/suicide()
	set hidden = TRUE
	be_suicidal()


/mob/living/proc/be_suicidal(forced = FALSE)
	if(stat == DEAD)
		to_chat(src, "You're already dead!")
		return

	if(!SSticker)
		to_chat(src, "You can't commit suicide before the game starts!")
		return

	if(suiciding)
		to_chat(src, "You're already committing suicide! Be patient!")
		return


	var/confirm = null
	if(!forced)
		if(ischangeling(src))
			// the alternative is to allow clings to commit suicide, but then you'd probably have them
			// killing themselves as soon as they're in cuffs
			to_chat(src, span_warning("We refuse to take the coward's way out."))
			return
		confirm = alert("Are you sure you want to commit suicide?", "Confirm Suicide", "Yes", "No")

	if(stat == DEAD || suiciding) //We check again, because alerts sleep until a choice is made
		to_chat(src, "You're already dead!")
		return

	if(forced || (confirm == "Yes"))
		if(!forced && isAntag(src))
			confirm = alert("Are you absolutely sure? If you do this after you got converted/joined as an antagonist, you could face a jobban!", "Confirm Suicide", "Yes", "No")
			if(confirm == "Yes")
				suiciding = TRUE
				do_suicide()
				create_log(ATTACK_LOG, "Attempted suicide as special role")
				message_admins("[src] with a special role attempted suicide at [ADMIN_JMP(src)]")
				return
			return
		suiciding = TRUE
		do_suicide()
		create_log(ATTACK_LOG, "Attempted suicide")


/mob/living/proc/do_suicide()
	return


/mob/living/simple_animal/do_suicide()
	setOxyLoss((health * 1.5), TRUE)


/mob/living/simple_animal/mouse/do_suicide()
	visible_message(span_danger("[src] is playing dead permanently! It looks like [p_theyre()] trying to commit suicide."))
	adjustOxyLoss(max(100 - getBruteLoss(100), 0))


/mob/living/simple_animal/slime/do_suicide()
	setOxyLoss(100, FALSE)
	adjustBruteLoss(100 - getBruteLoss(), FALSE)
	setToxLoss(100, FALSE)
	setCloneLoss(100, FALSE)
	updatehealth()


/mob/living/silicon/do_suicide()
	to_chat(viewers(src), span_danger("[src] is powering down. It looks like [p_theyre()] trying to commit suicide."))
	//put em at -175
	adjustOxyLoss(max(maxHealth * 2 - getToxLoss() - getFireLoss() - getBruteLoss() - getOxyLoss(), 0))


/mob/living/silicon/robot/drone/do_suicide()
	shut_down()


/mob/living/silicon/pai/do_suicide()
	if(canmove || resting)
		close_up()
	card.removePersonality()
	visible_message(span_notice("[src] flashes a message across its screen, \"Wiping core files. Please acquire a new personality to continue using pAI device functions.\""), blind_message = span_notice("[src] bleeps electronically."))
	death(gibbed = FALSE, cleanWipe = TRUE)


/mob/living/carbon/do_suicide()
	death(gibbed = FALSE)
	suiciding = FALSE


/mob/living/carbon/brain/do_suicide()
	to_chat(viewers(loc), span_danger("[src]'s brain is growing dull and lifeless. It looks like it's lost the will to live."))
	spawn(5 SECONDS)
		death(gibbed = FALSE)
		suiciding = FALSE


/mob/living/carbon/alien/humanoid/do_suicide()
	to_chat(viewers(src), span_danger("[src] is thrashing wildly! It looks like [p_theyre()] trying to commit suicide."))
	//put em at -175
	adjustOxyLoss(max(175 - getFireLoss() - getBruteLoss() - getOxyLoss(), 0))


/mob/living/carbon/human/do_suicide()
	var/obj/item/held_item = get_active_hand()
	var/damagetype = SEND_SIGNAL(src, COMSIG_HUMAN_SUICIDE_ACT) || held_item?.suicide_act(src)

	if(damagetype)
		if(damagetype & SHAME)
			adjustStaminaLoss(200)
			suiciding = FALSE
			return
		if(damagetype & OBLITERATION) // Does it gib or something? Don't deal damage
			return
		human_suicide(damagetype, held_item)
		return

	for(var/obj/O in orange(1, src))
		if(O.suicidal_hands)
			continue
		damagetype = O.suicide_act(src)
		if(damagetype)
			if(damagetype & SHAME)
				adjustStaminaLoss(200)
				suiciding = FALSE
				return
			if(damagetype & OBLITERATION)
				return
			human_suicide(damagetype, O)
			return

	to_chat(viewers(src), span_danger("[src] [replacetext(pick(dna.species.suicide_messages), "their", p_their())] It looks like [p_theyre()] trying to commit suicide."))
	human_suicide(0)


/mob/living/carbon/human/proc/human_suicide(damagetype, byitem)
	var/threshold = check_death_method() ? ((HEALTH_THRESHOLD_CRIT + HEALTH_THRESHOLD_DEAD) / 2) : (HEALTH_THRESHOLD_DEAD - 50)
	var/dmgamt = maxHealth - threshold

	var/damage_mod = 1
	switch(damagetype) //Sorry about the magic numbers. // this was here before I refactored it i'm not touching the magic numbers
					//brute = 1, burn = 2, tox = 4, oxy = 8
		if(15) //4 damage types
			damage_mod = 4

		if(6, 11, 13, 14) //3 damage types
			damage_mod = 3

		if(3, 5, 7, 9, 10, 12) //2 damage types
			damage_mod = 2

		if(1, 2, 4, 8) //1 damage type
			damage_mod = 1

		else //This should not happen, but if it does, everything should still work
			damage_mod = 1

	//Do dmgamt damage divided by the number of damage types applied.
	if(damagetype & BRUTELOSS)
		adjustBruteLoss(dmgamt / damage_mod, FALSE)

	if(damagetype & FIRELOSS)
		adjustFireLoss(dmgamt / damage_mod, FALSE)

	if(damagetype & TOXLOSS)
		adjustToxLoss(dmgamt / damage_mod, FALSE)

	if(damagetype & OXYLOSS)
		adjustOxyLoss(dmgamt / damage_mod, FALSE)

	// Failing that...
	if(!(damagetype & BRUTELOSS) && !(damagetype & FIRELOSS) && !(damagetype & TOXLOSS) && !(damagetype & OXYLOSS))
		if(NO_BREATHE in dna.species.species_traits)
			// the ultimate fallback
			take_overall_damage(max(dmgamt - getToxLoss() - getFireLoss() - getBruteLoss() - getOxyLoss(), 0), 0, updating_health = FALSE)
		else
			adjustOxyLoss(max(dmgamt - getToxLoss() - getFireLoss() - getBruteLoss() - getOxyLoss(), 0), updating_health = FALSE)

	var/obj/item/organ/external/affected = get_organ(BODY_ZONE_HEAD)
	if(affected)
		affected.add_autopsy_data(byitem ? "Suicide by [byitem]" : "Suicide", dmgamt)

	updatehealth()

