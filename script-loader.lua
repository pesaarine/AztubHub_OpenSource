if (ah_loaderRan) then return end;
getgenv().ah_loaderRan = true;

local HttpService = game:GetService('HttpService');
local TweenService = game:GetService('TweenService');
local RunService = game:GetService('RunService');
local CoreGui = game:GetService('CoreGui');

local function setStatus() end;
local function destroyUI() end;

local oldRequest = clonefunction(syn.request);

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

local CanvasGroup = {}; do
    CanvasGroup.__index = CanvasGroup;

    function CanvasGroup.new(gui)
        local self = setmetatable({}, CanvasGroup);

        self._gui = gui;
        self._value = 1;

        self._objects = {};

        local function onDescendantAdded(child)
            table.insert(self._objects, {
                instance = child,
                properties = self:_getInstanceProperties(child)
            });
        end;

        for _, child in next, self._gui:GetDescendants() do
            onDescendantAdded(child);
        end;

        self._gui.DescendantAdded:Connect(onDescendantAdded);

        onDescendantAdded(self._gui);

        self.ValueObject = Instance.new('NumberValue');
        self.ValueObject:GetPropertyChangedSignal('Value'):Connect(function()
            self:_setValue(self.ValueObject.Value);
        end);

        return self;
    end;

    function CanvasGroup:_getInstanceProperties(object)
        local properties = {};

        if (object:IsA('Frame') or object:IsA('ViewportFrame')) then
            properties.BackgroundTransparency = object.BackgroundTransparency;
        end;

        if (object:IsA('UIStroke')) then
            properties.Transparency = object.Transparency;
        end;

        if (object:IsA('TextLabel') or object:IsA('TextBox') or object:IsA('TextButton')) then
            properties.BackgroundTransparency = object.BackgroundTransparency;

            properties.TextTransparency = object.TextTransparency;
            properties.TextStrokeTransparency = object.TextStrokeTransparency;
        end;

        if (object:IsA('ImageButton') or object:IsA('ImageLabel') or object:IsA('ViewportFrame')) then
            properties.ImageTransparency = object.ImageTransparency;
        end;

        return properties;
    end;

    function CanvasGroup:_setValue(value)
        value = math.clamp(value, 0, 1);
        self._value = value;

        for _, objectObject in next, self._objects do
            for propertyName, propertyValue in next, objectObject.properties do
                if (propertyValue == 1) then continue end;
                objectObject.instance[propertyName] = (propertyValue + (1 - propertyValue)) * self._value;
            end;
        end;
    end;
end;

local Children = {};
local refs = {};

local oldGethui = gethui;

local function gethui(ui)
    if (syn.protect_gui) then
        syn.protect_gui(ui);
    else
        return oldGethui();
    end;

    return CoreGui;
end;

local function c(instanceType, props)
    local i = Instance.new(instanceType);
    local ref = props.ref;
    props.ref = nil;

    for propName, propValue in next, props do
        if (propName == Children) then
            for _, child in next, propValue do
                child.Parent = i;
            end;
        else
            i[propName] = propValue;
        end;
    end;

    if (ref) then
        refs[ref] = i;
    end;

    return i;
end;

local function corner(cornerSize)
    return c('UICorner', {
        CornerRadius = UDim.new(0, cornerSize),
    });
end;

local function padding(paddingSize)
    return c('UIPadding', {
        PaddingBottom = UDim.new(0, paddingSize),
        PaddingLeft = UDim.new(0, paddingSize),
        PaddingRight = UDim.new(0, paddingSize),
        PaddingTop = UDim.new(0, paddingSize),
    });
end;

