/obj/item/assembly/voice
	name = "voice analyzer"
	desc = "A small electronic device able to record a voice sample, and send a signal when that sample is repeated."
	icon_state = "voice"
	materials = list(MAT_METAL=500, MAT_GLASS=50)
	origin_tech = "magnets=1;engineering=1"
	var/listening = FALSE
	var/recorded = null	//the activation message
	var/recorded_type = 0 // 0 for say, 1 for emote

	bomb_name = "voice-activated bomb"


/obj/item/assembly/voice/examine(mob/user)
	. = ..()
	if(recorded || listening)
		. += span_notice("A meter on it flickers with every nearby sound.")
	else
		. += span_notice("It is deactivated.")


/obj/item/assembly/voice/hear_talk(mob/living/M, list/message_pieces)
	hear_input(M, multilingual_to_message(message_pieces), 0)


/obj/item/assembly/voice/hear_message(mob/living/M, msg)
	hear_input(M, msg, 1)


/obj/item/assembly/voice/proc/hear_input(mob/living/M, msg, type)
	if(!isliving(M))
		return
	if(listening)
		if(findtext(msg, "</span>"))
			recorded = strip_html_properly(msg)
		else
			recorded = msg
		recorded = msg
		recorded_type = type
		listening = FALSE
		var/turf/T = get_turf(src)	//otherwise it won't work in hand
		T.visible_message("[bicon(src)] beeps, \"Activation message is [type ? "the sound when one [recorded]" : "'[recorded]'."]\"")
	else if(findtext(msg, recorded) && type == recorded_type)
		var/turf/T = get_turf(src)  //otherwise it won't work in hand
		T.visible_message(span_warning("[bicon(src)] beeps!"))
		pulse(0, M)


/obj/item/assembly/voice/activate()
	return // previously this toggled listning when not in a holder, that's a little silly.  It was only called in attack_self that way.


/obj/item/assembly/voice/attack_self(mob/user)
	if(!user || !secured)
		return FALSE

	listening = !listening
	var/turf/T = get_turf(src)
	T.visible_message("[bicon(src)] beeps, \"[listening ? "Now" : "No longer"] recording input.\"")
	return TRUE


/obj/item/assembly/voice/toggle_secure()
	. = ..()
	listening = FALSE


/obj/item/assembly/voice/noise
	name = "noise sensor"
	desc = "A simple noise sensor that triggers on vocalizations other than speech."
	icon_state = "voice"
	materials = list(MAT_METAL=100, MAT_GLASS=10)
	origin_tech = "magnets=1;engineering=1"
	bomb_name = "noise-activated bomb"


/obj/item/assembly/voice/noise/attack_self(mob/user)
	return


/obj/item/assembly/voice/noise/examine(mob/user)
	. = ..()
	. += span_notice("It does not appear to have any controls.")


/obj/item/assembly/voice/noise/hear_talk(mob/living/M, list/message_pieces)
	return


/obj/item/assembly/voice/noise/hear_message(mob/living/M, msg)
	pulse(0, M)
	var/turf/T = get_turf(src)  //otherwise it won't work in hand
	T.visible_message(span_warning("[bicon(src)] beeps!"))

