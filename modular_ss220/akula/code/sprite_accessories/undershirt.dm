/datum/sprite_accessory/undershirt/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/undershirt/nude/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)
