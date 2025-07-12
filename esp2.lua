local lib = {
    settings = {
        boxes = {},
        tracers = {},
        nametag = {},
        health = {},
        skeleton = {}
    },
    global_toggle = true,
    overrides = {},
    flags = {},
    team_check = false,
    drawings = {},
    debug = true
}

local function DEBUG_PRINT(...)
    if lib.flags.debug then
        print("[DEBUG]: ", ...)
    end
end

setmetatable(lib.overrides, {
    __index = function(_, key)
        if lib.overrides[key] then
            DEBUG_PRINT("calling override: " .. tostring(key))
            local ret = lib.overrides[key]
            DEBUG_PRINT("Override ret: " .. tostring(ret))
            return ret
        else
            DEBUG_PRINT("Attempted to access non-existent override: " .. tostring(key))
            return nil
        end
    end,
    __newindex = function(_, key, value)
        DEBUG_PRINT("Setting new override: " .. tostring(key) .. " = " .. tostring(value))
        rawset(lib.overrides, key, value)
    end
})

lib.settings.boxes = {
    enabled = true,
    color = Color3.fromRGB(255, 0, 0),
    use_team_color = true,
    thickness = 2,
    filled = false,
    transparency = 0.5,
    outline = true,
    outline_color = Color3.fromRGB(0, 0, 0),
    outline_thickness = 1
}

lib.settings.tracers = {
    enabled = true,
    color = Color3.fromRGB(255, 0, 0),
    use_team_color = true,
    thickness = 2,
    transparency = 0.5
}

lib.settings.nametag = {
    enabled = true,
    color = Color3.fromRGB(255, 0, 0),
    use_team_color = true,
    font = Drawing.Fonts.Plex,
    size = 12,
    transparency = 0.5
}

lib.settings.health = {
    enabled = true,
    color = Color3.fromRGB(255, 0, 0),
    use_team_color = true,
    thickness = 2,
    transparency = 0.5
}

lib.settings.skeleton = {
    enabled = false,
    color = Color3.fromRGB(255, 255, 255),
    use_team_color = true,
    thickness = 2,
    transparency = 0.5
}

local function isEnabled(setting)
    return lib.settings[setting] and lib.settings[setting].enabled or false
end

local camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

function lib:toViewport(...)
    local pos, visible = camera:WorldToViewportPoint(...)
    return Vector2.new(pos.X, pos.Y), visible, pos.Z        
end

function lib.overrides:isTeammate(player)
    return lib.team_check and player.Team == LocalPlayer.Team
end

function lib.overrides:getCharacter(player)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character
    end
    return nil
end

function lib.overrides:getHealth(player)
    local character = self:getCharacter(player)
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid.Health, humanoid.MaxHealth
        end
    end
    return -1, -1
end

function lib.overrides:isAlive(player)
    local character = self:getCharacter(player)
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.Health > 0
    end
    return false
end

function lib.overrides:getPlayerFromCharacter(character)
    return Players:GetPlayerFromCharacter(character) or nil
end

function lib.overrides:getAllCharacters()
    local characters = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local character = self:getCharacter(player)
        if character then
            local health, maxHealth = self:getHealth(player)
            characters[player] = {
                character = character,
                health = health,
                maxHealth = maxHealth,
                name = player.Name,
                team = player.Team,
                isTeammate = self:isTeammate(player),
                isAlive = self:isAlive(player),
            }
        end
    end
    return characters
end

local paint = DrawingImmediate.GetPaint()
local paintConnected = false

local function getPlayerColor(player, setting)
    if lib.settings[setting].use_team_color and player.Team and player.Team.TeamColor then
        return player.Team.TeamColor.Color
    end
    return lib.settings[setting].color
end

