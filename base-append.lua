---@diagnostic disable: invalid-class-name

local statusEvent = getgenv().ah_statusEvent;

local function setStatus(...)
    if (not statusEvent) then return end;
    statusEvent:Fire(...);
end;

if (getgenv().aztupHubV3Ran or getgenv().aztupHubV3RanReal) then return setStatus('Script already ran', true) end;
getgenv().aztupHubV3Ran = true;
getgenv().aztupHubV3RanReal = true;

if (typeof(game) ~= 'Instance') then return SX_CRASH() end;
if (typeof(websiteKey) ~= 'string' or typeof(scriptKey) ~= 'string') then return SX_CRASH() end;

local originalFunctions = {};
local HttpService = game:GetService('HttpService');

xpcall(function()
    local functionsToCheck = {
        fireServer = Instance.new('RemoteEvent').FireServer,
        invokeServer = Instance.new('RemoteFunction').InvokeServer,

        fire = Instance.new('BindableEvent').Fire,
        invoke = Instance.new('BindableFunction').Invoke,

        enum = getrawmetatable(Enum).__tostring,
        signals = getrawmetatable(game.Changed),
        newIndex = getrawmetatable(game).__newindex,
        namecall = getrawmetatable(game).__namecall,
        index = getrawmetatable(game).__index,

        stringMT = getrawmetatable(''),

        UDim2,
        Rect,
        BrickColor,
        Instance,
        Region3,
        Region3int16,
        utf8,
        UDim,
        Vector2,
        Vector3,
        CFrame,

        getrawmetatable(UDim2.new()),
        getrawmetatable(Rect.new()),
        getrawmetatable(BrickColor.new()),
        getrawmetatable(Region3.new()),
        getrawmetatable(Region3int16.new()),
        getrawmetatable(utf8),
        getrawmetatable(UDim.new()),
        getrawmetatable(Vector2.new()),
        getrawmetatable(Vector3.new()),
        getrawmetatable(CFrame.new()),

        task.wait,
        task.spawn,
        task.delay,
        task.defer,

        wait,
        spawn,
        ypcall,
        pcall,
        xpcall,
        error,

        tonumber,
        tostring,

        rawget,
        rawset,
        rawequal,

        string = string,
        math = math,
        bit32 = bit32,
        table = table,
        pairs,
        next,
        unpack,
        getfenv,

        jsonEncode = HttpService.JSONEncode,
        jsonDecode = HttpService.JSONDecode,
        findFirstChild = game.FindFirstChild,
    };

    local function checkForFunction(t, i)
        local dataType = typeof(t);

        if (dataType == 'table') then
            for i, v in next, t do
                local suc, result = checkForFunction(v, i);
                if (not suc) then
                    return false, result;
                end;
            end;
        elseif (dataType == 'function') then
            local suc, uv = pcall(getupvalue, t, 1);

            if (is_synapse_function(t) or islclosure(t) or (suc and uv and typeof(uv) ~= 'userdata')) then
                return false, i;
            end;
        end;

        return true;
    end;

    if (not checkForFunction(functionsToCheck)) then
        messagebox('Sanity check failed\nThis usually happens cause you ran a script before the hub.\n\nIf you don\'t know why this happened.\nPlease check your auto execute folder.\n\nThis error has been logged.', 'Aztup Hub Security Error', 0);
        return SX_CRASH();
    else
        for i, v in next, functionsToCheck do
            if (typeof(v) == 'function') then
                originalFunctions[i] = clonefunction(v);
            end;
        end;
    end;

    originalFunctions.runOnActor = getgenv().syn.run_on_actor;
    originalFunctions.createCommChannel = getgenv().syn.create_comm_channel;
end, function()
    messagebox('Sanity check failed\nThis usually happens cause you ran a script before the hub.\n\nIf you don\'t know why this happened.\nPlease check your auto execute folder.\n\nThis error has been logged.', 'Aztup Hub Security Error', 0);
    return SX_CRASH();
end);

if (not game:IsLoaded()) then
    setStatus('Waiting for game to load');
    game.Loaded:Wait();
end;

setreadonly(syn, false);

local oldRequest = clonefunction(syn.request);
local gameId = game.GameId;

local function isRequestValid(req)
    if (not req.Headers or not req.Headers.Date or req.Headers.Date == '') then return false end;
    return req.StatusCode < 500 and req.StatusCode ~= 0;
end;

local function httpRequest(...)
    local reqData = oldRequest(...);
    local attempts = 0;

    if (not isRequestValid(reqData)) then
        repeat
            reqData = oldRequest(...);
            attempts += 1;
            task.wait(1);
        until isRequestValid(reqData) or attempts > 30;
    end;

    return reqData;
end;

local LocalPlayer = game:GetService('Players').LocalPlayer;
originalFunctions.getRankInGroup = clonefunction(LocalPlayer.GetRankInGroup);

local websiteKey, scriptKey = getgenv().websiteKey, getgenv().scriptKey;
local jobId, placeId = game.JobId, game.PlaceId;

local userId = LocalPlayer.UserId;
local isUserTrolled = false;
local accountData;
local scriptVersion;
local serverConstants = {};

do -- //Hook print debug
    if (not debugMode) then
        function print() end;
        function warn() end;
        function printf() end;
    end;
end;

setStatus('Checking whitelist');

do -- // Whitelist check
    -- A lot of this was redacted for obvious reasons

    -- This is most likely not working

    decryptedData = jsonDecode(HttpService, decryptedData);
    local jsonData = decryptedData.a;

    isUserTrolled = jsonData.isUserTrolled;
    accountData = jsonData.accountData;
    scriptVersion = jsonData.scriptVersion;
    serverConstants = jsonData.serverConstants;

    --print("Whitelist Took:" .. tick() - START_WHITELIST);
end;

local sharedRequires = {};

if (not accountData.tosAccepted) then
    setStatus('', 'tos');

    local data = statusEvent.Event:Wait();
    if (data ~= 'tosAccepted') then
        return task.wait(9e9);
    end;
end;

setStatus('All done', true);