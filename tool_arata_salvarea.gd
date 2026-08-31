extends Node

# Tipareste ce e in salvarea reala (`user://scores.save`): leaderboard-ul, monedele si
# upgrade-urile permanente. Nu scrie nimic — doar citeste ce a incarcat `GameSettings`.
# Se ruleaza cand vrei sa te asiguri ca o unealta care omoara player-ul n-a stricat nimic.

func _ready() -> void:
	print("monede: %d" % GameSettings.coins)
	print("upgrade-uri permanente: %s" % [GameSettings.upgrades])
	print("scoruri (%d):" % GameSettings.scores.size())
	for s in GameSettings.scores:
		print("  %6.1f s   nivel %2d   kills %d" % [s.get("time", 0.0), s.get("level", 0), s.get("kills", 0)])
	get_tree().quit()
