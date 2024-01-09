----- COSMETICS -----
-- Position of the wf icon
local POSITIONX, POSITIONY = 0, -200

-- Size of the wf icon
local ICONWIDTH, ICONHEIGHT = 65, 65

-- Position and size of the countdown number
local FONTOFFSETY, FONTOFFSETX = 0, 0
local FONT_SIZE = 33

----- CONSTANTS FOR SPELL AND ITEM TEXTURES -----
local WFTotemTextureName = "Interface\\Icons\\Spell_Nature_Windfury"
local airTotemTextureName = "Interface\\Icons\\Spell_Nature_InvisibilityTotem"
local earthTotemTextureName = "Interface\\Icons\\Spell_Nature_EarthBindTotem"
local waterShieldTextureName = "Interface\\Icons\\Ability_Shaman_WaterShield"
local fireTotemTextureName = "Interface\\Icons\\Spell_FireResistanceTotem_01"
local manaTotemTextureName = "Interface\\Icons\\Spell_Nature_ManaRegenTotem"
local healTotemTextureName = "Interface\\Icons\\INV_Spear_04"
local natureTotemTextureName = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem"
local ThunderRelicTextureName = "Interface\\Icons\\Spell_Nature_Invisibilty"
local StonebreakerRelicTextureName = "Interface\\Icons\\Spell_Nature_Earthshock"
local CrusaderBuffTextureName = "Interface\\Icons\\Spell_Holy_BlessingOfStrength"

----- OTHER VARIABLES -----
local windfuryTimeTreshhold = 0.5 -- WF totem becomes available at this time till current wf buff is over.
local timeWFdropped = -1 -- Makes the WF buff countdown start from 9 instead of 10.
local hasCastWindfury = false  -- Variable to track whether "Windfury Totem" has been cast.
local isCasting = false -- Can't use totems while casting.

-- Bloodlust variables
local Addon = CreateFrame("FRAME")
local DeltaTime = 0
local OldTime = GetTime()
local IconLifeSpan = 0
local BLTarget = nil
local BLTargetName = nil
local RemainingCDPosted = false

local DEFAULT_SCALE = 1.0
local DEFAULT_ALPHA = 0.8
local DEFAULT_PASSWORD = "BL now!"
local DEFAULT_RESPONSE = "BL used!"

Enhancer_Config = {
	Scale = DEFAULT_SCALE,
	Alpha = DEFAULT_ALPHA,
	Password = DEFAULT_PASSWORD,
	Response = DEFAULT_RESPONSE,
}

----- COMMUNICATION -----

local START_COLOR = "\124CFF"
local END_COLOR = "\124r"

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("[Enhancer]: "..tostring(msg))
end

local function Error(msg)
	local COLOR = "FF0000"
	DEFAULT_CHAT_FRAME:AddMessage("[Enhancer]: "..START_COLOR..COLOR..tostring(msg)..END_COLOR)
end

local function SendWhisper(message, target)
	if (not target) then
		Error("Invalid target.")
		return
	end
	local channel = "WHISPER"
	local language = GetDefaultLanguage()
	SendChatMessage(message, channel, language, target)
end

----- UTILITY -----

local function ToString(str)
	if str == nil then return "nil" end
	return tostring(str)
end

local function print(message)
	DEFAULT_CHAT_FRAME:AddMessage(message)
end

local function getSpellId(targetSpellName, targetSpellRank)
    for i = 1, 200 do
        local spellName, spellRank = GetSpellName(i, "spell")
        if spellName == targetSpellName and spellRank == targetSpellRank then
            return i
        end
    end
    return nil
end

local function GetCooldown(spellId)
	if not spellId then
		return 10
	end

	local start, duration, enabled = GetSpellCooldown(spellId, "spell")
	if duration == 0 then
		return 0
	end

	return start + duration - GetTime()
end

local function SpellReady(spellId)
    local start, duration, enabled = GetSpellCooldown(spellId, "spell")
    return duration == 0
end

local function ItemLinkToName(link)
	if ( link ) then
   	return gsub(link,"^.*%[(.*)%].*$","%1");
	end
end

local function FindItem(item)
	if ( not item ) then return; end
	item = string.lower(ItemLinkToName(item));
	local link;
	for i = 1,23 do
		link = GetInventoryItemLink("player",i);
		if ( link ) then
			if ( item == string.lower(ItemLinkToName(link)) )then
				return i, nil, GetInventoryItemTexture('player', i), GetInventoryItemCount('player', i);
			end
		end
	end
	local count, bag, slot, texture;
	local totalcount = 0;
	for i = 0,NUM_BAG_FRAMES do
		for j = 1,MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i,j);
			if ( link ) then
				if ( item == string.lower(ItemLinkToName(link))) then
					bag, slot = i, j;
					texture, count = GetContainerItemInfo(i,j);
					totalcount = totalcount + count;
				end
			end
		end
	end
	return bag, slot, texture, totalcount;
end

