/datum/sprite_accessory/socks/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)

/datum/sprite_accessory/socks/nude/New()
	. = ..()
	LAZYINITLIST(species_allowed)
	species_allowed.Add(SPECIES_AKULA)
