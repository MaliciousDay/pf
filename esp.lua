local esp = {
settings = {
	boxes = {
		enabled = true,
		thickness = 2,
		outline = true,
		filled = false -- TODO : Add transparent fill
	},
	tracers = {
		enabled = false,
		thickness = 1,
		outline = true
	},
	nametags = {
		enabled = true,
		showDistance = true,
		showFlag = false
	},
	healthBar = {
		enabled = true,
		color = Color3.fromRGB(0, 255, 0),
		showText = true
	},
	colors = {
		friendly = Color3.fromRGB(0, 255, 0),
		enemy = Color3.fromRGB(255, 0, 0),
		global = Color3.fromRGB(255, 255, 255)
	},
	skeleton = {
		enabled = false,
		color = Color3.fromRGB(255, 255, 255),
		thickness = 2,
		outline = true
	},
	useTeamColors = true,
	teamCheck = true,
	textSize = 13,
	textOutline = true
},
drawings = {},
overrides = {},
queue = {},
rootName = "HumanoidRootPart",
tracerOrigin = Vector3.new(),
enabled = false
}


local players = game:GetService("Players");
local runService = game:GetService("RunService");

local localPlayer = players.LocalPlayer;
local camera = workspace.CurrentCamera;

function esp.draw(object, data)
    local properties = data or {};
    local drawing = Drawing.new(object);

    pcall(function()
        for property, value in pairs(properties) do
            drawing[property] = value;
        end
    end)

    table.insert(esp.drawings, drawing);

    return drawing;
end

function esp:toViewport(...)
    local position, visible = camera.WorldToViewportPoint(camera, ...);

    return Vector2.new(position.X, position.Y), visible, position.Z;
end

function esp:getTeam(player)
    local override = self.overrides.getTeam;
    if override then 
        return override(player); 
    end
    return (player and player:IsA("Player") and player.Team) or nil;
end

function esp:isTeammate(player)
    return esp:getTeam(player) == esp:getTeam(localPlayer);
end

function esp:getCharacter(player)
    local override = self.overrides.getCharacter;
    if override then 
        return override(player);
    end
    return (player and player:IsA("Player") and player.Character) or nil;
end

function esp:getHealth(player)
    local override = self.overrides.getHealth;
    if override then 
        return override(player);
    end
    
    local character = player.Character;
    local humanoid = (character and character:FindFirstChild("Humanoid")) or nil;
    
    return (character and humanoid and humanoid.Health) or 0;
end

function esp:getMaxHealth(player)
    local override = self.overrides.getMaxHealth;
    if override then 
        return override(player);
    end
    
    local character = player.Character;
    local humanoid = (character and character:FindFirstChild("Humanoid")) or nil;
    
    return (character and humanoid and humanoid.MaxHealth) or 100;
end

function esp:isAlive(player)
    local override = self.overrides.isAlive;
    if override then
        return override(player);
    end

    local character = esp:getCharacter(player);
    local rootPart = (character and character:FindFirstChild(esp.rootName)) or nil;

    return ((character and rootPart) and esp:getHealth(player) > 0) or false;
end

function esp:getColor(player)
    local override = self.overrides.getColor;
    if override then 
        return override(player);
    end
    return esp:getTeam(player).TeamColor.Color;
end

function esp:getPlayerFromCharacter(character)
    local override = self.overrides.getPlayerFromCharacter;
    if override then 
        return override(character);
    end

    return players:GetPlayerFromCharacter(character);
end

function esp:penetrationCheck() -- TODO : Wall penetration check

end

