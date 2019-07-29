Record ArchivedEquipment
{
	item [slot] previous_equipment;
	familiar previous_familiar;
};

ArchivedEquipment __global_archived_equipment;

ArchivedEquipment ArchiveEquipment()
{
	ArchivedEquipment ae;
	
	foreach s in $slots[hat,weapon,off-hand,back,shirt,pants,acc1,acc2,acc3,familiar]
		ae.previous_equipment[s] = s.equipped_item();
	ae.previous_familiar = my_familiar();
	
	__global_archived_equipment = ae;
	return ae;
}


void RestoreArchivedEquipment(ArchivedEquipment ae)
{
	use_familiar(ae.previous_familiar);
	foreach s, it in ae.previous_equipment
	{
		if (s.equipped_item() != it && it.available_amount() > 0)
			equip(s, it);
	}
}

void RestoreArchivedEquipment()
{
	RestoreArchivedEquipment(__global_archived_equipment);
}
string [string] __pirate_file_state;

string __pirate_version = "1.0.2";


Record PirateRealmSettings
{
	string [int] island_1_order;
	string [int] island_2_order;
	string [int] island_3_order;
	string [int] curio_order;
	string [int] ship_order;
	
	boolean first_island_only;
	
	boolean [string] player_requested_islands;
	
	boolean key_only;
};
PirateRealmSettings __pr_settings;


void writePirateFileState()
{
	map_to_file(__pirate_file_state, "piraterealm_tracking_" + my_id() + ".txt");
}

void readPirateFileState()
{
	file_to_map("piraterealm_tracking_" + my_id() + ".txt", __pirate_file_state);
}

readPirateFileState();

boolean [item] __pirate_store_unlockables = $items[PirateRealm party hat, crabsicle, pirate shaving cream, bottle of dark rhum, bottle of extra-dark rhum, bottle of super-extra-dark rhum, PirateRealm guest pass, conquistador's breastplate, pirate radio ring, piratical blunderbuss, plush sea serpent, pirate fork, Scurvy and Sobriety Prevention, lucky gold ring, Island Drinkin'\, a Tiki Mixology Odyssey,Red Roger tattoo kit]; //'

void parseFunALog()
{
	boolean everything_unlocked = true;
	foreach it in __pirate_store_unlockables
	{
		if (!__pirate_file_state[it.to_int() + " unlocked for buying"].to_boolean())
		{
			everything_unlocked = false;
		}
	}
	if (everything_unlocked) return;
	buffer page_text = visit_url("shop.php?whichshop=piraterealm");
	if (!page_text.contains_text("You've had your fun, now spend it")) return;
	
	foreach it in __pirate_store_unlockables
	{
		if (page_text.contains_text(it))
			__pirate_file_state[it.to_int() + " unlocked for buying"] = true;
		else
			__pirate_file_state[it.to_int() + " unlocked for buying"] = false;
	}
	writePirateFileState();
}

//Guns,Grub,Grog,Glue,Gold,Fund
int [string] __pirate_charpane_state;
void parsePirateCharpaneState()
{
	foreach key in __pirate_charpane_state
		remove __pirate_charpane_state[key];
	buffer page_text = visit_url("charpane.php");
	string [int][int] matches = page_text.group_string("<b>([^:]*):</b></td><td class=small>([0-9]*)</td></tr>");
	foreach key in matches
	{
		string type = matches[key][1];
		int value = matches[key][2].to_int();
		//print_html("\"" + type + "\" = " + value);
		__pirate_charpane_state[type] = value;
	}
}


boolean [slot] runEquipment(boolean [item] equipment)
{
	boolean [slot] slots_used;
	slot next_accessory_slot = $slot[acc1];
	foreach it in equipment
	{
		slot s = it.to_slot();
		if (s == $slot[acc1])
		{
			s = next_accessory_slot;
			if (next_accessory_slot == $slot[acc1])
				next_accessory_slot = $slot[acc2];
			else if (next_accessory_slot == $slot[acc2])
				next_accessory_slot = $slot[acc3];
		}
		if (it.available_amount() == 0) continue;
		if (it.equipped_amount() > 0) //equip() will fail because equip() is fragile
			cli_execute("unequip " + it);
		equip(s, it);
		slots_used[s] = true;
	}
	return slots_used;
}

