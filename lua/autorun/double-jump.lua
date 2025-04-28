local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local AddonName = "Double/Long Jump's"

local default_double_jump_count = CreateConVar( "sv_double_jump_count", "4", bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ), "The default limit of the double jumps.", 0x0, 0x4000 ):GetInt()

cvars.AddChangeCallback( "sv_double_jump_count", function( _, __, new_value )
    default_double_jump_count = tonumber( new_value, 10 ) or 0
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

    setmetatable( next_double_jump_charge, {
        __index = function( _, ply )
            ---@cast ply Player
            return ENTITY_GetNW2Var( ply, "m_iDoubleJumpChargingTime", 0 )
        end
    } )

    --- [SERVER]
    ---
    --- Returns the time of occurrence of a double jump charge.
    ---
    ---@return number
    function PLAYER:GetDoubleJumpChargingTime()
        return next_double_jump_charge[ self ]
    end

    --- [SERVER]
    ---
    --- Sets time of occurrence of a double jump charge.
    ---
    ---@param ply Player
    ---@param count time
    function PLAYER:SetDoubleJumpChargingTime( next_charge_time )
        next_charge_time = math_max( 0, next_charge_time )
        next_double_jump_charge[ self ] = next_charge_time
        ENTITY_SetNW2Var( self, "m_iDoubleJumpChargingTime", next_charge_time )
    end

    ---@class table<Player, number>
    local double_jump_limits = {}

    setmetatable( double_jump_limits, {
        __index = function( _, ply )
            ---@cast ply Player
            return ENTITY_GetNW2Var( ply, "m_iDoubleJumpLimit", default_double_jump_count )
        end
    } )

    --- [SERVER]
    ---
    --- Returns the limit of the double jumps.
    ---
    ---@return number
    function PLAYER:GetDoubleJumpLimit()
        return double_jump_limits[ self ]
    end

    --- [SERVER]
    ---
    --- Sets the limit of the double jumps.
    ---
    ---@param limit number
    function PLAYER:SetDoubleJumpLimit( limit )
        limit = math_max( 0, limit )
        double_jump_limits[ self ] = limit
        ENTITY_SetNW2Var( self, "m_iDoubleJumpLimit", limit )
    end

    ---@class table<Player, integer>
    local double_jump_counts = {}

    setmetatable( double_jump_counts, {
        __index = function( _, ply )
            ---@cast ply Player
            return ENTITY_GetNW2Var( ply, "m_iDoubleJumpCount", 0 )
        end
    } )

    --- [SERVER]
    ---
    --- Returns the count of the double jumps.
    ---
    ---@return number
    function PLAYER:GetDoubleJumpCount()
        return double_jump_counts[ self ]
    end

    --- [SERVER]
    ---
    --- Sets the count of the double jumps.
    ---
    ---@param new_count number
    function PLAYER:SetDoubleJumpCount( new_count )
        local old_count = double_jump_counts[ self ]
        new_count = math_max( 0, new_count )

        double_jump_counts[ self ] = new_count
        ENTITY_SetNW2Var( self, "m_iDoubleJumpCount", new_count )

        if old_count > new_count then
            local curtime = CurTime()
            if next_double_jump_charge[ self ] <= curtime - 0.1 then
                self:SetDoubleJumpChargingTime( curtime + double_jump_charge_speed )
            end
        elseif new_count == double_jump_limits[ self ] then
            self:SetDoubleJumpChargingTime( 0 )
        end
    end

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
        double_jump_powers[ self ] = math_max( 0, power )
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
        long_jump_powers[ self ] = math_max( 0, power )
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
                return -- already in double jump
            end

            local player_jump_count = double_jump_counts[ ply ]
            if player_jump_count == 0 then
                ply:EmitSound( "player/suit_denydevice.wav", 75, math_random( 75, 175 ), 1, 6, 0, 1 )
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
            ply:SetDoubleJumpCount( player_jump_count - 1 )
            ply:EmitSound(
                math_random( 0, 1 ) == 0 and "vehicles/airboat/pontoon_impact_hard1.wav" or "vehicles/airboat/pontoon_impact_hard2.wav",
                75, math_floor( Lerp( player_jump_count / double_jump_limits[ ply ], 75, 125 ) ),
                1, 6, 0, 1
            )
        end )

    end

    hook.Add( "PlayerSpawn", AddonName, function( ply )
        ply:SetDoubleJumpCount( double_jump_limits[ ply ] )
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
            if next_charge ~= 0 and next_charge <= curtime then
                ply:SetDoubleJumpChargingTime( curtime + double_jump_charge_speed )
                local player_jump_count = double_jump_counts[ ply ]
                local player_jump_limit = double_jump_limits[ ply ]
                if player_jump_count < player_jump_limit then
                    ply:EmitSound( "buttons/button24.wav", 75, math_floor( Lerp( player_jump_count / player_jump_limit, 25, 50 ) ), 1, 6, 0, 1 )
                    ply:SetDoubleJumpCount( player_jump_count + 1 )
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
    return ENTITY_GetNW2Var( ply, "m_iDoubleJumpLimit", default_double_jump_count )
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

--- [SHARED]
---
--- Returns the time of occurrence of a double jump charge
---
---@return number
function getDoubleJumpChargingTime( ply )
    return ENTITY_GetNW2Var( ply, "m_iDoubleJumpChargingTime", 0 )
end

PLAYER.GetDoubleJumpChargingTime = getDoubleJumpChargingTime

local double_jump_count = 0
local double_jump_limit = default_double_jump_count

local double_jump_charging_time = 0
local double_jump_start_charging_time = 0

local function initPlayer()
    local_player = LocalPlayer()
    if not ( local_player and local_player:IsValid() ) then return end

    double_jump_count = getDoubleJumpCount( local_player )
    double_jump_limit = getDoubleJumpLimit( local_player )

    double_jump_charging_time = getDoubleJumpChargingTime( local_player )

    local_player:SetNW2VarProxy( "m_iDoubleJumpLimit", function( _, __, ___, value )
        double_jump_limit = value
    end )

    local_player:SetNW2VarProxy( "m_iDoubleJumpCount", function( _, __, ___, value )
        double_jump_count = value
    end )

    local_player:SetNW2VarProxy( "m_iDoubleJumpChargingTime", function( _, __, ___, value )
        double_jump_start_charging_time = CurTime()
        double_jump_charging_time = value
    end )
end

hook.Add( "InitPostEntity", AddonName, initPlayer )
initPlayer()

local screen_width, screen_height = ScrW(), ScrH()
local vmin = math.min( screen_width, screen_height ) * 0.01

hook.Add( "OnScreenSizeChanged", AddonName, function( _, __, w, h )
    screen_width, screen_height = w, h
    vmin = math.min( w, h ) * 0.01
end )

local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local draw_RoundedBox = draw.RoundedBox

local color1 = Color( 0, 0, 0, 100 )

hook.Add( "HUDPaint", AddonName, function()
    if local_player == nil or not local_player:Alive() then return end

    local box_width, box_height = math_floor( vmin * 21.25 ), math_floor( vmin * 3 )
    local x, y = math_floor( vmin * 3.4 ), screen_height - ( box_height + math_floor( vmin * 11.2 ) )

    draw_RoundedBox( 4, x, y, box_width, box_height, color1 )

    local bar_count = double_jump_count
    local bar_limit = math_max( double_jump_limit, bar_count )

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

        if bar_count + 1 < bar_limit then
            local frac = (CurTime() - double_jump_start_charging_time) / (double_jump_charging_time - double_jump_start_charging_time)

            surface_SetDrawColor(
                255,
                Lerp( frac, 0, 255 ),
                Lerp( math.ease.OutBounce( frac ), 0, 50 ),
                Lerp( math.ease.OutBounce( frac ), 100, 150 )
            )

            surface_DrawRect( bar_x + ( bar_count + 1 ) * ( bar_width + spacing ), bar_y, frac * bar_width, bar_height )
        end
    end
end )
