extends Node

# TRADUCERILE JOCULUI. Autoload „I18n".
#
# Cum funcționează, pe scurt:
#   • Textele din joc rămân scrise în ENGLEZĂ direct în cod (`b.text = "START"`). Engleza e
#     „limba sursă", deci nu are nevoie de tabel.
#   • Aici construim, la pornire, câte un `Translation` pentru fiecare din celelalte 8 limbi și
#     îl dăm lui `TranslationServer`. Din momentul ăla, Godot traduce SINGUR orice text pus pe
#     un Label/Button (se numește „auto-translate") — inclusiv când schimbi limba din meniu:
#     nodurile primesc NOTIFICATION_TRANSLATION_CHANGED și se redesenează în limba nouă.
#   • De aia codul jocului aproape nu s-a schimbat: nu trebuie `tr(...)` peste tot.
#
# ⚠️ SINGURA excepție: textele CU FORMATARE (`"Kills: %d" % n`). Acolo trebuie scris explicit
# `tr("Kills: %d") % n` — altfel cheia căutată ar fi „Kills: 42", care nu există în tabel.
# Vezi hud.gd, gameover.gd, interact_ui.gd, menu.gd (leaderboard).
#
# CUM ADAUGI UN TEXT NOU: îl scrii în engleză în cod, apoi adaugi un rând în TRAD cu exact
# aceeași cheie (litere mari/mici, spații, semne — totul contează) și cele 8 traduceri, în
# ORDINEA din `ORDINE`. `tool_check_i18n.gd` verifică dacă ai uitat ceva.
#
# CUM ADAUGI O LIMBĂ NOUĂ: adaugi codul în `ORDINE`, un rând în `LIMBI` (cu numele scris în
# limba ei), încă o traducere la FIECARE rând din TRAD și un steag în `menu/flags/<cod>.png`
# (se desenează cu `tool_flags.gd`).

# Ordinea coloanelor din tabelul de mai jos. Engleza NU e aici: e limba în care e scris jocul.
const ORDINE := ["zh", "de", "es", "ru", "fr", "ja", "pl", "tr"]

# Ce se vede în selectorul de limbă: codul, numele scris ÎN limba lui, steagul.
const LIMBI := [
	{"cod": "en", "nume": "English",  "steag": "res://menu/flags/en.png"},
	{"cod": "zh", "nume": "中文",      "steag": "res://menu/flags/zh.png"},
	{"cod": "de", "nume": "Deutsch",  "steag": "res://menu/flags/de.png"},
	{"cod": "es", "nume": "Español",  "steag": "res://menu/flags/es.png"},
	{"cod": "ru", "nume": "Русский",  "steag": "res://menu/flags/ru.png"},
	{"cod": "fr", "nume": "Français", "steag": "res://menu/flags/fr.png"},
	{"cod": "ja", "nume": "日本語",     "steag": "res://menu/flags/ja.png"},
	{"cod": "pl", "nume": "Polski",   "steag": "res://menu/flags/pl.png"},
	{"cod": "tr", "nume": "Türkçe",   "steag": "res://menu/flags/tr.png"},
]

