/obj/machinery/bluespacedrive
	name = "bluespace drive"
	desc = "The Naophoros-pattern jump drive is a machine created by the skrell, mated with countless human devices and apparatuses to make it able to interface with the vastly different technology used in their ships."
	icon = 'icons/obj/machines/bluespacedrive.dmi'
	icon_state = "bsd_core"
	anchored = TRUE
	density = TRUE
	pixel_y = -32
	pixel_x = -32
	idle_power_usage = 15 KILOWATTS
	health_max = 1000
	damage_hitsound = 'sound/machines/BSD_damaging.ogg'
	health_min_damage = 10

	/// Indicates whether the drive should show effects.
	var/const/STATE_BROKEN = FLAG_01

	/// Indicates whether the drive should use the unstable core effect.
	var/const/STATE_UNSTABLE = FLAG_02

	/// A field of STATE_* flags related to the drive.
	var/state = FLAGS_OFF

	/// The token for the drive's idle loop
	var/drive_sound

	///Whether or not the BSD Instability event is active
	var/instability_event_active = FALSE

	///Chance to teleport someone to the interlude during a pulse.
	var/interlude_chance = 55

	var/affect_chance = 50

	var/interlude_min_time = 30 SECONDS
	var/interlude_max_time = 3 MINUTES

	var/next_zap_time = 0
	var/obj/machinery/power/capacitor/connected_capacitor
	var/current_charge = 0
	var/max_charge = 45 MEGAWATTS
	var/minimum_charge = 9 MEGAWATTS
	var/required_charge_per_second = 2 MEGAWATTS
	var/current_charge_per_second = 0
	var/current_charge_window = 0
	var/cooldown_length = 1 MINUTE
	var/current_cooldown = 0
	var/instability_score = 0
	var/max_instability = 100
	var/cost_per_step = 3.6 //final calculation will be in MW, adding the multiplier then
	var/long_range_cost_multiplier = 5
	var/short_range_limit = 5
	var/obj/overmap/visitable/ship/ship
	/// Bumped whenever held charge is spent, so the warning/forced-discharge timers of an earlier charge ignore themselves.
	var/charge_cycle = 0


/obj/machinery/bluespacedrive/Destroy()
	QDEL_NULL(drive_sound)
	particles = null
	return ..()


/obj/machinery/bluespacedrive/Initialize()
	. = ..()
	drive_sound = GLOB.sound_player.PlayLoopingSound(src, "\ref[src]", 'sound/machines/BSD_idle.ogg', 50, 12)
	AddParticles(/particles/torus/bluespace)
	set_light(15, 1, COLOR_CYAN)
	update_icon()

/obj/machinery/bluespacedrive/on_update_icon()
	ClearOverlays()
	if (state & STATE_BROKEN)
		icon_state = "bsd_core_broken"
	else
		icon_state = "bsd_core"
	if (state & STATE_UNSTABLE)
		AddOverlays("bsd_c_u")
	else
		AddOverlays("bsd_c_s")


/obj/machinery/bluespacedrive/emp_act(severity)
	..()
	if (!(state & STATE_BROKEN))
		visible_message(SPAN_WARNING("\The [src]'s field warps and buckles uneasily!"))
		playsound(loc, damage_hitsound, 80)


/obj/machinery/bluespacedrive/bullet_act(obj/item/projectile/projectile)
	. = ..()
	if (!(state & STATE_BROKEN))
		visible_message(SPAN_WARNING("\The [src]'s field crackles disturbingly!"))
		playsound(loc, damage_hitsound, 80)


/obj/machinery/bluespacedrive/post_health_change(health_mod, prior_health, damage_type)
	. = ..()
	var/damage_percentage = get_damage_percentage()
	if (damage_percentage >= 50 && !(state & STATE_UNSTABLE))
		state |= STATE_UNSTABLE
		queue_icon_update()
	else if (damage_percentage < 50 && (state & STATE_UNSTABLE))
		state &= ~STATE_UNSTABLE
		queue_icon_update()


/obj/machinery/bluespacedrive/on_death()
	playsound(loc, 'sound/machines/BSD_explosion.ogg', 100)
	visible_message(SPAN_DANGER(FONT_LARGE("\The [src] begins emitting an ear-splitting, horrible shrill! Get back!")))
	addtimer(new Callback(src, PROC_REF(explode)), 5 SECONDS)
	..()


/// Final death act handler for the drive where it explodes. You really shouldn't call this directly or you'll make weird broken things regarding health tracking. Use `kill_health()` instead, the death handler calls this.
/obj/machinery/bluespacedrive/proc/explode()
	visible_message(SPAN_DANGER(FONT_LARGE("\The [src]'s containment field is wracked by a series of horrendous distortions, buckling and twisting like a living thing before bursting in a flash of light!")))
	explosion(get_turf(src), 15, EX_ACT_HEAVY)
	empulse(get_turf(src), 7, 14)
	state |= STATE_BROKEN
	for (var/verb in verbs)
		verbs -= verb
	update_icon()

