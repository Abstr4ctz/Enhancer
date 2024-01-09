# Enhancer


https://github.com/Abstr4ctz/Enhancer/assets/137886338/04d2e804-6bfb-4d47-b971-6af1d6064e2c



One button enhancement shaman rotation including two modes and Bloodlust on whisper.

Twist mode:  
Create "/enhancer twist" macro and spam to activate.
- Water Shield
- Strength of Earth Totem
- WF/GoA twisting
- Auto-equip Totem of Crackling Thunder and cast Stormstrike(Rank 2) and Stormstrike(Rank 1) when haste buff is not active.  
 (Skip next step if Totem of the Stonebreaker not in bag or equipped)
- Auto-equip Totem of the Stonebreaker and cast Earth Shock(Rank 1).

Twist Windfury Totem rank 1 mode:  
Create "/enhancer twistr1" macro and spam to activate.
- Same as above but WF is rank 1.

Twist Nature Resistance Totem mode:  
Create "/enhancer twistnature" macro and spam to activate.
- Same as above but NRT.  

Basic mode:  
Create "/enhancer basic" macro and spam to activate.
- Water Shield
- Strength of Earth Totem
- Windfury Totem
- Auto-equip Totem of Crackling Thunder and cast Stormstrike(Rank 2) and Stormstrike(Rank 1) when haste buff is not active.  
 (Skip next step if Totem of the Stonebreaker not in bag or equipped)
- Auto-equip Totem of the Stonebreaker and cast Earth Shock(Rank 1).

Basic Grace of Air mode:  
Create "/enhancer basicgoa" macro and spam to activate.  
- Same as above but with Grace of Air.

Totemic Recall:  
Instead of using Totemic Recall from your spell book, use macro "/enhancer recall".  
This will cast Totemic Recall and inform addon that it has to start new rotation.

Bloodlust on whisper:  
Whenever someone from party or raid whispers you the "password" you can use command "/enhancer bl" to automatically give them Bloodlust. Addon will inform your last Bloodlust target and your raid when cooldown on Bloodlust has ended.

Type /enhancer or /enhancer help to see all options and change "password"(default is "BL now!"). 

Important Notice:  
- To adjust position of windfury icon, open Enhancer.lua and modify the numbers on top. Save and reload.
- This addon works by reading your buffs which makes it important that all your own buffs are visible. That's why I recommend using https://github.com/Geigerkind/VCB
- Placing new Strength of Earth Totem with either mode starts new rotation circle (addon assumes you went out of range of your old totems, recalled them or they expired).

To get the most of this addon, use your command macros with added attack command e.g. this macro will attack, use twist rotation and cast bloodlust on whisper:  
/script if (not PlayerFrame.inCombat) then AttackTarget() end  
/enhancer twist  
/enhancer bl