# ============================ TABELUL DE TRADUCERI ============================
# cheie (engleza din cod) : [zh, de, es, ru, fr, ja, pl, tr]
const TRAD := {
# ---------- meniul principal ----------
"START": ["开始", "START", "JUGAR", "СТАРТ", "JOUER", "スタート", "START", "BAŞLA"],
"CHOOSE CHARACTER": ["选择角色", "CHARAKTER WÄHLEN", "ELEGIR PERSONAJE", "ВЫБОР ПЕРСОНАЖА", "CHOISIR UN PERSONNAGE", "キャラクター選択", "WYBIERZ POSTAĆ", "KARAKTER SEÇ"],
"CHOOSE WEAPON": ["选择武器", "WAFFE WÄHLEN", "ELEGIR ARMA", "ВЫБОР ОРУЖИЯ", "CHOISIR UNE ARME", "武器選択", "WYBIERZ BROŃ", "SİLAH SEÇ"],
"LEADERBOARD": ["排行榜", "BESTENLISTE", "CLASIFICACIÓN", "ТАБЛИЦА ЛИДЕРОВ", "CLASSEMENT", "ランキング", "RANKING", "SIRALAMA"],
"BACK": ["返回", "ZURÜCK", "VOLVER", "НАЗАД", "RETOUR", "戻る", "POWRÓT", "GERİ"],
"SETTINGS": ["设置", "EINSTELLUNGEN", "AJUSTES", "НАСТРОЙКИ", "OPTIONS", "設定", "USTAWIENIA", "AYARLAR"],
"LANGUAGE": ["语言", "SPRACHE", "IDIOMA", "ЯЗЫК", "LANGUE", "言語", "JĘZYK", "DİL"],
"PISTOL": ["手枪", "PISTOLE", "PISTOLA", "ПИСТОЛЕТ", "PISTOLET", "ピストル", "PISTOLET", "TABANCA"],
"MAGE STAFF": ["法杖", "MAGIERSTAB", "BÁCULO MÁGICO", "ПОСОХ МАГА", "BÂTON DE MAGE", "魔法の杖", "KOSTUR MAGA", "BÜYÜCÜ ASASI"],
"EXTINGUISHER": ["灭火器", "FEUERLÖSCHER", "EXTINTOR", "ОГНЕТУШИТЕЛЬ", "EXTINCTEUR", "消火器", "GAŚNICA", "YANGIN SÖNDÜRÜCÜ"],
"CURSED SWORD": ["诅咒之剑", "VERFLUCHTES SCHWERT", "ESPADA MALDITA", "ПРОКЛЯТЫЙ МЕЧ", "ÉPÉE MAUDITE", "呪われた剣", "PRZEKLĘTY MIECZ", "LANETLİ KILIÇ"],
"Only one character for now: \"Grasu\".\nMore coming soon!": ["目前只有一个角色：“Grasu”。\n更多角色即将推出！", "Momentan gibt es nur einen Charakter: „Grasu“.\nMehr folgen bald!", "Por ahora solo hay un personaje: «Grasu».\n¡Pronto habrá más!", "Пока есть только один персонаж: «Grasu».\nСкоро будут ещё!", "Un seul personnage pour l’instant : « Grasu ».\nD’autres arrivent bientôt !", "今のところキャラクターは「Grasu」だけ。\n近日追加予定！", "Na razie jest tylko jedna postać: „Grasu”.\nWięcej wkrótce!", "Şimdilik tek karakter var: “Grasu”.\nYakında daha fazlası!"],
"No scores yet. Play a round!": ["还没有成绩。来玩一局吧！", "Noch keine Ergebnisse. Spiel eine Runde!", "Aún no hay puntuaciones. ¡Juega una partida!", "Пока нет результатов. Сыграй раунд!", "Aucun score pour l’instant. Fais une partie !", "まだ記録がありません。一回遊んでみよう！", "Brak wyników. Zagraj rundę!", "Henüz skor yok. Bir tur oyna!"],
"%d.   %d:%02d   ·   Level %d   ·   %d kills": ["%d.   %d:%02d   ·   等级 %d   ·   击杀 %d", "%d.   %d:%02d   ·   Level %d   ·   %d Kills", "%d.   %d:%02d   ·   Nivel %d   ·   %d muertes", "%d.   %d:%02d   ·   Уровень %d   ·   убийств: %d", "%d.   %d:%02d   ·   Niveau %d   ·   %d élim.", "%d.   %d:%02d   ·   レベル %d   ·   撃破 %d", "%d.   %d:%02d   ·   Poziom %d   ·   %d zab.", "%d.   %d:%02d   ·   Seviye %d   ·   %d öldürme"],
"SURVIVED": ["幸存", "ÜBERLEBT", "SOBREVIVIÓ", "ВЫЖИЛ", "SURVÉCU", "生還", "PRZETRWAŁ", "HAYATTA KALDI"],

# ---------- settings ----------
"MUSIC": ["音乐", "MUSIK", "MÚSICA", "МУЗЫКА", "MUSIQUE", "音楽", "MUZYKA", "MÜZİK"],
"SOUND FX": ["音效", "SOUNDEFFEKTE", "EFECTOS", "ЗВУКИ", "EFFETS SONORES", "効果音", "EFEKTY", "SES EFEKTİ"],
"CONTROLS": ["控制", "STEUERUNG", "CONTROLES", "УПРАВЛЕНИЕ", "COMMANDES", "操作", "STEROWANIE", "KONTROLLER"],
"EFFECTS": ["特效", "EFFEKTE", "EFECTOS", "ЭФФЕКТЫ", "EFFETS", "エフェクト", "EFEKTY", "EFEKTLER"],
"KEYBINDS": ["按键", "TASTEN", "TECLAS", "КЛАВИШИ", "TOUCHES", "キー設定", "KLAWISZE", "TUŞLAR"],
"GRAPHICS": ["画面", "GRAFIK", "GRÁFICOS", "ГРАФИКА", "GRAPHISMES", "グラフィック", "GRAFIKA", "GRAFİK"],
"FULLSCREEN": ["全屏", "VOLLBILD", "PANTALLA COMPLETA", "ПОЛНЫЙ ЭКРАН", "PLEIN ÉCRAN", "フルスクリーン", "PEŁNY EKRAN", "TAM EKRAN"],
"V-SYNC": ["垂直同步", "V-SYNC", "V-SYNC", "ВЕРТ. СИНХР.", "V-SYNC", "垂直同期", "V-SYNC", "V-SYNC"],
"VIGNETTE": ["暗角", "VIGNETTE", "VIÑETA", "ВИНЬЕТКА", "VIGNETTAGE", "ビネット", "WINIETA", "VİNYET"],
"GLOW": ["辉光", "LEUCHTEN", "RESPLANDOR", "СВЕЧЕНИЕ", "HALO", "グロー", "POŚWIATA", "PARLAMA"],
"effects apply in-game": ["效果在游戏中生效", "wirkt sich im Spiel aus", "se aplican en la partida", "применяется в игре", "s’applique en jeu", "ゲーム中に反映されます", "działa w grze", "oyun içinde geçerli"],
"ON": ["开", "AN", "SÍ", "ВКЛ", "OUI", "オン", "WŁ", "AÇIK"],
"OFF": ["关", "AUS", "NO", "ВЫКЛ", "NON", "オフ", "WYŁ", "KAPALI"],
"press a key…": ["按一个键…", "Taste drücken…", "pulsa una tecla…", "нажми клавишу…", "appuie sur une touche…", "キーを押して…", "naciśnij klawisz…", "bir tuşa bas…"],
"Up": ["上", "Hoch", "Arriba", "Вверх", "Haut", "上", "Góra", "Yukarı"],
"Down": ["下", "Runter", "Abajo", "Вниз", "Bas", "下", "Dół", "Aşağı"],
"Left": ["左", "Links", "Izquierda", "Влево", "Gauche", "左", "Lewo", "Sol"],
"Right": ["右", "Rechts", "Derecha", "Вправо", "Droite", "右", "Prawo", "Sağ"],
"Interact": ["互动", "Interagieren", "Interactuar", "Действие", "Interagir", "調べる", "Interakcja", "Etkileşim"],

# ---------- pauză ----------
"PAUSED": ["已暂停", "PAUSE", "PAUSA", "ПАУЗА", "PAUSE", "ポーズ", "PAUZA", "DURAKLATILDI"],
"Resume": ["继续", "Fortsetzen", "Continuar", "Продолжить", "Reprendre", "再開", "Wznów", "Devam Et"],
"Main Menu": ["主菜单", "Hauptmenü", "Menú principal", "Главное меню", "Menu principal", "メインメニュー", "Menu główne", "Ana Menü"],
"Restart Run": ["重新开始", "Neustart", "Reiniciar", "Начать заново", "Recommencer", "リスタート", "Zacznij od nowa", "Yeniden Başlat"],
"Settings": ["设置", "Einstellungen", "Ajustes", "Настройки", "Options", "設定", "Ustawienia", "Ayarlar"],
"Quit Game": ["退出游戏", "Spiel beenden", "Salir del juego", "Выйти из игры", "Quitter le jeu", "ゲーム終了", "Wyjdź z gry", "Oyundan Çık"],
"Back": ["返回", "Zurück", "Volver", "Назад", "Retour", "戻る", "Powrót", "Geri"],

# ---------- game over / HUD ----------
"YOU DIED": ["你死了", "DU BIST TOT", "HAS MUERTO", "ТЫ УМЕР", "VOUS ÊTES MORT", "死亡", "ZGINĄŁEŚ", "ÖLDÜN"],
"PLAY AGAIN": ["再玩一次", "NOCHMAL SPIELEN", "JUGAR OTRA VEZ", "ИГРАТЬ СНОВА", "REJOUER", "もう一度", "ZAGRAJ PONOWNIE", "TEKRAR OYNA"],
"MENU": ["菜单", "MENÜ", "MENÚ", "МЕНЮ", "MENU", "メニュー", "MENU", "MENÜ"],
"Survived: %d:%02d": ["存活时间: %d:%02d", "Überlebt: %d:%02d", "Sobreviviste: %d:%02d", "Продержался: %d:%02d", "Survécu : %d:%02d", "生存時間: %d:%02d", "Przetrwałeś: %d:%02d", "Hayatta kalma: %d:%02d"],
"   (Final Swarm: +%d:%02d)": ["   (最终虫潮: +%d:%02d)", "   (Finaler Schwarm: +%d:%02d)", "   (Enjambre Final: +%d:%02d)", "   (Финальная волна: +%d:%02d)", "   (Nuée finale : +%d:%02d)", "   (ファイナルスウォーム: +%d:%02d)", "   (Finałowy Rój: +%d:%02d)", "   (Son Akın: +%d:%02d)"],
"Level reached: %d": ["达到等级: %d", "Level erreicht: %d", "Nivel alcanzado: %d", "Достигнут уровень: %d", "Niveau atteint : %d", "到達レベル: %d", "Osiągnięty poziom: %d", "Ulaşılan seviye: %d"],
"Kills: %d": ["击杀: %d", "Kills: %d", "Muertes: %d", "Убийства: %d", "Élim. : %d", "撃破: %d", "Zabójstwa: %d", "Öldürme: %d"],
"Level %d": ["等级 %d", "Level %d", "Nivel %d", "Уровень %d", "Niveau %d", "レベル %d", "Poziom %d", "Seviye %d"],
"Press %s to interact": ["按 %s 互动", "%s drücken zum Interagieren", "Pulsa %s para interactuar", "Нажми %s для действия", "Appuie sur %s pour interagir", "%s キーで調べる", "Naciśnij %s, aby wejść w interakcję", "Etkileşim için %s'e bas"],
"Blocked": ["格挡", "Geblockt", "Bloqueado", "Заблокировано", "Bloqué", "ブロック", "Zablokowane", "Engellendi"],
"You need a key": ["需要钥匙", "Du brauchst einen Schlüssel", "Necesitas una llave", "Нужен ключ", "Il te faut une clé", "カギが必要", "Potrzebujesz klucza", "Bir anahtar gerek"],

# ---------- level up ----------
"LEVEL UP!  Choose:": ["升级！选择:", "LEVEL UP!  Wähle:", "¡SUBES DE NIVEL!  Elige:", "НОВЫЙ УРОВЕНЬ!  Выбери:", "NIVEAU SUPÉRIEUR !  Choisis :", "レベルアップ！選べ:", "NOWY POZIOM!  Wybierz:", "SEVİYE ATLADIN!  Seç:"],
"STATS": ["属性", "WERTE", "ESTADÍSTICAS", "ХАРАКТЕРИСТИКИ", "STATS", "ステータス", "STATYSTYKI", "İSTATİSTİK"],
"Common": ["普通", "Gewöhnlich", "Común", "Обычный", "Commun", "コモン", "Zwykły", "Sıradan"],
"Uncommon": ["罕见", "Ungewöhnlich", "Poco común", "Необычный", "Peu commun", "アンコモン", "Niezwykły", "Az Bulunur"],
"Rare": ["稀有", "Selten", "Raro", "Редкий", "Rare", "レア", "Rzadki", "Nadir"],
"Epic": ["史诗", "Episch", "Épico", "Эпический", "Épique", "エピック", "Epicki", "Destansı"],
"Legendary": ["传说", "Legendär", "Legendario", "Легендарный", "Légendaire", "レジェンダリー", "Legendarny", "Efsanevi"],

# ---------- panoul de statusuri (rândurile trebuie să rămână SCURTE, panoul are lățime fixă) ----------
"Damage": ["伤害", "Schaden", "Daño", "Урон", "Dégâts", "攻撃力", "Obrażenia", "Hasar"],
"Attack Speed": ["攻速", "Angriffstempo", "Vel. ataque", "Скорострел.", "Cadence", "攻撃速度", "Szybkostrz.", "Saldırı Hızı"],
"Crit": ["暴击", "Krit", "Crítico", "Крит", "Critique", "クリティカル", "Kryt", "Kritik"],
"Projectiles": ["弹丸", "Geschosse", "Proyectiles", "Снаряды", "Projectiles", "弾数", "Pociski", "Mermi"],
"Pierce": ["穿透", "Durchschlag", "Perforación", "Пробитие", "Perforation", "貫通", "Przebicie", "Delme"],
"Weapon Size": ["武器大小", "Waffengröße", "Tamaño arma", "Размер оруж.", "Taille d’arme", "武器サイズ", "Rozmiar broni", "Silah Boyutu"],
"Knockback": ["击退", "Rückstoß", "Retroceso", "Отброс", "Recul", "ノックバック", "Odrzut", "Geri İtme"],
"Instakill": ["秒杀", "Sofortkill", "Ejecución", "Мгн. смерть", "Exécution", "即死", "Egzekucja", "Anlık Ölüm"],
"Luck": ["幸运", "Glück", "Suerte", "Удача", "Chance", "運", "Szczęście", "Şans"],
"Move Speed": ["移速", "Tempo", "Velocidad", "Скорость", "Vitesse", "移動速度", "Szybkość", "Hız"],
"Max HP": ["最大生命", "Max. HP", "HP máx.", "Макс. HP", "PV max", "最大HP", "Maks. HP", "Maks. CAN"],
"HP Regen": ["生命回复", "HP-Regen", "Regen. HP", "Реген. HP", "Régén. PV", "HP回復", "Regen. HP", "CAN Yenil."],
"Damage Taken": ["受到伤害", "Erlitt. Schaden", "Daño recibido", "Получ. урон", "Dégâts subis", "被ダメージ", "Otrzym. obraż.", "Alınan Hasar"],

# ---------- anunțurile de pe ecran ----------
"LIMBO": ["灵薄狱", "LIMBUS", "LIMBO", "ЛИМБ", "LIMBES", "リンボ", "LIMBO", "LİMBO"],
"Survive 1:00 and you go back": ["撑过 1:00 就能回去", "Überlebe 1:00 und du kommst zurück", "Sobrevive 1:00 y volverás", "Продержись 1:00 и вернёшься", "Survis 1:00 et tu reviens", "1:00 生き延びれば戻れる", "Przetrwaj 1:00, a wrócisz", "1:00 hayatta kal ve geri dön"],
"YOU MADE IT": ["你成功了", "GESCHAFFT", "LO LOGRASTE", "ПОЛУЧИЛОСЬ", "TU AS RÉUSSI", "やり遂げた", "UDAŁO SIĘ", "BAŞARDIN"],
"The spirit sends you back": ["灵魂送你回去", "Der Geist schickt dich zurück", "El espíritu te devuelve", "Дух отправляет тебя назад", "L’esprit te renvoie", "精霊が君を送り返す", "Duch odsyła cię z powrotem", "Ruh seni geri gönderiyor"],
"THE NETHER": ["下界", "DER NETHER", "EL NETHER", "НИЖНИЙ МИР", "LE NETHER", "ネザー", "NETHER", "NETHER"],
"Kill Saratalin to leave": ["杀死 Saratalin 才能离开", "Töte Saratalin, um zu gehen", "Mata a Saratalin para salir", "Убей Saratalin, чтобы уйти", "Tue Saratalin pour sortir", "サラタリンを倒して脱出", "Zabij Saratalina, by wyjść", "Çıkmak için Saratalin’i öldür"],
"SARATALIN LIVES": ["Saratalin 还活着", "SARATALIN LEBT", "SARATALIN SIGUE VIVO", "SARATALIN ЖИВ", "SARATALIN EST VIVANT", "サラタリンは生きている", "SARATALIN ŻYJE", "SARATALIN YAŞIYOR"],
"The portal will not open until he falls": ["他不倒下，传送门就不会开", "Das Portal öffnet sich erst, wenn er fällt", "El portal no se abrirá hasta que caiga", "Портал не откроется, пока он не падёт", "Le portail ne s’ouvrira pas avant sa chute", "彼が倒れるまでポータルは開かない", "Portal nie otworzy się, póki nie padnie", "O düşmeden portal açılmaz"],
"The portals are closing": ["传送门正在关闭", "Die Portale schließen sich", "Los portales se cierran", "Порталы закрываются", "Les portails se ferment", "ポータルが閉じていく", "Portale się zamykają", "Portallar kapanıyor"],
"NETHER SWARM": ["下界虫潮", "NETHER-SCHWARM", "ENJAMBRE DEL NETHER", "РОЙ НИЖНЕГО МИРА", "NUÉE DU NETHER", "ネザースウォーム", "RÓJ NETHERU", "NETHER AKINI"],
"The portal still works. For now.": ["传送门还能用。暂时。", "Das Portal geht noch. Vorerst.", "El portal aún funciona. Por ahora.", "Портал ещё работает. Пока что.", "Le portail marche encore. Pour l’instant.", "ポータルはまだ使える。今は。", "Portal wciąż działa. Na razie.", "Portal hâlâ çalışıyor. Şimdilik."],
"THE WAY IS OPEN": ["出路已开", "DER WEG IST OFFEN", "EL CAMINO ESTÁ ABIERTO", "ПУТЬ ОТКРЫТ", "LA VOIE EST OUVERTE", "道が開いた", "DROGA OTWARTA", "YOL AÇIK"],
"Press E at the portal to go back": ["在传送门按 E 返回", "Am Portal E drücken, um zurückzukehren", "Pulsa E en el portal para volver", "Нажми E у портала, чтобы вернуться", "Appuie sur E au portail pour revenir", "ポータルで E を押して戻る", "Naciśnij E przy portalu, by wrócić", "Geri dönmek için portalda E’ye bas"],
"SURVIVE 10:00": ["撑过 10:00", "ÜBERLEBE 10:00", "SOBREVIVE 10:00", "ПРОДЕРЖИСЬ 10:00", "SURVIS 10:00", "10:00 生き延びろ", "PRZETRWAJ 10:00", "10:00 HAYATTA KAL"],
"Summon the boss at the statue when you're ready": ["准备好了就在雕像召唤 Boss", "Beschwöre den Boss an der Statue, wenn du bereit bist", "Invoca al jefe en la estatua cuando estés listo", "Призови босса у статуи, когда будешь готов", "Invoque le boss à la statue quand tu es prêt", "準備ができたら像でボスを召喚", "Przywołaj bossa przy posągu, gdy będziesz gotów", "Hazır olunca heykelde patronu çağır"],
"FINAL SWARM": ["最终虫潮", "FINALER SCHWARM", "ENJAMBRE FINAL", "ФИНАЛЬНАЯ ВОЛНА", "NUÉE FINALE", "ファイナルスウォーム", "FINAŁOWY RÓJ", "SON AKIN"],
"They just keep coming. Survive as long as you can.": ["它们源源不断。尽力活下去。", "Sie hören nicht auf. Überlebe so lange du kannst.", "No dejan de venir. Sobrevive lo máximo posible.", "Они всё идут. Держись сколько сможешь.", "Ils continuent d’arriver. Survis le plus longtemps possible.", "敵は止まらない。できるだけ長く生き延びろ。", "Nie przestają nadchodzić. Przetrwaj jak najdłużej.", "Gelmeye devam ediyorlar. Elinden geldiğince dayan."],
"It comes down from above": ["它从天而降", "Es kommt von oben herab", "Baja desde arriba", "Он спускается сверху", "Il descend d’en haut", "上から降りてくる", "Nadchodzi z góry", "Yukarıdan iniyor"],

# ---------- cazinoul EGT (casino.gd) ----------
# Numele pariurilor (RED, BLACK, EVEN, ODD, 1st 12, 2 to 1…) NU se traduc: sunt scrise în
# engleză chiar pe poza mesei, iar o etichetă tradusă n-ar mai avea pereche pe masă.
"Let's go gambling": ["走，去赌一把", "Auf geht's ins Casino", "Vamos a apostar", "Идём играть", "Allons parier", "さあ、賭けよう", "Idziemy się zakładać", "Hadi kumar oynayalım"],
"Gamble your stats": ["赌上你的属性", "Setze deine Werte", "Apuesta tus estadísticas", "Поставь характеристики", "Parie tes stats", "ステータスを賭ける", "Postaw statystyki", "İstatistiklerini oyna"],
"Gamble your items": ["赌上你的道具", "Setze deine Items", "Apuesta tus objetos", "Поставь предметы", "Parie tes objets", "アイテムを賭ける", "Postaw przedmioty", "Eşyalarını oyna"],
"Coming soon": ["敬请期待", "Bald verfügbar", "Próximamente", "Скоро", "Bientôt", "近日公開", "Wkrótce", "Yakında"],
"Leave": ["离开", "Verlassen", "Salir", "Уйти", "Partir", "立ち去る", "Wyjdź", "Ayrıl"],
"Lose = half the stat": ["输 = 属性减半", "Verlust = halber Wert", "Pierdes = la mitad", "Проигрыш = половина", "Perdu = la moitié", "負け = ステータス半分", "Przegrana = połowa", "Kaybet = yarısı"],
"Win x%s": ["赢 x%s", "Gewinn x%s", "Ganas x%s", "Выигрыш x%s", "Gain x%s", "勝ち x%s", "Wygrana x%s", "Kazanç x%s"],
"Place your bet on the table": ["在桌上下注", "Setze auf den Tisch", "Haz tu apuesta en la mesa", "Сделай ставку на столе", "Place ta mise sur la table", "テーブルに賭けて", "Postaw zakład na stole", "Masaya bahsini koy"],
"SPIN": ["旋转", "DREHEN", "GIRAR", "КРУТИТЬ", "LANCER", "スピン", "ZAKRĘĆ", "ÇEVİR"],
"Bet: %s": ["下注：%s", "Einsatz: %s", "Apuesta: %s", "Ставка: %s", "Mise : %s", "賭け: %s", "Zakład: %s", "Bahis: %s"],
"YOU WIN!": ["你赢了！", "GEWONNEN!", "¡GANASTE!", "ТЫ ВЫИГРАЛ!", "GAGNÉ !", "勝ち！", "WYGRANA!", "KAZANDIN!"],
"YOU LOSE": ["你输了", "VERLOREN", "PERDISTE", "ТЫ ПРОИГРАЛ", "PERDU", "負け", "PRZEGRANA", "KAYBETTİN"],

# ---------- numele upgrade-urilor ----------
# Numele proprii (Stroh, Duridama, Hellas, Saratalin) rămân la fel în toate limbile.
"Weird Concoction": ["奇怪的调制品", "Seltsames Gebräu", "Brebaje Raro", "Странное Варево", "Mixture Étrange", "奇妙な調合薬", "Dziwna Mikstura", "Tuhaf Karışım"],
"Wine": ["葡萄酒", "Wein", "Vino", "Вино", "Vin", "ワイン", "Wino", "Şarap"],
"Last Resort": ["最后手段", "Letztes Mittel", "Último Recurso", "Последнее Средство", "Dernier Recours", "最後の手段", "Ostatnia Deska Ratunku", "Son Çare"],
"Beer": ["啤酒", "Bier", "Cerveza", "Пиво", "Bière", "ビール", "Piwo", "Bira"],
"Vodka": ["伏特加", "Wodka", "Vodka", "Водка", "Vodka", "ウォッカ", "Wódka", "Votka"],
"Stroh": ["Stroh", "Stroh", "Stroh", "Stroh", "Stroh", "Stroh", "Stroh", "Stroh"],
"Rolling Papers": ["卷烟纸", "Blättchen", "Papel de Liar", "Бумага для Самокруток", "Feuilles à Rouler", "巻紙", "Bibułki", "Sarma Kâğıdı"],
"Grinder": ["研磨器", "Grinder", "Grinder", "Гриндер", "Grinder", "グラインダー", "Młynek", "Öğütücü"],
"Jean's Bomb": ["Jean 的炸弹", "Jeans Bombe", "La Bomba de Jean", "Бомба Жана", "La Bombe de Jean", "ジャンの爆弾", "Bomba Jeana", "Jean’in Bombası"],
"Firewalker": ["火行者", "Feuerläufer", "Caminafuego", "Огнеход", "Marcheur de Feu", "ファイアウォーカー", "Ognisty Wędrowiec", "Ateşte Yürüyen"],
"Frostwalker": ["霜行者", "Frostläufer", "Caminahielo", "Ледоход", "Marcheur de Givre", "フロストウォーカー", "Mroźny Wędrowiec", "Buzda Yürüyen"],
"Twin Comets": ["双子彗星", "Zwillingskometen", "Cometas Gemelos", "Кометы-Близнецы", "Comètes Jumelles", "ツインコメット", "Bliźniacze Komety", "İkiz Kuyrukluyıldız"],
"Drill": ["钻头", "Bohrer", "Taladro", "Дрель", "Perceuse", "ドリル", "Wiertło", "Matkap"],
"Adrenaline": ["肾上腺素", "Adrenalin", "Adrenalina", "Адреналин", "Adrénaline", "アドレナリン", "Adrenalina", "Adrenalin"],
"Double Dose": ["双倍剂量", "Doppelte Dosis", "Dosis Doble", "Двойная Доза", "Double Dose", "ダブルドーズ", "Podwójna Dawka", "Çift Doz"],
"Knockback Stick": ["击退棍", "Rückstoßstock", "Palo de Retroceso", "Палка Отбрасывания", "Bâton de Recul", "ノックバック棒", "Kij Odrzutu", "Geri İtme Sopası"],
"Pufferfish": ["河豚", "Kugelfisch", "Pez Globo", "Рыба-Ёж", "Poisson-Globe", "フグ", "Rozdymka", "Balon Balığı"],
"Rat's Burger": ["老鼠汉堡", "Ratten-Burger", "Hamburguesa de Rata", "Крысиный Бургер", "Burger de Rat", "ネズミバーガー", "Szczurzy Burger", "Fare Burgeri"],
"Rabbit's Foot": ["兔子脚", "Hasenpfote", "Pata de Conejo", "Кроличья Лапка", "Patte de Lapin", "ウサギの足", "Zajęcza Łapka", "Tavşan Ayağı"],
"Mike's Hedgehog": ["Mike 的刺猬", "Mikes Igel", "El Erizo de Mike", "Ёж Майка", "Le Hérisson de Mike", "マイクのハリネズミ", "Jeż Mike’a", "Mike’ın Kirpisi"],
"The Nightclub": ["夜店", "Der Nachtclub", "La Discoteca", "Ночной Клуб", "La Boîte de Nuit", "ナイトクラブ", "Klub Nocny", "Gece Kulübü"],
"Rusty Hacksaw": ["生锈钢锯", "Rostige Säge", "Sierra Oxidada", "Ржавая Ножовка", "Scie Rouillée", "錆びた金鋸", "Zardzewiała Piła", "Paslı Testere"],
"Doctor's Hacksaw": ["医生的钢锯", "Säge des Doktors", "La Sierra del Doctor", "Ножовка Доктора", "La Scie du Docteur", "医者の金鋸", "Piła Doktora", "Doktorun Testeresi"],
"Stolen Halo": ["偷来的光环", "Gestohlener Heiligenschein", "Aureola Robada", "Украденный Нимб", "Auréole Volée", "盗まれた光輪", "Skradziona Aureola", "Çalıntı Hale"],
"Alex's Protection": ["Alex 的护佑", "Alex’ Schutz", "La Protección de Alex", "Защита Алекса", "La Protection d’Alex", "アレックスの加護", "Ochrona Alexa", "Alex’in Koruması"],
"Theo's Wrath": ["Theo 的怒火", "Theos Zorn", "La Ira de Theo", "Гнев Тео", "La Colère de Theo", "テオの怒り", "Gniew Theo", "Theo’nun Gazabı"],
"Cigarette Pack": ["香烟盒", "Zigarettenschachtel", "Paquete de Tabaco", "Пачка Сигарет", "Paquet de Cigarettes", "タバコの箱", "Paczka Papierosów", "Sigara Paketi"],
"Diesel Power": ["柴油动力", "Dieselkraft", "Potencia Diésel", "Дизельная Мощь", "Puissance Diesel", "ディーゼルパワー", "Moc Diesla", "Dizel Güç"],
"Megane's Katana": ["Megane 的武士刀", "Meganes Katana", "La Katana de Megane", "Катана Мэган", "Le Katana de Megane", "メガネの刀", "Katana Megane", "Megane’nin Katanası"],
"Panic Button": ["紧急按钮", "Panikknopf", "Botón de Pánico", "Тревожная Кнопка", "Bouton Panique", "パニックボタン", "Przycisk Paniki", "Panik Butonu"],
"Broken Watch": ["坏掉的手表", "Kaputte Uhr", "Reloj Roto", "Сломанные Часы", "Montre Cassée", "壊れた時計", "Zepsuty Zegarek", "Bozuk Saat"],
"Gunslinger": ["枪手", "Revolverheld", "Pistolero", "Стрелок", "Pistolero", "ガンスリンガー", "Rewolwerowiec", "Silahşor"],
"Lucky Die": ["幸运骰子", "Glückswürfel", "Dado de la Suerte", "Счастливый Кубик", "Dé Chanceux", "ラッキーダイス", "Szczęśliwa Kostka", "Şanslı Zar"],
"Death Sentence": ["死刑判决", "Todesurteil", "Sentencia de Muerte", "Смертный Приговор", "Condamnation à Mort", "死刑宣告", "Wyrok Śmierci", "Ölüm Cezası"],
"Thunder God": ["雷神", "Donnergott", "Dios del Trueno", "Бог Грома", "Dieu du Tonnerre", "雷神", "Bóg Piorunów", "Şimşek Tanrısı"],
"Plugged In": ["接通电源", "Eingestöpselt", "Enchufado", "Под Напряжением", "Branché", "通電中", "Podłączony", "Fişe Takılı"],
"Undying Spirit": ["不死之魂", "Unsterblicher Geist", "Espíritu Inmortal", "Бессмертный Дух", "Esprit Immortel", "不死の魂", "Nieśmiertelny Duch", "Ölümsüz Ruh"],
"Unusual Clover": ["奇异四叶草", "Seltsames Kleeblatt", "Trébol Inusual", "Необычный Клевер", "Trèfle Insolite", "珍しいクローバー", "Niezwykła Koniczyna", "Sıra Dışı Yonca"],
"The Office": ["办公室", "Das Büro", "La Oficina", "Офис", "Le Bureau", "ジ・オフィス", "Biuro", "Ofis"],
"Royal Flush": ["皇家同花顺", "Royal Flush", "Escalera Real", "Флеш-Рояль", "Quinte Flush Royale", "ロイヤルフラッシュ", "Poker Królewski", "Floş Royal"],
"Tome of Knowledge": ["知识之书", "Buch des Wissens", "Tomo del Saber", "Том Знаний", "Tome du Savoir", "知識の書", "Księga Wiedzy", "Bilgi Kitabı"],
"Duridama": ["Duridama", "Duridama", "Duridama", "Duridama", "Duridama", "Duridama", "Duridama", "Duridama"],
"Hellas": ["Hellas", "Hellas", "Hellas", "Hellas", "Hellas", "Hellas", "Hellas", "Hellas"],
"Borat's Mankini": ["Borat 的男士比基尼", "Borats Mankini", "El Mankini de Borat", "Манкини Бората", "Le Mankini de Borat", "ボラットのマンキニ", "Mankini Borata", "Borat’ın Mankinisi"],
"Horse Mask": ["马头面具", "Pferdemaske", "Máscara de Caballo", "Маска Лошади", "Masque de Cheval", "馬のマスク", "Maska Konia", "At Maskesi"],
"Psychic Flip Flop": ["通灵人字拖", "Psycho-Flipflop", "Chancla Psíquica", "Психическая Вьетнамка", "Tong Psychique", "サイキックビーサン", "Psychiczny Japonek", "Medyum Terlik"],
"Bloody Situation": ["血腥场面", "Blutige Lage", "Situación Sangrienta", "Кровавая Ситуация", "Situation Sanglante", "血まみれの状況", "Krwawa Sytuacja", "Kanlı Durum"],
"Hermes' Sandals": ["赫尔墨斯的凉鞋", "Hermes’ Sandalen", "Las Sandalias de Hermes", "Сандалии Гермеса", "Les Sandales d’Hermès", "ヘルメスのサンダル", "Sandały Hermesa", "Hermes’in Sandaletleri"],
"Aussie Special": ["澳洲特调", "Aussie-Spezial", "Especial Australiano", "Австралийский Особый", "Spécial Aussie", "オージースペシャル", "Australijski Specjał", "Avustralya Özel"],
"Old Reliable": ["老伙计", "Der Bewährte", "El Viejo Confiable", "Старый Надёжный", "Le Vieux Fidèle", "頼れる相棒", "Stary Niezawodny", "Eski Güvenilir"],
"5G Tower": ["5G 信号塔", "5G-Mast", "Torre 5G", "Вышка 5G", "Tour 5G", "5Gタワー", "Wieża 5G", "5G Kulesi"],

# ---------- descrierile upgrade-urilor ----------
"+60 Speed +25% Attack Speed": ["+60 速度 +25% 攻速", "+60 Tempo +25% Angriffstempo", "+60 Velocidad +25% Vel. ataque", "+60 скорость +25% скорострельность", "+60 Vitesse +25% Cadence", "+60 移動速度 +25% 攻撃速度", "+60 Szybkość +25% Szybkostrzelność", "+60 Hız +25% Saldırı Hızı"],
"+3 HP/sec, Heal 30 HP": ["+3 生命/秒, 恢复 30 生命", "+3 HP/Sek., heilt 30 HP", "+3 HP/seg, cura 30 HP", "+3 HP/сек, лечит 30 HP", "+3 PV/sec, soigne 30 PV", "+3 HP/秒、30 HP 回復", "+3 HP/sek, leczy 30 HP", "+3 CAN/sn, 30 CAN iyileştir"],
"+7 Bullet damage": ["+7 子弹伤害", "+7 Geschossschaden", "+7 Daño de bala", "+7 урон пули", "+7 Dégâts de balle", "+7 弾のダメージ", "+7 Obrażenia pocisku", "+7 Mermi hasarı"],
"+35 Max HP": ["+35 最大生命", "+35 Max. HP", "+35 HP máx.", "+35 макс. HP", "+35 PV max", "+35 最大HP", "+35 Maks. HP", "+35 Maks. CAN"],
"-3 Damage taken": ["-3 受到伤害", "-3 erlittener Schaden", "-3 Daño recibido", "-3 получаемый урон", "-3 Dégâts subis", "-3 被ダメージ", "-3 Otrzymywane obrażenia", "-3 Alınan hasar"],
"+10 Damage +18% Attack Speed": ["+10 伤害 +18% 攻速", "+10 Schaden +18% Angriffstempo", "+10 Daño +18% Vel. ataque", "+10 урон +18% скорострельность", "+10 Dégâts +18% Cadence", "+10 攻撃力 +18% 攻撃速度", "+10 Obrażenia +18% Szybkostrzelność", "+10 Hasar +18% Saldırı Hızı"],
"+10% Attack speed": ["+10% 攻速", "+10% Angriffstempo", "+10% Vel. de ataque", "+10% скорострельность", "+10% Cadence", "+10% 攻撃速度", "+10% Szybkostrzelność", "+10% Saldırı hızı"],
"-15% XP to level": ["升级所需经验 -15%", "-15% XP bis Level-up", "-15% XP para subir", "-15% опыта до уровня", "-15% XP pour monter", "レベルアップ必要XP -15%", "-15% XP do awansu", "Seviye için -15% XP"],
"+20 damage & AOE for 15% of damage": ["+20 伤害, 范围伤害为伤害的 15%", "+20 Schaden & Flächenschaden für 15% des Schadens", "+20 daño y AoE por el 15% del daño", "+20 урон и AOE на 15% урона", "+20 dégâts et zone à 15% des dégâts", "+20 ダメージ、ダメージの15%を範囲攻撃", "+20 obrażeń i AOE za 15% obrażeń", "+20 hasar ve hasarın %15’i alan hasarı"],
"Burning Trail": ["燃烧足迹", "Brennende Spur", "Rastro Ardiente", "Огненный След", "Traînée Brûlante", "炎の軌跡", "Płonący Ślad", "Yanan İz"],
"Freezing Trail": ["冰冻足迹", "Frostige Spur", "Rastro Helado", "Ледяной След", "Traînée Glaçante", "氷の軌跡", "Mroźny Ślad", "Donduran İz"],
"+2 projectiles": ["+2 弹丸", "+2 Geschosse", "+2 proyectiles", "+2 снаряда", "+2 projectiles", "+2 弾", "+2 pociski", "+2 mermi"],
"Bullets pierce +1 enemy": ["子弹多穿透 1 个敌人", "Geschosse durchdringen +1 Gegner", "Las balas atraviesan +1 enemigo", "Пули пробивают +1 врага", "Les balles transpercent +1 ennemi", "弾が敵を+1体貫通", "Pociski przebijają +1 wroga", "Mermiler +1 düşman deler"],
"+15% Crit chance": ["+15% 暴击率", "+15% Kritchance", "+15% Prob. crítico", "+15% шанс крита", "+15% Chance de critique", "+15% クリティカル率", "+15% Szansa na kryt", "+15% Kritik şansı"],
"Bigger Projectiles +5 damage": ["更大的弹丸 +5 伤害", "Größere Geschosse +5 Schaden", "Proyectiles más grandes +5 daño", "Снаряды больше +5 урон", "Projectiles plus gros +5 dégâts", "弾が大きくなる +5 ダメージ", "Większe pociski +5 obrażeń", "Daha büyük mermi +5 hasar"],
"Bullets knock enemies back": ["子弹击退敌人", "Geschosse stoßen Gegner zurück", "Las balas empujan a los enemigos", "Пули отбрасывают врагов", "Les balles repoussent les ennemis", "弾が敵を吹き飛ばす", "Pociski odrzucają wrogów", "Mermiler düşmanları geri iter"],
"+10 Weapon size": ["+10 武器大小", "+10 Waffengröße", "+10 Tamaño de arma", "+10 размер оружия", "+10 Taille d’arme", "+10 武器サイズ", "+10 Rozmiar broni", "+10 Silah boyutu"],
"+30% Weapon size": ["+30% 武器大小", "+30% Waffengröße", "+30% Tamaño de arma", "+30% размер оружия", "+30% Taille d’arme", "+30% 武器サイズ", "+30% Rozmiar broni", "+30% Silah boyutu"],
"-5 Damage +25% Move speed": ["-5 伤害 +25% 移速", "-5 Schaden +25% Tempo", "-5 Daño +25% Velocidad", "-5 урон +25% скорость", "-5 Dégâts +25% Vitesse", "-5 攻撃力 +25% 移動速度", "-5 Obrażenia +25% Szybkość", "-5 Hasar +25% Hız"],
"Reflect 100% damage (once/6s)": ["反弹 100% 伤害 (每6秒一次)", "100% Schaden reflektieren (1x/6s)", "Refleja 100% del daño (1 vez/6s)", "Отражает 100% урона (раз в 6с)", "Renvoie 100% des dégâts (1x/6s)", "ダメージを100%反射 (6秒に1回)", "Odbija 100% obrażeń (raz/6s)", "%100 hasarı yansıt (6sn’de bir)"],
"+35% Damage -35% Attack Speed": ["+35% 伤害 -35% 攻速", "+35% Schaden -35% Angriffstempo", "+35% Daño -35% Vel. ataque", "+35% урон -35% скорострельность", "+35% Dégâts -35% Cadence", "+35% 攻撃力 -35% 攻撃速度", "+35% Obrażenia -35% Szybkostrzelność", "+35% Hasar -35% Saldırı Hızı"],
"1% instakill": ["1% 秒杀", "1% Sofortkill", "1% muerte instantánea", "1% мгн. смерть", "1% exécution", "1% 即死", "1% natychmiastowe zabicie", "%1 anında öldürme"],
"5% instakill": ["5% 秒杀", "5% Sofortkill", "5% muerte instantánea", "5% мгн. смерть", "5% exécution", "5% 即死", "5% natychmiastowe zabicie", "%5 anında öldürme"],
"+10 Damage +5 Max HP": ["+10 伤害 +5 最大生命", "+10 Schaden +5 Max. HP", "+10 Daño +5 HP máx.", "+10 урон +5 макс. HP", "+10 Dégâts +5 PV max", "+10 攻撃力 +5 最大HP", "+10 Obrażenia +5 Maks. HP", "+10 Hasar +5 Maks. CAN"],
"+25% Max HP +15% Movement Speed": ["+25% 最大生命 +15% 移速", "+25% Max. HP +15% Tempo", "+25% HP máx. +15% Velocidad", "+25% макс. HP +15% скорость", "+25% PV max +15% Vitesse", "+25% 最大HP +15% 移動速度", "+25% Maks. HP +15% Szybkość", "+25% Maks. CAN +15% Hız"],
"+15% Damage under 20% HP": ["生命低于 20% 时 +15% 伤害", "+15% Schaden unter 20% HP", "+15% daño con menos del 20% HP", "+15% урон при HP ниже 20%", "+15% dégâts sous 20% PV", "HP 20%以下で +15% ダメージ", "+15% obrażeń poniżej 20% HP", "%20 CAN altında +15% hasar"],
"+5% Damage": ["+5% 伤害", "+5% Schaden", "+5% Daño", "+5% урон", "+5% Dégâts", "+5% 攻撃力", "+5% Obrażenia", "+5% Hasar"],
"+15% Damage while moving": ["移动时 +15% 伤害", "+15% Schaden in Bewegung", "+15% daño en movimiento", "+15% урон в движении", "+15% dégâts en mouvement", "移動中 +15% ダメージ", "+15% obrażeń w ruchu", "Hareket hâlinde +15% hasar"],
"+15% Crit while moving": ["移动时 +15% 暴击", "+15% Krit in Bewegung", "+15% crítico en movimiento", "+15% крит в движении", "+15% critique en mouvement", "移動中 +15% クリティカル", "+15% kryt w ruchu", "Hareket hâlinde +15% kritik"],
"100 Damage to all enemies, once": ["对所有敌人造成 100 伤害, 一次", "100 Schaden an alle Gegner, einmalig", "100 de daño a todos los enemigos, una vez", "100 урона всем врагам, один раз", "100 dégâts à tous les ennemis, une fois", "全敵に100ダメージ、1回だけ", "100 obrażeń wszystkim wrogom, raz", "Tüm düşmanlara 100 hasar, bir kez"],
"50% chance to fire +1 projectile": ["50% 几率多射 1 发", "50% Chance auf +1 Geschoss", "50% de prob. de disparar +1 proyectil", "50% шанс выстрелить +1 снарядом", "50% de chance de tirer +1 projectile", "50%の確率で弾を+1発", "50% szans na +1 pocisk", "%50 ihtimalle +1 mermi"],
"+1 projectile": ["+1 弹丸", "+1 Geschoss", "+1 proyectil", "+1 снаряд", "+1 projectile", "+1 弾", "+1 pocisk", "+1 mermi"],
"Reroll a new page of items": ["重掷一页新道具", "Neue Seite mit Items würfeln", "Vuelve a tirar una página de objetos", "Перебросить новую страницу предметов", "Relance une nouvelle page d’objets", "アイテムを引き直す", "Przelosuj nową stronę przedmiotów", "Yeni eşya sayfası çevir"],
"-35% speed +20% damage & attack speed": ["-35% 速度 +20% 伤害与攻速", "-35% Tempo +20% Schaden & Angriffstempo", "-35% velocidad +20% daño y vel. ataque", "-35% скорость +20% урон и скорострельность", "-35% vitesse +20% dégâts et cadence", "-35% 移動速度 +20% 攻撃力と攻撃速度", "-35% szybkość +20% obrażenia i szybkostrzelność", "-35% hız +20% hasar ve saldırı hızı"],
"Get the power of Zeus": ["获得宙斯之力", "Erhalte die Macht des Zeus", "Obtén el poder de Zeus", "Получи силу Зевса", "Obtiens le pouvoir de Zeus", "ゼウスの力を得る", "Zdobądź moc Zeusa", "Zeus’un gücünü al"],
"+10% to become Zeus": ["+10% 成为宙斯", "+10% Chance auf Zeus", "+10% para convertirte en Zeus", "+10% стать Зевсом", "+10% de devenir Zeus", "+10% ゼウスになる確率", "+10% szans, by zostać Zeusem", "Zeus olma şansı +%10"],
"Second chance": ["第二次机会", "Zweite Chance", "Segunda oportunidad", "Второй шанс", "Seconde chance", "セカンドチャンス", "Druga szansa", "İkinci şans"],
"+5 Luck": ["+5 幸运", "+5 Glück", "+5 Suerte", "+5 удача", "+5 Chance", "+5 運", "+5 Szczęście", "+5 Şans"],
"+2.5 Luck +5% Attack Speed": ["+2.5 幸运 +5% 攻速", "+2.5 Glück +5% Angriffstempo", "+2.5 Suerte +5% Vel. ataque", "+2.5 удача +5% скорострельность", "+2.5 Chance +5% Cadence", "+2.5 運 +5% 攻撃速度", "+2.5 Szczęście +5% Szybkostrzelność", "+2.5 Şans +5% Saldırı Hızı"],
"+10 Luck": ["+10 幸运", "+10 Glück", "+10 Suerte", "+10 удача", "+10 Chance", "+10 運", "+10 Szczęście", "+10 Şans"],
"50% less XP to level up": ["升级所需经验减半", "50% weniger XP zum Level-up", "50% menos XP para subir de nivel", "На 50% меньше опыта до уровня", "50% d’XP en moins pour monter", "レベルアップ必要XP 50%減", "50% mniej XP do awansu", "Seviye için %50 daha az XP"],
"Make enemies golden": ["让敌人变成金色", "Macht Gegner golden", "Vuelve dorados a los enemigos", "Делает врагов золотыми", "Rend les ennemis dorés", "敵を黄金にする", "Zamienia wrogów w złotych", "Düşmanları altına çevir"],
"+15% Move speed +5% Crit chance": ["+15% 移速 +5% 暴击率", "+15% Tempo +5% Kritchance", "+15% Velocidad +5% Prob. crítico", "+15% скорость +5% шанс крита", "+15% Vitesse +5% Chance de critique", "+15% 移動速度 +5% クリティカル率", "+15% Szybkość +5% Szansa na kryt", "+15% Hız +5% Kritik şansı"],
"50% chance xp to drop every 5s": ["每5秒 50% 几率掉落经验", "50% Chance auf XP alle 5s", "50% de prob. de soltar XP cada 5s", "50% шанс выпадения опыта каждые 5с", "50% de chance d’XP toutes les 5s", "5秒ごとに50%の確率でXP", "50% szans na XP co 5s", "Her 5sn’de %50 ihtimalle XP"],
"5% to charm an enemy": ["5% 魅惑敌人", "5% Chance, einen Gegner zu bezaubern", "5% de encantar a un enemigo", "5% очаровать врага", "5% de charmer un ennemi", "5%で敵を魅了", "5% szans na oczarowanie wroga", "%5 düşmanı büyüleme"],
"Aimbot": ["自动瞄准", "Zielhilfe", "Apuntado automático", "Автоприцел", "Visée auto", "オートエイム", "Autocelowanie", "Otomatik nişan"],
"Crits heal you 2 HP": ["暴击回复 2 生命", "Krits heilen dich um 2 HP", "Los críticos te curan 2 HP", "Криты лечат на 2 HP", "Les critiques te soignent 2 PV", "クリティカルで2HP回復", "Kryty leczą 2 HP", "Kritikler 2 CAN iyileştirir"],
"+100 Movement Speed +10% Attack Speed": ["+100 移速 +10% 攻速", "+100 Tempo +10% Angriffstempo", "+100 Velocidad +10% Vel. de ataque", "+100 скорость +10% скорость атаки", "+100 Vitesse +10% Vitesse d’attaque", "+100 移動速度 +10% 攻撃速度", "+100 Szybkość +10% Szybkość ataku", "+100 Hız +10% Saldırı hızı"],
"Projectiles ricochet +1 time": ["弹射 +1 次", "Geschosse prallen +1x ab", "Los proyectiles rebotan +1 vez", "Снаряды рикошетят +1 раз", "Les projectiles ricochent +1 fois", "弾が+1回跳ね返る", "Pociski odbijają się +1 raz", "Mermiler +1 kez sekiyor"],
"Reflect 15% of damage taken": ["反弹 15% 所受伤害", "15% des erlittenen Schadens reflektieren", "Refleja 15% del daño recibido", "Отражает 15% полученного урона", "Renvoie 15% des dégâts subis", "受けたダメージの15%を反射", "Odbija 15% otrzymanych obrażeń", "Alınan hasarın %15’ini yansıt"],
"Enemies drop 15% more xp": ["敌人掉落经验 +15%", "Gegner lassen 15% mehr XP fallen", "Los enemigos sueltan 15% más de XP", "Враги дают на 15% больше опыта", "Les ennemis lâchent 15% d’XP en plus", "敵のXPドロップ +15%", "Wrogowie dają 15% więcej XP", "Düşmanlar %15 daha fazla XP düşürür"],
}
# ========================== SFÂRȘITUL TABELULUI ==========================

