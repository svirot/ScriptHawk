-----------------------
-- Load JSON library --
-----------------------

--JSON = require "lib.JSON";

-----------------------

local level_object_array_pointer;
local romName = gameinfo.getromname();

if not bizstring.contains(romName, "Banjo-Kazooie") and not bizstring.contains(romName, "Banjo to Kazooie no Daibouken") then
	print("This game is not currently supported.");
end

if bizstring.contains(romName, "Europe") then
	level_object_array_pointer = 0x36EAE0;
elseif bizstring.contains(romName, "Japan") then
	level_object_array_pointer = 0x36F260;
elseif bizstring.contains(romName, "USA") and bizstring.contains(romName, "Rev A") then
	level_object_array_pointer = 0x36D760;
elseif bizstring.contains(romName, "USA") then
	level_object_array_pointer = 0x36E560;
else
	print("This version of the game is not currently supported.");
	return false;
end

-- Slot data
local slot_base = 0x08;
local slot_size = 0x180;
local max_slots = 0x100;

-- Relative to slot start
slot_variables = {
	[0x00] = {["Type"] = "Pointer"}, -- TODO: Does this have anything to do with that huge linked list?
	[0x04] = {["Type"] = "Float", ["Name"] = "X Position"},
	[0x08] = {["Type"] = "Float", ["Name"] = "Y Position"},
	[0x0C] = {["Type"] = "Float", ["Name"] = "Z Position"},

	[0x14] = {["Type"] = "Pointer"},
	[0x18] = {["Type"] = "Pointer"},

	[0x28] = {["Type"] = "Float"}, -- TODO: Velocity?

	[0x48] = {["Type"] = "Float", ["Name"] = "Race path progression"}, 
	[0x4C] = {["Type"] = "Float", ["Name"] = "Speed (rubberband)"}, 

	[0x50] = {["Type"] = "Float", ["Name"] = "Facing"},

	[0x60] = {["Type"] = "Float", ["Name"] = "Recovery Timer"}, -- TTC Crab
	[0x64] = {["Type"] = "Float", ["Name"] = "Unknown Angle"},
	[0x68] = {["Type"] = "Float", ["Name"] = "Rotation X"},

	[0x8C] = {["Type"] = "Float", ["Name"] = "Countdown timer?"},
	[0xE8] = {["Type"] = "Byte", ["Name"] = "Damages Player"},

	[0x114] = {["Type"] = "Float", ["Name"] = "Sound timer?"},
	[0x118] = {["Type"] = "Float"},
	[0x11C] = {["Type"] = "Float"},
	[0x120] = {["Type"] = "Float"},

	[0x125] = {["Type"] = "Byte", ["Name"] = "Transparancy"},
	[0x127] = {["Type"] = "Byte", ["Name"] = "Eye State"},
	[0x128] = {["Type"] = "Float", ["Name"] = "Scale"},
};

local function fillBlankVariableSlots()
	local data_size = 0x04;
	for i = 0, slot_size - data_size, data_size do
		if type(slot_variables[i]) == "nil" then
			slot_variables[i] = {["Type"] = "Z4_Unknown"};
		end
	end
end
fillBlankVariableSlots();

local slot_data = {};

--------------------
-- Output Helpers --
--------------------

function is_binary(var_type)
	return var_type == "Byte";
end
isBinary = is_binary;

function is_hex(var_type)
	return var_type == "Pointer" or var_type == "4_Unknown" or var_type == "Z4_Unknown";
end
isHex = is_hex;

function toHexString(value)
	value = string.format("%X", value or 0);
	if string.len(value) % 2 ~= 0 then
		value = "0"..value;
	end
	return "0x"..value;
end

function format_for_output(var_type, value)
	if is_binary(var_type) then
		local binstring = bizstring.binary(value);
		if binstring ~= "" then
			return binstring;
		end
		return "0";
	elseif is_hex(var_type) then
		return toHexString(value);
	end
	return ""..value;
end
formatForOutput = format_for_output;

function is_interesting(variable)
	local min = get_minimum_value(variable);
	local max = get_maximum_value(variable);
	return slot_variables[variable].Type ~= "Z4_Unknown" or min ~= max;
end
isInteresting = is_interesting;

------------
-- Output --
------------

function output_slot(index)
	if index > 0 and index < #slot_data then
		local previous_type = "";
		local current_slot = slot_data[index + 1];
		print("Starting output of slot "..index + 1);
		for i = 0, slot_size do
			if type(slot_variables[i]) == "table" then
				if slot_variables[i].Type ~= "Z4_Unknown" then
					if slot_variables[i].Type ~= previous_type then
						previous_type = slot_variables[i].Type;
						print("");
					end
					if type(slot_variables[i].Name) == "string" then
						print(toHexString(i).." "..(slot_variables[i].Name).." ("..(slot_variables[i].Type).."): "..format_for_output(slot_variables[i].Type, current_slot[i]));
					else
						print(toHexString(i).." "..(slot_variables[i].Type)..": "..format_for_output(slot_variables[i].Type, current_slot[i]));
					end
				else
					--print(toHexString(i).." Nothing interesting.");
				end
			end
		end
	end
