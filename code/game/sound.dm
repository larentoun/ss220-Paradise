
///Default override for echo
/sound
	echo = list(
		0, // Direct
		0, // DirectHF
		-10000, // Room, -10000 means no low frequency sound reverb
		-10000, // RoomHF, -10000 means no high frequency sound reverb
		0, // Obstruction
		0, // ObstructionLFRatio
		0, // Occlusion
		0.25, // OcclusionLFRatio
		1.5, // OcclusionRoomRatio
		1.0, // OcclusionDirectRatio
		0, // Exclusion
		1.0, // ExclusionLFRatio
		0, // OutsideVolumeHF
		0, // DopplerFactor
		0, // RolloffFactor
		0, // RoomRolloffFactor
		1.0, // AirAbsorptionFactor
		0, // Flags (1 = Auto Direct, 2 = Auto Room, 4 = Auto RoomHF)
	)
	environment = SOUND_ENVIRONMENT_NONE //Default to none so sounds without overrides dont get reverb

/*! playsound

playsound is a proc used to play a 3D sound in a specific range. This uses SOUND_RANGE + extra_range to determine that.
source - Origin of sound
soundin - Either a file, or a string that can be used to get an SFX
vol - The volume of the sound, excluding falloff and pressure affection.
vary - bool that determines if the sound changes pitch every time it plays
extrarange - modifier for sound range. This gets added on top of SOUND_RANGE
falloff_exponent - Rate of falloff for the audio. Higher means quicker drop to low volume. Should generally be over 1 to indicate a quick dive to 0 rather than a slow dive.
frequency - playback speed of audio
channel - The channel the sound is played at
pressure_affected - Whether or not difference in pressure affects the sound (E.g. if you can hear in space)
ignore_walls - Whether or not the sound can pass through walls.
falloff_distance - Distance at which falloff begins. Sound is at peak volume (in regards to falloff) aslong as it is in this range.

*/

/proc/playsound(atom/source, soundin, vol as num, vary, extrarange as num, falloff_exponent = SOUND_FALLOFF_EXPONENT, frequency = null, channel = 0, pressure_affected = TRUE, ignore_walls = TRUE, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, use_reverb = TRUE)
	if(isarea(source))
		error("[source] is an area and is trying to make the sound: [soundin]")
		return

	var/turf/turf_source = get_turf(source)
	if(!turf_source)
		return
	if(!SSsounds.channel_list) // Not ready yet
		return

	//allocate a channel if necessary now so its the same for everyone
	channel = channel || SSsounds.random_available_channel()

	// Looping through the player list has the added bonus of working for mobs inside containers
	var/sound/S = sound(get_sfx(soundin))
	var/maxdistance = SOUND_RANGE + extrarange
	var/source_z = turf_source.z
	var/list/listeners = SSmobs.clients_by_zlevel[source_z].Copy()
	if(!ignore_walls) //these sounds don't carry through walls
		listeners = listeners & hearers(maxdistance, turf_source)
	else
		var/turf/above_turf = GET_TURF_ABOVE(turf_source)
		if(above_turf?.transparent_floor)
			listeners += SSmobs.clients_by_zlevel[above_turf.z]
		var/turf/below_turf = GET_TURF_BELOW(turf_source)
		if(below_turf?.transparent_floor)
			listeners += SSmobs.clients_by_zlevel[below_turf.z]
	for(var/mob/M in listeners)
		if(!M.client)
			continue
		if(get_dist(M, turf_source) <= maxdistance)
			M.playsound_local(turf_source, soundin, vol, vary, frequency, falloff_exponent, channel, pressure_affected, S, maxdistance, falloff_distance, 1, use_reverb)
	for(var/P in SSmobs.dead_players_by_zlevel[source_z])
		var/mob/M = P
		if(get_dist(M, turf_source) <= maxdistance)
			M.playsound_local(turf_source, soundin, vol, vary, frequency, falloff_exponent, channel, pressure_affected, S, maxdistance, falloff_distance, 1, use_reverb)