local function UseItemByName(item)
	local bag,slot = FindItem(item);
	if ( not bag ) then return; end;
	if ( slot ) then
		UseContainerItem(bag,slot); -- use, equip item in bag
		return bag, slot;
	else
		UseInventoryItem(bag); -- unequip from body
		return bag;
	end
end

local function CastSwapByName(targetSpellName, targetSpellRank, itemName)
    local spellId = getSpellId(targetSpellName, targetSpellRank)
    if spellId then
        local spellReady = SpellReady(spellId)
        if spellReady then
            UseItemByName(itemName)
            CastSpell(spellId, "spell")
        end
    end
end

-- Bloodlust utility
local function SetScale(frame, scale)
	local prevScale = frame:GetScale()
	local point, _, _, xOfs, yOfs = frame:GetPoint()
	frame:SetScale(scale)
	frame:ClearAllPoints()
	frame:SetPoint(point, xOfs / (scale / prevScale), yOfs / (scale / prevScale))
end

local function Round(value, precision)
	return tonumber(string.format("%."..precision.."f", value))
end

local function GetBLSpell()
	local spell = 1
	while true do
		local spellName = GetSpellName(spell, BOOKTYPE_SPELL)
		if (not spellName) then return end
		if (spellName == "Bloodlust") then
			break
		end
		spell = spell + 1
	end
	return spell
end

function string.empty(str)
	if (str == nil) then return true end
	if (str == "") then return true end
	local i = 1
	while i <= strlen(str) do
		local char = strsub(str, i, i)
		if (char ~= " ") then
			return false
		end
		i = i + 1
	end
	return true
end

local function NotEnoughMana()
	local mana = UnitMana("player")
	local required = 395
	return (mana < required)
end

----- COMMANDS -----

local function CommandUnlockWF(msg, msglower)
	if (msglower == "unlock wf" or msglower == "unlockwf") then
		Enhancer:EnableMouse(true)
		Enhancer:Show()
		Print("Windfury frame unlocked.")
		return true
	end
	return false
end

local function CommandLockWF(msg, msglower)
	if (msglower == "lock wf" or msglower == "lockwf") then
		Enhancer:EnableMouse(false)
		return true
	end
	return false
end

local function CommandEnhancerTwist(msg, msglower)
	if (msglower == "enh1" or msglower == "twist") then
		EnhancerTwist()
		return true
	end
	return false
end

local function CommandEnhancerTwistR1(msg, msglower)
	if (msglower == "enh1r1" or msglower == "twistr1") then
		EnhancerTwistR1()
		return true
	end
	return false
end

local function CommandEnhancerBasic(msg, msglower)
	if (msglower == "enh2" or msglower == "basic") then
		EnhancerBasic()
		return true
	end
	return false
end

local function CommandEnhancerBasicGoA(msg, msglower)
	if (msglower == "enh2GoA" or msglower == "basicGoA") then
		EnhancerBasicGoA()
		return true
	end
	return false
end

-- Totemic Recall function
local function CommandResetWindfury(msg, msglower)
    if (msglower == "recall" or msglower == "totemic recall") then
        local recallCooldown = GetCooldown(getSpellId("Totemic Recall", ""))
        if recallCooldown == 0 then
            CastSpellByName("Totemic Recall")
            hasCastWindfury = false
        else
        end
        return true
    end
    return false
end

local function CommandBL(msg, msglower)
	if (msglower == "bl" or msglower == "bloodlust") then
		EnhancerBloodlust()
		return true
	end
	return false
end

local function CommandShow(msg, msglower)
	if (msglower == "show") then
		Enhancer_BLIcon:Show()
		Enhancer_BLIcon:EnableMouse(true)
		return true
	end
	return false
end

local function CommandHide(msg, msglower)
	if (msglower == "hide") then
		Enhancer_BLIcon:Hide()
		Enhancer_BLIcon:EnableMouse(false)
		return true
	end
	return false
end

local function CommandScale(msg, msglower)
	if (strsub(msglower, 1, 5) == "scale") then
		local value = string.sub(msg, 7)
		local scale = tonumber(value)
		if (not scale) then
			Error("Invalid value ("..value..").")
			return true
		end 
		SetScale(Enhancer_BLIcon, scale)
		Enhancer_Config.Scale = scale
		Print("Bloodlust icon's scale set to \""..START_COLOR.."00AA00"..scale..END_COLOR.."\"")
		return true
	end
	return false
end

local function CommandAlpha(msg, msglower)
	if (strsub(msglower, 1, 5) == "alpha") then
		local value = string.sub(msg, 7)
		local alpha = tonumber(value)
		if (not alpha) then
			Error("Invalid value ("..value..").")
			return true
		end
		Enhancer_BLIcon:SetAlpha(alpha)
		Enhancer_Config.Alpha = alpha
		Print("Bloodlust icon's alpha channel set to \""..START_COLOR.."00AA00"..alpha..END_COLOR.."\"")
		return true
	end
	return false
end

