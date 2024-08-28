#!/bin/bash
set -eou pipefail

# Namespace functions and variables to avoid conflicts
GAME_DIR="isopod_shell"
STATE_FILE="$GAME_DIR/state.json"
LOCATIONS=("forest" "river" "burrow")
ITEMS=("hiding_place" "cookie_crumb" "isopod_friend")

# Source the log.sh script if $DEBUG is set
# otherwise the test fail.
if [[ -n "${DEBUG:-}" ]]; then
	function log() {
		return 0
	}
else
  # shell check can't deal with paths with variables in them.
	source "./dependencies/bashlog/log.sh"
fi

#######################################
# Initialize game environment.
# Globals:
#   GAME_DIR
#   STATE_FILE
#   LOCATIONS
#   ITEMS
# Arguments:
#   None
# Outputs:
#   None
#######################################
function game_init() {
	# empty the game directory
	log info 'Clearing game directory'
	rm -rf "$GAME_DIR"

	mkdir -p "$GAME_DIR"

	# Initialize locations and descriptions
	mkdir -p "$GAME_DIR/forest" "$GAME_DIR/river" "$GAME_DIR/burrow"
	echo "You are in a dark forest with towering trees." >"$GAME_DIR/forest/description.txt"
	echo "You are by a flowing river. The sound of water is soothing." >"$GAME_DIR/river/description.txt"
	echo "You are in a small burrow. It's cozy here." >"$GAME_DIR/burrow/description.txt"

	# Place items randomly in locations
	local item_location
	for item in "${ITEMS[@]}"; do
		# Place items randomly in locations without overwriting
		while true; do
			item_location="${LOCATIONS[$((RANDOM % ${#LOCATIONS[@]}))]}"
			if [[ ! -f "$GAME_DIR/$item_location/item.txt" ]]; then
				echo "$item" >"$GAME_DIR/$item_location/item.txt"
				log info "Stored item in $item_location"
				break
			fi
		done
	done

	# Initialize game state
	echo '{"location": "forest", "hiding_place": false, "cookie_crumb": false, "isopod_friend": false}' >"$STATE_FILE"
	return 0
}

#######################################
# Display the current location description.
# Globals:
#   STATE_FILE
#   GAME_DIR
# Outputs:
#   Writes location description to stdout
#######################################
function game_describe_location() {
	local location
	location=$(jq -r '.location' "$STATE_FILE")
	cat "$GAME_DIR/$location/description.txt"
	return 0
}

#######################################
# Check the current location for items.
# Globals:
#   STATE_FILE
#   GAME_DIR
# Outputs:
#   Updates the game state if an item is found
#######################################
function game_check_for_items() {
	local location
	location=$(jq -r '.location' "$STATE_FILE")

	if [[ -f "$GAME_DIR/$location/item.txt" ]]; then
		local item
		item=$(cat "$GAME_DIR/$location/item.txt")
		jq ".$item = true" "$STATE_FILE" >"${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
		echo "You found a $item!"
		rm "$GAME_DIR/$location/item.txt"
		# successful
		return 0
	else
		echo "There's nothing special here."
	fi
}

#######################################
# Move to a new location.
# Globals:
#   STATE_FILE
#   LOCATIONS
# Arguments:
#   $1 - New location
# Outputs:
#   Updates the game state with the new location
#######################################
function game_move_to_location() {
	local new_location=$1
	if [[ " ${LOCATIONS[*]} " == *" $new_location "* ]]; then
		jq ".location = \"$new_location\"" "$STATE_FILE" >"${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
		echo "You moved to the $new_location."
		return 0
	else
		# This needs to set a return value without exiting the script
		echo "You can't go there."
	fi
}

#######################################
# Check if the player has won.
# Globals:
#   STATE_FILE
# Outputs:
#   Writes win message to stdout if all items are found
#######################################
function game_check_win_condition() {
	local hiding_place
	local cookie_crumb
	local isopod_friend

	hiding_place=$(jq -r '.hiding_place' "$STATE_FILE")
	cookie_crumb=$(jq -r '.cookie_crumb' "$STATE_FILE")
	isopod_friend=$(jq -r '.isopod_friend' "$STATE_FILE")

	if [[ "$hiding_place" == "true" && "$cookie_crumb" == "true" && "$isopod_friend" == "true" ]]; then
		echo "Congratulations! You've found a place to hide, a cookie crumb, and another isopod friend. You win!"
		exit 0
	else
		log info "Still didn't win"
	fi
	return 0
}

#######################################
# Main game loop.
# Globals:
#   None
# Outputs:
#   Game interaction messages
#######################################
function game_loop() {
	while true; do
		game_describe_location
		game_check_for_items
		game_check_win_condition

		echo "What would you like to do?"
		echo "1. Move to another location"
		echo "2. Inspect the area"
		echo "3. Quit"
		read -r choice

		case $choice in
		1)
			echo "Where would you like to go? (forest, river, burrow)"
			read -r new_location
			if ! game_move_to_location "$new_location"; then
				echo "Failed to move to $new_location. Please try again."
			fi
			;;
		2)
			if ! game_check_for_items; then
				echo "No items found."
			fi
			;;
		3)
			echo "Goodbye!"
			exit 0
			;;
		*)
			echo "Invalid choice, please try again."
			;;
		esac
	done
}

# Only run game_init and game_loop if the script is executed directly
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
	# Export everything
	export -f game_init
	export -f game_loop
	export -f game_describe_location
	export -f game_check_for_items
	export -f game_move_to_location
	export -f game_check_win_condition
else
	# my_script "${@}"
	game_init
	game_loop
	exit $?
fi
