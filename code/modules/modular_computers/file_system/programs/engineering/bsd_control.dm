/datum/computer_file/program/bsd_control
	filename = "bsdcontrol"
	filedesc = "Bluespace Drive Control"
	nanomodule_path = /datum/nano_module/program/bsd_control
	program_icon_state = "bsd_control"
	program_key_state = "rd_key"
	program_menu_icon = "shuffle"
	extended_desc = "This program allows control over the ship's bluespace drive jump systems."
	required_access = access_atmospherics
	requires_ntnet = TRUE
	network_destination = "bsd control system"
	requires_ntnet_feature = NTNET_SYSTEMCONTROL
	usage_flags = PROGRAM_CONSOLE
	category = PROG_ENG
	size = 17

/datum/nano_module/program/bsd_control
	name = "Bluespace Drive Control"
	available_to_ai = TRUE
	var/obj/machinery/bluespacedrive/connected_drive
	var/jump_dx = 0
	var/jump_dy = 0
	var/const/cal_count = 5
	var/list/calibration
	var/list/calexpected
	var/accuracy = 0

/datum/nano_module/program/bsd_control/New()
	..()
	reset_calibration()
	var/obj/holder = program.computer.holder
	if (istype(holder))
		var/turf/holder_turf = get_turf(holder)
		var/obj/overmap/visitable/ship = map_sectors["[holder_turf.z]"]
		var/list/map_z = ship?.map_z
		for (var/obj/machinery/bluespacedrive/drive in SSmachines.machinery)
			if (drive.z in map_z)
				connected_drive = drive
				break

/datum/nano_module/program/bsd_control/Topic(href, href_list)
	if(..())
		return TOPIC_HANDLED

	if (href_list["set_output"])
		var/input = input("Enter new output for the capacitors in MW:", "Set Capacitors Output", "") as null|num
		if (!isnum(input))
			return TOPIC_HANDLED
		connected_drive.connected_capacitor.set_output = input MEGAWATTS
		return TOPIC_REFRESH
	if (href_list["discharge"])
		connected_drive.connected_capacitor.start_discharge()
		return TOPIC_REFRESH
	if (href_list["toggle_auto_charge"])
		connected_drive.connected_capacitor.auto_charge = !connected_drive.connected_capacitor.auto_charge
		return TOPIC_REFRESH
	if (href_list["setjumpx"])
		var/newx = input("Input new destination x coordinate", "Coordinate input", jump_dx) as num|null
		if (newx)
			jump_dx = clamp(newx, 2, GLOB.using_map.overmap_size - 1) // can_jump rejects anything outside this
			if (connected_drive.ship.mode == SHIP_MODE_JUMP) // otherwise it would overwrite the hop charge requirement
				connected_drive.get_jump_cost(jump_dx, jump_dy)
	if (href_list["setjumpy"])
		var/newy = input("Input new destination y coordinate", "Coordinate input", jump_dy) as num|null
		if (newy)
			jump_dy = clamp(newy, 2, GLOB.using_map.overmap_size - 1)
			if (connected_drive.ship.mode == SHIP_MODE_JUMP)
				connected_drive.get_jump_cost(jump_dx, jump_dy)
	if (href_list["jump"])
		if (connected_drive.ship.mode != SHIP_MODE_JUMP)
			to_chat(usr, SPAN_DANGER("The drive is set to hop mode. Switch to jump mode at the helm to perform a jump."))
			return TOPIC_HANDLED
		if (!jump_dx || !jump_dy)
			to_chat(usr, SPAN_DANGER("Jump destination not set!"))
			return TOPIC_HANDLED
		else if (connected_drive.current_charge < connected_drive.max_charge)
			to_chat(usr, SPAN_DANGER("The bluespace drive is not charged enough to perform a jump!"))
			return TOPIC_HANDLED
		var/accuracy = cal_accuracy() - get_env_offset()
		if (accuracy < 75)
			to_chat(usr, SPAN_WARNING("Jump accuracy is only at [accuracy]%, there is a risk of missing the target!"))
			var/confirmation = alert(usr, "Jump accuracy is only at [accuracy]%, there is a risk of missing the target!", "Accuracy Low", "Confirm Jump", "Cancel")
			if (confirmation == "Cancel")
				return TOPIC_HANDLED
		connected_drive.ship.start_microjump(jump_dx, jump_dy, SHIP_MODE_JUMP, accuracy)
		if (connected_drive.ship.jumping)
			reset_calibration()
		return TOPIC_REFRESH
	if(href_list["calibration"])
		var/input = input("0-9", "jump calibration", 0) as num|null
		if(!isnull(input))
			var/calnum = sanitize_integer(text2num(href_list["calibration"]), 0, cal_count - 1)
			calibration[calnum + 1] = sanitize_integer(input, 0, 9, 0)
		return TOPIC_REFRESH