boolean run_choice_by_text(string page_text, string identifier)
{
	identifier = identifier.replace_string("?", "\\?"); //FIXME remove/escape other grepables
	string [int][int] matches = page_text.group_string("value=\"?([0-9]*)\"?><input [ ]*class=button type=submit value=\"" + identifier);
	int choice_id = matches[0][1].to_int();
	if (choice_id <= 0)
		return false;
	run_choice(choice_id);
	return true;
}

boolean run_choice_by_text(string identifier)
{
	visit_url("choice.php");
	foreach key, option in available_choice_options()
	{
		if (identifier == option)
		{
			run_choice(key);
			return true;
		}
	}
	return false;
}


boolean run_choice_by_text_list(string [int] identifiers)
{
	visit_url("choice.php");
	foreach key, identifier in identifiers
	{
		foreach key, option in available_choice_options()
		{
			if (identifier == option)
			{
				run_choice(key);
				return true;
			}
		}
	}
	return false;
}


	
void statCheck()
{
	foreach s in $stats[]
	{
		if (my_buffedstat(s) >= 100)
		{
			//hardcode this one because this is the one I always see
			if (s == $stat[mysticality] && $effect[Magically Delicious].have_effect() > 0)
				cli_execute("uneffect Magically Delicious");
			if (my_buffedstat(s) >= 100)
				abort("Remove whichever effect makes our " + s + " over 100.");
		}
	}
}

void pirateHandleShop()
{
	boolean save_gold = false;
	int min_grub = 40;
	int min_grog = 40;
	int breakout = 100;
	while (breakout > 0)
	{
		parsePirateCharpaneState();
		breakout -= 1;
		string target = "";
		if (__pirate_charpane_state["Grub"] == 0)
			target = "Buy 5 food";
		else if (__pirate_charpane_state["Grog"] == 0)
			target = "Buy 5 booze";
		else if (__pirate_charpane_state["Glue"] == 0)
			target = "Buy 1 glue";
		else if (__pirate_charpane_state["Grub"] < __pirate_charpane_state["Grog"] && __pirate_charpane_state["Grub"] < min_grub)
			target = "Buy 5 food";
		else if (__pirate_charpane_state["Grub"] > __pirate_charpane_state["Grog"] && __pirate_charpane_state["Grog"] < min_grog)
			target = "Buy 5 booze";
		else if (__pirate_charpane_state["Glue"] < 5)
			target = "Buy 1 glue";
		else if (__pirate_charpane_state["Gold"] > 200 && !save_gold)
			target = "Buy an additional cannon";
		else if (false && !save_gold && __pirate_charpane_state["Grub"] < __pirate_charpane_state["Grog"])
			target = "Buy 5 food";
		else if (false && !save_gold && __pirate_charpane_state["Grub"] > __pirate_charpane_state["Grog"])
			target = "Buy 5 booze";
			
		boolean finished = true;
		if (target != "")
		{
			print_html("Trying " + target);
			finished = !run_choice_by_text(target);
		}
		if (finished)
		{
			run_choice_by_text("Sail away");
			return;
		}
	}
}