local function CommandPW(msg, msglower)
	local password = nil
	if (strsub(msglower, 1, 14) == "trigger message") then
		password = strsub(msg, 16)
	elseif (strsub(msglower, 1, 10) == "trigger msg") then
		password = strsub(msg, 12)
	elseif (strsub(msglower, 1, 8) == "password") then
		password = strsub(msg, 10)
	elseif (strsub(msglower, 1, 2) == "pw" or strsub(msglower, 1, 2) == "tm") then
		password = strsub(msg, 4)
	end
	if (not password) then return false end
	if (string.empty(password)) then
		Error("Invalid value ("..password..").")
		return true
	end
	Enhancer_Config.Password = password
	Print("Bloodlust trigger message set to \""..START_COLOR.."00AA00"..password..END_COLOR.."\"")
	return true
end

local function CommandRes(msg, msglower)
	local response = nil
	if (strsub(msglower, 1, 8) == "response") then
		response = strsub(msg, 10)
	elseif (strsub(msglower, 1, 3) == "res") then
		response = strsub(msg, 5)
	end
	if (not response) then return false end
	if (string.empty(response)) then
		Error("Invalid value ("..response..").")
		return true
	end
	Enhancer_Config.Response = response
	Print("Message sent while casting Bloodlust set to \""..START_COLOR.."00AA00"..response..END_COLOR.."\"")
	return true
end

local function CommandPrintPW(msg, msglower)
	if (msglower == "printpw" or
		msglower == "print pw" or
		msglower == "printpassword" or
		msglower == "print password" or
		msglower == "printtm" or
		msglower == "print tm" or
		msglower == "printtriggermsg" or
		msglower == "print trigger msg" or
		msglower == "print triggermsg" or
		msglower == "printtriggermessage" or
		msglower == "print trigger message" or
		msglower == "print triggermessage") then
		Print("Current Bloodlust trigger message: \""..START_COLOR.."00AA00"..Enhancer_Config.Password..END_COLOR.."\"")
		return true
	end
	return false
end

local function CommandPrintRes(msg, msglower)
	if (msglower == "printres" or
		msglower == "print res" or
		msglower == "printresponse" or
		msglower == "print response") then
		Print("Current message sent while casting Bloodlust: \""..START_COLOR.."00AA00"..Enhancer_Config.Response..END_COLOR.."\"")
		return true
	end
	return false
end

local function CommandHelp(msg, msglower, force)
	if (msglower == "help" or force) then
		local COLOR = "0000FF"
		Print("-------------- Commands --------------")
		Print(START_COLOR..COLOR.."/enhancer recall"..END_COLOR.." - use this macro instead of Totemic Recall spell.")
		Print(START_COLOR..COLOR.."/enhancer twist"..END_COLOR.." - macro to cast Twist rotation.")
		Print(START_COLOR..COLOR.."/enhancer twistr1"..END_COLOR.." - macro to cast Twist rotation with rank 1 windfury totem.")
		Print(START_COLOR..COLOR.."/enhancer basic"..END_COLOR.." - macro to cast Basic rotation.")
		Print(START_COLOR..COLOR.."/enhancer bl"..END_COLOR.." - macro to cast Bloodlust.")
		Print("-------------- Settings --------------")
		Print(START_COLOR..COLOR.."/enhancer show"..END_COLOR.." - sets status of Bloodlust icon to visible and allows mouse dragging.")
		Print(START_COLOR..COLOR.."/enhancer hide"..END_COLOR.." - hides Bloodlust icon.")
		Print(START_COLOR..COLOR.."/enhancer scale \"number\""..END_COLOR.." - set Bloodlust icon's scale to given number.")
		Print(START_COLOR..COLOR.."/enhancer alpha \"number\""..END_COLOR.." - sets Bloodlust icon's alpha channel to given number.")
		Print(START_COLOR..COLOR.."/enhancer pw \"text\""..END_COLOR.." - sets text of Bloodlust trigger message.")
		Print(START_COLOR..COLOR.."/enhancer res \"text\""..END_COLOR.." - sets text of message sent while casting Bloodlust.")
		Print(START_COLOR..COLOR.."/enhancer print pw"..END_COLOR.." - prints in chat current Bloodlust trigger message.")
		Print(START_COLOR..COLOR.."/enhancer print res"..END_COLOR.." - prints in chat message sent while casting Bloodlust.")
		return true
	end
	return false
end

