/datum/sprite_accessory/underwear/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/underwear/nude/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)