local function getBoundingBox(character)
    local head = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not head or not rootPart then return nil end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    local hipHeight = 3
    if humanoid then
        hipHeight = humanoid.HipHeight + 2
    end
    
    local headTop = head.Position.Y + (head.Size.Y / 2)
    local feetBottom = rootPart.Position.Y - hipHeight
    
    local centerPos = Vector3.new(rootPart.Position.X, (headTop + feetBottom) / 2, rootPart.Position.Z)
    local height = headTop - feetBottom
    
    local camCFrame = camera.CFrame
    local toCam = (camCFrame.Position - centerPos).Unit
    local camRight = camCFrame.RightVector
    local camUp = Vector3.new(0, 1, 0)
    
    local width = 2.5
    local depth = 1.5
    
    local rightOffset = camRight * (width / 2)
    local upOffset = camUp * (height / 2)
    local forwardOffset = toCam * (depth / 2)
    
    local corners3D = {
        centerPos - rightOffset + upOffset - forwardOffset,
        centerPos + rightOffset + upOffset - forwardOffset,
        centerPos + rightOffset - upOffset - forwardOffset,
        centerPos - rightOffset - upOffset - forwardOffset,
        centerPos - rightOffset + upOffset + forwardOffset,
        centerPos + rightOffset + upOffset + forwardOffset,
        centerPos + rightOffset - upOffset + forwardOffset,
        centerPos - rightOffset - upOffset + forwardOffset,
    }
    
    local corners2D = {}
    local visibleCorners = 0
    local minDepth, maxDepth = math.huge, -math.huge
    
    for i, corner in ipairs(corners3D) do
        local screenPos, visible, depth = lib:toViewport(corner)
        corners2D[i] = {pos = screenPos, visible = visible, depth = depth}
        if visible then
            visibleCorners = visibleCorners + 1
            minDepth = math.min(minDepth, depth)
            maxDepth = math.max(maxDepth, depth)
        end
    end
    
    if visibleCorners < 4 then
        local headPos, headVisible = lib:toViewport(Vector3.new(head.Position.X, headTop, head.Position.Z))
        local feetPos, feetVisible = lib:toViewport(Vector3.new(rootPart.Position.X, feetBottom, rootPart.Position.Z))
        
        if not headVisible or not feetVisible then return nil end
        
        local boxHeight = math.abs(headPos.Y - feetPos.Y)
        local boxWidth = boxHeight * 0.6
        
        local centerX = (headPos.X + feetPos.X) / 2
        local topY = math.min(headPos.Y, feetPos.Y)
        
        return {
            type = "2D",
            corners = {
                Vector2.new(centerX - boxWidth/2, topY),
                Vector2.new(centerX + boxWidth/2, topY),
                Vector2.new(centerX + boxWidth/2, topY + boxHeight),
                Vector2.new(centerX - boxWidth/2, topY + boxHeight),
            },
            position = Vector2.new(centerX - boxWidth/2, topY),
            size = Vector2.new(boxWidth, boxHeight)
        }
    end
    
    local frontCorners = {}
    local backCorners = {}
    local allVisibleCorners = {}
    
    for i = 1, 8 do
        if corners2D[i].visible then
            table.insert(allVisibleCorners, {index = i, data = corners2D[i]})
            
            if i <= 4 then
                table.insert(backCorners, corners2D[i])
            else
                table.insert(frontCorners, corners2D[i])
            end
        end
    end
    
    local selectedCorners = {}
    local useQuad = false
    
    if #allVisibleCorners >= 4 then
        if #frontCorners >= 4 and #backCorners >= 4 then
            local frontAvgDepth = 0
            local backAvgDepth = 0
            
            for _, corner in ipairs(frontCorners) do
                frontAvgDepth = frontAvgDepth + corner.depth
            end
            for _, corner in ipairs(backCorners) do
                backAvgDepth = backAvgDepth + corner.depth
            end
            
            frontAvgDepth = frontAvgDepth / #frontCorners
            backAvgDepth = backAvgDepth / #backCorners
            
            if frontAvgDepth < backAvgDepth then
                selectedCorners = {corners2D[5].pos, corners2D[6].pos, corners2D[7].pos, corners2D[8].pos}
            else
                selectedCorners = {corners2D[1].pos, corners2D[2].pos, corners2D[3].pos, corners2D[4].pos}
            end
            useQuad = true
        elseif #frontCorners >= 4 then
            selectedCorners = {corners2D[5].pos, corners2D[6].pos, corners2D[7].pos, corners2D[8].pos}
            useQuad = true
        elseif #backCorners >= 4 then
            selectedCorners = {corners2D[1].pos, corners2D[2].pos, corners2D[3].pos, corners2D[4].pos}
            useQuad = true
        else
            table.sort(allVisibleCorners, function(a, b) return a.data.depth < b.data.depth end)
            for i = 1, math.min(4, #allVisibleCorners) do
                table.insert(selectedCorners, allVisibleCorners[i].data.pos)
            end
            useQuad = true
        end
    else
        for _, corner in ipairs(allVisibleCorners) do
            table.insert(selectedCorners, corner.data.pos)
        end
    end
    
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    
    for _, corner in ipairs(selectedCorners) do
        if corner.X then
            minX = math.min(minX, corner.X)
            maxX = math.max(maxX, corner.X)
            minY = math.min(minY, corner.Y)
            maxY = math.max(maxY, corner.Y)
        end
    end
    
    return {
        type = useQuad and "3D_QUAD" or "3D_LINES",
        corners = selectedCorners,
        corners3D = corners2D,
        position = Vector2.new(minX, minY),
        size = Vector2.new(maxX - minX, maxY - minY)
    }
end

local function drawBox(context, boundingBox, color, transparency, thickness, filled)
    if boundingBox.type == "3D_QUAD" and boundingBox.corners and #boundingBox.corners == 4 then
        local corners = boundingBox.corners
        if filled then
            context.FilledQuad(corners[1], corners[2], corners[3], corners[4], color, 1 - transparency)
        else
            if lib.settings.boxes.outline then
                context.Line(corners[1], corners[2], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                context.Line(corners[2], corners[3], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                context.Line(corners[3], corners[4], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                context.Line(corners[4], corners[1], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
            end
            context.Line(corners[1], corners[2], color, 1 - transparency, thickness)
            context.Line(corners[2], corners[3], color, 1 - transparency, thickness)
            context.Line(corners[3], corners[4], color, 1 - transparency, thickness)
            context.Line(corners[4], corners[1], color, 1 - transparency, thickness)
        end
    elseif boundingBox.type == "3D_LINES" and boundingBox.corners3D then
        local corners3D = boundingBox.corners3D
        
        local edges = {
            {1, 2}, {2, 3}, {3, 4}, {4, 1},
            {5, 6}, {6, 7}, {7, 8}, {8, 5},
            {1, 5}, {2, 6}, {3, 7}, {4, 8}
        }
        
        for _, edge in ipairs(edges) do
            local start = corners3D[edge[1]]
            local finish = corners3D[edge[2]]
            if start.visible and finish.visible then
                if lib.settings.boxes.outline then
                    context.Line(start.pos, finish.pos, lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                end
                context.Line(start.pos, finish.pos, color, 1 - transparency, thickness)
            end
        end
    elseif boundingBox.corners then
        local corners = boundingBox.corners
        if filled then
            context.FilledQuad(corners[1], corners[2], corners[3], corners[4], color, 1 - transparency)
        else
            if lib.settings.boxes.outline then
                context.Line(corners[1], corners[2], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                context.Line(corners[2], corners[3], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                context.Line(corners[3], corners[4], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
                context.Line(corners[4], corners[1], lib.settings.boxes.outline_color, 1, lib.settings.boxes.outline_thickness + 2)
            end
            context.Line(corners[1], corners[2], color, 1 - transparency, thickness)
            context.Line(corners[2], corners[3], color, 1 - transparency, thickness)
            context.Line(corners[3], corners[4], color, 1 - transparency, thickness)
            context.Line(corners[4], corners[1], color, 1 - transparency, thickness)
        end
    else
        if filled then
            context.FilledRectangle(boundingBox.position, boundingBox.size, color, 1 - transparency, 0)
        else
            if lib.settings.boxes.outline then
                context.Rectangle(boundingBox.position, boundingBox.size, lib.settings.boxes.outline_color, 1, 0, lib.settings.boxes.outline_thickness + 2)
            end
            context.Rectangle(boundingBox.position, boundingBox.size, color, 1 - transparency, 0, thickness)
        end
    end
end

local function drawTracer(context, rootPart, color, transparency, thickness)
    local rootPos, visible = lib:toViewport(rootPart.Position)
    if not visible then return end
    
    local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
    context.Line(screenCenter, rootPos, color, 1 - transparency, thickness)
end

local function drawNameTag(context, head, name, color, transparency)
    local headPos, visible = lib:toViewport(head.Position + Vector3.new(0, head.Size.Y/2 + 0.5, 0))
    if not visible then return end
    
    context.OutlinedText(
        headPos,
        lib.settings.nametag.font,
        lib.settings.nametag.size,
        color,
        1 - transparency,
        Color3.new(0, 0, 0),
        0.8,
        name,
        true
    )
end

local function drawHealthBar(context, boundingBox, health, maxHealth, color, transparency, thickness)
    if health <= 0 or maxHealth <= 0 then return end
    
    local healthPercent = health / maxHealth
    local barWidth = 4
    local barHeight = boundingBox.size.Y
    local barPos = Vector2.new(boundingBox.position.X - barWidth - 2, boundingBox.position.Y)
    
    context.FilledRectangle(barPos, Vector2.new(barWidth, barHeight), Color3.new(0, 0, 0), 0.5, 0)
    
    local healthColor = Color3.new(1 - healthPercent, healthPercent, 0)
    local healthBarHeight = barHeight * healthPercent
    local healthBarPos = Vector2.new(barPos.X, barPos.Y + barHeight - healthBarHeight)
    
    context.FilledRectangle(healthBarPos, Vector2.new(barWidth, healthBarHeight), healthColor, 1 - transparency, 0)
    
    context.Rectangle(barPos, Vector2.new(barWidth, barHeight), Color3.new(1, 1, 1), 0.8, 0, 1)
end

local function drawSkeleton(context, character, color, transparency, thickness)
    local function getLimbPositions()
        local positions = {}
        local limbs = {
            head = character:FindFirstChild("Head"),
            torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"),
            leftUpperArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm"),
            rightUpperArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm"),
            leftLowerArm = character:FindFirstChild("LeftLowerArm"),
            rightLowerArm = character:FindFirstChild("RightLowerArm"),
            leftHand = character:FindFirstChild("LeftHand"),
            rightHand = character:FindFirstChild("RightHand"),
            leftUpperLeg = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftUpperLeg"),
            rightUpperLeg = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg"),
            leftLowerLeg = character:FindFirstChild("LeftLowerLeg"),
            rightLowerLeg = character:FindFirstChild("RightLowerLeg"),
            leftFoot = character:FindFirstChild("LeftFoot"),
            rightFoot = character:FindFirstChild("RightFoot"),
            lowerTorso = character:FindFirstChild("LowerTorso")
        }
        
        for name, limb in pairs(limbs) do
            if limb then
                local pos, visible = lib:toViewport(limb.Position)
                if visible then
                    positions[name] = pos
                end
            end
        end
        
        return positions
    end
    
    local positions = getLimbPositions()
    if not positions.torso then return end
    
    local connections = {}
    
    if positions.head then
        table.insert(connections, {positions.head, positions.torso})
    end
    
    if positions.lowerTorso then
        table.insert(connections, {positions.torso, positions.lowerTorso})
    end
    
    if positions.leftUpperArm then
        table.insert(connections, {positions.torso, positions.leftUpperArm})
        if positions.leftLowerArm then
            table.insert(connections, {positions.leftUpperArm, positions.leftLowerArm})
            if positions.leftHand then
                table.insert(connections, {positions.leftLowerArm, positions.leftHand})
            end
        end
    end
    
    if positions.rightUpperArm then
        table.insert(connections, {positions.torso, positions.rightUpperArm})
        if positions.rightLowerArm then
            table.insert(connections, {positions.rightUpperArm, positions.rightLowerArm})
            if positions.rightHand then
                table.insert(connections, {positions.rightLowerArm, positions.rightHand})
            end
        end
    end
    
    local hipConnection = positions.lowerTorso or positions.torso
    
    if positions.leftUpperLeg then
        table.insert(connections, {hipConnection, positions.leftUpperLeg})
        if positions.leftLowerLeg then
            table.insert(connections, {positions.leftUpperLeg, positions.leftLowerLeg})
            if positions.leftFoot then
                table.insert(connections, {positions.leftLowerLeg, positions.leftFoot})
            end
        end
    end
    
    if positions.rightUpperLeg then
        table.insert(connections, {hipConnection, positions.rightUpperLeg})
        if positions.rightLowerLeg then
            table.insert(connections, {positions.rightUpperLeg, positions.rightLowerLeg})
            if positions.rightFoot then
                table.insert(connections, {positions.rightLowerLeg, positions.rightFoot})
            end
        end
    end
    
    for _, connection in ipairs(connections) do
        if connection[1] and connection[2] then
            context.Line(connection[1], connection[2], color, 1 - transparency, thickness)
        end
    end
end

local function draw(context)
    if not lib.global_toggle then return end
    
    local characters = lib.overrides:getAllCharacters()
    for player, data in pairs(characters) do
        if data.isAlive and player ~= LocalPlayer and (not data.isTeammate or not lib.team_check) then
            local character = data.character
            local head = character:FindFirstChild("Head")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if head and rootPart then
                local boundingBox = getBoundingBox(character)
                if boundingBox then
                    if isEnabled("boxes") then
                        local color = getPlayerColor(player, "boxes")
                        drawBox(context, boundingBox, color, lib.settings.boxes.transparency, lib.settings.boxes.thickness, lib.settings.boxes.filled)
                    end
                    
                    if isEnabled("health") and data.health > 0 then
                        local color = getPlayerColor(player, "health")
                        drawHealthBar(context, boundingBox, data.health, data.maxHealth, color, lib.settings.health.transparency, lib.settings.health.thickness)
                    end
                end
                
                if isEnabled("tracers") then
                    local color = getPlayerColor(player, "tracers")
                    drawTracer(context, rootPart, color, lib.settings.tracers.transparency, lib.settings.tracers.thickness)
                end
                
                if isEnabled("nametag") then
                    local color = getPlayerColor(player, "nametag")
                    drawNameTag(context, head, data.name, color, lib.settings.nametag.transparency)
                end
                
                if isEnabled("skeleton") then
                    local color = getPlayerColor(player, "skeleton")
                    drawSkeleton(context, character, color, lib.settings.skeleton.transparency, lib.settings.skeleton.thickness)
                end
            end
        end
    end
end

function lib:enablePaint()
    if not paintConnected then
        paint:Connect(draw)
        paintConnected = true
        return true
    end
    return false
end

function lib:disablePaint()
    if paintConnected then
        paint:Disconnect()
        paintConnected = false
        return true
    end
    return false
end

function lib:toggle()
    self.global_toggle = not self.global_toggle
    return self.global_toggle
end

function lib:toggleFeature(feature)
    if self.settings[feature] then
        self.settings[feature].enabled = not self.settings[feature].enabled
        return self.settings[feature].enabled
    end
    return false
end

function lib:setTeamCheck(enabled)
    self.team_check = enabled
end

function lib:setColor(feature, color)
    if self.settings[feature] then
        self.settings[feature].color = color
    end
end

function lib:setTransparency(feature, transparency)
    if self.settings[feature] then
        self.settings[feature].transparency = math.clamp(transparency, 0, 1)
    end
end

function lib:setThickness(feature, thickness)
    if self.settings[feature] then
        self.settings[feature].thickness = math.max(thickness, 1)
    end
end

function lib:setOutline(feature, enabled)
    if self.settings[feature] and self.settings[feature].outline ~= nil then
        self.settings[feature].outline = enabled
    end
end

function lib:setOutlineColor(feature, color)
    if self.settings[feature] and self.settings[feature].outline_color then
        self.settings[feature].outline_color = color
    end
end

function lib:setOutlineThickness(feature, thickness)
    if self.settings[feature] and self.settings[feature].outline_thickness then
        self.settings[feature].outline_thickness = math.max(thickness, 1)
    end
end

return lib