-- Twist rotation
function EnhancerTwist()

	if isShaman then
		if LazyPig_IsMounted and LazyPig_Dismount and LazyPig_IsMounted() then
			LazyPig_Dismount()
		elseif not isCasting then
				
			-- Check the cooldown of Stormstrike rank 1 (id 131)
			local ssRank1Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 1"))

			-- Check the cooldown of Stormstrike rank 2 (id 132)
			local ssRank2Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 2"))
			
			-- Check the cooldown of Earth Shock rank 1
			local shockCooldown = GetCooldown(getSpellId("Earth Shock", "Rank 1"))

			-- Check the cooldown of Water Totems
			local waterTotemCooldown = GetCooldown(getSpellId("Windfury Totem", "Rank 1"))			
			
			local wfTime = 10 - (GetTime() - timeWFdropped)		

			local hasAgilityTotem = false
			local hasStrengthTotem = false
			local hasWaterShield = false
			local hasWaterTotem = false
			local hasNatureResistTotem = false
			local hasThunderRelic = false
			local hasStonebreakerRelic = false
			local hasCrusaderBuff = false
			
			for i = 0, 31 do

				local buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL")
				if buffIndex > -1 then

					local buffTexture = GetPlayerBuffTexture(buffIndex)

					if buffTexture == waterShieldTextureName then
						hasWaterShield = true
					end

					if buffTexture == airTotemTextureName then
						hasAgilityTotem = true
					end

					if buffTexture == fireTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == manaTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == healTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == earthTotemTextureName then
						hasStrengthTotem = true
					end

					if buffTexture == natureTotemTextureName then
						hasNatureResistTotem = true
					end

					if buffTexture == ThunderRelicTextureName then
						hasThunderRelic = true
					end

					if buffTexture == StonebreakerRelicTextureName then
						hasStonebreakerRelic = true	
					end
					
					if buffTexture == CrusaderBuffTextureName then
						hasCrusaderBuff = true	
					end
				end

			end

			local playerMana = UnitMana("player")
			local hasTotemicFocus = GetTalentInfo(3, 5)
			local hasConvection = GetTalentInfo(1, 1)
			
			
			 if not hasWaterShield and playerMana >= 15 then
                CastSpellByName("Water Shield")

			elseif not hasStrengthTotem and ((hasTotemicFocus and playerMana >= 206) or (not hasTotemicFocus and playerMana >= 275)) then
				CastSpellByName("Strength of Earth Totem")	
				hasCastWindfury = false  -- Reset the flag

			elseif not hasNatureResistTotem and not hasCastWindfury and wfTime < windfuryTimeTreshhold and waterTotemCooldown == 0 and ((hasTotemicFocus and playerMana >= 187) or (not hasTotemicFocus and playerMana >= 250)) then	
				CastSpellByName("Windfury Totem")
				timeWFdropped = GetTime()
				hasCastWindfury = true
				
			elseif not hasNatureResistTotem and not hasAgilityTotem and waterTotemCooldown == 0 and ((hasTotemicFocus and playerMana >= 232) or (not hasTotemicFocus and playerMana >= 310)) then	
				CastSpellByName("Grace of Air Totem")
				hasCastWindfury = false
				
			elseif not hasThunderRelic and (hasNatureResistTotem or hasAgilityTotem) and ssRank2Cooldown == 0 and playerMana >= 182 then
				CastSwapByName("Stormstrike", "Rank 2", "Totem of Crackling Thunder")

			elseif not hasThunderRelic and (hasNatureResistTotem or hasAgilityTotem) and ssRank1Cooldown == 0 and playerMana >= 319 then
				CastSwapByName("Stormstrike", "Rank 1", "Totem of Crackling Thunder")	
				
			elseif shockCooldown == 0 and ((hasConvection and playerMana >= 27) or (not hasTotemicFocus and playerMana >= 30)) then
				local totemStonebreakerPresent = FindItem("Totem of the Stonebreaker")
				
				if totemStonebreakerPresent then
					CastSwapByName("Earth Shock", "Rank 1", "Totem of the Stonebreaker")
				end
			end
		end	
	end
end

