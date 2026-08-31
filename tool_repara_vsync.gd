extends Node

# UNEALTĂ DE REPARAT O URMĂ LĂSATĂ DE MINE (se rulează ca SCENĂ):
#
#   godot --path <proiect> res://tool_repara_vsync.tscn
#
# Pe 2026-08-31, o versiune intermediară a lui `tool_profil_greu.gd` stingea v-sync-ul prin
# `GameSettings.set_vsync(false)`. Metoda aia cheamă și `_save()`, adică scrie în fișierul REAL
# de setări (`user://scores.save`) — deci i-a rămas lui Răzvan v-sync-ul stins în joc, deși el
# nu ceruse asta. Unealta de profilare a fost reparată (scrie câmpul direct, fără `_save`);
# asta pune setarea la loc pe ADEVĂRAT, cum era.
#
# Leaderboard-ul și monedele nu sunt atinse: `_save()` scrie tot fișierul, iar scorurile sunt
# citite din memorie, unde au rămas neschimbate.

func _ready() -> void:
	print("vsync înainte: %s" % GameSettings.vsync)
	GameSettings.set_vsync(true)
	print("vsync după:    %s" % GameSettings.vsync)
	get_tree().quit()