end
outputSlot = output_slot;

function output_stats()
	if #slot_data == 0 then
		print("Error: Slot data is empty, please run parseSlotData()");
		return;
	end
	print("------------------------------");
	print("-- Starting output of stats --");
	print("------------------------------");
	local min, max;
	local previous_type = "";
	for i = 0, slot_size do
		if type(slot_variables[i]) == "table" then
			if is_interesting(i) then
				min = get_minimum_value(i);
				max = get_maximum_value(i);
				if slot_variables[i].Type ~= previous_type then
					previous_type = slot_variables[i].Type;
					print("");
				end
				if type(slot_variables[i].Name) ~= "nil" then
					print(toHexString(i).." "..(slot_variables[i].Type)..": "..format_for_output(slot_variables[i].Type, min).. " to "..format_for_output(slot_variables[i].Type, max).." - "..(slot_variables[i].Name));
				else
					print(toHexString(i).." "..(slot_variables[i].Type)..": "..format_for_output(slot_variables[i].Type, min).. " to "..format_for_output(slot_variables[i].Type, max));
				end
			else
				--print(toHexString(i).." Nothing interesting.");
			end
		end
	end
end
outputStats = output_stats;

function format_slot_data()
	local formatted_data = {};
	local relative_address, variable_data;
	for i = 1, #slot_data do
		formatted_data[i] = {};
		for relative_address, variable_data in pairs(slot_variables) do
			if type(variable_data) == "table" and is_interesting(relative_address) then
				if type(variable_data.Name) == "string" then
					formatted_data[i][toHexString(relative_address).." "..variable_data.Name] = {
						["Type"] = variable_data.Type,
						["Value"] = format_for_output(variable_data.Type, slot_data[i][relative_address])
					};
				else
					formatted_data[i][toHexString(relative_address).." "..variable_data.Type] = {
						["Value"] = format_for_output(variable_data.Type, slot_data[i][relative_address])
					};
				end
			end
		end
	end
	return formatted_data;
end
formatSlotData = format_slot_data;

function json_slots()
	local json_data = JSON:encode_pretty(format_slot_data());
	local file = io.open("Lua/ScriptHawk/Level_Object_Array.json", "w+");
	if type(file) ~= "nil" then
		io.output(file);
		io.write(json_data);
		io.close(file);
	else
		print("Error writing to file =(");
	end
end
jsonSlots = json_slots;

--------------
-- Analysis --
--------------

function find_root(object)
	local count = 0;
	while object > 0 do
		print(count..": .."..toHexString(object));
		object = mainmemory.read_u24_be(object + 1);
		count = count + 1;
	end
end
findRoot = find_root;

function resolve_variable_name(name)
	-- Make sure comparisons are case insensitive
	name = bizstring.toupper(name);

	-- Comparison loop
	local relative_address, variable_data;
	for relative_address, variable_data in pairs(slot_variables) do
		if type(variable_data) == "table" and type(variable_data.Name) ~= "nil" and bizstring.toupper(variable_data.Name) == name then
			return relative_address;
		end
	end

	-- Default + Error
	print("Variable name: '"..name.."' not found =(");
	return 0x00;
end
resolveVariableName = resolve_variable_name;

function get_minimum_value(variable)
	if type(variable) == "string" then
		variable = resolve_variable_name(variable);
	end
	if type(slot_variables[variable]) == "table" then
		local min = slot_data[1][variable];
		for i = 1, #slot_data do
			if slot_data[i][variable] < min then
				min = slot_data[i][variable];
			end
		end
		return min;
	end
	return 0;
end
getMinimumValue = get_minimum_value;

function get_maximum_value(variable)
	if type(variable) == "string" then
		variable = resolve_variable_name(variable);
	end
	if type(slot_variables[variable]) == "table" then
		local max = slot_data[1][variable];
		for i = 1, #slot_data do
			if slot_data[i][variable] > max then
				max = slot_data[i][variable];
			end
		end
		return max;
	end
	return 0;
end
getMaximumValue = get_maximum_value;