-- Twist WF rank 1 rotation
function EnhancerTwistR1()

	if isShaman then
		if LazyPig_IsMounted and LazyPig_Dismount and LazyPig_IsMounted() then
			LazyPig_Dismount()
		elseif not isCasting then
				
			-- Check the cooldown of Stormstrike rank 1 (id 131)
			local ssRank1Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 1"))

			-- Check the cooldown of Stormstrike rank 2 (id 132)
			local ssRank2Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 2"))
			
			-- Check the cooldown of Earth Shock rank 1
			local shockCooldown = GetCooldown(getSpellId("Earth Shock", "Rank 1"))

			-- Check the cooldown of Water Totems
			local waterTotemCooldown = GetCooldown(getSpellId("Windfury Totem", "Rank 1"))			
			
			local wfTime = 10 - (GetTime() - timeWFdropped)		

			local hasAgilityTotem = false
			local hasStrengthTotem = false
			local hasWaterShield = false
			local hasWaterTotem = false
			local hasNatureResistTotem = false
			local hasThunderRelic = false
			local hasStonebreakerRelic = false
			local hasCrusaderBuff = false
			
			for i = 0, 31 do

				local buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL")
				if buffIndex > -1 then

					local buffTexture = GetPlayerBuffTexture(buffIndex)

					if buffTexture == waterShieldTextureName then
						hasWaterShield = true
					end

					if buffTexture == airTotemTextureName then
						hasAgilityTotem = true
					end

					if buffTexture == fireTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == manaTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == healTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == earthTotemTextureName then
						hasStrengthTotem = true
					end

					if buffTexture == natureTotemTextureName then
						hasNatureResistTotem = true
					end

					if buffTexture == ThunderRelicTextureName then
						hasThunderRelic = true
					end

					if buffTexture == StonebreakerRelicTextureName then
						hasStonebreakerRelic = true	
					end
					
					if buffTexture == CrusaderBuffTextureName then
						hasCrusaderBuff = true	
					end
				end

			end

			local playerMana = UnitMana("player")
			local hasTotemicFocus = GetTalentInfo(3, 5)
			local hasConvection = GetTalentInfo(1, 1)
			
			
			 if not hasWaterShield and playerMana >= 15 then
                CastSpellByName("Water Shield")

			elseif not hasStrengthTotem and ((hasTotemicFocus and playerMana >= 206) or (not hasTotemicFocus and playerMana >= 275)) then
				CastSpellByName("Strength of Earth Totem")	
				hasCastWindfury = false  -- Reset the flag

			elseif not hasNatureResistTotem and not hasCastWindfury and wfTime < windfuryTimeTreshhold and waterTotemCooldown == 0 and ((hasTotemicFocus and playerMana >= 86) or (not hasTotemicFocus and playerMana >= 115)) then	
				CastSpellByName("Windfury Totem(Rank 1")
				timeWFdropped = GetTime()
				hasCastWindfury = true
				
			elseif not hasNatureResistTotem and not hasAgilityTotem and waterTotemCooldown == 0 and ((hasTotemicFocus and playerMana >= 232) or (not hasTotemicFocus and playerMana >= 310)) then	
				CastSpellByName("Grace of Air Totem")
				hasCastWindfury = false
				
			elseif not hasThunderRelic and (hasNatureResistTotem or hasAgilityTotem) and ssRank2Cooldown == 0 and playerMana >= 182 then
				CastSwapByName("Stormstrike", "Rank 2", "Totem of Crackling Thunder")

			elseif not hasThunderRelic and (hasNatureResistTotem or hasAgilityTotem) and ssRank1Cooldown == 0 and playerMana >= 319 then
				CastSwapByName("Stormstrike", "Rank 1", "Totem of Crackling Thunder")	
				
			elseif shockCooldown == 0 and ((hasConvection and playerMana >= 27) or (not hasTotemicFocus and playerMana >= 30)) then
				local totemStonebreakerPresent = FindItem("Totem of the Stonebreaker")
				
				if totemStonebreakerPresent then
					CastSwapByName("Earth Shock", "Rank 1", "Totem of the Stonebreaker")
				end
			end
		end	
	end
end

-- Basic rotation
function EnhancerBasic()

	if isShaman then

		if LazyPig_IsMounted and LazyPig_Dismount and LazyPig_IsMounted() then
			LazyPig_Dismount()
		elseif not isCasting then
		
			-- Check the cooldown of Stormstrike rank 1 (id 131)
			local ssRank1Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 1"))

			-- Check the cooldown of Stormstrike rank 2 (id 132)
			local ssRank2Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 2"))
			
			-- Check the cooldown of Earth Shock rank 1
			local shockCooldown = GetCooldown(getSpellId("Earth Shock", "Rank 1"))

			-- Check the cooldown of Water Totems
			local waterTotemCooldown = GetCooldown(getSpellId("Windfury Totem", "Rank 1"))	
			
			local wfTime = 10 - (GetTime() - timeWFdropped)					
					

			local hasAgilityTotem = false
			local hasStrengthTotem = false
			local hasWaterShield = false
			local hasWaterTotem = false
			local hasNatureResistTotem = false
			local hasThunderRelic = false
			local hasStonebreakerRelic = false
			local hasCrusaderBuff = false
			
			for i = 0, 31 do

				local buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL")
				if buffIndex > -1 then

					local buffTexture = GetPlayerBuffTexture(buffIndex)

					if buffTexture == waterShieldTextureName then
						hasWaterShield = true
					end

					if buffTexture == airTotemTextureName then
						hasAgilityTotem = true
					end

					if buffTexture == fireTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == manaTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == healTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == earthTotemTextureName then
						hasStrengthTotem = true
					end

					if buffTexture == natureTotemTextureName then
						hasNatureResistTotem = true
					end

					if buffTexture == ThunderRelicTextureName then
						hasThunderRelic = true
					end

					if buffTexture == StonebreakerRelicTextureName then
						hasStonebreakerRelic = true	
					end
					
					if buffTexture == CrusaderBuffTextureName then
						hasCrusaderBuff = true	
					end
				end

			end
			
			local playerMana = UnitMana("player")
			local hasTotemicFocus = GetTalentInfo(3, 5)
			local hasConvection = GetTalentInfo(1, 1)

			if not hasWaterShield and playerMana >= 15 then
				CastSpellByName("Water Shield")

			elseif not hasStrengthTotem and ((hasTotemicFocus and playerMana >= 206) or (not hasTotemicFocus and playerMana >= 275)) then
				CastSpellByName("Strength of Earth Totem")	
				hasCastWindfury = false  -- Reset the flag
								
			elseif not hasNatureResistTotem and not hasCastWindfury and wfTime < windfuryTimeTreshhold and waterTotemCooldown == 0 and ((hasTotemicFocus and playerMana >= 187) or (not hasTotemicFocus and playerMana >= 250)) then
				CastSpellByName("Windfury Totem")
				timeWFdropped = GetTime()
				hasCastWindfury = true  -- Set the flag to true after casting "Windfury Totem"
				
			elseif not hasThunderRelic and ssRank2Cooldown == 0 and playerMana >= 182 then
				CastSwapByName("Stormstrike", "Rank 2", "Totem of Crackling Thunder")

			elseif not hasThunderRelic and ssRank1Cooldown == 0 and playerMana >= 319 then
				CastSwapByName("Stormstrike", "Rank 1", "Totem of Crackling Thunder")
				  
			elseif shockCooldown == 0 and ((hasConvection and playerMana >= 27) or (not hasTotemicFocus and playerMana >= 30)) then
				local totemStonebreakerPresent = FindItem("Totem of the Stonebreaker")
				
				if totemStonebreakerPresent then
					CastSwapByName("Earth Shock", "Rank 1", "Totem of the Stonebreaker")
				end
			end
		end

	end

