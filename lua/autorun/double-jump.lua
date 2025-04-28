local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local AddonName = "Double Jump by Unknown Developer"

local double_jump_count = CreateConVar( "sv_double_jump_count", "4", { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }, "The default count of the double jumps.", 0x0, 0x4000 ):GetInt()

cvars.AddChangeCallback( "sv_double_jump_count", function( _, __, new_value )
    double_jump_count = tonumber( new_value, 10 ) or 0
end, AddonName )

local double_jump_limit = CreateConVar( "sv_double_jump_limit", "4", { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }, "The default limit of the double jumps.", 0x0, 0x4000 ):GetInt()

cvars.AddChangeCallback( "sv_double_jump_limit", function( _, __, new_value )
    double_jump_limit = tonumber( new_value, 10 ) or 0
end, AddonName )

---@class Entity
local ENTITY = FindMetaTable( "Entity" )

---@class Player
local PLAYER = FindMetaTable( "Player" )

local ENTITY_GetNW2Var = ENTITY.GetNW2Var

if SERVER then

    local ENTITY_SetNW2Var = ENTITY.SetNW2Var
    local math_random = math.random
    local CurTime = CurTime

    local double_jump_charge_speed = CreateConVar( "sv_double_jump_charge_speed", "3", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "The count of seconds to charge one double jump.", 0x0, 0x4000 ):GetFloat()

    cvars.AddChangeCallback( "sv_double_jump_charge_speed", function( _, __, new_value )
        double_jump_charge_speed = tonumber( new_value, 10 ) or 0
    end, AddonName )

    ---@class table<Player, number>
    local next_double_jump_charge = {}

    ---@class table<Player, number>
    local double_jump_limits = {}

    setmetatable( double_jump_limits, {
        __index = function( _, ply )
            ---@cast ply Player
            return ENTITY_GetNW2Var( ply, "m_iDoubleJumpLimit", double_jump_limit )
        end
    } )

    --- [SERVER]
    ---
    --- Returns the limit of the double jumps.
    ---
    ---@param ply Player
    ---@return number
    local function getDoubleJumpLimit( ply )
        return math_max( 0, double_jump_limits[ ply ] )
    end

    PLAYER.GetDoubleJumpLimit = getDoubleJumpLimit

    --- [SERVER]
    ---
    --- Sets the limit of the double jumps.
    ---
    ---@param limit number
    function PLAYER:SetDoubleJumpLimit( limit )
        double_jump_limits[ self ] = limit
        ENTITY_SetNW2Var( self, "m_iDoubleJumpLimit", limit )
    end

    ---@class table<Player, integer>
    local double_jump_counts = {}

    setmetatable( double_jump_counts, {
        __index = function( _, ply )
            ---@cast ply Player
            return ENTITY_GetNW2Var( ply, "m_iDoubleJumpCount", double_jump_count )
        end
    } )

    --- [SERVER]
    ---
    --- Returns the count of the double jumps.
    ---
    ---@param ply Player
    ---@return number
    local function getDoubleJumpCount( ply )
        return math_max( 0, math_min( double_jump_counts[ ply ], getDoubleJumpLimit( ply ) ) )
    end

    PLAYER.GetDoubleJumpCount = getDoubleJumpCount

    --- [SERVER]
    ---
    --- Sets the count of the double jumps.
    ---
    ---@param ply Player
    ---@param count number
    local function setDoubleJumpCount( ply, count )
        local old_count = getDoubleJumpCount( ply )
        double_jump_counts[ ply ] = count
        ENTITY_SetNW2Var( ply, "m_iDoubleJumpCount", count )

        if old_count > count then
            next_double_jump_charge[ ply ] = CurTime() + double_jump_charge_speed
        end
    end

    PLAYER.SetDoubleJumpCount = setDoubleJumpCount

    ---@class table<Player, number>
    local double_jump_powers = {}

    --- [SERVER]
    ---
    --- Returns the power of the double jump.
    ---
    ---@return number
    function PLAYER:GetDoubleJumpPower()
        return double_jump_powers[ self ]
    end

    --- [SERVER]
    ---
    --- Sets the power of the double jump.
    ---
    ---@param power number
    function PLAYER:SetDoubleJumpPower( power )
        double_jump_powers[ self ] = power
    end

    do

        local sv_double_jump_power = CreateConVar( "sv_double_jump_power", "400", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "The power of the double jump.", 0x0, 0x4000 )
        local default_double_jump_power = sv_double_jump_power:GetFloat()

        cvars.AddChangeCallback( "sv_double_jump_power", function( _, __, new_value )
            default_double_jump_power = tonumber( new_value, 10 ) or 0
        end, AddonName )

        setmetatable( double_jump_powers, {
            __index = function()
                return default_double_jump_power
            end
        } )

    end

    ---@class table<Player, number>
    local long_jump_powers = {}

    --- [SERVER]
    ---
    --- Returns the power of the long jump.
    ---
    ---@return number
    function PLAYER:GetLongJumpPower()
        return long_jump_powers[ self ]
    end

    --- [SERVER]
    ---
    --- Sets the power of the long jump.
    ---
    ---@param power number
    function PLAYER:SetLongJumpPower( power )
        long_jump_powers[ self ] = power
    end

    ---@class table<Player, boolean>
    local is_in_double_jump = {}

    --- [SERVER]
    ---
    --- Returns whether the player is in the double jump.
    ---
    ---@return boolean
    function PLAYER:IsInDoubleJump()
        return is_in_double_jump[ self ]
    end

    do

        local sv_long_jump_power = CreateConVar( "sv_long_jump_power", "200", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "The power of the long jump.", 0x0, 0x4000 )
        local default_long_jump_power = sv_long_jump_power:GetFloat()

        cvars.AddChangeCallback( "sv_long_jump_power", function( _, __, new_value )
            default_long_jump_power = tonumber( new_value, 10 )
        end, AddonName )

        setmetatable( long_jump_powers, {
            __index = function()
                return default_long_jump_power
            end
        } )

    end

    ---@class table<Player, number>
    local last_on_ground_times = {}

    do

        local angle_zero, vector_origin = angle_zero, vector_origin
        local LocalToWorld = LocalToWorld
        local bit_band = bit.band

        local double_jump_window_min = CreateConVar( "sv_double_jump_window_min", "0.2", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "The window of the double jump in seconds.", 0x0, 0x4000 ):GetFloat()

        cvars.AddChangeCallback( "sv_double_jump_window_min", function( _, __, new_value )
            double_jump_window_min = tonumber( new_value, 10 ) or 0
        end, AddonName )

        local double_jump_window_max = CreateConVar( "sv_double_jump_window_max", "0.8", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "The window of the double jump in seconds.", 0x0, 0x4000 ):GetFloat()

        cvars.AddChangeCallback( "sv_double_jump_window", function( _, __, new_value )
            double_jump_window_max = tonumber( new_value, 10 ) or 0
        end, AddonName )

        local vec3_temp = Vector( 0, 0, 0 )

        hook.Add( "Move", AddonName, function( ply, mv )
            ---@cast ply Player
            ---@cast mv CMoveData

            if not ply:Alive() or ply:GetMoveType() ~= 2 then
                return
            end

            if ply:IsOnGround() then
                last_on_ground_times[ ply ] = CurTime()

                if is_in_double_jump[ ply ] then
                    is_in_double_jump[ ply ] = false
                end

                return -- on ground
            end

            local buttons = mv:GetButtons()
            if bit_band( mv:GetOldButtons(), 2 ) ~= 0 or bit_band( buttons, 2 ) == 0 then return end -- not jumping

            local time_in_air = CurTime() - ( last_on_ground_times[ ply ] or 0 )
            if time_in_air < double_jump_window_min or time_in_air > double_jump_window_max then
                return -- not in double jump window
            end

            if is_in_double_jump[ ply ] then
                ply:EmitSound( "player/suit_denydevice.wav", 75, math_random( 75, 175 ), 1, 6, 0, 1 )
                next_double_jump_charge[ ply ] = CurTime() + double_jump_charge_speed
                return -- already in double jump
            end

            local player_jump_count = getDoubleJumpCount( ply )
            if player_jump_count == 0 then
                ply:EmitSound( "player/suit_denydevice.wav", 75, math_random( 75, 175 ), 1, 6, 0, 1 )
                next_double_jump_charge[ ply ] = CurTime() + double_jump_charge_speed
                return -- no more double jumps
            end

            is_in_double_jump[ ply ] = true

            local long_jump_power = long_jump_powers[ ply ]
            if long_jump_power == 0 then
                local double_jump_power = double_jump_powers[ ply ]
                if double_jump_power == 0 then
                    return
                end

                local vec3_velocity = mv:GetVelocity()
                vec3_velocity:SetUnpacked( 0, 0, double_jump_power )
                mv:SetVelocity( vec3_velocity )

                return
            end

            if bit_band( buttons, 1560 ) == 0 then
                vec3_temp:SetUnpacked( 1, 0, double_jump_powers[ ply ] )
            else

                local x, y = 0, 0

                if bit_band( buttons, 8 ) ~= 0 then
                    x = x + long_jump_power
                end

                if bit_band( buttons, 16 ) ~= 0 then
                    x = x - long_jump_power
                end

                if bit_band( buttons, 512 ) ~= 0 then
                    y = y + long_jump_power
                end

                if bit_band( buttons, 1024 ) ~= 0 then
                    y = y - long_jump_power
                end

                vec3_temp:SetUnpacked( x, y, double_jump_powers[ ply ] )

            end

            mv:SetVelocity( mv:GetVelocity() + LocalToWorld( vec3_temp, angle_zero, vector_origin, mv:GetMoveAngles() ) )
            ply:EmitSound(
                math_random( 0, 1 ) == 0 and "vehicles/airboat/pontoon_impact_hard1.wav" or "vehicles/airboat/pontoon_impact_hard2.wav",
                75, math_floor( Lerp( player_jump_count / getDoubleJumpLimit( ply ), 75, 175 ) ), 1, 6, 0, 1 )
            setDoubleJumpCount( ply, player_jump_count - 1 )
        end )

    end

    hook.Add( "PlayerSpawn", AddonName, function( ply )
        setDoubleJumpCount( ply, getDoubleJumpLimit( ply ) )
    end )

    hook.Add( "PlayerDisconnected", AddonName, function( ply )
        next_double_jump_charge[ ply ] = nil
        last_on_ground_times[ ply ] = nil
        double_jump_counts[ ply ] = nil
        double_jump_limits[ ply ] = nil
        double_jump_powers[ ply ] = nil
        is_in_double_jump[ ply ] = nil
        long_jump_powers[ ply ] = nil
    end )

    local player_Iterator = player.Iterator
    local Lerp = Lerp

    hook.Add( "Tick", AddonName, function()
        local curtime = CurTime()

        for _, ply in player_Iterator() do
            local next_charge = next_double_jump_charge[ ply ]
            if next_charge == nil or next_charge < curtime then
                next_double_jump_charge[ ply ] = curtime + double_jump_charge_speed

                local player_jump_count = getDoubleJumpCount( ply )
                local player_jump_limit = getDoubleJumpLimit( ply )
                if player_jump_count < player_jump_limit then
                    setDoubleJumpCount( ply, player_jump_count + 1 )
                    ply:EmitSound( "buttons/button24.wav", 75, math_floor( Lerp( player_jump_count / player_jump_limit, 25, 50 ) ), 1, 6, 0, 1 )
                end
            end
        end
    end )

    return
