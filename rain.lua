--[[
    Second attempt at matrix rain.
]]

local component = require("component")
local gpu = component.gpu
local event = require("event")

local wid, hig = gpu.getResolution()

local delay = 0.035
local frequency = 0
local persistence = {4, math.floor(hig / 2)}
local notontop = 0.33
local maxDrops = 50
local usercolor = "green"
local tails = true
local screenregion = 0.5
local statictails = false

local colors = {
    "red",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
    "violet",
    "gray",
    "grey",
    "pink",
    "white" --white should always be at the end, to exclude it from the random selection
}

local function swap(a, b)
    if a < b then
        return a, b
    else
        return b, a
    end
end

local function argError(arg, type, usage)
    print("arg_error: " .. arg .. " requires a " .. type .. " value")
    print("usage: " .. usage)
    os.exit()
end

local args = {...}
local ii = 1
for i=1,#args do
    if ii > #args then
        break
    end
    if args[ii] == "-d" or args[ii] == "--delay" then
        ii = ii + 1
        if ii <= #args then
            delay = tonumber(args[ii]) --the time between each raindrop
        else
            argError("delay", "number", "rain [-d|--delay] <delay>")
        end
    elseif args[ii] == "-f" or args[ii] == "--frequency" then
        ii = ii + 1
        if ii <= #args then
            frequency = tonumber(args[ii]) --how many iters between each raindrop
        else
            argError("frequency", "number", "rain [-f|--frequency] <frequency>")
        end
    elseif args[ii] == "-p" or args[ii] == "--persistence" then
        if ii + 2 <= #args then
            local persmin, persmax = swap(tonumber(args[ii+1]), tonumber(args[ii+2]))
            persmin = math.floor(persmin * hig)
            persmax = math.floor(persmax * hig)
            persistence = {persmin, persmax}
        else
            argError("persistence", "number", "rain [-p|--persistence] <persistence>")
        end
        ii = ii + 2
    elseif args[ii] == "-t" or args[ii] == "--notontop" then
        if ii <= #args then
            notontop = tonumber(args[ii+1]) --chance for raindrop to spawn below y=1
        else
            argError("notontop", "number", "rain [-t|--notontop] <notontop>")
        end
        ii = ii + 1
    elseif args[ii] == "-m" or args[ii] == "--maxdrops" then
        if ii <= #args then
            maxDrops = tonumber(args[ii+1]) --max number of raindrops
        else
            argError("maxdrops", "number", "rain [-m|--maxdrops] <maxdrops>")
        end
        ii = ii + 1
    elseif args[ii] == "-c" or args[ii] == "--color" then
        if ii <= #args then
            --make sure the color is valid
            local valid = false
            for i=1,#colors do
                if args[ii+1] == colors[i] then
                    valid = true
                    break
                end
            end
            if valid then
                usercolor = args[ii+1]
            elseif args[ii+1] == "random" then
                usercolor = colors[math.random(1, #colors - 1)]
            else
                argError("color", "color", "rain [-c|--color] <color>")
            end
        else
            argError("color", "color", "rain [-c|--color] <color>")
        end
        ii = ii + 1
    elseif args[ii] == "-n" or args[ii] == "--no-tails" then
        tails = false
    elseif args[ii] == "-s" or args[ii] == "--screenregion" then
        if ii <= #args then
            screenregion = tonumber(args[ii+1]) --percentage of the screen the raindrops will spawn in from top
        else
            argError("screenregion", "number", "rain [-s|--screenregion] <screenregion>")
        end
        ii = ii + 1
    elseif args[ii] == "-u" or args[ii] == "--static-tails" then
        statictails = true
    elseif args[ii] == "-v" or args[ii] == "--version" then
        print("Rain v1.0")
        print("By minater247")
        os.exit()
    elseif args[ii] == "-h" or args[ii] == "--help" then
        print("usage: rain [-d|--delay] <delay> [-f|--frequency] <frequency> [-p|--persistence] <persistence> [-t|--notontop] <notontop>\n")
        print("-d|--delay <float>: the time between each raindrop")
        print("-f|--frequency <int>: how many iters between each raindrop")
        print("-p|--persistence <float> <float>: The minimum and maximum length of the raindrops, in percent of the screen height")
        print("-t|--notontop <float>: The chance that a raindrop will not be on the top of the screen")
        print("-m|--maxdrops <int>: The maximum number of raindrops that can be on the screen at once")
        print("-c|--color <string>: The color of the raindrops. Must be either a color name or 'random'")
        print("-n|--no-tails: Whether or not to draw tails on the raindrops")
        print("-s|--screenregion <float>: The percentage of the screen the raindrops will spawn in from top")
        print("-u|--static-tails: Make the bottom character of the raindrop the same")
        os.exit()
    else
        print("arg_error: unknown argument " .. args[ii])
        print("usage: rain [-d|--delay] <delay> [-f|--frequency] <frequency> [-p|--persistence] <persistence> [-t|--notontop] <notontop>")
        os.exit()
    end
    ii = ii + 1
end



local function genchars(len)
    local str = ""
    for i=1, len do
        local s = string.char(math.random(32, 126))
        if s == " " then
            s = "&"
        end
        str = str .. s
    end
    return str
end
local charset = genchars(1000)
local charsetlen = 1000
local currchar = 1


local Drops = {}
local function createDrop()
    local drop = {}
    drop.x = math.random(1, wid)
    if math.random() < notontop then
        drop.y = math.random(1, math.floor(hig * screenregion))
    else
        drop.y = 1
    end
    drop.char = charset:sub(currchar, currchar)
    currchar = currchar + 1
    if currchar > charsetlen then
        currchar = 1
    end
    drop.persistence = math.random(persistence[1], persistence[2])
    table.insert(Drops, drop)
end

local function moveDropsDown()
    for i, drop in ipairs(Drops) do
        drop.y = drop.y + 1
        if drop.y > hig then
            table.remove(Drops, i)
        end
    end
end

local Screen = {}
for y=1, hig do
    Screen[y] = {}
    for x=1, wid do
        Screen[y][x] = 0
    end
end

local function subtractOne()
    for y=1, hig do
        for x=1, wid do
            if Screen[y][x] > 0 then
                Screen[y][x] = Screen[y][x] - 1
            end
        end
    end
end

local screencolors = {}
screencolors.red = {
    0x000000,
    0x330000,
    0x660000,
    0x990000,
    0xcc0000,
    0xff0000
}
screencolors.orange = {
    0x000000,
    0x330000,
    0xCC4900,
    0xFF4900,
    0xFF6D00
}
screencolors.yellow = {
    0xFFB600,
    0xFFDB00,
    0xFFFF00
}
screencolors.green = {
    0x000000,
    0x002400,
    0x004900,
    0x006d00,
    0x009200,
    0x00b600,
    0x00db00,
    0x00ff00
}
screencolors.blue = {
    0x000000,
    0x000040,
    0x000080,
    0x0000c0,
    0x0000ff,
    0x0024ff,
    0x0049ff,
    0x006dff,
    0x0092ff
}
screencolors.purple = {
    0x000000,
    0x3300C0,
    0x3300FF,
    0x6624FF,
    0x6649FF,
    0x9949FF    
}
screencolors.violet = screencolors.purple
screencolors.white = {
    0xFFFFFF
}
screencolors.gray = {
    0x000000,
    0x0F0F0F,
    0x1E1E1E,
    0x2D2D2D,
    0x3C3C3C,
    0x4B4B4B,
    0x5A5A5A,
    0x696969,
    0x787878,
    0x878787,
    0x969696,
    0xA5A5A5,
    0xB4B4B4,
    0xC3C3C3,
    0xD2D2D2,
    0xE1E1E1,
    0xF0F0F0
}
screencolors.grey = screencolors.gray
screencolors.pink = {
    0x000000,
    0x660080,
    0x9900FF,
    0xCC00FF,
    0xFF00FF,
    0xFF24FF
}

local currcolors = screencolors[usercolor]

local function drawScreen()
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, wid, hig, " ")
    for y=1, hig do
        for x=1, wid do
            if Screen[y][x] > 0 then
                if Screen[y][x] > #currcolors then
                    gpu.setForeground(currcolors[#currcolors])
                else
                    gpu.setForeground(currcolors[Screen[y][x]])
                end
                gpu.set(x, y, charset:sub(currchar, currchar))
                currchar = currchar + 1
                if currchar > charsetlen then
                    currchar = 1
                end
            end
        end
    end
end


local function addDropsToScreen()
    for i, drop in ipairs(Drops) do
        Screen[drop.y][drop.x] = drop.persistence
        if not tails and not statictails then
            drop.char = charset:sub(currchar, currchar)
            currchar = currchar + 1
            if currchar > charsetlen then
                currchar = 1
            end
        end
    end
end

local function drawDrops()
    if tails then
        gpu.setForeground(0xFFFFFF)
    else
        gpu.setForeground(currcolors[#currcolors])
    end
    for i, drop in ipairs(Drops) do
        gpu.set(drop.x, drop.y, drop.char)
    end
end

local iter = 0
while true do
    moveDropsDown()
    subtractOne()
    if #Drops < maxDrops then
        if frequency < 1 and frequency > 0 then
            for i=1,math.floor(1 / frequency) do
                createDrop()
            end
        elseif frequency > 0 then
            if iter % frequency == 0 then
                createDrop()
            end
        else
            createDrop()
        end
    end
    addDropsToScreen()
    drawScreen()
    drawDrops()
    local ev = event.pull(delay, "key_down")
    if ev then
        gpu.fill(1, 1, wid, hig, " ")
        io.write("\x1b[1;1H") --terminal escape to 1,1
        break
    end
    iter = iter + 1
end