function get_all_unique(variable)
	if type(variable) == "string" then
		variable = resolve_variable_name(variable);
	end
	if type(slot_variables[variable]) == "table" then
		local unique_values = {};
		local value, count;
		if #slot_data == 0 then
			parseSlotData();
		end
		for i = 1, #slot_data do
			value = format_for_output(slot_variables[variable].Type, slot_data[i][variable]);
			if type(unique_values[value]) ~= "nil" then
				unique_values[value] = unique_values[value] + 1;
			else
				unique_values[value] = 1;
			end
		end

		-- Output the findings
		print("Starting output of variable "..toHexString(variable));
		for value, count in pairs(unique_values) do
			print(""..value.." appears "..count.." times");
		end
	end
end
getAllUnique = get_all_unique;

function set_all(variable, value)
	if type(variable) == "string" then
		variable = resolve_variable_name(variable);
	end
	if type(slot_variables[variable]) == "table" then
		local level_object_array = mainmemory.read_u24_be(level_object_array_pointer + 1);
		local numSlots = math.min(max_slots, mainmemory.read_u32_be(level_object_array));

		local currentSlotBase;
		for i = 0, numSlots - 1 do
			currentSlotBase = get_slot_base(level_object_array, i);
			if slot_variables[variable].Type == "Float" then
				--print("writing float to slot "..i);
				mainmemory.writefloat(currentSlotBase + variable, value, true);
			elseif is_hex(slot_variables[variable].Type) then
				--print("writing u32_be to slot "..i);
				mainmemory.write_u32_be(currentSlotBase + variable, value);
			else
				--print("writing byte to slot "..i);
				mainmemory.writebyte(currentSlotBase + variable, value);
			end
		end
	end
end
setAll = set_all;

-------------------
-- More analysis --
-------------------

-- Example call

--function condition(slot)
--	return value > 0;
--end

--get_variables({0x28, 0x2C, 0x30}, condition);

function db_select(variables, slots)
	local current_slot, value;
	local pulled_data = {};
	for i = 1, #variables do
		for j = 1, #slots do
			current_slot = slot_data[slots[j]];
			value = current_slot[variables[i]];
			if pulled_data[variables[i]] == nil then
				pulled_data[variables[i]] = {};
			end
			table.insert(pulled_data[variables[i]], value);
		end
	end
	return pulled_data;
end
dbSelect = db_select;

function db_not(slots)
	local slot_found;
	local matchedSlots = {};
	for i = 1, #slot_data do
		slot_found = false;
		if #slots > 0 then
			for j = 1, #slots do
				if i == slots[j] then
					slot_found = true;
				end
			end
		end
		if not slot_found then
			table.insert(matchedSlots, i);
		end
	end
	return matchedSlots;
end
dbNot = db_not;

function db_where(condition)
	local matchedSlots = {};
	if condition ~= nil then
		for i = 1, #slot_data do
			if condition(slot_data[i]) then
				table.insert(matchedSlots, i);
			end
		end
	end
	return matchedSlots;
end
dbWhere = db_where;

----------------------
-- Data acquisition --
----------------------

function get_slot_base(object_array, index)
	return object_array + slot_base + index * slot_size;
end
getSlotBase = get_slot_base;

function address_to_slot(address)
	local level_object_array = mainmemory.read_u24_be(level_object_array_pointer + 1);
	local numSlots = math.min(max_slots, mainmemory.read_u32_be(level_object_array));
	local position = address - level_object_array - slot_base;
	local relativeToObject = position % slot_size;
	local objectNumber = math.floor(position / slot_size);
	print("Object number "..objectNumber.." address relative "..toHexString(relativeToObject));
end
addressToSlot = address_to_slot;

function process_slot(slot_base)
	local current_slot_variables = {};
	local relative_address, variable_data;
	for relative_address, variable_data in pairs(slot_variables) do
		if type(variable_data) == "table" then
			if variable_data.Type == "Byte" then
				current_slot_variables[relative_address] = mainmemory.readbyte(slot_base + relative_address);
			elseif variable_data.Type == "4_Unknown" or variable_data.Type == "Z4_Unknown" or variable_data.Type == "Pointer" then
				current_slot_variables[relative_address] = mainmemory.read_u32_be(slot_base + relative_address);
			elseif variable_data.Type == "Float" then
				current_slot_variables[relative_address] = mainmemory.readfloat(slot_base + relative_address, true);
			end
		end
	end
	return current_slot_variables;
end
processSlot = process_slot;

function parse_slot_data()
	local level_object_array = mainmemory.read_u24_be(level_object_array_pointer + 1);
	local numSlots = math.min(max_slots, mainmemory.read_u32_be(level_object_array));

	-- Clear out old data
	slot_data = {};

	local currentSlotBase;
	for i = 0, numSlots - 1 do
		currentSlotBase = get_slot_base(level_object_array, i);
		table.insert(slot_data, process_slot(currentSlotBase));
	end

	output_stats();
end
parseSlotData = parse_slot_data;