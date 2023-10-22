/datum/sprite_accessory/body_markings/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/none/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tiger/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tattoo/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tattoo/tiger_body/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_body_markings.dmi'
	species_allowed = list(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/head/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_head_markings.dmi'
	species_allowed = list(SPECIES_AKULA)

/datum/sprite_accessory/body_markings/tail/akula
	icon = 'modular_ss220/akula/icons/sprite_accessories/akula_tail_markings.dmi'
	species_allowed = list(SPECIES_AKULA)
