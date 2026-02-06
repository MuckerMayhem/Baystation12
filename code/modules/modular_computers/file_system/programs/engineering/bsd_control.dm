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

/datum/nano_module/program/bsd_control/New()
	..()
	var/obj/holder = program.computer.holder
	if (istype(holder))
		var/turf/holder_turf = get_turf(holder)
		var/obj/overmap/visitable/ship = map_sectors["[holder_turf.z]"]
		var/list/map_z = ship.map_z
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

/datum/nano_module/program/bsd_control/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1, master_ui = null, datum/topic_state/state = GLOB.default_state)
	var/data = list()

	data["drive_charge"] = connected_drive.get_charge_percentage()
	data["required_charge_rate"] = connected_drive.required_charge_per_second / 1000000
	var/obj/machinery/power/capacitor/capacitor = connected_drive.connected_capacitor
	data["set_output"] = capacitor.set_output / 1000000 // Convert to MW for display.
	data["last_charge"] = capacitor.last_charge / 1000000
	data["running"] = capacitor.running
	data["drive_charge"] = connected_drive.get_charge_percentage()
	data["available_power"] = capacitor.powernet.avail / 1000000
	data["auto_charge"] = capacitor.auto_charge
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