/mob/proc/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff_exponent = SOUND_FALLOFF_EXPONENT, channel = 0, pressure_affected = TRUE, sound/S, max_distance, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, distance_multiplier = 1, use_reverb = TRUE, wait = FALSE)
	if(!client || !can_hear())
		return

	if(!S)
		S = sound(get_sfx(soundin))

	S.wait = wait
	S.channel = channel || SSsounds.random_available_channel()
	S.volume = vol
	S.environment = SOUND_ENVIRONMENT_NONE

	if(vary)
		if(islist(vary))
			S.frequency = rand(vary[1], vary[2])
		else if(frequency)
			S.frequency = frequency
		else
			S.frequency = get_rand_frequency()

	if(isturf(turf_source))
		var/turf/T = get_turf(src)

		//sound volume falloff with distance
		var/distance = get_dist(T, turf_source)
		distance *= distance_multiplier

		if(max_distance) //If theres no max_distance we're not a 3D sound, so no falloff.
			S.volume -= (max(distance - falloff_distance, 0) ** (1 / falloff_exponent)) / ((max(max_distance, distance) - falloff_distance) ** (1 / falloff_exponent)) * S.volume
			//https://www.desmos.com/calculator/sqdfl8ipgf

		if(pressure_affected)
			//Atmosphere affects sound
			var/pressure_factor = 1
			var/datum/gas_mixture/hearer_env = T.return_air()
			var/datum/gas_mixture/source_env = turf_source.return_air()

			if(hearer_env && source_env)
				var/pressure = min(hearer_env.return_pressure(), source_env.return_pressure())
				if(pressure < ONE_ATMOSPHERE)
					pressure_factor = max((pressure - SOUND_MINIMUM_PRESSURE)/(ONE_ATMOSPHERE - SOUND_MINIMUM_PRESSURE), 0)
			else //space
				pressure_factor = 0

			if(distance <= 1)
				pressure_factor = max(pressure_factor, 0.15) //touching the source of the sound

			S.volume *= pressure_factor
			//End Atmosphere affecting sound

		if(S.volume <= 0)
			return //No sound

		var/dx = turf_source.x - T.x // Hearing from the right/left
		S.x = dx * distance_multiplier
		var/dz = turf_source.y - T.y // Hearing from infront/behind
		S.z = dz * distance_multiplier
		// The y value is for above your head, but there is no ceiling in 2d spessmens.
		S.y = 1
		S.falloff = max_distance || 1 //use max_distance, else just use 1 as we are a direct sound so falloff isnt relevant.

		// Sounds can't have their own environment. A sound's environment will be:
		// 1. the mob's
		// 2. the area's (defaults to SOUND_ENVRIONMENT_NONE)
		if(sound_environment_override != SOUND_ENVIRONMENT_NONE)
			S.environment = sound_environment_override
		else
			var/area/A = get_area(src)
			S.environment = A.sound_environment

		if(use_reverb && S.environment != SOUND_ENVIRONMENT_NONE) //We have reverb, reset our echo setting
			// Check that the user has reverb enabled in their prefs
			if(!(client?.prefs?.toggles2 & PREFTOGGLE_2_REVERB_DISABLE))
				S.echo[3] = 0 //Room setting, 0 means normal reverb
				S.echo[4] = 0 //RoomHF setting, 0 means normal reverb.

	S.volume *= USER_VOLUME(src, CHANNEL_GENERAL)
	if(channel)
		S.volume *= USER_VOLUME(src, channel)

	SEND_SOUND(src, S)
	return S


/proc/sound_to_playing_players_on_station_level(soundin, volume = 100, vary = FALSE, frequency = 0, channel = 0, pressure_affected = FALSE, sound/S)
	if(!S)
		S = sound(get_sfx(soundin))
	for(var/mob/m as anything in GLOB.player_list)
		if(!isnewplayer(m) && is_station_level(m.z))
			m.playsound_local(m, null, volume, vary, frequency, null, channel, pressure_affected, S)


/proc/sound_to_playing_players(soundin, volume = 100, vary = FALSE, frequency = 0, channel = 0, pressure_affected = FALSE, sound/S)
	if(!S)
		S = sound(get_sfx(soundin))
	for(var/m in GLOB.player_list)
		if(ismob(m) && !isnewplayer(m))
			var/mob/M = m
			M.playsound_local(M, null, volume, vary, frequency, null, channel, pressure_affected, S)


/mob/proc/stop_sound_channel(chan)
	SEND_SOUND(src, sound(null, repeat = 0, wait = 0, channel = chan))


/mob/proc/set_sound_channel_volume(channel, volume)
	var/sound/S = sound(null, FALSE, FALSE, channel, volume)
	S.status = SOUND_UPDATE
	SEND_SOUND(src, S)