end

-- Basic rotation
function EnhancerBasicGoA()

	if isShaman then

		if LazyPig_IsMounted and LazyPig_Dismount and LazyPig_IsMounted() then
			LazyPig_Dismount()
		elseif not isCasting then
		
			-- Check the cooldown of Stormstrike rank 1 (id 131)
			local ssRank1Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 1"))

			-- Check the cooldown of Stormstrike rank 2 (id 132)
			local ssRank2Cooldown = GetCooldown(getSpellId("Stormstrike", "Rank 2"))
			
			-- Check the cooldown of Earth Shock rank 1
			local shockCooldown = GetCooldown(getSpellId("Earth Shock", "Rank 1"))

			-- Check the cooldown of Water Totems
			local waterTotemCooldown = GetCooldown(getSpellId("Windfury Totem", "Rank 1"))	
			
			local wfTime = 10 - (GetTime() - timeWFdropped)					
					

			local hasAgilityTotem = false
			local hasStrengthTotem = false
			local hasWaterShield = false
			local hasWaterTotem = false
			local hasNatureResistTotem = false
			local hasThunderRelic = false
			local hasStonebreakerRelic = false
			local hasCrusaderBuff = false
			
			for i = 0, 31 do

				local buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL")
				if buffIndex > -1 then

					local buffTexture = GetPlayerBuffTexture(buffIndex)

					if buffTexture == waterShieldTextureName then
						hasWaterShield = true
					end

					if buffTexture == airTotemTextureName then
						hasAgilityTotem = true
					end

					if buffTexture == fireTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == manaTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == healTotemTextureName then
						hasWaterTotem = true
					end

					if buffTexture == earthTotemTextureName then
						hasStrengthTotem = true
					end

					if buffTexture == natureTotemTextureName then
						hasNatureResistTotem = true
					end

					if buffTexture == ThunderRelicTextureName then
						hasThunderRelic = true
					end

					if buffTexture == StonebreakerRelicTextureName then
						hasStonebreakerRelic = true	
					end
					
					if buffTexture == CrusaderBuffTextureName then
						hasCrusaderBuff = true	
					end
				end

			end
			
			local playerMana = UnitMana("player")
			local hasTotemicFocus = GetTalentInfo(3, 5)
			local hasConvection = GetTalentInfo(1, 1)

			if not hasWaterShield and playerMana >= 15 then
				CastSpellByName("Water Shield")

			elseif not hasStrengthTotem and ((hasTotemicFocus and playerMana >= 206) or (not hasTotemicFocus and playerMana >= 275)) then
				CastSpellByName("Strength of Earth Totem")	
				hasCastWindfury = false  -- Reset the flag
				
			elseif not hasNatureResistTotem and not hasAgilityTotem and waterTotemCooldown == 0 and ((hasTotemicFocus and playerMana >= 232) or (not hasTotemicFocus and playerMana >= 310)) then	
				CastSpellByName("Grace of Air Totem")
				hasCastWindfury = false
				
			elseif not hasThunderRelic and ssRank2Cooldown == 0 and playerMana >= 182 then
				CastSwapByName("Stormstrike", "Rank 2", "Totem of Crackling Thunder")

			elseif not hasThunderRelic and ssRank1Cooldown == 0 and playerMana >= 319 then
				CastSwapByName("Stormstrike", "Rank 1", "Totem of Crackling Thunder")
				  
			elseif shockCooldown == 0 and ((hasConvection and playerMana >= 27) or (not hasTotemicFocus and playerMana >= 30)) then
				local totemStonebreakerPresent = FindItem("Totem of the Stonebreaker")
				
				if totemStonebreakerPresent then
					CastSwapByName("Earth Shock", "Rank 1", "Totem of the Stonebreaker")
				end
			end
		end

	end

end

local overlay = {}
overlay.index = 1
overlay.lastUpdated = 0
	  
