/datum/sprite_accessory/head_accessory/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/head_accessory/none/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/head_accessory/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_facial_hair.dmi'
	species_allowed = SPECIES_AKULA
