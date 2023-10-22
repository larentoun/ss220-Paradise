/datum/sprite_accessory/hair/bald/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/hair/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_hair.dmi'
	species_allowed = list(SPECIES_AKULA)