SLASH_ENHANCER1 = "/Enhancer"
SlashCmdList["ENHANCER"] = function(msg)
    local msglower = strlower(msg)
    if CommandEnhancerTwist(msg, msglower) then return end
	if CommandEnhancerTwistR1(msg, msglower) then return end
    if CommandEnhancerBasic(msg, msglower) then return end
	if CommandEnhancerBasicGoA(msg, msglower) then return end
	if CommandResetWindfury(msg, msglower) then return end
	if (CommandBL(msg, msglower)) then return end
	if (CommandShow(msg, msglower)) then return end
	if (CommandHide(msg, msglower)) then return end
	if (CommandScale(msg, msglower)) then return end
	if (CommandAlpha(msg, msglower)) then return end
	if (CommandPW(msg, msglower)) then return end
	if (CommandRes(msg, msglower)) then return end
	if (CommandPrintPW(msg, msglower)) then return end
	if (CommandPrintRes(msg, msglower)) then return end
	if (CommandHelp(msg, msglower, true)) then return end
end

local function OnEvent()
	if (event == "VARIABLES_LOADED") then
		if (not Enhancer_Config.Scale) then
			Enhancer_Config.Scale = DEFAULT_SCALE
		end
		if (not Enhancer_Config.Alpha) then
			Enhancer_Config.Alpha = DEFAULT_ALPHA
		end
		if (not Enhancer_Config.Password) then
			Enhancer_Config.Password = DEFAULT_PASSWORD
		end
		if (not Enhancer_Config.Response) then
			Enhancer_Config.Response = DEFAULT_RESPONSE
		end
		SetScale(Enhancer_BLIcon, Enhancer_Config.Scale)
		Enhancer_BLIcon:SetAlpha(Enhancer_Config.Alpha)
	elseif (event == "CHAT_MSG_WHISPER") then
		if (arg1 == Enhancer_Config.Password) then
			local _,_,_,_,rank = GetTalentInfo(2, 16)
			if (rank <= 0) then
				SendWhisper("I don't have this talent.", arg2)
				return
			end
			local CD, CDvalue = GetSpellCooldown(GetBLSpell(), BOOKTYPE_SPELL)
			if (CD and CD ~= 0) then
				local remainingCD = CDvalue - (GetTime() - CD)
				SendWhisper("BL ready in "..Round(remainingCD, 0).." sec.", arg2)
			elseif (GetNumRaidMembers() > 0) then
				local unit
				for i = 1, GetNumRaidMembers() do
					unit = "raid"..i
					if (arg2 == UnitName(unit)) then
						BLTarget = unit
						BLTargetName = arg2
						Enhancer_BLIcon:Show()
						Enhancer_BLIcon:EnableMouse(false)
						IconLifeSpan = 15
						break
					end
				end
			elseif (GetNumPartyMembers() > 0) then
				for i = 1, GetNumPartyMembers() do
					unit = "party"..i
					if (arg2 == UnitName(unit)) then
						BLTarget = unit
						BLTargetName = arg2
						Enhancer_BLIcon:Show()
						Enhancer_BLIcon:EnableMouse(false)
						IconLifeSpan = 15
						break
					end
				end
			end
		end
	end
end

local function OnUpdate()
	local newTime = GetTime()
	DeltaTime = newTime - OldTime
	OldTime = newTime
	if (IconLifeSpan > 0) then
		IconLifeSpan = IconLifeSpan - DeltaTime
		if (IconLifeSpan <= 0) then
			Enhancer_BLIcon:Hide()
			BLTarget = nil
		end
	end
	local _,_,_,_,rank = GetTalentInfo(2, 16)
	if (rank >= 1) then
		local start, duration = GetSpellCooldown(GetBLSpell(), BOOKTYPE_SPELL)
		local remaining = (start + duration) - GetTime()
		if (start ~= 0 and BLTarget and Enhancer_BLIcon:IsShown()) then
			SendWhisper(Enhancer_Config.Response, BLTargetName)
			SendChatMessage(Enhancer_Config.Response, "RAID")
			Enhancer_BLIcon:Hide()
			BLTarget = nil
		elseif (BLTargetName and (RemainingCDPosted == false) and (remaining <= 30) and (remaining > 25)) then
			SendWhisper("BL ready in 30 sec.", BLTargetName)
			 SendChatMessage("BL ready in 30 sec.", "RAID")
			RemainingCDPosted = true
		elseif ((start == 0) and (BLTargetName) and (not BLTarget)) then
			SendWhisper("BL ready!", BLTargetName)
			SendChatMessage("BL ready!", "RAID")
			BLTargetName = nil
			RemainingCDPosted = false
		end
	end
end

