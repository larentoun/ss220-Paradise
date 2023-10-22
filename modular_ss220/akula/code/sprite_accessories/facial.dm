/datum/sprite_accessory/facial_hair/shaved/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/facial_hair/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_facial_hair.dmi'
	species_allowed = list(SPECIES_AKULA)
	gender = NEUTER