boolean pirateRunSailingTurn(buffer pirate_realm_page_text)
{
	parsePirateCharpaneState();
	int [int] choice_adventures;
	choice_adventures[1352] = -1; //first lsland
	choice_adventures[1353] = -1; //second island
	choice_adventures[1354] = -1; //third island
	choice_adventures[1355] = 1; //Land Ho!
	
	choice_adventures[1358] = 1; //The Starboard is Bare
	choice_adventures[1359] = 1; //Grog for the Grogless
	
	choice_adventures[1361] = 1; //Avast, a Mast!
	choice_adventures[1362] = 2; //Stormy Weather
	choice_adventures[1363] = 1; //Who Pirates the Pirates?
	choice_adventures[1364] = 1; //An Opportunity for Dastardly Do - by default, attack the civilian ship. I mean, we're pirates
	choice_adventures[1365] = 1; //A Sea Monster! amusingly, you have more fun fighting the sea monster even if you lose
	
	if (__pirate_charpane_state["Glue"] > 0)
		choice_adventures[1367] = 1; //The Ship is Wrecked with glue
	else
		choice_adventures[1367] = 2; //The Ship is Wrecked without glue

	if (__pirate_charpane_state["Grub"] > 3 && __pirate_charpane_state["Grub"] >= __pirate_charpane_state["Grog"])
	{
		//prefer food
		choice_adventures[1356] = 1; //Smooth Sailing
		choice_adventures[1357] = 1; //High Tide, Low Morale
	}
	else if (__pirate_charpane_state["Grog"] > 3 && __pirate_charpane_state["Grub"] <= __pirate_charpane_state["Grog"])
	{
		//prefer drinking
		choice_adventures[1356] = 2; //Smooth Sailing
		choice_adventures[1357] = 2; //High Tide, Low Morale
	}
	else
	{
		//abstain
		choice_adventures[1356] = 3; //Smooth Sailing
		choice_adventures[1357] = 4; //High Tide, Low Morale
	}
	
	foreach choice_number, choice_id in choice_adventures
		set_property("choiceAdventure" + choice_number, choice_id);
	runEquipment($items[PirateRealm eyepatch,Red Roger's red right foot,PirateRealm party hat, Red Roger's red left foot, Red Roger's red left hand, Red Roger's red right hand]); //' run them all because temple island, at all times
	statCheck();
	buffer page_text = visit_url("adventure.php?snarfblat=530");
	if (page_text.contains_text("SHOP"))
	{
		pirateHandleShop();
	}
	else if (page_text.contains_text("Island #1, Who Are You"))
	{
		run_choice_by_text_list(__pr_settings.island_1_order);
	}
	else if (page_text.contains_text("What's Behind Island"))
	{
		run_choice_by_text_list(__pr_settings.island_2_order);
		if (__pr_settings.key_only)
			return true;
	}
	else if (page_text.contains_text("Third Island's the Charm"))
	{
		run_choice_by_text_list(__pr_settings.island_3_order);
		if (__pr_settings.key_only)
			return true;
	}
	else
		run_turn();
	return false;
}

