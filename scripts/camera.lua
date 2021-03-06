local Camera = {}

local Utils = require("scripts.utils")

local maxZoom = 1
local minZoom = 0.031250
local ticks_per_second = 60
local tileSize = 32

function Camera.newCamera(player, cameraList)
    local nameIndex = 1
    local cameraName = "new camera"
    while cameraList ~= nil and not Utils.uniqueName(cameraList, cameraName) do
        nameIndex = nameIndex + 1
        cameraName = "new camera-" .. nameIndex
    end

    local camera = {
        name = cameraName,
        enabled = false,
        entityInfo = false,
        trackers = {},
        centerPos = player.position,
        zoom = 1,
        -- settings/defaults
        width = 1920,
        height = 1080,
        frameRate = 25,
        speedGain = 60,
        zoomPeriod = 1.5
    }

    Camera.updateConfig(camera)

    return camera
end

function Camera.updateConfig(camera)
    camera.screenshotInterval = math.max(math.floor((ticks_per_second * camera.speedGain) / camera.frameRate), 1)
    camera.zoomTicks = math.max(math.floor(ticks_per_second * camera.zoomPeriod * camera.speedGain), 1)
    camera.realtimeInterval = math.max(math.floor(ticks_per_second / camera.frameRate), 1)
    camera.zoomTicksRealtime = math.max(math.floor(ticks_per_second * camera.zoomPeriod), 1)
end

function Camera.refreshConfig(camera)
    local zoomPeriod, frameRate, speedGain
    if camera.speedGain == nil then
        -- Try to recover as good as possible...
        zoomPeriod = camera.zoomTicksRealtime / ticks_per_second
        frameRate = ticks_per_second / camera.realtimeInterval

        local speedGain1 = camera.zoomTicks / (ticks_per_second * zoomPeriod)
        local speedGain2 = (camera.screenshotInterval * frameRate) / ticks_per_second
        speedGain = (speedGain1 + speedGain2) / 2
    else
        zoomPeriod = camera.zoomTicks / (camera.speedGain * ticks_per_second)
        frameRate = math.floor((ticks_per_second * camera.speedGain) / camera.screenshotInterval)

        -- Two ways to calculate speedGain, so take average
        local speedGain1 = camera.zoomTicks / (ticks_per_second * camera.zoomPeriod)
        local speedGain2 = (camera.screenshotInterval * camera.frameRate) / ticks_per_second
        speedGain = (speedGain1 + speedGain2) / 2
    end

    camera.zoomPeriod = math.floor(zoomPeriod * 100) / 100
    camera.frameRate = math.floor(frameRate + 0.5)
    camera.speedGain = math.floor(speedGain * 100) / 100
end

function Camera.followTracker(playerSettings, player, camera, tracker)
    if tracker.centerPos == nil then
        return
    end

    if tracker.smooth then
        Camera.followTrackerSmooth(playerSettings, player, camera, tracker)
    else
        camera.centerPos = tracker.centerPos
        camera.zoom = Camera.zoom(camera, tracker)
    end
end

function Camera.followTrackerSmooth(playerSettings, player, camera, tracker)
    local ticksLeft = tracker.lastChange - game.tick
    if tracker.realtimeCamera then
        ticksLeft = ticksLeft + camera.zoomTicksRealtime
    else
        ticksLeft = ticksLeft + camera.zoomTicks
    end

    if ticksLeft > 0 then
        local stepsLeft
        if tracker.realtimeCamera then
            stepsLeft = ticksLeft / camera.realtimeInterval
        else
            stepsLeft = ticksLeft / camera.screenshotInterval
        end

        -- Gradually move to new center of the base
        local xDiff = tracker.centerPos.x - camera.centerPos.x
        local yDiff = tracker.centerPos.y - camera.centerPos.y
        camera.centerPos.x = camera.centerPos.x + xDiff / stepsLeft
        camera.centerPos.y = camera.centerPos.y + yDiff / stepsLeft

        -- Gradually zoom out with same duration as centering
        local zoom = Camera.zoom(camera, tracker)
        camera.zoom = camera.zoom - (camera.zoom - zoom) / stepsLeft

        if camera.zoom < minZoom then
            if playerSettings.noticeMaxZoom == nil then
                player.print({"max-zoom"}, {r = 1})
                player.print({"msg-once"})
                playerSettings.noticeMaxZoom = true
            end

            camera.zoom = minZoom
        else
            -- Max (min atually) zoom is not reached (anymore)
            playerSettings.noticeMaxZoom = nil
        end
    end
end

function Camera.zoom(camera, tracker)
    -- Calculate desired zoom
    local zoomX = camera.width / (tileSize * tracker.size.x)
    local zoomY = camera.height / (tileSize * tracker.size.y)
    return math.min(zoomX, zoomY, maxZoom)
end

function Camera.setWidth(camera, width)
    width = tonumber(width)

    if width == nil or width < 320 then
        -- keep minimum width
        width = 320
    end

    if width ~= camera.width then
        -- Make sure to start (smooth) zooming to new width
        camera.lastChange = game.tick
    end
    camera.width = width
end

function Camera.setHeight(camera, height)
    height = tonumber(height)

    if height == nil or height < 240 then
        -- keep minimum height
        height = 240
    end

    if height ~= camera.height then
        -- Make sure to start (smooth) zooming to new height
        camera.lastChange = game.tick
    end
    camera.height = height
end

function Camera.setFrameRate(camera, framerate)
    framerate = tonumber(framerate)

    if framerate == nil or framerate < 1 then
        -- keep minimum frame rate
        framerate = 1
    end

    camera.frameRate = framerate
    Camera.updateConfig(camera)
end

function Camera.setSpeedGain(camera, speedGain)
    speedGain = tonumber(speedGain)

    if speedGain == nil or speedGain < 1 then
        -- keep minimum speed gain
        speedGain = 1
    end

    camera.speedGain = speedGain
    Camera.updateConfig(camera)
end

function Camera.setZoomPeriod(camera, zoomPeriod)
    zoomPeriod = tonumber(zoomPeriod)

    if zoomPeriod == nil or zoomPeriod < 0 then
        -- keep minimum zoom period (0 = disabled)
        zoomPeriod = 0
    end

    camera.zoomPeriod = zoomPeriod
    Camera.updateConfig(camera)
end

return Camera
