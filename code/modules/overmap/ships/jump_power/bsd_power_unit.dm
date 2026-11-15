#define POWERBANK_OFF FLAG(0)
#define POWERBANK_CHARGING FLAG(1)
#define POWERBANK_DISCHARGING FLAG(2)

/obj/machinery/power/bsd_powerbank
	name = "bluespace drive powerbank"
	desc = "A heavy duty power bank designed to provide immense amounts of energy to a bluespace drive unit."
	icon = 'icons/obj/machines/shielding.dmi'
	icon_state = "generator0"
	density = TRUE
	base_type = /obj/machinery/power/bsd_powerbank
	construct_state = /singleton/machine_construction/default/panel_closed
	wires = /datum/wires/bsd_powerbank
	uncreated_component_parts = null
	stat_immune = FALSE
	machine_name = "bluespace drive powerbank"
	machine_desc = "A power storage unit designed to rapidly discharge energy into the bluespace drive to power microjumps."
	uncreated_component_parts = list(
		/obj/item/stock_parts/smes_coil/advanced = 1,
		/obj/item/stock_parts/smes_coil/super_capacity = 1)
	var/max_energy = 1 GIGAWATTS                  // Maximal stored energy. In joules. Depends on the type of used SMES coil when constructing this generator.
	var/current_energy = 0              // Current stored energy.
	var/field_radius = 1                // Current field radius.
	var/target_radius = 1               // Desired field radius.
	var/running = POWERBANK_OFF            // Whether the generator is enabled or not.
	var/input_cap = 1 MEGAWATTS         // Currently set input limit. Set to 0 to disable limits altogether. The bank will try to input this value per tick at most
	var/upkeep_power_usage = 0          // Upkeep power usage last tick.
	var/upkeep_multiplier = 1           // Multiplier of upkeep values.
	var/power_usage = 0                 // Total power usage last tick.
	var/overloaded = FALSE                  // Whether the field has overloaded and shut down to regenerate.
	var/hacked = FALSE                      // Whether the generator has been hacked by cutting the safety wire.
	var/offline_for = 0                 // The generator will be inoperable for this duration in ticks.
	var/input_cut = FALSE                   // Whether the input wire is cut.
	var/mode_changes_locked = FALSE         // Whether the control wire is cut, locking out changes.
	var/ai_control_disabled = FALSE         // Whether the AI control is disabled.
	var/input_cap = 10 MEGAWATTS        // Maximal input capacity.

	var/required_power_modifier = 1     // Modifier to the amount of power required to perform a job. Changes with upgrades.


/obj/machinery/power/bsd_powerbank/Initialize()
	. = ..()
	connect_to_network()

/obj/machinery/power/bsd_powerbank/Destroy()
	. = ..()
	// blow it up if theres lots of power maybe

/obj/machinery/power/bsd_powerbank/RefreshParts()
	max_energy = 0
	current_energy = clamp(current_energy, 0, max_energy)

	..()



/datum/wires/bsd_powerbank
	holder_type = /obj/machinery/power/bsd_powerbank
	wire_count = 5
	descriptions = list(
		new /datum/wire_description(BSD_POWERBANK_WIRE_POWER, "This wire seems to be carrying a heavy current.", "Power", SKILL_EXPERIENCED),
		new /datum/wire_description(BSD_POWERBANK_WIRE_HACK, "This wire seems designed to enable a manual override.", "Override"),
		new /datum/wire_description(BSD_POWERBANK_WIRE_CONTROL, "This wire connects to the main control panel.", "Interface"),
		new /datum/wire_description(BSD_POWERBANK_WIRE_AICONTROL, "This wire connects to automated control systems.", "AI")
	)

var/global/const/BSD_POWERBANK_WIRE_POWER = 1			// Cut to disable power input into the generator. Pulse does nothing. Mend to restore.
var/global/const/BSD_POWERBANK_WIRE_HACK = 2			// Pulse to hack the generator, enabling hacked modes. Cut to unhack. Mend does nothing.
var/global/const/BSD_POWERBANK_WIRE_CONTROL = 4		// Cut to lock most unit controls. Mend to unlock them. Pulse does nothing.
var/global/const/BSD_POWERBANK_WIRE_AICONTROL = 8		// Cut to disable AI control. Mend to restore.
var/global/const/BSD_POWERBANK_WIRE_NOTHING = 16		// A blank wire that doesn't have any specific function

/datum/wires/bsd_powerbank/CanUse()
	var/obj/machinery/power/bsd_powerbank/S = holder
	if(S.panel_open)
		return TRUE
	return FALSE

/datum/wires/bsd_powerbank/UpdateCut(index, mended)
	var/obj/machinery/power/bsd_powerbank/S = holder
	switch(index)
		if(BSD_POWERBANK_WIRE_POWER)
			S.input_cut = !mended
		if(BSD_POWERBANK_WIRE_HACK)
			if(!mended)
				S.hacked = TRUE
				if(S.check_flag(MODEFLAG_BYPASS))
					S.toggle_flag(MODEFLAG_BYPASS)
				if(S.check_flag(MODEFLAG_OVERCHARGE))
					S.toggle_flag(MODEFLAG_OVERCHARGE)
		if(BSD_POWERBANK_WIRE_CONTROL)
			S.mode_changes_locked = !mended
		if(BSD_POWERBANK_WIRE_AICONTROL)
			S.ai_control_disabled = !mended

/datum/wires/bsd_powerbank/UpdatePulsed(index)
	var/obj/machinery/power/bsd_powerbank/S = holder
	switch(index)
		if(BSD_POWERBANK_WIRE_HACK)
			S.hacked = TRUE

/obj/machinery/power/bsd_powerbank/proc/input_power(percentage)
	var/to_input = target_load * (percentage/100)
	to_input = clamp(to_input, 0, target_load)
	input_available = 0
	if(percentage == 100)
		inputting = 2
	else if(percentage)
		inputting = 1
	// else inputting = 0, as set in process()

	for(var/obj/item/stock_parts/power/terminal/term in power_components)
		var/inputted = term.use_power_oneoff(src, to_input, power_channel)
		add_charge(inputted)
		input_available += inputted
