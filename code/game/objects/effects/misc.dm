//MISC EFFECTS

//This file is for effects that are less than 20 lines and don't fit very well in any other category.

/*CURRENT CONTENTS
	Strange Present
	Mark
	Beam
	Laser
	Begin
	Stop
	Projection
	Shut_controller
	Showcase
	Spawner
	List_container
*/

//The effect when you wrap a dead body in gift wrap
/obj/effect/spresent
	name = "strange present"
	desc = "It's a ... present?"
	icon = 'icons/obj/items.dmi'
	icon_state = "strangepresent"
	density = TRUE
	anchored = FALSE

/obj/effect/mark
		var/mark = ""
		icon = 'icons/misc/mark.dmi'
		icon_state = "blank"
		anchored = TRUE
		layer = 99
		plane = HUD_PLANE
		mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/beam
	name = "beam"
	var/def_zone
	pass_flags = PASSTABLE

/obj/effect/laser
	name = "laser"
	desc = "IT BURNS!!!"
	icon = 'icons/obj/weapons/projectiles.dmi'
	var/damage = 0.0
	var/range = 10.0

/obj/effect/begin
	name = "begin"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "begin"
	anchored = TRUE

/obj/effect/projection
	name = "Projection"
	desc = "This looks like a projection of something."
	anchored = TRUE


/obj/effect/shut_controller
	name = "shut controller"
	var/moving = null
	var/list/parts = list(  )

/obj/structure/showcase
	name = "Showcase"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "showcase_1"
	desc = "A stand with the empty body of a cyborg bolted to it."
	density = TRUE
	anchored = TRUE

/obj/effect/spawner
	name = "object spawner"

/obj/effect/list_container
	name = "list container"

/obj/effect/list_container/mobl
	name = "mobl"
	var/master = null

	var/list/container = list(  )


/obj/structure/showcase/horrific_experiment
	name = "horrific experiment"
	desc = "Some sort of pod filled with blood and vicerea. You swear you can see it moving..."
	icon = 'icons/obj/machines/cloning.dmi'
	icon_state = "pod_mess"


//Makes a tile fully lit no matter what
/obj/effect/fullbright
	icon = 'icons/effects/alphacolors.dmi'
	icon_state = "white"
	plane = LIGHTING_PLANE
	layer = LIGHTING_LAYER
	blend_mode = BLEND_ADD


/obj/effect/dummy/lighting_obj
	name = "lighting fx obj"
	desc = "Tell a coder if you're seeing this."
	icon_state = "nothing"
	light_color = "#FFFFFF"
	light_system = MOVABLE_LIGHT
	light_range = MINIMUM_USEFUL_LIGHT_RANGE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/dummy/lighting_obj/Initialize(mapload, _range, _power, _color, _duration)
	. = ..()
	if(!isnull(_range))
		set_light_range(_range)
	if(!isnull(_power))
		set_light_power(_power)
	if(!isnull(_color))
		set_light_color(_color)
	if(_duration)
		QDEL_IN(src, _duration)

/obj/effect/dummy/lighting_obj/moblight
	name = "mob lighting fx"

/obj/effect/dummy/lighting_obj/moblight/Initialize(mapload, _color, _range, _power, _duration)
	. = ..()
	if(!ismob(loc))
		return INITIALIZE_HINT_QDEL

/obj/effect/frosty_breath //used only for unathi firebreath, so... yeah..
	icon = 'icons/effects/effects.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_MOB_LAYER
	anchored = TRUE

/obj/effect/frosty_breath/Initialize(mapload, mob/living/carbon/C)
	. = ..()
	dir = C.dir
	if(C.buckled)
		pixel_y = (C.buckled.buckle_offset + 10)
	if(dir == NORTH)
		layer = BELOW_MOB_LAYER
	flick("breath_[C.lying_prev]", src)
	QDEL_IN(src, 2 SECONDS)