/client/proc/playtitlemusic()
	if(!SSticker || !SSticker.login_music || CONFIG_GET(flag/disable_lobby_music))
		return
	if(prefs.sound & SOUND_LOBBY)
		SEND_SOUND(src, sound(SSticker.login_music, repeat = 0, wait = 0, volume = 85 * prefs.get_channel_volume(CHANNEL_LOBBYMUSIC), channel = CHANNEL_LOBBYMUSIC)) // MAD JAMS


/proc/get_rand_frequency()
	return rand(32000, 55000) //Frequency stuff only works with 45kbps oggs.


/proc/get_sfx(soundin)
	if(istext(soundin))
		switch(soundin)
			if("shatter")
				soundin = pick('sound/effects/glassbr1.ogg','sound/effects/glassbr2.ogg','sound/effects/glassbr3.ogg')
			if("explosion")
				soundin = pick('sound/effects/explosion1.ogg','sound/effects/explosion2.ogg')
			if("explosion_creaking")
				soundin = pick('sound/effects/explosioncreak1.ogg', 'sound/effects/explosioncreak2.ogg')
			if("hull_creaking")
				soundin = pick('sound/effects/creak1.ogg', 'sound/effects/creak2.ogg', 'sound/effects/creak3.ogg')
			if("sparks")
				soundin = pick('sound/effects/sparks1.ogg','sound/effects/sparks2.ogg','sound/effects/sparks3.ogg','sound/effects/sparks4.ogg')
			if("rustle")
				soundin = pick('sound/effects/rustle1.ogg','sound/effects/rustle2.ogg','sound/effects/rustle3.ogg','sound/effects/rustle4.ogg','sound/effects/rustle5.ogg')
			if("bodyfall")
				soundin = pick('sound/effects/bodyfall1.ogg','sound/effects/bodyfall2.ogg','sound/effects/bodyfall3.ogg','sound/effects/bodyfall4.ogg')
			if("punch")
				soundin = pick('sound/weapons/punch1.ogg','sound/weapons/punch2.ogg','sound/weapons/punch3.ogg','sound/weapons/punch4.ogg')
			if("swing_hit")
				soundin = pick('sound/weapons/genhit1.ogg', 'sound/weapons/genhit2.ogg', 'sound/weapons/genhit3.ogg')
			if("hiss")
				soundin = pick('sound/voice/hiss1.ogg','sound/voice/hiss2.ogg','sound/voice/hiss3.ogg','sound/voice/hiss4.ogg')
			if("pageturn")
				soundin = pick('sound/effects/pageturn1.ogg', 'sound/effects/pageturn2.ogg','sound/effects/pageturn3.ogg')
			if("gunshot")
				soundin = pick('sound/weapons/gunshots/gunshot.ogg', 'sound/weapons/gunshots/gunshot2.ogg','sound/weapons/gunshots/gunshot3.ogg','sound/weapons/gunshots/gunshot4.ogg')
			if("casingdrop")
				soundin = pick('sound/weapons/gun_interactions/casingfall1.ogg', 'sound/weapons/gun_interactions/casingfall2.ogg', 'sound/weapons/gun_interactions/casingfall3.ogg')
			if("computer_ambience")
				soundin = pick('sound/goonstation/machines/ambicomp1.ogg', 'sound/goonstation/machines/ambicomp2.ogg', 'sound/goonstation/machines/ambicomp3.ogg')
			if("ricochet")
				soundin = pick('sound/weapons/effects/ric1.ogg', 'sound/weapons/effects/ric2.ogg','sound/weapons/effects/ric3.ogg','sound/weapons/effects/ric4.ogg','sound/weapons/effects/ric5.ogg')
			if("bullet")
				soundin = pick('sound/weapons/bullet.ogg', 'sound/weapons/bullet2.ogg', 'sound/weapons/bullet3.ogg')
			if("terminal_type")
				soundin = pick('sound/machines/terminal_button01.ogg', 'sound/machines/terminal_button02.ogg', 'sound/machines/terminal_button03.ogg',
							  'sound/machines/terminal_button04.ogg', 'sound/machines/terminal_button05.ogg', 'sound/machines/terminal_button06.ogg',
							  'sound/machines/terminal_button07.ogg', 'sound/machines/terminal_button08.ogg')
			if("growls")
				soundin = pick('sound/goonstation/voice/growl1.ogg', 'sound/goonstation/voice/growl2.ogg', 'sound/goonstation/voice/growl3.ogg')

			if("bonebreak")
				soundin = pick('sound/effects/bone_break_1.ogg', 'sound/effects/bone_break_2.ogg', 'sound/effects/bone_break_3.ogg', 'sound/effects/bone_break_4.ogg', 'sound/effects/bone_break_5.ogg', 'sound/effects/bone_break_6.ogg')
			if("honkbot_e")
				soundin = pick('sound/items/bikehorn.ogg', 'sound/items/AirHorn2.ogg', 'sound/misc/sadtrombone.ogg', 'sound/items/AirHorn.ogg', 'sound/items/WEEOO1.ogg', 'sound/voice/biamthelaw.ogg', 'sound/voice/bcreep.ogg','sound/magic/Fireball.ogg' ,'sound/effects/pray.ogg', 'sound/voice/hiss1.ogg','sound/machines/buzz-sigh.ogg', 'sound/machines/ping.ogg', 'sound/weapons/flashbang.ogg', 'sound/weapons/bladeslice.ogg')
			if("u_fscream")
				soundin = pick('sound/voice/unathi/f_u_scream.ogg', 'sound/voice/unathi/f_u_scream2.ogg')
			if("u_mscream")
				soundin = pick('sound/voice/unathi/m_u_scream.ogg', 'sound/voice/unathi/m_u_scream2.ogg')
			if("clownstep")
				soundin = pick('sound/effects/clownstep1.ogg','sound/effects/clownstep2.ogg')
			if("desceration")
				soundin = pick('sound/misc/desceration-01.ogg','sound/misc/desceration-02.ogg','sound/misc/desceration-03.ogg')
			else
				var/check_sound = FALSE
				for(var/format in SOUND_ALLOWED_FILE_FORMATS)
					if(dd_hassuffix(soundin, format))
						check_sound = TRUE
						break
					else
						continue
				if(!check_sound)
					CRASH("No sound file were found for \'[soundin]\' input!")
	return soundin