/datum/nano_module/program/bsd_control/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1, master_ui = null, datum/topic_state/state = GLOB.default_state)
	var/data = list()

	data["jump_mode"] = connected_drive.ship.mode == SHIP_MODE_JUMP
	data["drive_charge"] = connected_drive.get_charge_percentage()
	var/no_hop = connected_drive.ship.mode == SHIP_MODE_HOP && !connected_drive.ship.is_moving() // matches the helm: no movement, no hop cost
	data["required_charge_rate"] = no_hop ? 0 : connected_drive.required_charge_per_second / 1000000
	data["required_total_charge"] = no_hop ? 0 : connected_drive.max_charge / 1000000
	var/obj/machinery/power/capacitor/capacitor = connected_drive.connected_capacitor
	data["set_output"] = capacitor.set_output / 1000000 // Convert to MW for display.
	data["last_charge"] = capacitor.last_charge / 1000000
	data["running"] = capacitor.running
	data["drive_charge"] = connected_drive.get_charge_percentage()
	data["available_power"] = capacitor.powernet.avail / 1000000
	data["auto_charge"] = capacitor.auto_charge
	data["jump_dx"] = jump_dx
	data["jump_dy"] = jump_dy
	data["calibration"] = calibration
	data["cal_accuracy"] = cal_accuracy()
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "bsd_controller.tmpl", src.name, 625, 625, state = state)
		if(host.update_layout()) // This is necessary to ensure the status bar remains updated along with rest of the UI.
			ui.auto_update_layout = 1
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/computer/modular/preset/bsd
	default_software = list(
		/datum/computer_file/program/power_monitor,
		/datum/computer_file/program/alarm_monitor,
		/datum/computer_file/program/rcon_console,
		/datum/computer_file/program/camera_monitor,
		/datum/computer_file/program/bsd_control
	)

/datum/nano_module/program/bsd_control/proc/get_calibration()
	var/list/calresult = new(cal_count)
	for(var/i = 1 to cal_count)
		if(calibration[i] == calexpected[i])
			calresult[i] = 2
		else if(calibration[i] in calexpected)
			calresult[i] = 1
		else
			calresult[i] = 0
	return calresult

/datum/nano_module/program/bsd_control/proc/reset_calibration()
	calexpected = new(cal_count)
	calibration = new(cal_count)
	for(var/i = 1 to cal_count)
		calexpected[i] = rand(0, 9)
		calibration[i] = 0

/datum/nano_module/program/bsd_control/proc/cal_accuracy()
	var/top = 0
	// Maximum possible value, aka 100% accuracy
	var/divisor = cal_count * 2
	for(var/i in get_calibration())
		top += i
	accuracy = round(top * 100 / divisor)
	return round(top * 100 / divisor)

///Permanent debuf to accuracy based on dark matter present in sector.
/datum/nano_module/program/bsd_control/proc/get_env_offset()
	var/total = 0
	for (var/obj/overmap/event/gravity/dark_matter in /area/overmap)
		total += 1

	if (total <= 10)
		return 0

	//lower accuracy based on total dark matter, 1% per DM, up to 25% max
	return min(total, 25)
