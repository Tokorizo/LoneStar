// Fallout tribes (A shameless copy of the tribes.dm with a different name)

// Names that serve as a blacklist to prevent inappropiate or duplicit tribe names
GLOBAL_LIST_INIT(tribe_names, list ( \
"white legs", \
"80s", \
"sun dogs", \
"navarro", \
"blackfoot", \
"sorrows", \
"great khans", \
))

//Which social factions are allowed to join tribe?
GLOBAL_LIST_INIT(allowed_tribe_factions, list ( \
"Tribal", \
))

// List of all existing tribe
GLOBAL_LIST_EMPTY(all_tribes)

/datum/tribe/New(starting_members, starting_leader)
	. = ..()
	if(starting_leader)
		add_leader(starting_leader)
	if(starting_members)
		if(islist(starting_members))
			for(var/mob/living/L in starting_members)
				add_member(L)
		else
			add_member(starting_members)

/datum/tribe/proc/is_solo()
	return members.len == 1

/datum/tribe/proc/add_leader(mob/living/carbon/new_leader)
	leader = new_leader

	remove_verb(new_leader,/mob/living/proc/assumeleader)

	add_verb(new_leader,/mob/living/proc/invitetribe)
	add_verb(new_leader,/mob/living/proc/removemember)
	add_verb(new_leader,/mob/living/proc/transferleader)
	add_verb(new_leader,/mob/living/proc/setwelcome)
	if(!round_start)
		add_verb(new_leader,/mob/living/proc/setcolor)
	add_verb(new_leader,/mob/living/proc/leavetribe)
	to_chat(new_leader, "<span class='notice'>You have become a new chief of the [name]! You can now invite and remove members at will.")

	//var/obj/item/device/tribetool/tribetool = new(new_leader) (Code in later for now)
	//tribetool.tribe = new_leader.tribe
	//assigned_tool = tribetool

	//var/list/slots = list (
		//"backpack" = SLOT_IN_BACKPACK,
		//"left pocket" = SLOT_L_STORE,
		//"right pocket" = SLOT_R_STORE
	//)

	//var/where = new_leader.equip_in_one_of_slots(tribetool, slots, FALSE)
	//if(!where)
		//tribetool.forceMove(get_turf(new_leader))

	//if(assigned_tool)
		//var/obj/item/device/tribetool/tool = assigned_tool
		//tool.name = "[initial(tool.name)] - [name]"

/datum/tribe/proc/remove_leader(mob/living/carbon/old_leader)
	leader = null
	remove_verb(old_leader,/mob/living/proc/invitetribe)
	remove_verb(old_leader,/mob/living/proc/removemember)
	remove_verb(old_leader,/mob/living/proc/transferleader)
	remove_verb(old_leader,/mob/living/proc/setwelcome)
	if(!round_start)
		remove_verb(old_leader,/mob/living/proc/setcolor)
	add_verb(old_leader,/mob/living/proc/assumeleader)
	to_chat(old_leader, "<span class='warning'>You are no longer the chief of the [name]!</span>")
	if(assigned_tool)
		assigned_tool.audible_message("<span class='warning'>With a change of the [name] leadership, [assigned_tool] ceases to function and self-destructs!</span>")
		qdel(assigned_tool)

/datum/tribe/proc/add_member(mob/living/carbon/new_member)
	members |= new_member
	new_member.faction |= "[name]-tribe"
	remove_verb(new_member,/mob/living/proc/createtribe)

	add_verb(new_member,/mob/living/proc/leavetribe)

	add_verb(new_member,/mob/living/proc/assumeleader)
	to_chat(new_member, "<span class='notice'>You are now a member of the [name]! Everyone can recognize your new tribal marks.</span>")
	if(welcome_text)
		to_chat(new_member, "<span class='notice'>Welcome text: </span><span class='purple'>[welcome_text]</span>")

/datum/tribe/proc/remove_member(mob/living/carbon/member)
	members -= member
	member.tribe = null
	member.faction -= "[name]-tribe"
	add_verb(member,/mob/living/proc/createtribe)
	remove_verb(member,/mob/living/proc/leavetribe)
	remove_verb(member,/mob/living/proc/assumeleader)
	to_chat(member, "<span class='warning'>You are no longer a tribal of the [name]!</span>")

	if(!members.len && !round_start)
		GLOB.tribe_names -= lowertext(name)
		GLOB.all_tribes -= src
		qdel(src)

/mob/living/proc/invitetribe()
	set name = "Invite To tribe"
	set desc = "Invite others to your tribe."
	set category = "tribe"

	var/list/possible_targets = list()
	for(var/mob/living/carbon/target in oview())
		if(target.stat || !target.mind || !target.client)
			continue
		if(target.tribe == tribe)
			continue
		if(!(target.social_faction in GLOB.allowed_tribe_factions))
			continue
		if(target.tribe)
			continue
		possible_targets += target

	if(!possible_targets.len)
		return

	var/mob/living/carbon/C
	C = input("Choose who to invite to your tribe!", "tribe invitation") as null|mob in possible_targets
	if(!C)
		return

	var/datum/tribe/G = tribe
	if(alert(C, "[src] invites you to join the [G.name].", "tribe invitation", "Yes", "No") == "No")
		visible_message(C, "<span class='warning'>[C.name] refused an offer to join the [G.name]!</span>")
		return
	else
		visible_message(C, "<span class='notice'>[C.name] accepted an offer to join the [G.name]!</span>")

	G.add_member(C)
	C.tribe = G