boolean pirateRunFightingTurn(buffer pirate_realm_page_text)
{
	//Parse current island:
	
	string [string] gifs_to_islands = {
	"island1.gif":"Crab Island",
	"island2.gif":"Battle Island",
	"island3.gif":"Plastic Skull Island",
	"island4.gif":"Key Key",
	"island5.gif":"Glass Island",
	"island6.gif":"Dessert Island",
	"island12.gif":"Jungle Island",
	"island13.gif":"Isla Gublar",
	"island14.gif":"Trash Island",
	"island15.gif":"Cemetery Island",
	"island16.gif":"Prison Island",
	"island21.gif":"Signal Island",
	"island22.gif":"Tiki Island",
	"island23.gif":"Temple Island",
	"island24.gif":"Red Roger's Fortress",
	"island25.gif":"Glass Jack's Hideout",
	"island26.gif":"Storm Island",
	};
	
	string current_island = "";
	foreach island_gif, island_name in gifs_to_islands
	{
		if (pirate_realm_page_text.contains_text(island_gif))
		{
			current_island = island_name;
			break;
		}
	}
	
	int [int] choice_adventures;
	//just assume all of these are 1s:
	for choice_id from 1368 to 1385
	{
		choice_adventures[choice_id] = 1;
	}
	
	foreach choice_number, choice_id in choice_adventures
		set_property("choiceAdventure" + choice_number, choice_id);
		
	
	
	int [item] desired_items = {$item[water wings for babies]:1, $item[red badge]:1, $item[security flashlight]:1};
	foreach it, amount in desired_items
	{
		if (it.available_amount() >= amount) continue;
		retrieve_item(amount, it);
	}
	
	//Red Roger's red right hand
	boolean [slot] slots_used = runEquipment($items[PirateRealm eyepatch,Red Roger's red left foot,Red Roger's red left hand,PirateRealm party hat]); //'
	
	string maximisation_string = "maximize -100.0 monster level 1.0 spell damage percent -tie";// -equip HOA regulation book -equip space trip safety headphones -equip pine cone necklace";
	foreach s in slots_used
		maximisation_string += " -" + s;
	cli_execute(maximisation_string);
	if ($familiar[trick-or-treating tot].have_familiar() && $item[li'l ninja costume].available_amount() > 0) //'
	{
		cli_execute("familiar trick-or-treating tot");
		cli_execute("equip li'l ninja costume");
	}
	string combat_script = "";
	if ($skill[stuffed mortar shell].have_skill())
	{
		combat_script += "skill stuffed mortar shell;";
	}
	if ($skill[saucestorm].have_skill() && ($strings[Crab Island,Battle Island,Plastic Skull Island,Key Key,Glass Island,Dessert Island,Jungle Island,Isla Gublar,Trash Island,Cemetery Island,Prison Island] contains current_island)) //saucestorm first on low-level islands
		combat_script += "skill saucestorm;repeat;";
	if ($skill[saucegeyser].have_skill())
		combat_script += "skill saucegeyser;repeat;";
	if ($skill[weapon of the pastalord].have_skill())
		combat_script += "skill weapon of the pastalord;repeat;";
	if ($skill[saucestorm].have_skill())
		combat_script += "skill saucestorm;repeat;";
	//some combat item idk
	if (current_island == "Storm Island")
	{
		//survive ten rounds with the seal tooth
		if (can_interact())
			retrieve_item(1, $item[seal tooth]);
		combat_script += "use seal tooth;repeat;";
	}
	if (get_ccs_action(0) == "consult scripts/Helix Fossil/Helix Fossil.ash" && false) //worship
		combat_script = "";
	statCheck();
	//cli_execute("gain.ash 1000000 item 1000 maxmeatspent");
	if (can_interact())
		cli_execute("call gain.ash 500 hp 1000 maxmeatspent");
	restore_hp(MIN(my_maxhp(), 300));
	restore_mp(96);
	adv1($location[PirateRealm Island], 0, combat_script);
	if (get_property("lastEncounter").to_monster() != $monster[none] && !run_combat().contains_text("WINWINWIN")) //FIXME run_combat() without running, to get the text
	{
		print("Beaten up?");
		return true;
	}
	return false;
}

//random() will halt the script if range is <= 1, which can happen when picking a random object out of a variable-sized list.
//There's also a hidden bug where values above 2147483647 will be treated as zero.
int random_safe(int range)
{
	if (range < 2 || range > 2147483647)
		return 0;
	return random(range);
}

float randomf()
{
    return random_safe(2147483647).to_float() / 2147483647.0;
}

void pirateStartRun()
{
	runEquipment($items[PirateRealm eyepatch]);
	buffer page_text = visit_url("place.php?whichplace=realm_pirate&action=pr_port");
	run_choice_by_text("Head to Groggy's");
	
	//negative is better
	float [string] first_mate_priorities = {
	"Beligerent":0.0, //Unlocks Jungle Island. Can give an extra Gun at Shipwreck Salvage.
	"Dipsomaniacal":-5.0, //Can give one Grog after combat. Can give extra Grog at Shipwreck Salvage.
	"Gluttonous":-5.0, //Can give one Grub after combat. Can give extra Grub at Shipwreck Salvage. Helps when running out of Grub.
	"Pinch-Fisted":0.0, //Gives 5-10 Gold at the end of PirateRealm combats. Increases Gold yields from sinking pirate ships.
	"Wide-Eyed":-10.0, //Unlocks Skull Island, Gain more fun from birdwatching.
	
	"Coxswain":0.0, //Helps when outrunning from storms.
	"Cryptobotanist":0.0, //Unlocks Jungle Island, helps when running out of Grog.
	"Cuisinier":-10.0, //Unlocks Dessert Island, bonus fun for eating in Smooth Sailing.
	"Harquebusier":-15.0, //Unlocks Skull Island, deals damage in combat, and gives +1 fun from fights.
	"Mixologist":-10.0, //Drinking Grog gives +2 fun, required to unlock Island Drinkin', a Tiki Mixology Odyssey.
	};
	if (__pr_settings.player_requested_islands["Dessert Island"])
	{
		first_mate_priorities["Cuisinier"] -= 100.0;
	}
	if (__pr_settings.player_requested_islands["Jungle Island"])
	{
		first_mate_priorities["Cuisinier"] -= 100.0;
		first_mate_priorities["Beligerent"] -= 100.0;
	}
	if (__pr_settings.player_requested_islands["Skull Island"])
	{
		first_mate_priorities["Wide-Eyed"] -= 100.0;
		first_mate_priorities["Harquebusier"] -= 100.0;
	}
	if (__pr_settings.player_requested_islands["Tiki Island"]) //FIXME only if they don't
	{
		first_mate_priorities["Mixologist"] -= 5.0;
	}
	
	float [int] each_first_mate_score;
	int [int] first_mate_order;
	foreach key, choice_text in available_choice_options()
	{
		float priority = 0.0;
		first_mate_order[first_mate_order.count()] = key;
		foreach first_mate, value in first_mate_priorities
		{
			if (choice_text.contains_text(first_mate))
				priority += value;
		}
		priority += randomf() / 16777216.0; //random tiebreaker
		each_first_mate_score[key] = priority;
	}
	sort first_mate_order by each_first_mate_score[value];
	run_choice(first_mate_order[0]);
	//{"1":"the Pinch-Fisted\r Coxswain\r","2":"the Dipsomaniacal\r Cuisinier\r","3":"the Gluttonous\r Harquebusier\r"}
	//{"1":"the bloody harpoon","2":"the cursed compass","3":"the ancient skull key","4":"the curious anemometer","5":"Red Roger's flag","6":"Glass Jack's spyglass"}
	run_choice_by_text_list(__pr_settings.curio_order);
	//{"1":"The Rigged Frigate","2":"The Intimidating Galleon","3":"The Speedy Caravel","4":"The Swift Clipper","5":"The Menacing Man o' War"}
	run_choice_by_text_list(__pr_settings.ship_order);
	
	//{"1":"Head for the sea"}
	run_choice_by_text("Head for the sea");
}

void pirateRunLoop()
{
	int breakout = 100;
	boolean encountered_fighting = false;
	while (breakout > 0)
	{
		breakout -= 1;
		buffer pirate_realm_page_text = visit_url("place.php?whichplace=realm_pirate");
		if (pirate_realm_page_text.contains_text("adventure.php?snarfblat=530"))
		{
			if (encountered_fighting && __pr_settings.key_only)
				break;
			boolean stop = pirateRunSailingTurn(pirate_realm_page_text);
			if (stop)
				break;
		}
		else if (pirate_realm_page_text.contains_text("adventure.php?snarfblat=531"))
		{
			encountered_fighting = true;
			boolean stop = pirateRunFightingTurn(pirate_realm_page_text);
			if (stop)
				break;
		}
		else if (pirate_realm_page_text.contains_text("(fully explored)"))
		{
			visit_url("place.php?whichplace=realm_pirate&action=pr_port");
			print("Finished.");
			return;
		}
		else if (pirate_realm_page_text.contains_text("PirateRealm"))
		{
			if (my_adventures() < 40)
			{
				print("You'll need forty adventures to start.", "red");
				return;
			}
			//Start!
			if ($item[PirateRealm eyepatch].available_amount() == 0)
			{
				visit_url("place.php?whichplace=realm_pirate&action=pr_port");
			}
			else
			{
				pirateStartRun();
			}
		}
		else
		{
			print("No pirates?");
			return;
		}
	}
}

/*
from wiki:
Island 1
Battle Island
Monsters: melty army man - Drops melty plastic grenade (combat item that deals scaling stench damage and elementally aligns enemy)
Reward: 3 guns

Crab Island
Monsters: giant crab - Drop 1 grub
Boss: giant giant crab - Unlocks the crabsicle in the Fun-a-Log. Drops 2000 base meat. Gives 17 fun.

Glass Island
Monsters: translucent monkey - Drop 1 grog
Reward: Some base booze. Unlocks bottle of dark rhum, bottle of extra-dark rhum, bottle of super-extra-dark rhum in the Fun-a-Log.

Dessert Island
Requires a Cuisinier crewmate.
Monsters: melty freezeface - Drop oversized ice molecule (1-size spleen item, gives 50 turns of +5 cold res, +25 cold damage, +50 cold spell damage)
Reward: cocoa of youth, a usable item that extends the duration of up to 10 of your effects by 5 Adventures.

Key Key
Requires Glass Jack's spyglass curio.
Monsters: plastic pirate - Drop 7 fun each.
Reward: A Daily Dungeon key

Skull Island
Requires a Wide-Eyed or Harquebusier crewmate.
Monsters: plastic skeleton - Fights give 5-10 Gold. Gives 4 fun.
Reward: tomb-opener, which can be used on Cemetery Island to obtain the map to Red Roger's Fortress, giving one of Red Roger's parts.

Island 2
Isla Gublar
Monsters: toy dinosaur
Reward: Unlock pirate shaving cream in the Fun-a-Log. Subsequent visits yield 30 fun.

Cemetery Island
Monsters: plastic skeleton, vape ghost - Fights give 10-15 gold.
Reward: With tomb-opener, obtain Red Roger's map and 20 fun. Otherwise, gain 10 fun.

Jungle Island
Requires a Beligerent or Cryptobotanist crewmate
Monsters: translucent monkey
Boss: jungle titan - Unlocks conquistador's breastplate in the Fun-a-Log. Gives 17 fun.

Trash Island
Requires curious anemometer curio
Monsters: cockroach - Drop 1 grub and 1 grog
Reward: Your Empire of Dirt - Obtain random items from throughout the game.

Prison Island
Requires ancient skull key curio
Monsters: plastic pirate - Drop 7 fun each.
Reward: First time, permanently adds a third crewmate option and gives 10 fun. Subsequent visits yield 20 fun.

Island 3
Signal Island
Monsters: signal - Drops signal fragment
Boss: pirate radio - Unlocks pirate radio ring in the Fun-a-Log. Gives 3 fun.

Tiki Island
Monsters: tiki idol - Drops one of the tiki cocktail garnishes: hibiscus petal, huge mint leaf, or pineapple slab.
Reward: On first visit with a Mixologist mate, unlock Island Drinkin', a Tiki Mixology Odyssey in the Fun-a-Log. Otherwise, get 10 fun.

Storm Island
Monsters: strong wind - Reduces all damage sources to 1 and has about 70 HP. Use multiple damage sources, elemental damage, and passive damage. Negative Monster Level helps to reduce its starting HP. Drops a windicle, a combat item that runs away and reduces the remaining combats on a PirateRealm island by 3.
Reward: Unlocks curious anemometer curio. Subsequent visits yield 10 fun.

Red Roger's Fortress
Requires Red Roger's map
Monsters: plastic pirate - Drop 7 fun each.
Boss: Red Roger - Drops Red Roger's reliquary, which contains one of his four body parts. Gives 17 fun.

Glass Jack's Hideout‎
Requires recursed compass
Monsters: carnivorous plant
Boss: Glass Jack Hummel - Reduces all damage sources to 10 and has 200 HP. Use multiple damage sources, elemental damage, and passive damage. Unlocks the Glass Jack's spyglass curio. Gives 17 fun.

Temple Island
Requires you to equip all four pieces of Red Roger gear when entering the island #3 choice adventure.
Monsters: plastic skeleton, pewter torsohunter - Drops pewter shavings (size-1 spleen item that gives 100 Adventures of damage absorption +250, damage reduction: 25)
Reward: First visit: Red Roger's skull (familiar hatchling) and unlocks Red Roger tattoo kit in the Fun-a-Log, Subsequent visits give 10,000 meat.
*/

//ideal generic route:
//key key - (Glass Jack's spyglass curio), skull island
//prison island - (ancient skull key curio) -> isla gublar
//signal island (if farming) -> red roger's fortress (requires map) -> glass jack's hideout (requires recursed compass, complicated) -> storm island (no don't go there) -> tiki island

void outputHelp()
{
	print_html("<b>any</b>: default, which is key key / isla gublar / signal/tiki island");
	print_html("<b>keyonly</b>: only collect the daily dungeon key, no other islands");
	print_html("");
		
	string [string] islands = {
	"battle":"Battle Island",
	"crab":"Crab Island",
	"dessert":"Dessert Island",
	"skull":"Skull Island",
	"glass":"Glass Island",
	"dinosaurs":"Isla Gublar",
	"cemetery":"Cemetery Island",
	"jungle":"Jungle Island",
	"signal":"Signal Island",
	"tiki":"Tiki Island",
	"storm":"Storm Island",
	"temple":"Temple Island",
	"trash":"Trash Island",
	"prison":"Prison Island",
	"fortress":"Red Roger's Fortress",
	"key":"Key Key"
	};
	print_html("Sail to specific islands:");
	foreach island_command, island_description in islands
	{
		print_html("<b>" + island_command + "</b>: " + island_description);
	}
	print_html("");
	print_html("Multiple islands are supported, e.g. <b>piraterealm glass trash tiki</b>");
	print_html("");
	print_html("You'll have to unlock things by hand, alas.");
}
//return true if stop
boolean pirateSetup(string arguments_in)
{
	if (arguments_in == "")
	{
		outputHelp();
		return true;
	}
	foreach key, argument in arguments_in.split_string(" ")
	{
		argument = argument.to_lower_case();
		if (argument == "help")
		{
			outputHelp();
			return true;
		}
		/*
			√Battle Island - nothing
			√Crab Island - nothing
			√Glass Island - nothing
			√Dessert Island - Requires a Cuisinier crewmate
			√Key Key - Requires Glass Jack's spyglass curio
			√Skull Island - Requires a Wide-Eyed or Harquebusier crewmate. rewards tomb-opener, NEEDED FOR Red Roger's Fortress
			
			√Isla Gublar - nothing
			√Cemetery Island - nothing, but needed to go here if we need tomb-opener, NEEDED FOR Red Roger's Fortress
			√Jungle Island - Requires a Beligerent or Cryptobotanist crewmate
			√Trash Island - Requires curious anemometer curio
			√Prison Island - Requires ancient skull key curio
			
			√Signal Island - nothing
			√Tiki Island - nothing
			√Storm Island - nothing
			√Red Roger's Fortress - requires skull island + cemetery island + right crewmate
			Glass Jack's Hideout - Requires recursed compass, tricky to get
			√Temple Island - Requires you to equip all four pieces of Red Roger gear when entering the island #3 choice adventure.
		*/
		
		string [string] simple_islands = {
		"battle":"Battle Island",
		"crab":"Crab Island",
		"dessert":"Dessert Island",
		"skull":"Skull Island",
		"glass":"Glass Island",
		"dinosaurs":"Isla Gublar",
		"isla":"Isla Gublar",
		"gublar":"Isla Gublar",
		"jurassicpark":"Isla Gublar",
		"cemetery":"Cemetery Island",
		"cemetary":"Cemetery Island",
		"jungle":"Jungle Island",
		"signal":"Signal Island",
		"tiki":"Tiki Island",
		"storm":"Storm Island",
		"temple":"Temple Island"
		};
		
		if (simple_islands contains argument)
		{
			string target = simple_islands[argument];
			//lazy:
			__pr_settings.island_1_order[__pr_settings.island_1_order.count()] = target;
			__pr_settings.island_2_order[__pr_settings.island_2_order.count()] = target;
			__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = target;
			__pr_settings.player_requested_islands[target] = true;
		}
		//{"1":"the bloody harpoon","2":"the cursed compass","3":"the ancient skull key","4":"the curious anemometer","5":"Red Roger's flag","6":"Glass Jack's spyglass"}
		if (argument == "trash")
		{
			__pr_settings.curio_order[__pr_settings.curio_order.count()] = "the curious anemometer";
			__pr_settings.island_2_order[__pr_settings.island_2_order.count()] = "Trash Island";
			__pr_settings.player_requested_islands["Trash Island"] = true;
		}
		if (argument == "prison")
		{
			__pr_settings.curio_order[__pr_settings.curio_order.count()] = "the ancient skull key";
			__pr_settings.island_2_order[__pr_settings.island_2_order.count()] = "Prison Island";
			__pr_settings.player_requested_islands["Prison Island"] = true;
		}
		if (argument == "roger" || argument == "fortress" || argument == "red")
		{
			__pr_settings.island_1_order[__pr_settings.island_1_order.count()] = "Skull Island";
			__pr_settings.island_2_order[__pr_settings.island_2_order.count()] = "Cemetery Island";
			__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Red Roger's Fortress";
			__pr_settings.player_requested_islands["Red Roger's Fortress"] = true;
			__pr_settings.player_requested_islands["Skull Island"] = true;
			__pr_settings.player_requested_islands["Cemetery Island"] = true;
		}
		if (argument == "key" || argument == "keyonly")
		{
			__pr_settings.curio_order[__pr_settings.curio_order.count()] = "Glass Jack's spyglass";
			__pr_settings.island_1_order[__pr_settings.island_1_order.count()] = "Key Key";
			__pr_settings.player_requested_islands["Key Key"] = true;
		}
		if (argument == "keyonly")
		{
			__pr_settings.ship_order[__pr_settings.ship_order.count()] = "The Swift Clipper";
			__pr_settings.key_only = true;
		}
	}

	//__pr_settings.curio_order[__pr_settings.curio_order.count()] = "the curious anemometer";
	__pr_settings.curio_order[__pr_settings.curio_order.count()] = "Glass Jack's spyglass";
	__pr_settings.curio_order[__pr_settings.curio_order.count()] = "the ancient skull key";
	
	__pr_settings.island_1_order[__pr_settings.island_1_order.count()] = "Key Key";
	__pr_settings.island_1_order[__pr_settings.island_1_order.count()] = "Skull Island";
	__pr_settings.island_1_order[__pr_settings.island_1_order.count()] = "Crab Island";
	
	
	__pr_settings.island_2_order[__pr_settings.island_2_order.count()] = "Prison Island";
	__pr_settings.island_2_order[__pr_settings.island_2_order.count()] = "Isla Gublar";
	
	//we farm signal island because signals are expensive - switch to tiki exclusively if the puzzle comes out and they don't matter anymore
	if (random(2) == 0)
		__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Signal Island";
	else
		__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Tiki Island";
	__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Red Roger's Fortress";
	__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Glass Jack's Hideout‎";
	__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Tiki Island";
		__pr_settings.island_3_order[__pr_settings.island_3_order.count()] = "Signal Island";

	__pr_settings.ship_order[__pr_settings.ship_order.count()] = "The Menacing Man o' War";
	__pr_settings.ship_order[__pr_settings.ship_order.count()] = "The Rigged Frigate";
	
	return false;
}

void main(string arguments)
{
	int starting_fun_points = get_property("availableFunPoints").to_int();
	print("PirateRealm v" + __pirate_version);
	ArchiveEquipment();
	readPirateFileState();
	
	if (pirateSetup(arguments))
	{
		RestoreArchivedEquipment();
		return;
	}
	cli_execute("outfit birthday suit");
	pirateRunLoop();
	parseFunALog();
	parsePirateCharpaneState();
	int point_delta = get_property("availableFunPoints").to_int() - starting_fun_points;
	
	if (point_delta > 0)
		print("You have earned " + point_delta + " FunPoints today. (" + __pirate_charpane_state["Fun"] + " total)");
	else if (__pirate_charpane_state["Fun"] > 0)
		print("You have earned " + __pirate_charpane_state["Fun"] + " FunPoints total.");
	
	
	RestoreArchivedEquipment();
}