/datum/species/akula
	name = SPECIES_AKULA
	name_plural = "Akulas"
	icobase = 'modular_ss220/akula/icons/r_akula.dmi'
	language = "Akula"
	primitive_form = null
	tail = "fish"
	skinned_type = /obj/item/stack/sheet/leather
	unarmed_type = /datum/unarmed_attack/claws

	blurb = "Akula lore"

	species_traits = list(LIPS)
	clothing_flags = HAS_UNDERWEAR | HAS_UNDERSHIRT | HAS_SOCKS
	bodyflags = HAS_TAIL | TAIL_WAGGING | TAIL_OVERLAPPED | HAS_HEAD_ACCESSORY | HAS_MARKINGS | HAS_SKIN_COLOR
	dietflags = DIET_OMNI
	hunger_drain = 0.11
	taste_sensitivity = TASTE_SENSITIVITY_SHARP
	reagent_tag = PROCESS_ORG

	flesh_color = "#966464"
	base_color = "#CF4D2F"
	butt_sprite = "akula"

	scream_verb = "yelps"

	has_organ = list(
		"heart" =    /obj/item/organ/internal/heart/akula,
		"lungs" =    /obj/item/organ/internal/lungs/akula,
		"liver" =    /obj/item/organ/internal/liver/akula,
		"kidneys" =  /obj/item/organ/internal/kidneys/akula,
		"brain" =    /obj/item/organ/internal/brain/akula,
		"appendix" = /obj/item/organ/internal/appendix,
		"eyes" =     /obj/item/organ/internal/eyes/akula
		)

	allowed_consumed_mobs = list(/mob/living/simple_animal/mouse, /mob/living/simple_animal/lizard, /mob/living/simple_animal/chick, /mob/living/simple_animal/chicken,
								/mob/living/simple_animal/crab, /mob/living/simple_animal/butterfly, /mob/living/simple_animal/parrot, /mob/living/simple_animal/hostile/poison/bees)

	suicide_messages = list(
		"is attempting to bite their tongue off!",
		"is jamming their claws into their eye sockets!",
		"is twisting their own neck!",
		"is holding their breath!")

/datum/species/akula/handle_death(gibbed, mob/living/carbon/human/H)
	H.stop_tail_wagging()
