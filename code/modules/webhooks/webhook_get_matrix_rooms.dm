/singleton/webhook/get_matrix_rooms
	id = WEBHOOK_GET_MATRIX_ROOMS

// Data expects a "name" field containing the name of the submap being announced.
/singleton/webhook/get_matrix_rooms/get_message(list/data)
	. = ..()
