extends "res://scripts/battle_controller.gd"

# Phase 1 refactor anchor.
#
# The existing battle logic currently still lives in battle_controller.gd.
# This file provides a stable future core path so text UI and visual UI
# can start depending on a shared controller contract without breaking
# the current branch. A later refactor can move shared battle logic here
# and slim battle_controller.gd down into a pure text UI shell.