end

--- [SHARED]
---
--- Returns the limit of the double jumps.
---
---@param ply Player
---@return number
local function getDoubleJumpLimit( ply )
    return ENTITY_GetNW2Var( ply, "m_iDoubleJumpLimit", double_jump_limit )
end

PLAYER.GetDoubleJumpLimit = getDoubleJumpLimit

--- [SHARED]
---
--- Returns the count of the double jumps.
---
---@param ply Player
---@return number
local function getDoubleJumpCount( ply )
    return ENTITY_GetNW2Var( ply, "m_iDoubleJumpCount", 0 )
end

PLAYER.GetDoubleJumpCount = getDoubleJumpCount

local screen_width, screen_height = ScrW(), ScrH()
local vmin = math.min( screen_width, screen_height ) * 0.01

hook.Add( "OnScreenSizeChanged", AddonName, function( _, __, w, h )
    screen_width, screen_height = w, h
    vmin = math.min( w, h ) * 0.01
end )

local local_player = LocalPlayer()
if not ( local_player and local_player:IsValid() ) then
    ---@diagnostic disable-next-line: cast-local-type
    local_player = nil
end

hook.Add( "InitPostEntity", AddonName, function()
    local_player = LocalPlayer()
end )

local color1 = Color( 0, 0, 0, 100 )

