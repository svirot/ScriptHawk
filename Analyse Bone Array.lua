local pointer_list;
local max_objects = 0xFF;
local precision = 5 or precision;
print_every_frame = false;

local romName = gameinfo.getromname();

if bizstring.contains(romName, "Donkey Kong 64") then -- TODO: Detect using ROM hash rather than name
	if bizstring.contains(romName, "USA") and not bizstring.contains(romName, "Kiosk") then
		pointer_list = 0x7FBFF0;
	elseif bizstring.contains(romName, "Europe") then
		pointer_list = 0x7FBF10;
	elseif bizstring.contains(romName, "Japan") then
		pointer_list = 0x7FC460;
	elseif bizstring.contains(romName, "Kiosk") then
		pointer_list = 0x7B5E58;
	end
else
	print("This game is not supported.");
	return false;
end

-- Relative to objects in pointer list
local model_pointer = 0x00;
local rendering_parameters_pointer = 0x04;
local current_bone_array_pointer = 0x08;

-- Relative to shared model object
local num_bones = 0x20;

-- Relative to objects in bone array
local bone_size = 0x40;
local bone_position_x = 0x18; -- int 16 be
local bone_position_y = 0x1A; -- int 16 be
local bone_position_z = 0x1C; -- int 16 be

local bone_scale_x = 0x20; -- uint 16 be
local bone_scale_y = 0x2A; -- uint 16 be
local bone_scale_z = 0x34; -- uint 16 be

--------------------
-- Load Libraries --
--------------------

Stats = require "lib.Stats";
require "lib.DPrint";

----------------------
-- Helper functions --
----------------------

function round(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num));
end

function toHexString(value)
	value = string.format("%X", value or 0);
	if string.len(value) % 2 ~= 0 then
		value = "0"..value;
	end
	return "0x"..value;
end

local RDRAMBase = 0x80000000;
local RDRAMSize = 0x800000; -- Halved without expansion pak

-- Checks whether a value falls within N64 RDRAM
local function isRDRAM(value)
	return type(value) == "number" and value >= 0 and value < RDRAMSize;
end

-- Checks whether a value is a pointer
local function isPointer(value)
	return type(value) == "number" and value >= RDRAMBase and value < RDRAMBase + RDRAMSize;
end

------------------
-- Stupid stuff --
------------------

local safeBoneNumbers = {};

local function setNumberOfBones(modelBasePointer)
	if isRDRAM(modelBasePointer) then
		if safeBoneNumbers[modelBasePointer] == nil then
			safeBoneNumbers[modelBasePointer] = mainmemory.readbyte(modelBasePointer + num_bones);
		end

		local currentNumBones = mainmemory.readbyte(modelBasePointer + num_bones);
		local newNumBones;

		if joypad.getimmediate()["P1 L"] then
			newNumBones = math.max(currentNumBones - 1, 1);
		else
			newNumBones = math.min(currentNumBones + 1, safeBoneNumbers[modelBasePointer]);
		end

		if newNumBones ~= currentNumBones then
			mainmemory.writebyte(modelBasePointer + num_bones, newNumBones);
		end
	end
end

--------------------
-- The main event --
--------------------

local function getBoneInfo(baseAddress)
	local boneInfo = {};
	boneInfo["positionX"] = mainmemory.read_s16_be(baseAddress + bone_position_x);
	boneInfo["positionY"] = mainmemory.read_s16_be(baseAddress + bone_position_y);
	boneInfo["positionZ"] = mainmemory.read_s16_be(baseAddress + bone_position_z);
	boneInfo["scaleX"] = mainmemory.read_u16_be(baseAddress + bone_scale_x);
	boneInfo["scaleY"] = mainmemory.read_u16_be(baseAddress + bone_scale_y);
	boneInfo["scaleZ"] = mainmemory.read_u16_be(baseAddress + bone_scale_z);
	return boneInfo;
end

