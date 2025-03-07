/*
Immovable rod random event.
The rod will spawn at some location outside the station, and travel in a straight line to the opposite side of the station
Everything solid in the way will be ex_act()'d
In my current plan for it, 'solid' will be defined as anything with density == 1

--NEOFite
*/

/datum/event/immovable_rod
	announceWhen = 5

/datum/event/immovable_rod/announce()
	GLOB.event_announcement.Announce("Что это за хуйня?!", "ВНИМАНИЕ: ОБЩАЯ ТРЕВОГА.")

/datum/event/immovable_rod/start()
	var/startside = pick(GLOB.cardinal)
	var/level = pick(levels_by_trait(STATION_LEVEL))
	var/turf/startT = spaceDebrisStartLoc(startside, level)
	var/turf/endT = spaceDebrisFinishLoc(startside, level)
	new /obj/effect/immovablerod/event(startT, endT)

/obj/effect/immovablerod
	name = "Immovable Rod"
	desc = "What the fuck is that?"
	icon = 'icons/obj/objects.dmi'
	icon_state = "immrod"
	throwforce = 100
	density = TRUE
	anchored = TRUE
	var/z_original = 0
	var/destination
	var/notify = TRUE
	var/move_delay = 1

/obj/effect/immovablerod/New(atom/start, atom/end, delay)
	. = ..()
	loc = start
	z_original = z
	destination = end
	move_delay = delay
	if(notify)
		notify_ghosts("\A [src] is inbound!",
				enter_link="<a href=?src=[UID()];follow=1>(Click to follow)</a>",
				source=src, action=NOTIFY_FOLLOW)
	GLOB.poi_list |= src
	if(end && end.z==z_original)
		walk_towards(src, destination, move_delay)

/obj/effect/immovablerod/Topic(href, href_list)
	if(href_list["follow"])
		var/mob/dead/observer/ghost = usr
		if(istype(ghost))
			ghost.ManualFollow(src)

/obj/effect/immovablerod/Destroy()
	GLOB.poi_list.Remove(src)
	return ..()

/obj/effect/immovablerod/ex_act(severity)
	return 0

/obj/effect/immovablerod/singularity_act()
	return

/obj/effect/immovablerod/singularity_pull()
	return

/obj/effect/immovablerod/Bump(atom/clong)
	if(prob(10))
		playsound(src, 'sound/effects/bang.ogg', 50, 1)
		audible_message("ЛЯЗГ")

	if(clong && prob(25))
		x = clong.x
		y = clong.y

	if(istype(clong, /turf) || isobj(clong))
		if(clong.density)
			clong.ex_act(2)

	else if(istype(clong, /mob))
		if(ishuman(clong))
			var/mob/living/carbon/human/H = clong
			H.visible_message("<span class='danger'>[H.name] пронизан незыблемым стержнем!</span>" , "<span class='userdanger'>Стержень пронзает тебя!</span>" , "<span class ='danger'>Вы слышите ЛЯЗГ!</span>")
			H.adjustBruteLoss(160)
		if(clong.density || prob(10))
			clong.ex_act(2)

/obj/effect/immovablerod/event
	var/tiles_moved = 0

/obj/effect/immovablerod/event/Move()
	var/atom/oldloc = loc
	. = ..()
	tiles_moved++
	if(get_dist(oldloc, loc) > 2 && tiles_moved > 10) // We went on a journey, commit sudoku
		qdel(src)
