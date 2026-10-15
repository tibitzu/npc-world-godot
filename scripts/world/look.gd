class_name Look
## Colour helpers that keep the Godot version looking like the HTML game.


## The HTML game (three.js r128) lit material colours as if their hex values were linear,
## so the same hex appears lighter there. This gives the colour that looks the same here.
static func html_colour(c: Color) -> Color:
	return c.linear_to_srgb()


static func html_hex(hex: int) -> Color:
	return html_colour(Color.hex((hex << 8) | 0xff))
