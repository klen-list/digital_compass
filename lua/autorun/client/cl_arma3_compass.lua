local CreateMaterial = CreateMaterial
local surface_CreateFont = surface.CreateFont
local CreateClientConVar = CreateClientConVar
local concommand_Add = concommand.Add
local math_abs = math.abs
local math_floor = math.floor
local Matrix = Matrix
local Vector = Vector
local Angle = Angle
local LerpAngle = LerpAngle
local string_match = string.match
local Color = Color
local cvars_AddChangeCallback = cvars.AddChangeCallback
local cam_Start3D2D = cam.Start3D2D
local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect
local render_PushFilterMag = render.PushFilterMag
local render_PushFilterMin = render.PushFilterMin
local surface_GetTextSize = surface.GetTextSize
local surface_DrawOutlinedRect = surface.DrawOutlinedRect
local math_sin = math.sin
local CurTime = CurTime
local draw_DrawText = draw.DrawText
local string_format = string.format
local render_PopFilterMag = render.PopFilterMag
local render_PopFilterMin = render.PopFilterMin
local cam_End3D2D = cam.End3D2D
local IsValid = IsValid
local ClientsideModel = ClientsideModel
local GetViewEntity = GetViewEntity
local cam_Start3D = cam.Start3D
local render_MaterialOverrideByIndex = render.MaterialOverrideByIndex
local ProtectedCall = ProtectedCall
local cam_End3D = cam.End3D
local hook_Add = hook.Add

-- By Klen_list

local mdl = Model"models/bohemia_arma3/compass.mdl"

local grad = Material"gui/center_gradient"
local compass_star_rotated = CreateMaterial("compass_star_rotated", "vertexlitgeneric", {
	["$basetexture"] = "models/bohemia_arma3/compass_base_star_ca"
})

surface_CreateFont("Compass3D", {
	font = "Arial",
	extended = false,
	size = 150
})

surface_CreateFont("Compass3DSmall", {
	font = "Arial",
	extended = false,
	size = 35
})

local cvar_digital_enabled = CreateClientConVar("compass_digital_enable", 1)
local cvar_digital_color = CreateClientConVar("compass_digital_color", "255 255 255 150")
local cvar_forward_offset = CreateClientConVar("compass_forward_offs", 11)
local cvar_up_offset = CreateClientConVar("compass_up_offs", 4)
local cvar_pitch_offset = CreateClientConVar("compass_angle_offs", -40)

concommand_Add("compass_reset_settings", function()
	cvar_digital_enabled:SetInt(1)
	cvar_digital_color:SetString"255 255 255 150"
	cvar_forward_offset:SetInt(11)
	cvar_up_offset:SetInt(4)
	cvar_pitch_offset:SetInt(-40)
	Msg"Compass settings was reset to default.\n"
end)

local function GetDegMinSecFromGmodDeg(D)
	D = math_abs(D - 360 * math_floor(D / 360))
	local min = (D % 1) * 59
	local sec = (min % 1) * 59
	return math_floor(D), math_floor(min), math_floor(sec)
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

local function GetColorFromStr(str)
	local r, g, b, a = string_match(str, "(%d+)% (%d+)% (%d+)% *(%d*)")
	if r and g and b then
		return Color(r, g, b, a)
	end
	return Color(255, 255, 255, 150)
end

local DISABLED, pos, ang, angle = true, Vector(), Angle(), Angle()
local grad_col = Color(0, 0, 0, 255)
local text_col = GetColorFromStr(cvar_digital_color:GetString())

cvars_AddChangeCallback("compass_digital_color", function(_, __, new)
	text_col = GetColorFromStr(new)
end, "update_color")

local function RenderDigital()
	ang:RotateAroundAxis(ang:Right(), -65)
	ang:RotateAroundAxis(ang:Up(), 90)

	cam_Start3D2D(pos - ang:Forward() * 2 - ang:Right() * 3.5, ang, .01)
		surface_SetDrawColor(grad_col)
		surface_SetMaterial(grad)
		surface_DrawTexturedRect(0, 0, 400, 150)

		render_PushFilterMag(TEXFILTER.ANISOTROPIC)
		render_PushFilterMin(TEXFILTER.ANISOTROPIC)
			local deg, min, sec = GetDegMinSecFromGmodDeg(angle)

			surface.SetFont"Compass3D"
			local x, y = surface_GetTextSize(deg)

			surface_SetDrawColor(text_col.r, text_col.g, text_col.b, 128)
			surface_DrawOutlinedRect(190 + x * .5, 20, 27, 27, math_floor(math_sin(CurTime() * 6) * 3) + 7)

			draw_DrawText(deg, "Compass3D", 174, 0, text_col, TEXT_ALIGN_CENTER)
			draw_DrawText((deg == 0 or deg == 360) and "N" or
				deg < 90 and "NE" or
				deg == 90 and "E" or 
				deg < 180 and "SE" or -- looks bad, i know
				deg == 180 and "S" or 
				deg < 270 and "SW" or
				deg == 270 and "W" or
			deg < 360 and "NW", "Compass3DSmall", 190 + x * .5, 54, text_col) 
			draw_DrawText(string_format("%d'%d''", min, sec), "Compass3DSmall", 190 + x * .5, 91, text_col)
		render_PopFilterMag()
		render_PopFilterMin()
	cam_End3D2D()
end

local function Arma3CompassRender()
	if DISABLED then return end

	local lply = LocalPlayer()
	if not (IsValid(lply) and lply:Alive()) then return end
	--      ^  o no, player entity is gone! (yes, it's possible)

	if not IsValid(CompassCEnt) then
		CompassCEnt = ClientsideModel(mdl) -- CSEntity [class C_BaseFlex]
		CompassCEnt:Spawn()
	end

	local viewent = GetViewEntity()
	ang = viewent:EyeAngles()
	pos = viewent:EyePos()
	angle = -ang.y

	SetCompassAngle(angle)

	pos = pos + ang:Forward() * cvar_forward_offset:GetFloat() - ang:Up() * cvar_up_offset:GetFloat()

	ang:RotateAroundAxis(ang:Up(), 180)
	ang:RotateAroundAxis(ang:Right(), cvar_pitch_offset:GetFloat())

	CompassCEnt:SetRenderOrigin(pos)
	CompassCEnt:SetRenderAngles(ang)

	CompassCEnt:SetNoDraw(true) -- for safe, because other shitty addons can enable draw at any moment
	
	cam_Start3D()
		render_MaterialOverrideByIndex(2, compass_star_rotated)
		CompassCEnt:DrawModel()

		if cvar_digital_enabled:GetBool() then
			ProtectedCall(RenderDigital) -- does not allow skipping render.PopFilter* and cam.End3D2D due to an stack call break
		end
	cam_End3D()
end
hook_Add("HUDPaint", "Arma3CompassRender", Arma3CompassRender)

concommand_Add("+show_compass", function()
	DISABLED = false
end)

concommand_Add("-show_compass", function()
	DISABLED = true
end)