/proc/apply_sound_effect(effect, filename_input, filename_output)
	filename_input = filename_sanitize(filename_input)
	filename_output = filename_sanitize(filename_output)

	if(!effect)
		CRASH("Invalid sound effect chosen.")

	var/taskset
	if(GLOB.ffmpeg_cpuaffinity)
		taskset = "taskset -ac [GLOB.ffmpeg_cpuaffinity]"

	var/list/output
	switch(effect)
		if(SOUND_EFFECT_RADIO)
			output = world.shelleo({"[taskset] ffmpeg -y -hide_banner -loglevel error -i [filename_input] -filter:a "highpass=f=1000, lowpass=f=3000, acrusher=1:1:50:0:log" [filename_output]"})
		if(SOUND_EFFECT_ROBOT)
			output = world.shelleo({"[taskset] ffmpeg -y -hide_banner -loglevel error -i [filename_input] -filter:a "afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=1024:overlap=0.5, deesser=i=0.4, volume=volume=1.5" [filename_output]"})
		if(SOUND_EFFECT_RADIO_ROBOT)
			output = world.shelleo({"[taskset] ffmpeg -y -hide_banner -loglevel error -i [filename_input] -filter:a "afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=1024:overlap=0.5, deesser=i=0.4, volume=volume=1.5, highpass=f=1000, lowpass=f=3000, acrusher=1:1:50:0:log" [filename_output]"})
		if(SOUND_EFFECT_MEGAPHONE)
			output = world.shelleo({"[taskset] ffmpeg -y -hide_banner -loglevel error -i [filename_input] -filter:a "highpass=f=500, lowpass=f=4000, volume=volume=10, acrusher=1:1:45:0:log" [filename_output]"})
		if(SOUND_EFFECT_MEGAPHONE_ROBOT)
			output = world.shelleo({"[taskset] ffmpeg -y -hide_banner -loglevel error -i [filename_input] -filter:a "afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=1024:overlap=0.5, deesser=i=0.4, highpass=f=500, lowpass=f=4000, volume=volume=10, acrusher=1:1:45:0:log" [filename_output]"})
		else
			CRASH("Invalid sound effect chosen.")
	var/errorlevel = output[SHELLEO_ERRORLEVEL]
	var/stdout = output[SHELLEO_STDOUT]
	var/stderr = output[SHELLEO_STDERR]
	if(errorlevel)
		error("Error: apply_sound_effect([effect], [filename_input], [filename_output]) - See debug logs.")
		log_debug("apply_sound_effect([effect], [filename_input], [filename_output]) STDOUT: [stdout]")
		log_debug("apply_sound_effect([effect], [filename_input], [filename_output]) STDERR: [stderr]")
		return FALSE
	return TRUE
