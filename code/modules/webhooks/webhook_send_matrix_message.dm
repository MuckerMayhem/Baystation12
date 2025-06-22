/singleton/webhook/send_matrix_message
	id = WEBHOOK_SEND_MATRIX_MESSAGE

// Data expects a "name" field containing the name of the submap being announced.
/singleton/webhook/send_matrix_message/get_message(list/data)
	. = ..()
	if (!data)
		return
	var/sender = data["sender"]
	var/channel_name = data["channel_name"]
	var/message = data["message"]

	.["embeds"] = list(
		"channel" = channel_name,
		"sender" = sender,
		"message" = message,
		"color" = COLOR_WEBHOOK_DEFAULT
	)