func _ready() -> void:
	_inregistreaza()
	TranslationServer.set_locale(GameSettings.language)

# Construiește câte un Translation pentru fiecare limbă și îl dă lui TranslationServer.
# Engleza nu are nevoie: e limba în care sunt scrise cheile, iar dacă o traducere lipsește,
# TranslationServer întoarce oricum cheia (adică textul englezesc).
func _inregistreaza() -> void:
	for i in ORDINE.size():
		var t := Translation.new()
		t.locale = ORDINE[i]
		for cheie in TRAD:
			var randul: Array = TRAD[cheie]
			if i < randul.size():
				t.add_message(cheie, String(randul[i]))
		TranslationServer.add_translation(t)

# Schimbă limba pe loc: Godot anunță toate nodurile (NOTIFICATION_TRANSLATION_CHANGED) și
# textele simple se rescriu singure. Cele formatate se refac de cine le desenează.
func schimba_limba(cod: String) -> void:
	if cod == GameSettings.language:
		return
	GameSettings.set_language(cod)
	TranslationServer.set_locale(cod)

func steag(cod: String) -> Texture2D:
	for l in LIMBI:
		if l["cod"] == cod and ResourceLoader.exists(l["steag"]):
			return load(l["steag"])
	return null

func nume_limba(cod: String) -> String:
	for l in LIMBI:
		if l["cod"] == cod:
			return String(l["nume"])
	return cod
