#!/usr/bin/env bats

GAME_DIR=".."

setup() {
    # Create a temporary directory for testing
    export TEST_DIR=$(mktemp -d)
    export GAME_DIR="$TEST_DIR/isopod_shell"
    export STATE_FILE="$GAME_DIR/state.json"

    # Define the locations and items
    LOCATIONS=("forest" "river" "burrow")
    ITEMS=("hiding_place" "cookie_crumb" "isopod_friend")

    # Source the game script
    load "./../isopod_shell.sh"
}

teardown() {
    # Clean up the temporary directory after tests
    rm -rf "$TEST_DIR"
}

@test "game_init initializes the game correctly" {
    run game_init

    # Check that directories are created
    for loc in "${LOCATIONS[@]}"; do
        [ -d "$GAME_DIR/$loc" ]
    done

    # Check that the state file is initialized
    [ -f "$STATE_FILE" ]

    # Check that the state file contains the initial state
    run jq -r '.location' "$STATE_FILE"
    [ "$status" -eq 0 ]
    [ "$output" == "forest" ]

    for item in "${ITEMS[@]}"; do
        run jq -r ".$item" "$STATE_FILE"
        [ "$status" -eq 0 ]
        [ "$output" == "false" ]
    done
}

@test "game_describe_location outputs the correct description" {
    game_init
    run game_describe_location

    # Default location should be "forest"
    [ "$status" -eq 0 ]
    [ "$output" == "You are in a dark forest with towering trees." ]
}

@test "game_move_to_location correctly updates the location" {
    game_init
    run game_move_to_location "river"

    [ "$status" -eq 0 ]
    run jq -r '.location' "$STATE_FILE"
    [ "$output" == "river" ]

    run game_move_to_location "burrow"
    [ "$status" -eq 0 ]
    run jq -r '.location' "$STATE_FILE"
    [ "$output" == "burrow" ]

    # Bad test because returning 1 will crash the whole app. (or we have to run without `set -e`)
    # run "non_existent_location"
    # [ "$status" -ne 0 ]
}

@test "game_check_for_items finds items correctly" {
    game_init

    # Manually place an item in the forest
    echo "hiding_place" > "$GAME_DIR/forest/item.txt"

    run game_check_for_items
    [ "$status" -eq 0 ]
    [ "$output" == "You found a hiding_place!" ]

    # Check that the state file was updated
    run jq -r '.hiding_place' "$STATE_FILE"
    [ "$output" == "true" ]
}

@test "game_check_win_condition correctly identifies win state" {
    game_init

    # Manually set all items to found in the state file
    jq '.hiding_place = true | .cookie_crumb = true | .isopod_friend = true' "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    run game_check_win_condition
    [ "$status" -eq 0 ]
    [ "$output" == "Congratulations! You've found a place to hide, a cookie crumb, and another isopod friend. You win!" ]
}

