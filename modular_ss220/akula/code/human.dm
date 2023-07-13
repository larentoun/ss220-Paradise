/mob/living/carbon/human/akula/Initialize(mapload)
	. = ..(mapload, /datum/species/akula)

/datum/emote/living/carbon/human/wag/New()
	. = ..()
	species_type_whitelist_typecache.Add(/datum/species/akula)