function esp:generateSkeletonNodes(model)
    -- Please God forgive me for what I am about to do
    local humanoid = model:FindFirstChild("Humanoid");
    local head = model.Head;

    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        -- Upper Part
        local upperTorso = model.UpperTorso;
        
        -- Right Arm
        local rightUpperArm = model.RightUpperArm;
        local rightLowerArm = model.RightLowerArm;
        local rightHand = model.RightHand;

        -- Left Arm
        local leftUpperArm = model.LeftUpperArm;
        local leftLowerArm = model.LeftLowerArm;
        local leftHand = model.LeftHand;

        -- Lower Part
        local lowerTorso = model.LowerTorso;

        -- Right Leg
        local rightUpperLeg = model.RightUpperLeg;
        local rightLowerLeg = model.RightLowerLeg;
        local rightFoot = model.RightFoot;

        -- Left Leg
        local leftUpperLeg = model.LeftUpperLeg;
        local leftLowerLeg = model.LeftLowerLeg;
        local leftFoot = model.LeftFoot;

        return {
            -- Upper Part
            {esp:toViewport(head.Position), esp:toViewport(upperTorso.Position)},

            -- Right Arm
            {esp:toViewport(upperTorso.Position), esp:toViewport(rightUpperArm.Position)},
            {esp:toViewport(rightUpperArm.Position), esp:toViewport(rightLowerArm.Position)},
            {esp:toViewport(rightLowerArm.Position), esp:toViewport(rightHand.Position)},

            -- Left Arm
            {esp:toViewport(upperTorso.Position), esp:toViewport(leftUpperArm.Position)},
            {esp:toViewport(leftUpperArm.Position), esp:toViewport(leftLowerArm.Position)},
            {esp:toViewport(leftLowerArm.Position), esp:toViewport(leftHand.Position)},

            -- Lower Part
            {esp:toViewport(upperTorso.Position), esp:toViewport(lowerTorso.Position)},

            -- Right Leg
            {esp:toViewport(lowerTorso.Position), esp:toViewport(rightUpperLeg.Position)},
            {esp:toViewport(rightUpperLeg.Position), esp:toViewport(rightLowerLeg.Position)},
            {esp:toViewport(rightLowerLeg.Position), esp:toViewport(rightFoot.Position)},

            -- Left Leg
            {esp:toViewport(lowerTorso.Position), esp:toViewport(leftUpperLeg.Position)},
            {esp:toViewport(leftUpperLeg.Position), esp:toViewport(leftLowerLeg.Position)},
            {esp:toViewport(leftLowerLeg.Position), esp:toViewport(leftFoot.Position)},
        }
    elseif humanoid.RigType == Enum.HumanoidRigType.R6 then
        local torso = model.Torso;
        
        -- Arms
        local leftArm = model["Left Arm"];
        local rightArm = model["Right Arm"];

        -- Legs
        local leftLeg = model["Left Leg"];
        local rightLeg = model["Right Leg"];

        -- Positions
        local torsoUpvector = torso.CFrame.UpVector;

        local rightLegUpvector = rightLeg.CFrame.UpVector;
        local leftLegUpVector = leftLeg.CFrame.UpVector;

        local rightArmUpvector = rightArm.CFrame.UpVector;
        local leftArmUpvector = leftArm.CFrame.UpVector

        local shoulderHeight = torsoUpvector * (torso.Size / 4);
        local torsoSurface = torsoUpvector * (torso.Size / 2);

        local rightShoulderHeight = rightArmUpvector * (rightArm.Size / 4);
        local leftShoulderHeight = leftArmUpvector * (leftArm.Size / 4);

        local rightArmSurface = rightArmUpvector * (rightArm.Size / 2);
        local leftArmSurface = leftArmUpvector * (leftArm.Size / 2);

        local rightLegSurface = rightLegUpvector * (torso.Size / 2);
        local leftLegSurface = leftLegUpVector * (torso.Size / 2);

        local upperTorsoPos = torso.Position + shoulderHeight;
        local lowerTorsoPos = torso.Position - torsoSurface;

        local rightShoulderPos = rightArm.Position + rightShoulderHeight;
        local rightHandPos = rightArm.Position - rightArmSurface;

        local leftShoulderPos = leftArm.Position + leftShoulderHeight;
        local leftHandPos = leftArm.Position - leftArmSurface;

        local upperRightLegPos = rightLeg.Position + rightLegSurface;
        local lowerRightLegPos = rightLeg.Position - rightLegSurface;

        local upperLeftLegPos = leftLeg.Position + leftLegSurface;
        local lowerLeftLegPos = leftLeg.Position - leftLegSurface;

        return {
            -- Upper Part
            {esp:toViewport(head.Position), esp:toViewport(upperTorsoPos)},

            -- Right Arm
            {esp:toViewport(upperTorsoPos), esp:toViewport(rightShoulderPos)},
            {esp:toViewport(rightShoulderPos), esp:toViewport(rightHandPos)},

            -- Left Arm
            {esp:toViewport(upperTorsoPos), esp:toViewport(leftShoulderPos)},
            {esp:toViewport(leftShoulderPos), esp:toViewport(leftHandPos)},

            -- Lower Part
            {esp:toViewport(upperTorsoPos), esp:toViewport(lowerTorsoPos)},
            
            -- Right Leg
            {esp:toViewport(lowerTorsoPos), esp:toViewport(upperRightLegPos)},
            {esp:toViewport(upperRightLegPos), esp:toViewport(lowerRightLegPos)},

            -- Left Leg
            {esp:toViewport(lowerTorsoPos), esp:toViewport(upperLeftLegPos)},
            {esp:toViewport(upperLeftLegPos), esp:toViewport(lowerLeftLegPos)}
        }
    end
