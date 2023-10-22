GLOBAL_LIST_INIT(first_names_female_akula, file2list("config/names/first_female_akula.txt")) // TODO: UNIQUE NAME
GLOBAL_LIST_INIT(first_names_male_akula, file2list("config/names/first_male_akula.txt")) // TODO: UNIQUE NAME
GLOBAL_LIST_INIT(last_names_akula, file2list("config/names/last_akula.txt")) // TODO: UNIQUE NAME

/datum/language/akula
	name = "Akula"
	desc = "Akula language."
	speech_verb = "says"
	ask_verb = "asks"
	exclaim_verbs = list("yells")
	colour = "akula"
	key = "Unbound"
	flags = RESTRICTED
	syllables = list()

/datum/language/akula/get_random_name(gender)
	var/new_name
	if(gender == FEMALE)
		new_name = pick(GLOB.first_names_female_akula)
	else
		new_name = pick(GLOB.first_names_male_akula)
	new_name += " " + pick(GLOB.last_names_akula)
	return new_name
