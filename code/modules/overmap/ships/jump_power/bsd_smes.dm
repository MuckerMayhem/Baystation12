#define CAPACITOR_OFF 0
#define CAPACITOR_DISCHARGING 1
// maybe have the drive get gradually more unstable if it misses charges within the charging window
/obj/machinery/power/smes/buildable/preset/bsd
	name = "bluespace drive battery unit"
	desc = "A specialized superconducting magnetic energy storage (SMES) unit designed to provide power to bluespace drive."
	uncreated_component_parts = list(
		/obj/item/stock_parts/smes_coil/advanced = 1,
		/obj/item/stock_parts/smes_coil/super_capacity = 1)

/obj/machinery/power/capacitor
	name = "bluespace drive jump capacitor"
	desc = "A high-capacity capacitor designed to rapidly discharge large amounts of energy to power a bluespace drive jump."
	icon = 'icons/obj/machines/shielding.dmi'
	icon_state = "generator0"
	density = TRUE
	var/max_energy = 0
	var/min_energy = 1 MEGAWATTS		 // Minimal energy required to start and maintain discharging.
	var/set_output = 1 MEGAWATTS     	// Target energy output rate when discharging.
	var/last_charge = 0
	var/running = CAPACITOR_OFF            // Whether the capacitor is discharging or not.
	var/output_attempt = FALSE
	var/input_cut = FALSE
	var/input_pulsed = FALSE
	var/output_cut = FALSE
	var/output_pulsed = FALSE
	var/obj/machinery/bluespacedrive/connected_drive
	uncreated_component_parts = list(
		/obj/item/stock_parts/smes_coil/super_capacity = 1)

/obj/machinery/power/capacitor/Initialize()
	. = ..()
	for (var/obj/machinery/bluespacedrive/bsd in oview(src, 4))
		connected_drive = bsd
		connected_drive.connected_capacitors += src
		return

/obj/machinery/power/capacitor/on_update_icon()
	if(running)
		icon_state = "generator1"
	else
		icon_state = "generator0"

/obj/machinery/power/capacitor/RefreshParts()
	max_energy = 0
	for(var/obj/item/stock_parts/smes_coil/S in component_parts)
		max_energy += (S.ChargeCapacity / CELLRATE) * 5

/obj/machinery/power/capacitor/proc/start_discharge()
	START_PROCESSING_MACHINE(src, MACHINERY_PROCESS_SELF)
	running = CAPACITOR_DISCHARGING
	on_update_icon()

/obj/machinery/power/capacitor/proc/stop_discharge()
	STOP_PROCESSING_MACHINE(src, MACHINERY_PROCESS_SELF)
	running = CAPACITOR_OFF
	last_charge = 0
	on_update_icon()

/obj/machinery/power/capacitor/proc/deliver_charge(requested_power)
	if (requested_power < min_energy)
		stop_discharge()
		return

	if (connected_drive.current_charge >= connected_drive.max_charge)
		stop_discharge()
		return

	//draw a lightning arc to the bsd later
	last_charge = requested_power
	connected_drive.add_charge(requested_power)

/obj/machinery/power/capacitor/Process()
	if(running == CAPACITOR_DISCHARGING)
		if(powernet)
			deliver_charge(powernet.draw_power(set_output))
		else
			stop_discharge()

#undef CAPACITOR_OFF
#undef CAPACITOR_DISCHARGING