end

function esp:removeAll()
    for _, player in pairs(players:GetPlayers()) do
        local espObject = esp.queue[player];
        if espObject then
            espObject.remove();
        end
    end
end

function esp:queuePlayer(player, config)
    if not esp.enabled then
        return
    end

    config = config or {};

    local globalSettings = esp.settings;
    local boxSettings = globalSettings.boxes;
    local tracerSettings = globalSettings.tracers;
    local nametagSettings = globalSettings.nametags;
    local healthBarSettings = globalSettings.healthBar;
    local skeletonSettings = globalSettings.skeleton;

    local text = config.customText or player.Name;
    local flagText = config.flagText or "[None]";
    local flagColor = config.flagColor or Color3.fromRGB(255, 255, 255);

    local skeleton = {};
    local skeletonOutline = {};

    local box = esp.draw("Square", {
        Thickness = boxSettings.thickness,
        Filled = false,
        Visible = false,
        ZIndex = 1
    })
    local boxOutline = esp.draw("Square", {
        Filled = false,
        Visible = false,
        ZIndex = 0
    })

    local tracer = esp.draw("Line", {
        Visible = false,
        ZIndex = 1
    })
    local tracerOutline = esp.draw("Line", {
        Visible = false,
        ZIndex = 0,
        Color = Color3.fromRGB(0, 0, 0)
    })

    local healthBar = esp.draw("Line", {
        Thickness = 4,
        Visible = false,
        ZIndex = 0,
        Color = Color3.fromRGB(0, 0, 0)
    })
    local healthBarInline = esp.draw("Line", {
        Thickness = 2,
        Visible = false,
        ZIndex = 1
    })

    local nametag = esp.draw("Text", {
        Text = text,
        Size = globalSettings.textSize,
        Outline = globalSettings.textOutline,
        Font = Drawing.Fonts.Plex
    })

    local healthText = esp.draw("Text", {
        Text = text,
        Size = globalSettings.textSize,
        Outline = globalSettings.textOutline,
        Font = Drawing.Fonts.Plex
    })

    local distanceText = esp.draw("Text", {
        Text = "0",
        Size = globalSettings.textSize,
        Outline = globalSettings.textOutline,
        Font = Drawing.Fonts.Plex
    })

    local flagText = esp.draw("Text", {
        Text = flagText,
        Size = globalSettings.textSize,
        Outline = globalSettings.textOutline,
        Font = Drawing.Fonts.Plex
    })

    local espObject = {
        box = {
            main = box,
            outline = boxOutline
        },
        tracer = {
            main = tracer,
            outline = tracerOutline
        },
        nametag = nametag,
        healthText = healthText,
        distanceText = distanceText,
        flagText = flagText,
        healthBar = {
            main = healthBar,
            inline = healthBarInline
        },
        skeleton = {},
        player = player
    }

    -- Me being lazy
    local function removeSkeleton()
        for _, line in pairs(skeleton) do
            line.Visible = false;
            line:Remove();
        end
        for _, outline in pairs(skeletonOutline) do
            outline.Visible = false;
            outline:Remove();
        end

        skeleton = {};
        skeletonOutline = {};
    end
    
    local function stopRender()
        box.Visible = false;
        boxOutline.Visible = false;

        nametag.Visible = false;
        distanceText.Visible = false;
        flagText.Visible = false;
        healthText.Visible = false;

        tracer.Visible = false;
        tracerOutline.Visible = false;

        healthBar.Visible = false;
        healthBarInline.Visible = false;

        removeSkeleton();
    end

    espObject.connection = function()
        local globalColor = globalSettings.colors.global;

        local alive = esp:isAlive(player);

        if not alive then
            return stopRender();
        end
        
        local team = esp:getTeam(player);

        local playerColor = (globalSettings.useTeamColors and team and esp:getColor(player)) 
        or (team and ((esp:isTeammate(player) and globalSettings.colors.friendly) or globalSettings.colors.enemy))
        or globalColor;

        local character = esp:getCharacter(player);

        local health = esp:getHealth(player);
        local maxHealth = esp:getMaxHealth(player);

        local rootPart = character

        local worldPosition = rootPart.Position;
        local size = rootPart.Size;

        local offsetTop = Vector3.new(0, 3, 0);
        local offsetBottom = Vector3.new(0, 4, 0);

        local rootTop = esp:toViewport(worldPosition + ((size + offsetTop) / 2));
        local rootBottom = esp:toViewport(worldPosition - ((size + offsetBottom) / 2));

        local yTop = rootTop.Y;
        local yBottom = rootBottom.Y;

        local screenPosition, onScreen, depth = esp:toViewport(worldPosition);

        local visible = onScreen and
        ((team and (globalSettings.teamCheck and not esp:isTeammate(player)) or not team)
        or not globalSettings.teamCheck);

        box.Visible = visible and boxSettings.enabled;
        boxOutline.Visible = visible and boxSettings.enabled and boxSettings.outline;

        nametag.Visible = visible and nametagSettings.enabled;
        distanceText.Visible = visible and nametagSettings.enabled and nametagSettings.showDistance;
        flagText.Visible = visible and nametagSettings.enabled and nametagSettings.showFlag;

        tracer.Visible = visible and tracerSettings.enabled;
        tracerOutline.Visible = visible and tracerSettings.enabled and tracerSettings.outline;

        healthBar.Visible = visible and healthBarSettings.enabled;
        healthBarInline.Visible = visible and healthBarSettings.enabled;

        healthText.Visible = visible and healthBarSettings.enabled and healthBarSettings.showText;

        if visible then
            local screenRootSize = Vector2.new(2100 / depth, yTop - yBottom);
            local halfSizeX = screenRootSize.X / 2;
            local halfSizeY = screenRootSize.Y / 2;
            local top, bottom = screenPosition.Y + halfSizeY, screenPosition.Y - halfSizeY;
            local left, right = screenPosition.X - halfSizeX, screenPosition.X + halfSizeX;

            local textRightOffset = right + 10;

            local textYSize = nametag.TextBounds.Y;
            local skeletonNodes = {};

            if skeletonSettings.enabled then
                local status, nodes = pcall(esp.generateSkeletonNodes, esp, character);
                skeletonNodes = nodes;
                if not status then
                    skeletonNodes = {};
                    removeSkeleton();
                elseif #skeleton <= 0 then
                    for _ = 1, #skeletonNodes do
                        table.insert(skeleton, esp.draw("Line", {
                            ZIndex = 1,
                            Visible = true
                        }))
                        table.insert(skeletonOutline, esp.draw("Line", {
                            ZIndex = 0,
                            Color = Color3.fromRGB(0, 0, 0),
                            Visible = true
                        }))
                    end
                end
            elseif #skeleton > 0 then
                skeletonNodes = {};
                removeSkeleton();
            end

            if boxSettings.enabled then
                local boxPosition = Vector2.new(left, bottom);

                box.Position = boxPosition;
                box.Size = screenRootSize;
                box.Thickness = boxSettings.thickness;

                boxOutline.Position = boxPosition;
                boxOutline.Size = screenRootSize;
                boxOutline.Thickness = boxSettings.thickness * 2;

                box.Color = playerColor;
            end
            if nametagSettings.enabled then
                nametag.Outline = globalSettings.textOutline;
                nametag.Color = playerColor;
                nametag.Position = Vector2.new(textRightOffset, top);
                nametag.Size = globalSettings.textSize;

                local yMin1 = top + (textYSize * 2);
                local yMin2 = top + (textYSize * 3);

                if nametagSettings.showDistance then
                    local distance = (worldPosition - camera.CFrame.Position).Magnitude
                    distanceText.Outline = globalSettings.textOutline;
                    distanceText.Color = playerColor;
                    distanceText.Position = Vector2.new(textRightOffset, math.clamp(bottom - flagText.TextBounds.Y, yMin1, 9e9));
                    distanceText.Size = globalSettings.textSize;
                    distanceText.Text = "Distance: " .. tostring(math.floor(distance));
                end
                if nametagSettings.showFlag then
                    flagText.Outline = globalSettings.textOutline;
                    flagText.Color = flagColor;
                    flagText.Position = Vector2.new(textRightOffset, math.clamp(bottom, yMin2, 9e9));
                    flagText.Size = globalSettings.textSize;
                end
            end
            if tracerSettings.enabled then
                tracer.To = screenPosition;
                tracer.From = esp.tracerOrigin;
                tracer.Thickness = tracerSettings.thickness;

                tracerOutline.To = screenPosition;
                tracerOutline.From = esp.tracerOrigin;
                tracerOutline.Thickness = tracerSettings.thickness * 2;

                tracer.Color = playerColor;
            end
            if healthBarSettings.enabled then
                local inlineTop, inlineBottom = top, bottom - 1;

                local difference = (inlineTop - inlineBottom) / (maxHealth / math.clamp(health, 0, maxHealth));
                local healthTop = difference + bottom;
                local barRightOffset = right + 5;

                healthBar.To = Vector2.new(barRightOffset, top);
                healthBar.From = Vector2.new(barRightOffset, bottom);

                healthBarInline.To = Vector2.new(barRightOffset, healthTop);
                healthBarInline.From = Vector2.new(barRightOffset, inlineBottom);
                healthBarInline.Color = globalSettings.healthBar.color;

                if healthBarSettings.showText then
                    healthText.Outline = globalSettings.textOutline;
                    healthText.Color = playerColor;
                    healthText.Position = Vector2.new(textRightOffset, top + textYSize);
                    healthText.Size = globalSettings.textSize;
                    healthText.Text = tostring(math.floor(health)) .. " HP";
                end
            end
            if skeletonSettings.enabled then
                for index, node in pairs(skeletonNodes) do
                    local line = skeleton[index];
                    line.Thickness = skeletonSettings.thickness;
                    line.From = node[1];                       
                    line.To = node[2];
                    line.Color = skeletonSettings.color;

                    local outline = skeletonOutline[index]
                    outline.Thickness = skeletonSettings.thickness * 2;
                    outline.From = node[1];                       
                    outline.To = node[2];
                end
            end
        else
            removeSkeleton();
        end
    end

    function espObject.remove()
        --espObject.connection:Disconnect();

        box:Remove();
        boxOutline:Remove();

        tracer:Remove();
        tracerOutline:Remove();

        nametag:Remove();
        distanceText:Remove();
        flagText:Remove();
        healthText:Remove();

        healthBar:Remove();
        healthBarInline:Remove();

        removeSkeleton();

        esp.queue[player] = nil;
    end

    function espObject.changeFlag(newFlag, newColor)
        flagText.Text = newFlag;
        flagColor = newColor or Color3.fromRGB(255, 255, 255);
    end

    esp.queue[player] = espObject;

    return espObject;
end

function esp:toggle(state)
    esp:removeAll();

    if state then
        esp.enabled = true;
        for _, player in pairs(players:GetPlayers()) do
            if player == localPlayer then
                continue
            end
            esp:queuePlayer(player);
        end
    else
        esp.enabled = false;
    end
end

function esp:viewportSizeCallback()
    local newSize = camera.ViewportSize;

    local screenCenterX = newSize.X / 2;
    local screenBottomOffset = newSize.Y - 120;

    esp.tracerOrigin = Vector2.new(screenCenterX, screenBottomOffset);
end

players.PlayerRemoving:Connect(function(player)
    local espObject = esp.queue[player];
    if espObject then
        espObject.remove();
    end
end)

players.PlayerAdded:Connect(function(player)
    esp:queuePlayer(player);
end)

runService:BindToRenderStep("chetESP", Enum.RenderPriority.Character.Value, function()
    for _, espObject in pairs(esp.queue) do
        espObject.connection();
    end
end)

esp:viewportSizeCallback();

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    esp:viewportSizeCallback();
end)

return esp, esp.settings, esp.overrides;