/obj/machinery/bluespacedrive/use_grab(obj/item/grab/grab, list/click_params)
	to_chat(grab.assailant, SPAN_WARNING("\The [src] pulls at \the [grab.affecting] but they're too heavy."))
	return TRUE

/obj/machinery/bluespacedrive/use_tool(obj/item/item, mob/living/user, list/click_params)
	if ((. = ..()))
		return

	if (issilicon(user) || !user.unEquip(item, src))
		to_chat(user, SPAN_WARNING("\The [src] pulls at \the [item] but it's attached to you."))
		return TRUE
	user.visible_message(
		SPAN_WARNING("\The [user] reaches out \a [item] to \the [src], warping briefly as it disappears in a flash of blue light, scintillating motes left behind."),
		SPAN_DANGER("You touch \the [src] with \the [item], the field buckling around it before retracting with a crackle as it leaves small, blue scintillas on your hand as you flinch away."),
		SPAN_WARNING("You hear an otherwordly crackle, followed by humming.")
	)
	qdel(item)
	if (prob(5))
		playsound(loc, 'sound/items/eatfood.ogg', 40)
	else
		playsound(loc, 'sound/machines/BSD_interact.ogg', 40)
	return TRUE

/obj/machinery/bluespacedrive/examine_damage_state(mob/user)
	if (health_dead())
		to_chat(user, SPAN_DANGER("Its field is completely destroyed, the core revealed under the arcing debris."))
		return
	var/damage_percentage = get_damage_percentage()
	switch (damage_percentage)
		if (0)
			to_chat(user, SPAN_NOTICE("At a glance, its field is peacefully humming without any alterations."))
		if (1 to 32)
			to_chat(user, SPAN_WARNING("Its field is crackling gently, with the occasional twitch."))
		if (33 to 65)
			to_chat(user, SPAN_WARNING("Its damaged field is twitching and crackling dangerously!"))
		else
			to_chat(user, SPAN_DANGER("Its unstable field is cracking and shifting dangerously, revealing the core inside briefly!"))
	if (instability_event_active && !damage_percentage)
		to_chat(user, SPAN_WARNING("The core seems to be pulsing and lashing out at the contaiment field, as if trying to break free."))


/// Creates an expanding bluespace pulse on all z-levels connected to the drive
/obj/machinery/bluespacedrive/proc/do_pulse()
	playsound(src, 'sound/effects/EMPulse.ogg', 100, TRUE)
	for (var/level in GetConnectedZlevels(z))
		new /datum/bubble_effect/bluespace_pulse(x, y, level, 1, 1, src)


/// Creates a blinding flash of light that will blind and deafen those in range, and change turfs to bluespace
/obj/machinery/bluespacedrive/proc/create_flash(change_turf, range)
	playsound(src, "sound/effects/supermatter.ogg", 100, TRUE)
	var/list/victims = list()
	var/list/objs = list()
	get_mobs_and_objs_in_view_fast(loc, range, victims, objs)
	for (var/mob/living/living in victims)
		if (living.client)
			to_chat(living, SPAN_DANGER(FONT_LARGE("The Drive's field cracks open briefly, emitting a blinding flash of blue light and a deafening screech!")))
		living.flash_eyes(FLASH_PROTECTION_MAJOR)
		living.Stun(3)
		living.mod_confused(15)
		living.ear_damage += rand(0, 5)
		living.ear_deaf = max(living.ear_deaf, 15)
	if (!change_turf)
		return
	for (var/turf/simulated/floor/floor in range(range, src))
		if (prob(25))
			continue
		floor.ChangeTurf(/turf/simulated/floor/bluespace)

/obj/machinery/bluespacedrive/proc/add_charge(amount)
	// Called by connected capacitors to add charge to the drive
	// amount is in watts
	// For now, we just create a flash when enough charge is added

	if (current_cooldown > world.time)
		instability_score += 1 * (amount / 1000000)
		visible_message(SPAN_WARNING("The [src] warps and strains against the containment field."))

	current_charge = min(current_charge + amount, max_charge)
	current_charge_per_second += amount
	if (current_charge_per_second < required_charge_per_second)
		connected_capacitor.stop_discharge()
		instability_score += (max_charge - current_charge) / 1000000 // lost charge, so this must be counted before zeroing it
		current_charge = 0 //do something more here
		current_charge_per_second = 0
		return
	if (current_charge >= max_charge)
		charge_cycle++
		addtimer(new Callback(src, PROC_REF(emergency_discharge), charge_cycle), 1 MINUTE) //bsd can only hold charge for 1 minute before it has to discharge
		addtimer(new Callback(src, PROC_REF(warn_discharge), charge_cycle), 50 SECONDS)
		visible_message(SPAN_NOTICE("The bluespace drive hums loudly as it begins charging for a [ship?.mode == SHIP_MODE_HOP ? "hop" : "jump"]."))
		if (state & STATE_UNSTABLE)
			do_pulse()