local function outputBones(boneArrayBase, numBones)
	dprint("Bone,X,Y,Z,ScaleX,ScaleY,ScaleZ,");
	local boneInfoTables = {};
	for i = 0, numBones - 1 do
		local boneInfo = getBoneInfo(boneArrayBase + i * bone_size);
		table.insert(boneInfoTables, boneInfo);
		dprint(i..","..boneInfo["positionX"]..","..boneInfo["positionY"]..","..boneInfo["positionZ"]..","..boneInfo["scaleX"]..","..boneInfo["scaleY"]..","..boneInfo["scaleZ"]..",");
	end
	print_deferred();
	return boneInfoTables;
end

local function calculateCompleteBones(boneArrayBase, numberOfBones)
	local numberOfCompletedBones = numberOfBones;
	local statisticallySignificantX = {};
	local statisticallySignificantZ = {};
	for currentBone = 0, numberOfBones - 1 do
		-- Get all known information about the current bone
		local boneInfo = getBoneInfo(boneArrayBase + currentBone * bone_size);
		local boneDisplaced = false;

		-- Detect basic zeroing, the bone displacement method method currently detailed in the document
		if boneInfo["positionX"] == 0 and boneInfo["positionY"] == 0 and boneInfo["positionZ"] == 0 then
			if boneInfo["scaleX"] == 0 and boneInfo["scaleY"] == 0 and boneInfo["scaleZ"] == 0 then
				boneDisplaced = true;
			end
		end

		-- Detect position being set to -32768
		if boneInfo["positionX"] == -32768 and boneInfo["positionY"] == -32768 and boneInfo["positionZ"] == -32768 then
			boneDisplaced = true;
		end

		if boneDisplaced then
			numberOfCompletedBones = numberOfCompletedBones - 1;
		else
			table.insert(statisticallySignificantX, boneInfo["positionX"]);
			table.insert(statisticallySignificantZ, boneInfo["positionZ"]);
		end
	end

	-- Stats based check for type 3 "translation"
	local meanX = Stats.mean(statisticallySignificantX);
	local stdX = Stats.standardDeviation(statisticallySignificantX) * 2.5;

	local meanZ = Stats.mean(statisticallySignificantZ);
	local stdZ = Stats.standardDeviation(statisticallySignificantZ) * 2.5;

	-- Check for outliers
	for currentBone = 1, #statisticallySignificantX do
		local diffX = math.abs(meanX - statisticallySignificantX[currentBone]);
		local diffZ = math.abs(meanZ - statisticallySignificantZ[currentBone]);
		if diffX > stdX and diffZ > stdZ then
			numberOfCompletedBones = numberOfCompletedBones - 1;
		end
	end

	return math.max(0, numberOfCompletedBones);
end

print_threshold = 1;
local function processObject(objectPointer)
	local currentModelBase = mainmemory.read_u32_be(objectPointer + model_pointer);
	local currentBoneArrayBase = mainmemory.read_u32_be(objectPointer + current_bone_array_pointer);

	if isPointer(currentModelBase) and isPointer(currentBoneArrayBase) then
		currentModelBase = currentModelBase - RDRAMBase;
		currentBoneArrayBase = currentBoneArrayBase - RDRAMBase;

		-- Stupid stuff
		setNumberOfBones(currentModelBase);

		-- Calculate how many bones were correctly processed this frame
		local numberOfBones = mainmemory.readbyte(currentModelBase + num_bones);
		local completedBones = calculateCompleteBones(currentBoneArrayBase, numberOfBones);

		local completedBoneRatio = completedBones / numberOfBones;

		if completedBoneRatio < print_threshold or print_every_frame then
			print(toHexString(objectPointer).." updated "..completedBones.."/"..numberOfBones.." bones.");
			outputBones(currentBoneArrayBase, numberOfBones);
		end
	end
end

local function mainLoop()
	if not emu.islagged() then
		local objectPointer = 0x000000;
		local objectIndex = 0;
		repeat
			objectPointer = mainmemory.read_u24_be(pointer_list + (objectIndex * 4) + 1);
			objectIndex = objectIndex + 1;
			if isRDRAM(objectPointer) then
				processObject(objectPointer);
			end
		until not isRDRAM(objectPointer) or objectIndex >= max_objects;
	end
end

event.onframestart(mainLoop, "ScriptHawk - Analyse bone array");