local ui = c('ScreenGui', {
    Name = 'Loader',
    ref = 'gui',
    Enabled = not getgenv().silentLaunch,
    DisplayOrder = 9,
    IgnoreGuiInset = true,
    OnTopOfCoreBlur = true,
    ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

    [Children] = {
        -- // Container
        c('Frame', {
            Name = 'Frame',
            ref = 'container',
            AnchorPoint = Vector2.new(0.5, 0.5),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.8),
            Size = UDim2.fromOffset(250, 0),
            ZIndex = 2,

            [Children] = {
                padding(20),

                c('Frame', {
                    Name = 'LoadingCircle',
                    ref = 'loadingCircle',
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    Size = UDim2.fromOffset(15, 15),

                    [Children] = {
                        c('UIStroke', {
                            Name = 'UIStroke',
                            Color = Color3.fromRGB(255, 255, 255),
                            Thickness = 4,

                            [Children] = {
                                c('UIGradient', {
                                    ref = 'loadingCircleGrad',
                                    Name = 'UIGradient',
                                    Transparency = NumberSequence.new({
                                        NumberSequenceKeypoint.new(0, 1),
                                        NumberSequenceKeypoint.new(0.217, 1),
                                        NumberSequenceKeypoint.new(1, 0),
                                    }),
                                }),
                            }
                        }),

                        c('UICorner', {
                            CornerRadius = UDim.new(1, 0)
                        })
                    }
                }),

                c('UIListLayout', {
                    Name = 'UIListLayout',
                    ref = 'uiListLayout',
                    Padding = UDim.new(0, 15),
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),

                c('UIStroke', {
                    Name = 'UIStroke',
                    Color = Color3.fromRGB(66, 66, 66),
                    Thickness = 3,
                }),

                c('UIGradient', {
                    Name = 'UIGradient',
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20)),
                    }),
                }),

                corner(4),

                c('TextLabel', {
                    Name = 'Title',
                    ref = 'title',
                    FontFace = Font.new(
                        'rbxasset://fonts/families/SourceSansPro.json',
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Normal
                    ),
                    Text = 'AZTUP HUB LOADER',
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 25,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                }),

                c('TextBox', {
                    Name = 'Reason',
                    ref = 'reason',
                    FontFace = Font.new('rbxasset://fonts/families/Roboto.json'),
                    Text = '',
                    ClearTextOnFocus = false,
                    TextEditable = false,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    PlaceholderColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 20,
                    TextStrokeTransparency = 0.7,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(57, 57, 57),
                    BorderSizePixel = 0,
                    LayoutOrder = 3,
                    Size = UDim2.fromScale(1, 0),
                    Visible = false,

                    [Children] = {
                        corner(4),
                        padding(10)
                    }
                }),

                c('TextButton', {
                    Name = 'Button',
                    ref = 'button',
                    FontFace = Font.new(
                        'rbxasset://fonts/families/SourceSansPro.json',
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Normal
                    ),
                    Text = 'I UNDERSTAND, REACTIVATE MY ACCOUNT',
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 20,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(231, 76, 60),
                    LayoutOrder = 10,
                    Size = UDim2.fromScale(1, 0),
                    Visible = false,

                    [Children] = {
                        corner(4),
                        padding(10)
                    }
                }),

                c('TextButton', {
                    Name = 'Button',
                    ref = 'secondButton',
                    FontFace = Font.new(
                        'rbxasset://fonts/families/SourceSansPro.json',
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Normal
                    ),
                    Text = 'I UNDERSTAND, REACTIVATE MY ACCOUNT',
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 20,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(231, 76, 60),
                    LayoutOrder = 10,
                    Size = UDim2.fromScale(1, 0),
                    Visible = false,

                    [Children] = {
                        corner(4),
                        padding(10)
                    }
                }),

                c('TextButton', {
                    Name = 'Button',
                    ref = 'thirdButton',
                    FontFace = Font.new(
                        'rbxasset://fonts/families/SourceSansPro.json',
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Normal
                    ),
                    Text = 'I UNDERSTAND, REACTIVATE MY ACCOUNT',
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 20,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(57, 57, 57),
                    LayoutOrder = 10,
                    Size = UDim2.fromScale(1, 0),
                    Visible = false,

                    [Children] = {
                        corner(4),
                        padding(10)
                    }
                }),

                c('TextLabel', {
                    Name = 'Status',
                    FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json'),
                    Text = 'NO STATUS',
                    ref = 'status',
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 25,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    LayoutOrder = 2,
                    Size = UDim2.new(1, 0, 0, 20),
                }),
            }
        }),
    }
});