// /obj/machinery/bluespacedrive/proc/begin_jump_sequence()
// 	jumping = TRUE
// 	// playsound(loc, 'sound/machines/BSD_chargeup.ogg', 100, TRUE)
// 	addtimer(new Callback(src, PROC_REF(perform_jump)), 5 SECONDS)

/obj/machinery/bluespacedrive/proc/get_charge_percentage()
	return round((current_charge / max_charge) * 100)

/obj/machinery/bluespacedrive/proc/get_current_mode_cost(dest_x, dest_y)
	if (ship.mode == SHIP_MODE_JUMP)
		return get_jump_cost(dest_x, dest_y)

	return get_hop_cost()

/// Straight-line distance from the ship to the destination. get_dist() is Chebyshev (max of the axis differences), which hides one axis whenever the other is larger.
/obj/machinery/bluespacedrive/proc/get_travel_distance(dest_x, dest_y)
	return round(sqrt((ship.x - dest_x) ** 2 + (ship.y - dest_y) ** 2))

/// Sets the charge requirement for a jump to the given coordinates (the base requirement if none are set) and returns it in MW.
/obj/machinery/bluespacedrive/proc/get_jump_cost(dest_x, dest_y)
	if (!dest_x || !dest_y)
		reset_charge_requirement()
		return get_jump_cost_mw()

	var/distance_to_target = get_travel_distance(dest_x, dest_y)
	var/initial_cost = distance_to_target * cost_per_step
	if (distance_to_target > short_range_limit)
		initial_cost *= long_range_cost_multiplier

	max_charge = max(initial_cost, initial(max_charge) / 1000000) MEGAWATTS
	required_charge_per_second = max_charge / 16
	return get_jump_cost_mw()

/// Sets the charge requirement for a hop at the ship's current speed and heading. Returns the raw cost in MW.
/obj/machinery/bluespacedrive/proc/get_hop_cost()
	ship.calculate_hop_destination()
	var/cost = get_travel_distance(ship.hop_x, ship.hop_y) * cost_per_step

	max_charge = max(round(cost MEGAWATTS), minimum_charge)
	required_charge_per_second = max_charge / 16
	return cost

/// Restores the base (jump mode) charge requirement, used when switching back from hop mode.
/obj/machinery/bluespacedrive/proc/reset_charge_requirement()
	max_charge = initial(max_charge)
	required_charge_per_second = max_charge / 16

/obj/machinery/bluespacedrive/proc/get_jump_cost_mw()
	return max_charge / 1000000

//random location if done while unstable?
// bluespace some of the ship if unstable/done with very low accuracy?
// round-start global debuff to accuracy sometimes?
/obj/machinery/bluespacedrive/proc/perform_jump(dest_x, dest_y, accuracy)
	current_charge = 0
	current_charge_per_second = 0
	charge_cycle++
	// Actual jump logic handled elsewhere
	visible_message(SPAN_NOTICE("The bluespace drive hums loudly as it activates, warping the space around the ship briefly before settling down."))
	// playsound(loc, 'sound/machines/BSD_jump.ogg', 100, TRUE)
	create_flash(FALSE, 10)

	if (connected_capacitor.auto_charge)
		connected_capacitor.start_discharge()

/obj/machinery/bluespacedrive/proc/warn_discharge(cycle)
	if (cycle != charge_cycle || current_charge <= 0 || !connected_capacitor)
		return
	connected_capacitor.announce(SPAN_DANGER("Warning: bluespace drive charge cannot be held much longer. Forced discharge in 10 seconds!"))

/obj/machinery/bluespacedrive/proc/emergency_discharge(cycle)
	if (cycle != charge_cycle || current_charge <= 0)
		return

	visible_message(SPAN_DANGER("The bluespace drive emits a loud wailing noise as it forcefully discharges its stored energy!"))
	create_flash(FALSE, 10)
	var/charge_ratio = clamp(current_charge / max_charge, 0, 1)
	current_charge = 0
	current_charge_per_second = 0
	charge_cycle++
	zap_surroundings(charge_ratio)