function Enhancer_OnLoad()

	local playerClass = UnitClass("player")

	if playerClass == "Shaman" then

		isShaman = true
		this:RegisterEvent("SPELLCAST_DELAYED")
		this:RegisterEvent("SPELLCAST_FAILED")
		this:RegisterEvent("SPELLCAST_INTERRUPTED")
		this:RegisterEvent("SPELLCAST_STOP")
		this:RegisterEvent("SPELLCAST_START")

		Enhancer.wfTimer = UIParent:CreateFontString("Status", "DIALOG", "GameFontNormal")
		Enhancer.wfTimer:SetPoint("CENTER",UIParent,"CENTER", POSITIONX, POSITIONY + FONTOFFSETY)
		Enhancer.wfTimer:SetNonSpaceWrap(false)
		Enhancer.wfTimer:SetFont("Fonts\\FRIZQT__.TTF", FONT_SIZE, "OUTLINE")
		Enhancer.wfTimer:SetTextColor(1, 1, 1, 1)
		Enhancer.wfTimer:SetText("wfTime")
		Enhancer.wfTimer:Hide()

		Enhancer.wfIcon = UIParent:CreateTexture("Icon", "ARTWORK")
		Enhancer.wfIcon:SetPoint("CENTER",UIParent,"CENTER", POSITIONX, POSITIONY)
		Enhancer.wfIcon:SetTexture(WFTotemTextureName)
		Enhancer.wfIcon:SetWidth(ICONWIDTH)
		Enhancer.wfIcon:SetHeight(ICONHEIGHT) 

        overlay.background = UIParent:CreateTexture(nil, "OVERLAY")
        overlay.background:SetTexture("Interface\\AddOns\\Enhancer\\textures\\IconAlert")
        overlay.background:SetTexCoord(0.0546875, 0.4609375, 0.30078125, 0.50390625)
		overlay.background:SetWidth(ICONWIDTH + 20)
		overlay.background:SetHeight(ICONHEIGHT + 20) 
		overlay.background:SetPoint("CENTER",UIParent,"CENTER", POSITIONX, POSITIONY)

	end

end

local function OnLoad()
	if (UnitClass("player") ~= "Shaman") then return end
	Addon:RegisterEvent("VARIABLES_LOADED")
	Addon:RegisterEvent("CHAT_MSG_WHISPER")
	Addon:SetScript("OnEvent", OnEvent)
	Addon:SetScript("OnUpdate", OnUpdate)
end
OnLoad()


function Enhancer_OnEvent(event)

	if event == "SPELLCAST_DELAYED" or 	
	   event == "SPELLCAST_FAILED" or 	
	   event == "SPELLCAST_INTERRUPTED" or 	
	   event == "SPELLCAST_STOP" then

	    isCasting = false

	elseif event == "SPELLCAST_START" then

		isCasting = true

	end

end

function Enhancer_OnUpdate()

	if isShaman then

		local wfTime = 10 - (GetTime() - timeWFdropped)		

		if wfTime <= 0 then

			Enhancer.wfTimer:Hide()
			Enhancer.wfIcon:SetVertexColor(1, 1, 1, 1)

		else

			Enhancer.wfIcon:SetVertexColor(1, 1, 1, 0.40)
			Enhancer.wfTimer:Show()

			Enhancer.wfTimer:SetText(ToString(math.floor(wfTime)))

			local gb = math.min(1, math.max(0, wfTime / 10))
			Enhancer.wfTimer:SetTextColor(1, gb, gb, 1)

		end

		if wfTime <= windfuryTimeTreshhold then
			overlay.background:Show()
		else
			overlay.background:Hide()
		end

		local alpha = math.sin(10 * GetTime()) * 0.2 + 0.4
		overlay.background:SetVertexColor(1, 1, 1, alpha)
		
		-- Reset wfTimer every 5 seconds after Windfury Totem is placed if hasCastWindfury is true
        if hasCastWindfury and wfTime < 5 then
            timeWFdropped = GetTime()
        end
		
	end

end

----- IN GAME MACRO -----

function EnhancerBloodlust()
	if (not BLTarget) then return
	end
	local spell = GetBLSpell()
	if (not spell) then
		local COLOR = "FF0000"
		Print(START_COLOR..COLOR.."Spell not found."..END_COLOR)
		return
	end
	if (GetSpellCooldown(spell, BOOKTYPE_SPELL) ~= 0) then
		local COLOR = "FFAA00"
		Print(START_COLOR..COLOR.."Cooldown."..END_COLOR)
		return
	end

	if (NotEnoughMana()) then
		local COLOR = "FFAA00"
		Print(START_COLOR..COLOR.."Not enough mana."..END_COLOR)
		return
	end


	local targetingFriend = UnitIsFriend("player", "target")
	if (targetingFriend) then
		ClearTarget()
	end

	local autoSelfCast = GetCVar("autoSelfCast")
	SetCVar("autoSelfCast", 0)
	CastSpell(spell, BOOKTYPE_SPELL)
	if (not SpellCanTargetUnit(BLTarget)) then
		SpellStopTargeting()
		SetCVar("autoSelfCast", autoSelfCast)
		return
	end
	SpellTargetUnit(BLTarget)
	SpellStopTargeting()
	if (targetingFriend) then TargetLastTarget() end
	SetCVar("autoSelfCast", autoSelfCast)
end