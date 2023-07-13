/datum/sprite_accessory/body_markings/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/none/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tiger/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tattoo/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tattoo/tiger_body/New()
	. = ..()
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_body_markings.dmi'
	species_allowed = SPECIES_AKULA

/datum/sprite_accessory/body_markings/head/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_head_markings.dmi'
	species_allowed = SPECIES_AKULA

/datum/sprite_accessory/body_markings/tail/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_tail_markings.dmi'
	species_allowed = SPECIES_AKULA