local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local draw_RoundedBox = draw.RoundedBox

hook.Add( "HUDPaint", AddonName, function()
    if local_player == nil or not local_player:Alive() then return end

    local box_width, box_height = math_floor( vmin * 21.25 ), math_floor( vmin * 3 )
    local x, y = math_floor( vmin * 3.4 ), screen_height - ( box_height + math_floor( vmin * 11.2 ) )

    draw_RoundedBox( 4, x, y, box_width, box_height, color1 )

    local bar_count = getDoubleJumpCount( local_player )
    local bar_limit = math_max( getDoubleJumpLimit( local_player ), bar_count )

    local spacing = math_floor( vmin )

    local bar_width = math_floor( ( box_width - ( spacing * ( 2 + ( bar_limit - 1 ) ) ) ) / bar_limit )
    local bar_height = math_floor( vmin * 1.2 )

    local bar_y = y + ( box_height - bar_height ) * 0.5

    if bar_width < 1 then
        local temp_width = box_width - ( spacing * 2 )
        local bar_x = x + spacing

        surface_SetDrawColor( 100, 100, 100, 100 )
        surface_DrawRect( bar_x, bar_y, temp_width, bar_height )

        surface_SetDrawColor( 255, 255, 50, 20 )
        surface_DrawRect( bar_x, bar_y, temp_width * math_min( 1, math_max( 0, bar_count / bar_limit ) ), bar_height )
    else
        local bar_x = x + ( box_width - ( ( bar_width * bar_limit ) + ( spacing * ( bar_limit - 1 ) ) ) ) * 0.5
        bar_count = bar_count - 1

        for i = 0, bar_limit - 1, 1 do
            if i <= bar_count then
                surface.SetDrawColor( 255, 255, 50, 150 )
            else
                surface.SetDrawColor( 100, 100, 100, 100 )
            end

            surface_DrawRect( bar_x + i * ( bar_width + spacing ), bar_y, bar_width, bar_height )
        end
    end
end )
