local Main = {}

local tileSize = 32
local boundarySize = 2
local maxZoom = 1
local minZoom = 0.031250

function Main.tick()
    for index, player in pairs(game.players) do
        local playerSettings = global.playerSettings[player.index]

        if playerSettings.enabled and game.tick % playerSettings.screenshotInterval == 0 then
            if global.factorySize == nil then
                Main.follow_player(playerSettings, player)

                if playerSettings.followPlayer == false then
                    -- Do not take screenshots yet
                    return
                end
            elseif global.rocketLaunching ~= nil then
                -- Focus on launch
                Main.follow_center_pos(
                    playerSettings,
                    player,
                    global.rocketLaunching.centerPos,
                    global.rocketLaunching.size
                )
            else
                -- Focus on base
                Main.follow_center_pos(playerSettings, player, global.centerPos, global.factorySize)
            end

            game.take_screenshot {
                by_player = player,
                surface = game.surfaces[1],
                position = playerSettings.centerPos,
                resolution = {playerSettings.width, playerSettings.height},
                zoom = playerSettings.zoom,
                path = string.format("%s/%08d.png", playerSettings.saveFolder, game.tick),
                show_entity_info = false,
                allow_in_replay = true,
                daytime = 0 -- take screenshot at full light
            }

            if playerSettings.noticesEnabled then
                player.print({"screenshot-taken"})
            end
        end
    end
end

function Main.entity_built(event)
    -- top/bottom seems to be swapped, so use this table to reduce confusion of rest of the code
    local newEntityBBox = {
        left = event.created_entity.bounding_box.left_top.x - boundarySize,
        bottom = event.created_entity.bounding_box.left_top.y - boundarySize,
        right = event.created_entity.bounding_box.right_bottom.x + boundarySize,
        top = event.created_entity.bounding_box.right_bottom.y + boundarySize
    }

    if global.factorySize == nil then
        -- Set start point of base
        global.minPos = {x = newEntityBBox.left, y = newEntityBBox.bottom}
        global.maxPos = {x = newEntityBBox.right, y = newEntityBBox.top}
    else
        -- Recalculate base boundary
        if (newEntityBBox.left < global.minPos.x) then
            global.minPos.x = newEntityBBox.left
        end
        if (newEntityBBox.bottom < global.minPos.y) then
            global.minPos.y = newEntityBBox.bottom
        end
        if (newEntityBBox.right > global.maxPos.x) then
            global.maxPos.x = newEntityBBox.right
        end
        if (newEntityBBox.top > global.maxPos.y) then
            global.maxPos.y = newEntityBBox.top
        end
    end

    global.lastChange = game.tick
    global.factorySize = {
        x = global.maxPos.x - global.minPos.x,
        y = global.maxPos.y - global.minPos.y
    }

    -- Update center position
    global.centerPos = {
        x = global.minPos.x + global.factorySize.x / 2,
        y = global.minPos.y + global.factorySize.y / 2
    }
end

function Main.rocket_launch(event)
    if global.rocketLaunching ~= nil then
        -- already following a launch, ignore
        return
    end

    global.lastChange = game.tick
    global.rocketLaunching = {
        centerPos = event.rocket_silo.position,
        size = {x = 1, y = 1} -- don't care about size, it will fit with maxZoom
    }
end

function Main.rocket_launched()
    -- Done, recenter on base and allow tracking next launch
    global.lastChange = game.tick
    global.rocketLaunching = nil
end

function Main.follow_player(playerSettings, player)
    -- Follow player (update begin position)
    playerSettings.centerPos = player.position
    playerSettings.zoom = maxZoom
end

function Main.follow_center_pos(playerSettings, player, centerPos, centerSize)
    local ticksLeft = global.lastChange + playerSettings.zoomTicks - game.tick

    if ticksLeft > 0 then
        local stepsLeft = ticksLeft / playerSettings.screenshotInterval

        -- Gradually move to new center of the base
        local xDiff = centerPos.x - playerSettings.centerPos.x
        local yDiff = centerPos.y - playerSettings.centerPos.y
        playerSettings.centerPos.x = playerSettings.centerPos.x + xDiff / stepsLeft
        playerSettings.centerPos.y = playerSettings.centerPos.y + yDiff / stepsLeft

        -- Calculate desired zoom
        local zoomX = playerSettings.width / (tileSize * centerSize.x)
        local zoomY = playerSettings.height / (tileSize * centerSize.y)
        local zoom = math.min(zoomX, zoomY, maxZoom)

        -- Gradually zoom out with same duration as centering
        playerSettings.zoom = playerSettings.zoom - (playerSettings.zoom - zoom) / stepsLeft

        if playerSettings.zoom < minZoom then
            if playerSettings.noticeMaxZoom == nil then
                player.print({"max-zoom"}, {r = 1})
                player.print({"msg-once"})
                playerSettings.noticeMaxZoom = true
            end

            playerSettings.zoom = minZoom
        else
            -- Max (min atually) zoom is not reached (anymore)
            playerSettings.noticeMaxZoom = nil
        end
    end
end

return Main