///Zap surroundings with damage based on charge. High chance to zap people because funny
/obj/machinery/bluespacedrive/proc/zap_surroundings(charge_ratio = 1)
	set waitfor = FALSE
	playsound(src, 'sound/effects/bsd_zap_1.ogg', 75)
	var/simple_vector/start = new (x * world.icon_size, y * world.icon_size)
	var/list/targets = list()
	for (var/i = 1 to 5)
		targets += get_random_turf_in_range(src, 5)
	for (var/mob/living/target in view(7, src))
		if (prob(70))
			targets += get_turf(target)
			target.electrocute_act(rand(30, 50) * charge_ratio, src)
	for (var/turf/target_turf as anything in targets)
		if (!target_turf)
			continue
		target_turf.damage_health(10 * charge_ratio, DAMAGE_BURN)
		for (var/atom/object in target_turf.contents)
			object.damage_health(10 * charge_ratio, DAMAGE_BURN)
		var/simple_vector/dest = new (target_turf.x * world.icon_size, target_turf.y * world.icon_size)
		var/datum/bolt/bolt = new(start, dest, 90)
		bolt.Draw(z, color = "#01c4ff", thickness = 1)
		sleep(1)

/datum/bubble_effect/bluespace_pulse
	///List of mobs that can be swapped around when the pulse hits
	var/list/mob/living/mobs_to_switch = list()
	var/obj/machinery/bluespacedrive/parent
	var/affect_chance = 0

/datum/bubble_effect/bluespace_pulse/New(center_x, center_y, z, initial_radius, delta, parent)
	..()
	src.parent = parent
	START_PROCESSING(SSfastprocess, src)
	var/list/zlevels = GetConnectedZlevels(z)
	for (var/mob/living/L as anything in GLOB.alive_mobs)
		if (!(get_z(L) in zlevels))
			continue
		if (is_forbidden_type(L))
			continue
		mobs_to_switch += L

/datum/bubble_effect/bluespace_pulse/proc/is_forbidden_type(mob)
	return istype(mob, /mob/living/exosuit) || istype(mob, /mob/living/silicon/sil_brainmob) || istype(mob, /mob/living/carbon/brain)


/datum/bubble_effect/bluespace_pulse/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	return ..()


/datum/bubble_effect/bluespace_pulse/Process()
	if (radius > 50)
		qdel(src)
		return PROCESS_KILL
	Tick()


/datum/bubble_effect/bluespace_pulse/TurfEffect(turf/turf)
	if (TICK_CHECK)
		return TRUE
	if (radius <= 20)
		new /obj/temporary (turf, 0.2 SECONDS, 'icons/effects/effects.dmi', "cyan_sparkles")
	var/obj/machinery/light/light = locate() in turf
	if (light && prob(20))
		light.broken()

	var/mob/living/being
	for (var/mob/living/candidate as anything in GLOB.alive_mobs)
		var/turf/mob_turf = get_turf(candidate)
		if (mob_turf == turf)
			being = candidate
			break
	if (being && prob(parent.affect_chance))
		var/list/zlevels = GetConnectedZlevels(get_z(being))
		if (GLOB.using_map.use_bluespace_interlude && prob(parent.interlude_chance))
			if (istype(being, /mob/living/simple_animal) && prob(80))
				return
			if (is_forbidden_type(being))
				return
			var/turf/T = pick_area_turf_in_connected_z_levels(
				list(GLOBAL_PROC_REF(is_not_space_area)),
				list(
					GLOBAL_PROC_REF(not_turf_contains_dense_objects),
					GLOBAL_PROC_REF(IsTurfAtmosSafe)
				),
				zlevels[1])
			if (!T)
				return
			GLOB.using_map.do_interlude_teleport(being, T, frand(parent.interlude_min_time, parent.interlude_max_time))
			return

		//swap places with another mob
		for (var/mob/living/mob as anything in mobs_to_switch)
			var/swap_chance = affect_chance
			if (!(get_z(mob) in zlevels))
				continue
			if (is_forbidden_type(being))
				continue
			if (istype(mob.loc, /turf/space) || istype(being.loc, /turf/space))
				swap_chance = 10 //lots of mobs in space can cause the entire ship to get spaced, so lower the chance

			if (prob(swap_chance))
				continue

			if (mob != being)
				var/source_position = being.loc
				var/other_position = mob.loc
				do_teleport(mob, source_position)
				do_teleport(being, other_position)
				mobs_to_switch -= mob
				mobs_to_switch -= being
				to_chat(mob, SPAN_DANGER("A wave of energy washes over you, and you find yourself somewhere else!"))
				to_chat(being, SPAN_DANGER("A wave of energy washes over you, and you find yourself somewhere else!"))
				return
	else
		to_chat(being, SPAN_WARNING("A wave of energy washes over you, giving you a strange and uneasy feeling..."))
