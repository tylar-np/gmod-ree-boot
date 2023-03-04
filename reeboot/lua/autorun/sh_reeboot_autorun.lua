local wasReloaded = reeboot ~= nil

reeboot = reeboot or {}

-- REE-BOOT: server dying after 12 mins 50 seconds?
--  Install this badboy, drop an alias into your network.cfg, and all will be well.
--  Works on dedicated servers only.

-- Define this as an alias to "exit" in cfg/network.cfg.
-- i.e.: `alias reboot_server "exit"`
local reeboot_concommand = "reboot_server"
local reeboot_message = "The server is restarting. Give it a few minutes and it'll be right back online."
-- ===> Also put "sv_hibernate_think 1" in your cfg/server.cfg for Reeboot's timers to work with nobody online.

local reeboot_warning = 30 -- Minutes before reboot happens where people will be warned of the reboot.
local reeboot_grace_period = 10 -- Another warning, more urgent than before.
local reeboot_grace_period_urgent = 5 -- A VERY urgent warning of impending reboot.

-- Time at which reboot will happen, in terms of
local reeboot_at_hours = 12
local reeboot_at_minutes = 30

-- Start the default reboot timer when this script is loaded?
local start_at_load = true

-- For chat messages
local color_warn = Color(255, 155, 130)
local color_highlight = Color(255, 255, 0)

-- the reeboot command works like this:
--  help: gets the help page
--  schedule <X>: schedules a reboot in <X> minutes
--  cancel: cancels the reboot 
--  when: displays how much time is left until reboot 
--  announce: tells everyone how much time is left until reboot
-- all subcommands need admin or superadmin EXCEPT `when`



if CLIENT then 
    local tag_color = Color(155, 255, 0)
    net.Receive("reeboot_chat", function(len)
        local bytes = net.ReadUInt(16)
        local ctab = util.JSONToTable(util.Decompress(net.ReadData(bytes)))
        if ctab then
            chat.AddText(unpack({tag_color, "[Reeboot] ", color_white, unpack(ctab)}))
        end
    end)
end

