-- By Klen_list

local mdl = Model"models/bohemia_arma3/compass.mdl"

local grad = Material"gui/center_gradient"
local compass_star_rotated = CreateMaterial("compass_star_rotated", "vertexlitgeneric", {
    ["$basetexture"] = "models/bohemia_arma3/compass_base_star_ca"
})

surface.CreateFont("Compass3D", {
	font = "Arial",
	extended = false,
	size = 150
})

surface.CreateFont("Compass3DSmall", {
	font = "Arial",
	extended = false,
	size = 35
})

local cvar_digital_enabled = CreateClientConVar("compass_digital_enable", 1)
local compass_digital_color = CreateClientConVar("compass_digital_color", "255 255 255 150")
local cvar_forward_offset = CreateClientConVar("compass_forward_offs", 11)
local cvar_up_offset = CreateClientConVar("compass_up_offs", 4)
local cvar_pitch_offset = CreateClientConVar("compass_angle_offs", -40)

concommand.Add("compass_reset_settings", function()
    compass_digital_enable:SetInt(1)
    compass_digital_color:SetString"255 255 255 150"
    cvar_forward_offset:SetInt(11)
    cvar_up_offset:SetInt(4)
    cvar_pitch_offset:SetInt(-40)
    Msg"Compass settings was reset to default.\n"
end)

local function GetDegMinSecFromGmodDeg(D)
    D = math.abs(D - 360 * math.floor(D / 360))
    local min = (D % 1) * 59
    local sec = (min % 1) * 59
    return math.floor(D), math.floor(min), math.floor(sec)
end

local star_matrix = Matrix()
local vec_origin = Vector(.5, .5)
local rot_angle = Angle()
local deg_delayed = Angle()

local function SetCompassAngle(deg)
    deg_delayed.y = deg
    rot_angle = LerpAngle(.03, rot_angle, deg_delayed)
    star_matrix:Translate(vec_origin)
    star_matrix:SetAngles(rot_angle)
    star_matrix:Translate(-vec_origin)
    compass_star_rotated:SetMatrix("$basetexturetransform", star_matrix)
end

local DISABLED, pos, ang, angle = true, Vector(), Angle(), Angle()
local grad_col = Color(0, 0, 0, 255)
local text_col = Color(255, 255, 255, 150)

cvars.AddChangeCallback("compass_digital_color", function(_, __, new)
    local r, g, b, a = string.match(new, "(%d+)% (%d+)% (%d+)% (%d+)")
    if r and g and b and a then
        text_col = Color(r, g, b, a)
    end
end)

local function RenderDigital()
    ang:RotateAroundAxis(ang:Right(), -65)
    ang:RotateAroundAxis(ang:Up(), 90)

    cam.Start3D2D(pos - ang:Forward() * 2 - ang:Right() * 3.5, ang, .01)
        surface.SetDrawColor(grad_col)
        surface.SetMaterial(grad)
        surface.DrawTexturedRect(0, 0, 400, 150)

        render.PushFilterMag(TEXFILTER.ANISOTROPIC)
        render.PushFilterMin(TEXFILTER.ANISOTROPIC)
            local deg, min, sec = GetDegMinSecFromGmodDeg(angle)

            surface.SetFont"Compass3D"
            local x, y = surface.GetTextSize(deg)

            surface.SetDrawColor(text_col.r, text_col.g, text_col.b, 128)
            surface.DrawOutlinedRect(190 + x * .5, 20, 27, 27, math.floor(math.sin(CurTime() * 6) * 3) + 7)

            draw.DrawText(deg, "Compass3D", 174, 0, text_col, TEXT_ALIGN_CENTER)
            draw.DrawText((deg == 0 or deg == 360) and "N" or
                deg < 90 and "NE" or
                deg == 90 and "E" or 
                deg < 180 and "SE" or -- looks bad, i know
                deg == 180 and "S" or 
                deg < 270 and "SW" or
                deg == 270 and "W" or
            deg < 360 and "NW", "Compass3DSmall", 190 + x * .5, 20 + 27 + 7, text_col) 
            draw.DrawText(string.format("%d'%d''", min, sec), "Compass3DSmall", 190 + x * .5, 20 + 27 + 7 + 37, text_col)
        render.PopFilterMag()
        render.PopFilterMin()
    cam.End3D2D()
end

local function Arma3CompassRender()
    if DISABLED then return end

    if not CompassCEnt then
        CompassCEnt = ClientsideModel(mdl)
        CompassCEnt:Spawn()
    end

    local ply = LocalPlayer()
    ang = ply:EyeAngles()
    pos = ply:EyePos()
    angle = ang.y

    SetCompassAngle(angle)

    pos = pos + ang:Forward() * cvar_forward_offset:GetFloat() - ang:Up() * cvar_up_offset:GetFloat()

    ang:RotateAroundAxis(ang:Up(), 180)
    ang:RotateAroundAxis(ang:Right(), cvar_pitch_offset:GetFloat())

    CompassCEnt:SetRenderOrigin(pos)
    CompassCEnt:SetRenderAngles(ang)

    CompassCEnt:SetNoDraw(true) -- for safe, because other shitty addons can enable draw at any moment
    
    cam.Start3D()
        render.MaterialOverrideByIndex(2, compass_star_rotated)
        CompassCEnt:DrawModel()

        if cvar_digital_enabled:GetBool() then
            ProtectedCall(RenderDigital) -- does not allow skipping render.PopFilter* and cam.End3D2D due to an stack call break
        end
    cam.End3D()
end
hook.Add("HUDPaint", "Arma3CompassRender", Arma3CompassRender)

concommand.Add("+show_compass", function()
    DISABLED = false
end)

concommand.Add("-show_compass", function()
    DISABLED = true
end)