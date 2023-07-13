/obj/item/organ/internal/liver/akula
	name = "akula liver"
	icon = 'modular_ss220/akula/icons/organs.dmi'
	alcohol_intensity = 1.4

/obj/item/organ/internal/eyes/akula
	name = "akula eyeballs"
	icon = 'modular_ss220/akula/icons/organs.dmi'
	colourblind_matrix = MATRIX_VULP_CBLIND //The colour matrix and darksight parameters that the mob will recieve when they get the disability.
	replace_colours = PROTANOPIA_COLOR_REPLACE
	see_in_dark = 4

/obj/item/organ/internal/eyes/akula/wolpin //Being the lesser form of akula, Wolpins have an utterly incurable version of their colourblindness.
	name = "wolpin eyeballs"
	colourmatrix = MATRIX_VULP_CBLIND
	see_in_dark = 3
	replace_colours = PROTANOPIA_COLOR_REPLACE

/obj/item/organ/internal/heart/akula
	name = "akula heart"
	icon = 'modular_ss220/akula/icons/organs.dmi'

/obj/item/organ/internal/brain/akula
	icon = 'modular_ss220/akula/icons/organs.dmi'
	icon_state = "brain2"
	mmi_icon = 'modular_ss220/akula/icons/organs.dmi'
	mmi_icon_state = "mmi_full"

/obj/item/organ/internal/lungs/akula
	name = "akula lungs"
	icon = 'modular_ss220/akula/icons/organs.dmi'

/obj/item/organ/internal/kidneys/akula
	name = "akula kidneys"
	icon = 'modular_ss220/akula/icons/organs.dmi'