if SERVER then
    util.AddNetworkString("reeboot_chat")
    
    local reboot_internal = function()
        -- kick all players and show our nice message
        for k,v in next, player.GetAll(), nil do
            if IsValid(v) then 
                v:Kick(reeboot_message)
            end 
        end
        -- Issue the restart
        timer.Simple(0, function()
            game.ConsoleCommand(reeboot_concommand .. "\n")
        end)
    end

    -- Stops and removes the timers 
    local cancel_timers = function()
        timer.Stop("reeboot_timer_before_reboot")
        timer.Remove("reeboot_timer_before_reboot")
        timer.Stop("reeboot_timer_farout_warn")
        timer.Remove("reeboot_timer_farout_warn")
        timer.Stop("reeboot_timer_post_warn")
        timer.Remove("reeboot_timer_post_warn")
        timer.Stop("reeboot_timer_post_warn_urgent")
        timer.Remove("reeboot_timer_post_warn_urgent")
    end

    reeboot.tell = function(tbl, to)
        local filter = RecipientFilter()
        if not to then
            filter:AddAllPlayers()
        elseif type(to) == "table" then
            for _, ply in next, to, nil do
                filter:AddPlayer(ply)
            end
        elseif to.Nick then
            filter:AddPlayer(to)
        end

        if filter:GetCount() == 0 then return end

        local payload = util.Compress(util.TableToJSON(type(tbl) == "table" and tbl or {tbl}))

        net.Start("reeboot_chat")
            net.WriteUInt(#payload, 16)
            net.WriteData(payload)
        net.Send(filter)
    end
    
    -- Reboots the server after X seconds of delay.
    reeboot.reboot = function(sec_delay)
        local sec_delay = sec_delay or 0
        if sec_delay == 0 then 
            reboot_internal()
        else
            cancel_timers()
            
            -- Outer timer: actually reboots the server.
            timer.Create("reeboot_timer_before_reboot", sec_delay, 1, function()
                reeboot.tell("The server is rebooting. See you soon!")
                timer.Simple(5, function()
                    reboot_internal()
                end)
            end)
            
            -- First warning: to give people a notice that the server will go down in 30 minutes. Finish up.
            if (sec_delay > (reeboot_warning * 60)) then
                timer.Create("reeboot_timer_farout_warn", sec_delay - (reeboot_warning * 60), 1, function()
                    reeboot.tell({"Reminder: The server will reboot in ", color_highlight, reeboot_warning, color_white, " minutes. Take time ", color_highlight, "now", color_white, " to finish what you're doing."})
                end)
            end
            
            -- First grace period: to give people a grace period to save stuff.
            if (sec_delay > (reeboot_grace_period * 60)) then
                timer.Create("reeboot_timer_post_warn", sec_delay - (reeboot_grace_period * 60), 1, function()
                    reeboot.tell({color_highlight, "Warning!", color_white, " The server will reboot in ", color_highlight, reeboot_grace_period, color_white, " minutes. ", color_highlight, "Save your stuff!"})
                end)
            else
                -- We don't have enough time to cover the first grace period.
                reeboot.tell({color_highlight, "Warning!", color_white, " The server will reboot in ", color_highlight, math.floor(sec_delay / 60), color_white, " minutes. ", color_highlight, "Save your stuff!"})
            end
            
            -- Second grace period: to give people a notice of very shortly rebooting.
            if (sec_delay > (reeboot_grace_period_urgent * 60)) then
                timer.Create("reeboot_timer_post_warn_urgent", sec_delay - (reeboot_grace_period_urgent * 60), 1, function()
                    reeboot.tell({color_highlight, "Urgent warning!", color_white, " The server will reboot in ", color_highlight, reeboot_grace_period_urgent, " minutes. ", color_highlight, "Make sure all your stuff is saved!"})
                end)
            end
            
        end
    end
    
    -- Do up the concommand.
    concommand.Add("reeboot", function(ply, cmd, args, argStr)
        local operation = args[1]

        -- "reeboot when"
        if operation == "when" then
            local txt
            if timer.Exists("reeboot_timer_before_reboot") and (timer.TimeLeft("reeboot_timer_before_reboot") != nil) then
                local tleft = timer.TimeLeft(tname)
                local mleft = math.floor((tleft % 3600) / 60)
                local hleft = math.floor(tleft / 3600)
                txt = {"The server is restarting in ", color_highlight, hleft, color_white, " hours and ", color_highlight, mleft, color_white, " minutes."}
            else
                txt = {"There is no reboot scheduled."}
            end

            if IsValid(ply) then
                reeboot.tell(txt, ply)
            else
                table.insert(txt, "\n")
                MsgC(unpack(txt))
            end
        else
            local player_can_do = not IsValid(ply)
            if not player_can_do then
                player_can_do = ply:IsAdmin() or ply:IsSuperAdmin()
            end
            local nick = (IsValid(ply) and ply:Nick() or "The Server")
            if not player_can_do then
                print("Player " .. ply:SteamID() .. " (" .. ply:Nick() .. ") tried accessing reeboot.")
                reeboot.tell({"You aren't allowed to use Reeboot on this server."}, ply)
            else
                if operation == nil then
                    reeboot.tell({"Please pass an operation. Type ", color_highlight, "reeboot help", color_white, " for help."}, ply)
                elseif operation == "schedule" then
                    local delay = args[2]
                    if delay == nil then
                        reeboot.tell({"A delay (in minutes) is needed when scheduling a reboot. ", color_highlight, "0", color_white, " is the option for an immediate reboot."}, ply)
                    else
                        delay = tonumber(delay)
                        reeboot.reboot(delay * 60)
                        reeboot.tell({color_highlight, nick, color_white, " just scheduled a reboot for ", color_highlight, delay, color_white, " minutes from now."})
                    end
                elseif operation == "cancel" then
                    cancel_timers()
                    reeboot.tell({color_highlight, nick, color_white, " just canceled the scheduled reboot."})
                elseif operation == "announce" then
                    local tname = "reeboot_timer_before_reboot"
                    if timer.Exists(tname) and (timer.TimeLeft(tname) != nil) then
                        local tleft = timer.TimeLeft(tname)
                        local mleft = math.floor((tleft % 3600) / 60)
                        local hleft = math.floor(tleft / 3600)
                        reeboot.tell({"The server is restarting in ", color_highlight, hleft, color_white, " hours and ", color_highlight, mleft, color_white, " minutes."})
                    else
                        reeboot.tell({"There is no reboot scheduled right now."})
                    end
                elseif operation == "help" then
                    reeboot.tell({color_highlight, "[Reeboot] ", color_white, "Commands:"}, ply)
                    reeboot.tell({" `help`: displays this text."}, ply)
                    reeboot.tell({" `schedule <minutes>`: reboots in the specified minutes."}, ply)
                    reeboot.tell({" `when`: displays when the reboot will happen."}, ply)
                    reeboot.tell({" `cancel`: cancels the scheduled reboot."}, ply)
                    reeboot.tell({" `announce`: tells everyone when the reboot is happening."}, ply)
                end
            end
        end
    end)
    
    -- Informational hook for the player.
    -- Just have them run the "reeboot when" command as the code already exists there.
    hook.Add("PlayerInitialSpawn", "reeboot_PlayerInitialSpawn", function(ply)
        timer.Simple(30, function()
            ply:ConCommand("reeboot when")
        end)
    end)
    
    -- schedule the reboot.
    if start_at_load and not wasReloaded then
        print("Scheduling reboot for " .. reeboot_at_hours .. " hours and " .. reeboot_at_minutes .. " minutes from now.")
        reeboot.reboot((reeboot_at_hours * 3600) + (reeboot_at_minutes * 60))
    end
end