ui.Parent = gethui(ui);

local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad);

local loaderGUICanvas = CanvasGroup.new(ui);
loaderGUICanvas.ValueObject.Value = 1;
refs.container.Position = UDim2.new(0.5, 0, 0.8, 20);

TweenService:Create(loaderGUICanvas.ValueObject, tweenInfo, {Value = 0}):Play();
TweenService:Create(refs.container, tweenInfo, {Position = UDim2.fromScale(0.5, 0.85)}):Play();

local loadingCircleGrad = refs.loadingCircleGrad;
local loaderAnimTime = 0.6;
local ran = false;

local con;
con = RunService.Heartbeat:Connect(function(dt)
    local rot = dt * 360 / loaderAnimTime;
    local newRot = (loadingCircleGrad.Rotation + rot) % 360;
    loadingCircleGrad.Rotation = newRot;
end);

local statusEvent = Instance.new('BindableEvent');
getgenv().ah_statusEvent = statusEvent;

function setStatus(text, close, context)
    refs.status.Text = text;
    if (not close) then return end;

    if (typeof(close) ~= 'boolean') then
        refs.gui.Enabled = true;
        refs.title.TextXAlignment = Enum.TextXAlignment.Left;

        refs.reason.Visible = true;
        refs.reason.Text = text;
        refs.reason.Font = Enum.Font.SourceSans;

        refs.status.RichText = true;
        refs.status.TextXAlignment = Enum.TextXAlignment.Left;

        refs.uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
        refs.loadingCircle.Visible = false;
        refs.button.Visible = true;
        refs.button.Text = 'CLOSE MENU';

        refs.container.Size = UDim2.fromOffset(450, 0);
        refs.container.Position = UDim2.fromScale(0.5, 0.5);
    end;

    if (close == 'blacklist') then
        refs.title.Text = 'Your license has been revoked.';
        refs.status.Text = 'Your aztup hub license has been revoked for violating our terms of services. Continuous violations of our terms of services, could result in you not being allowed to purchase Aztup Hub. The reason of this decision can be found below. If you think this is a mistake please do not hesitate to contact the support. If you think this decision was fair you can re-purchase a license on the website dashboard by clicking on re-purchase.'

        refs.button.MouseButton1Click:Connect(function()
            if (destroyUI()) then
                statusEvent:Destroy();
                getgenv().ah_statusEvent = nil;
            end;
        end);
    elseif (close == 'hwid') then
        refs.title.Text = 'Hwid mismatch';
        refs.status.Text = string.format('This hwid has changed from the one we have in our records, to continue to use the script and confirm that you are owning the script, please input the 6 digits code that we\'ve just sent to you to your email %s (make sure to check your spams).', context.email);
        refs.reason.PlaceholderText = '6 Digits Code Here';
        refs.reason.TextEditable = true;

        refs.button.Text = 'Submit Code';

        refs.button.MouseButton1Click:Connect(function()
            local req = httpRequest({
                Method = 'POST',
                Url = 'https://aztupscripts.xyz/api/v1/whitelist/resetHwid',
                Body = HttpService:JSONEncode({code = refs.reason.Text}),
                Headers = {Authorization = websiteKey, ['Content-Type'] = 'application/json'}
            });

            refs.reason.Visible = false;
            refs.button.Visible = false;

            if (req.Success) then
                refs.button.Visible = false;
                return setStatus('Success! Please rejoin and re-execute the script.', true);
            else
                local errorMessage = 'Internal Server Error';
                pcall(function() errorMessage = HttpService:JSONDecode(req.Body).message;end);
                return setStatus(errorMessage, true);
            end;
        end);
    elseif (close == 'tos') then
        refs.title.Text = 'Please agree to the terms of services.';
        refs.status.Text = 'You must be aware that by using the script you are also agreeing to our terms of services and must follow them, this is just a reminder to go check them if you did not do yet and also making sure that you agree to them. Do you agree to our terms of services? If you haven\'t read them yet you can do so at https://aztupscripts.xyz/terms-of-services';
        refs.reason.Visible = false;

        refs.secondButton.Visible = true;
        refs.secondButton.Text = 'I don\'t agree, close the script.';

        refs.thirdButton.Visible = true;
        refs.thirdButton.Text = 'Copy terms of services link to clipboard.';

        refs.button.Visible = true;
        refs.button.BackgroundColor3 = Color3.fromHex('#16a085');
        refs.button.Text = 'I agree to the terms of services.';

        refs.secondButton.MouseButton1Click:Connect(function()
            refs.button.Visible = false;
            refs.secondButton.Visible = false;
            refs.thirdButton.Visible = false;

            setStatus('Thank you!', true);
        end);

        refs.thirdButton.MouseButton1Click:Connect(function()
            setclipboard('https://aztupscripts.xyz/terms-of-services');
            refs.thirdButton.Text = 'Copied!';
            task.wait(1);
            refs.thirdButton.Text = 'Copy terms of services link to clipboard.';
        end);

        refs.button.MouseButton1Click:Connect(function()
            local req = httpRequest({
                Method = 'PATCH',
                Url = 'https://aztupscripts.xyz/api/v1/user',
                Body = HttpService:JSONEncode({tosAccepted = true}),
                Headers = {Authorization = websiteKey, ['Content-Type'] = 'application/json'}
            });

            refs.reason.Visible = false;
            refs.secondButton.Visible = false;
            refs.thirdButton.Visible = false;
            refs.button.Visible = false;

            if (req.Success) then
                statusEvent:Fire('tosAccepted');
                return setStatus('Success!', true);
            else
                local errorMessage = 'Internal Server Error';
                pcall(function() errorMessage = HttpService:JSONDecode(req.Body).message; end);
                return setStatus(errorMessage, true);
            end;
        end);
    elseif (close == 'error') then
        refs.reason.Visible = false;
        refs.title.Text = 'Failed to launch script.';

        refs.button.MouseButton1Click:Connect(function()
            if (destroyUI()) then
                statusEvent:Destroy();
                getgenv().ah_statusEvent = nil;
            end;
        end);
    else
        task.delay((text == 'Script already ran' or text == 'All done' or text == 'Thank you!') and 1 or 8, function()
            if (destroyUI()) then
                statusEvent:Destroy();
                getgenv().ah_statusEvent = nil;
            end;
        end);
    end;