/mob/living/proc/createtribe()
	set name = "Create tribe"
	set category = "tribe"

	var/input = input(src, "Enter the name of your new tribe!", "tribe name") as text|null
	if(!input)
		return
	input = copytext(sanitize(input), 1, 30)
	if(lowertext(input) in GLOB.tribe_names)
		to_chat(src, "<span class='notice'>This tribe name is already taken!</span>")
		return
	GLOB.tribe_names |= lowertext(input)

	var/datum/tribe/G = new()
	G.name = input
	GLOB.all_tribes |= G
	tribe = G
	to_chat(src, "<span class='notice'>You have created [G.name]!</span>")

	G.add_member(src)
	G.add_leader(src)

/mob/living/proc/leavetribe()
	set name = "Leave tribe"
	set category = "tribe"

	var/datum/tribe/G = tribe
	if(!G)
		to_chat(src, "You are already not in any tribe!")
		return
	if(alert("Are you sure you want to leave [G.name]?", "Leave tribe", "Yes", "No") == "No")
		return

	if(G.leader == src)
		G.remove_leader(src)
	G.remove_member(src)

/mob/living/proc/assumeleader()
	set name = "Assume Leadership"
	set desc = "Become a new chief if the old one is missing or dead."
	set category = "tribe"

	var/datum/tribe/G = tribe
	if(G && G.leader)
		var/mob/living/L = G.leader
		if(L.stat != DEAD && L.client)
			to_chat(src, "<span class='warning'>The Chieftain is still alive and well!</span>")
			return
		else
			G.remove_leader(L)
			G.add_leader(src)
	else if(G)
		G.add_leader(src)

/mob/living/proc/transferleader()
	set name = "Transfer Leadership"
	set desc = "Transfer your leader position to a different tribe member in view."
	set category = "tribe"

	var/list/possible_targets = list()
	for(var/mob/living/carbon/target in oview())
		if(target.stat || !target.mind || !target.client)
			continue
		if(target.tribe != tribe)
			continue
		possible_targets += target

	if(!possible_targets.len)
		return

	var/datum/tribe/G = tribe
	if(G && G.leader == src)
		var/mob/living/carbon/new_leader
		new_leader = input(src, "Choose a new chieftan of the [G.name]!", "Transfer tribe Leadership") as null|mob in possible_targets
		if(!new_leader || new_leader == src)
			return
		var/mob/living/H = new_leader
		to_chat(src, "<span class='notice'>You have transferred tribal leadership of the [G.name] to [H.real_name]!</span>")
		to_chat(H, "<span class='notice'>You have received tribal leadership of the [G.name] from [src.real_name]!</span>")
		G.remove_leader(src)
		G.add_leader(H)

/mob/living/proc/removemember()
	set name = "Remove Member"
	set desc = "Remove an alive tribe member from the tribe in view."
	set category = "tribe"

	var/list/possible_targets = list()
	for(var/mob/living/carbon/target in oview())
		if(target.tribe != tribe)
			continue
		if(target.stat == DEAD)
			continue
		possible_targets += target

	if(!possible_targets.len)
		return

	var/datum/tribe/G = tribe
	if(G && G.leader == src)
		var/mob/living/carbon/kicked_member
		kicked_member = input(src, "Choose a tribe member to remove from [G.name]!", "tribe member removal") as null|mob in possible_targets
		if(!kicked_member || kicked_member == src)
			return

		var/mob/living/H = kicked_member
		to_chat(src, "<span class='notice'>You have removed [H.real_name] from the [G.name]!</span>")
		to_chat(H, "<span class='warning'>You have been kicked from the [G.name] by [src.real_name]!</span>")
		G.remove_member(H)

/mob/living/proc/setwelcome()
	set name = "Set Welcome Text"
	set desc = "Set a welcome text that will show to all new members of the tribe upon joining."
	set category = "tribe"

	var/datum/tribe/G = tribe
	var/input = input(src, "Set a welcome text for a new tribe members!", "Welcome text", G.welcome_text) as text|null
	if(!input)
		return
	input = copytext(sanitize(input), 1, 300)
	G.welcome_text = input

	to_chat(src, "<span class='notice'>You have set a welcome text for a new tribe members!</span>")

/mob/living/proc/setcolor()
	set name = "Choose tribe Color"
	set desc = "Set a color of your tribe that will be visible on the tribe members upon examine."
	set category = "tribe"

	var/datum/tribe/G = tribe
	var/picked_color = input(src, "", "Choose Color", color) as color|null
	if(!picked_color)
		return
	G.color = sanitize_color(picked_color)

	to_chat(src, "<span class='notice'>You have chosen a new tribe color!</span>")