end;

function destroyUI()
    if (ran) then return end;
    ran = true;

    TweenService:Create(loaderGUICanvas.ValueObject, tweenInfo, {Value = 1}):Play();
    TweenService:Create(refs.container, tweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 20)}):Play();

    task.delay(1, function()
        con:Disconnect();
        ui:Destroy();
    end);

    return true;
end;

statusEvent.Event:Connect(setStatus);
setStatus('Checking data');

local function logError(msg)
    msg = msg or '';

    setStatus('There was an error.\n\n' .. tostring(msg) .. '\n\n');
    task.delay(8, destroyUI);
end;

xpcall(function()
    local websiteKey = getgenv().websiteKey;
    if (typeof(websiteKey) ~= 'string') then return end;

    local function fromHex(str)
        return string.gsub(str, '..', function (cc)
            return string.char(tonumber(cc, 16));
        end);
    end;

    local suc, err = pcall(function()
        if (not isfolder('Aztup Hub V3')) then makefolder('Aztup Hub V3'); end;
        if (not isfolder('Aztup Hub V3/scripts')) then makefolder('Aztup Hub V3/scripts'); end;
    end);

    if (not suc) then
        logError(err);
        setStatus('Failed to create scripts folder, this could be caused by syn not being located in a proper directory.', true);
        return;
    end;

    local universeId;
    local metadataRequest;

    task.spawn(function()
        local localUniverseId;
        local doingRequest;

        repeat
            if (game.GameId ~= 0) then
                localUniverseId = game.GameId;
            elseif (game.PlaceId ~= 0 and not doingRequest) then
                task.spawn(function()
                    doingRequest = true;
                    localUniverseId = HttpService:JSONDecode(httpRequest({
                        Url = string.format('https://apis.roblox.com/universes/v1/places/%s/universe', game.PlaceId)
                    }).Body).universeId;
                    doingRequest = false;
                end);
            end;

            task.wait();
        until localUniverseId;

        universeId = localUniverseId;
    end);

    task.spawn(function()
        metadataRequest = httpRequest({
            Url = 'https://serve.aztupscripts.xyz/metadata.json'
        });
    end);

    -- // Wait for both requests to finish
    repeat task.wait(); until universeId and metadataRequest;

    if (not isRequestValid(metadataRequest)) then
        return setStatus('Failed to communicate with the server, please try again later.', true);
    elseif (not metadataRequest.Success) then
        return setStatus(string.format('%s - %s', tostring(metadataRequest.StatusCode), tostring(metadataRequest.Body)), true);
    end;

    if (not string.find(metadataRequest.Headers['Content-Type'], 'application/json')) then
        return setStatus('Failed to communicate with the server, please try again later.', true);
    end;

    metadataRequest = HttpService:JSONDecode(metadataRequest.Body);
    getgenv().ah_metadata = metadataRequest;
    local fileName = metadataRequest.games[tostring(universeId)];

    if (not fileName) then
        -- If no file name then we load the smallest file possible which in this case is KAT
        fileName = 'KAT';
    end;

    local scriptHashDataRequest = httpRequest({
        Url = string.format('https://serve.aztupscripts.xyz/hash/%s.lua', fileName),
        Method = 'GET',
    });

    if (not isRequestValid(scriptHashDataRequest)) then
        return setStatus('Failed to communicate with the server, please try again later.', true);
    elseif (not scriptHashDataRequest.Success) then
        return setStatus(string.format('%s - %s', tostring(scriptHashDataRequest.StatusCode), tostring(scriptHashDataRequest.Body)), true);
    end;

    local scriptHash = scriptHashDataRequest.Body;
    local scriptPath = string.format('Aztup Hub V3/scripts/%s.file', fileName);
    local scriptContent = isfile(scriptPath) and readfile(scriptPath);

    if (not scriptContent or syn.crypt.custom.hash('sha256', scriptContent) ~= scriptHash) then
        setStatus('Downloading script');
        local downloadAttempts = 0;

        repeat
            downloadAttempts += 1;
            scriptContent = httpRequest({
                Url = string.format('https://serve.aztupscripts.xyz/%s.lua', fileName),
                Method = 'GET'
            }).Body;
        until syn.crypt.custom.hash('sha256', scriptContent) == scriptHash or downloadAttempts > 10;

        if (syn.crypt.custom.hash('sha256', scriptContent) ~= scriptHash) then
            logError('critical error couldnt download script after 10 attempts');
            return setStatus('Script download has timed out after 10 attempts, please try again.', true);
        end;

        writefile(scriptPath, scriptContent);
    end;

    xpcall(function()
        setStatus('Launching script');

        syn.run_secure_lua(
            syn.crypt.custom.decrypt(
                'aes-ctr',
                syn.crypt.base64.encode(scriptContent),
                key,
                iv
            )
        );
    end, function(err)
        logError(err .. ' ' .. syn.crypt.base64.encode(scriptContent:sub(1, 50)));
        setStatus('Failed to decrypt the script, please try to get the script again.' .. err, true);
    end);
end, function(err)
    logError(err);
    setStatus(err, true);
end);