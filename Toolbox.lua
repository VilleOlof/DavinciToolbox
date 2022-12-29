-- Made by: VilleOlof
-- https://github.com/VilleOlof
-- Version 1.2.4 [Public Release] 2022-12-29  14:08 CET
--Added Save Profiles
--Fixed Content Filled not accounting for start marker thats not the start of timeline.
--Added Video Name Suffix (name_number.extension)
--Added a key-value table > CSV function (Export as CSV now works instead of .tbl file)
--Refined the startup, it now only switches to the render page once and back, less flickering
--Fixed "Start Editing" stopping the timer if started before
--Added a CopyPreviousProfile option when creating new profiles
::Start::

--## Variables/Settings to change:

--The name of the standard savedata file
local SavePath_File = "Toolbox_Standard_SaveData.tbl"

--Decides where it should save the "Data" table
local SavePath_Prefix = os.getenv('APPDATA')..[[/Blackmagic Design/DaVinci Resolve/Toolbox/]]

--Decides if it's only gonna count clips in track 1 for the "total clip count" in the UI
local OnlyCountTrackOne = false

--Default Render Directory
local RenderDir = ""
--Loads in the last used render directory when starting the script
local UseLastRenderDirWhenStarting = true

--Default Render Video Name (Include .Extension)
local RenderName = "Video.mp4"
--Loads in the last used render name when starting the script
local UseLastRenderNameWhenStarting = true

--Default Render Prest Index In Drop-down (Default is 5 and should equal to Youtube 1080p)
local RenderPresetDefaultIndex = 5
--Loads in the last used render preset when starting the script
local UseLastPresetWhenStarting = true

--Default Target Minute in the video proccessing bar
local DefaultTargetMinute = "8"
--Loads in the last used target minute when starting the script
local UseLastTargetMinuteWhenStarting = true

--Changes how big the note text box is, (Default is 100)
local NoteSize = 100

--When creating a new profile, this decides if it's gonna copy the current profile data to the new one 
--or create a fresh profile, Default is true
local CopyPreviousProfile = true

--########################################################
-- ## Don't touch variables but you can if you want: ## --

--Data Table, Saves all the script paths, names, folder paths, paths, timer Etc.
local Data = {}

local WindowTitleStart = "DaVinci Toolbox - "

--Marker Custom Data
local StartMarkerData = "start_marker"
local EndMarkerData = "end_marker"

--Main Timer Variables
local MainTimerInterval = 100 -- Milliseconds
local TimerRollover = 1 -- 100 Milliseconds
local ProgressionRollover = 10 -- 1 Second
local TenSecondTimerRollover = 100 -- 10 Seconds

--UI Timer Variables
local UI_Timer_Elapsed = 0
local UI_Timer_OSClock = 0

local ClipCountText = "Total Amount Of Clips: "
if OnlyCountTrackOne then ClipCountText = "Track One Amount Of Clips: " end

--Should not be touched at all, these changes during the use of the toolbox
local IsEditing = false
local IsTimerRunning = false
local FirstTimerRan = false
local restartScript = false
local SwitchBackToEditPage = false

--Main Timer:
local HeadTimer

--Script only works on windows has it uses certain commands and windows specific features
local platform = (FuPLATFORM_WINDOWS and "Windows") or (FuPLATFORM_MAC and "Mac") or (FuPLATFORM_LINUX and "Linux")
if platform == "Mac" or platform == "Linux" then 
    print("Platform Not Available")
    goto EndScript 
end
------------------------------------------
--#DavinkiThings
local projman = resolve:GetProjectManager()
local proj = projman:GetCurrentProject()
local mediapool = proj:GetMediaPool()
local mediaStorage = resolve:GetMediaStorage()
local timeline = proj:GetCurrentTimeline()

--Ensures that there is always a timeline to calculate from:
if not timeline then mediapool:CreateEmptyTimeline("Timeline 1") end
-------------------------------------------

--########################################################
--Functions For Loading/Saving Tables To File
--From: http://lua-users.org/wiki/SaveTableToFile
local function exportstring( s )
    return string.format("%q", s)
 end

 --// The Save Function
 function table.save(  tbl,filename )
    local charS,charE = "   ","\n"
    local file,err = io.open( filename, "wb" )
    if err then return err end

    -- initiate variables for save procedure
    local tables,lookup = { tbl },{ [tbl] = 1 }
    file:write( "return {"..charE )

    for idx,t in ipairs( tables ) do
       file:write( "-- Table: {"..idx.."}"..charE )
       file:write( "{"..charE )
       local thandled = {}

       for i,v in ipairs( t ) do
          thandled[i] = true
          local stype = type( v )
          -- only handle value
          if stype == "table" then
             if not lookup[v] then
                table.insert( tables, v )
                lookup[v] = #tables
             end
             file:write( charS.."{"..lookup[v].."},"..charE )
          elseif stype == "string" then
             file:write(  charS..exportstring( v )..","..charE )
          elseif stype == "number" then
             file:write(  charS..tostring( v )..","..charE )
          end
       end

       for i,v in pairs( t ) do
          -- escape handled values
          if (not thandled[i]) then
          
             local str = ""
             local stype = type( i )
             -- handle index
             if stype == "table" then
                if not lookup[i] then
                   table.insert( tables,i )
                   lookup[i] = #tables
                end
                str = charS.."[{"..lookup[i].."}]="
             elseif stype == "string" then
                str = charS.."["..exportstring( i ).."]="
             elseif stype == "number" then
                str = charS.."["..tostring( i ).."]="
             end
          
             if str ~= "" then
                stype = type( v )
                -- handle value
                if stype == "table" then
                   if not lookup[v] then
                      table.insert( tables,v )
                      lookup[v] = #tables
                   end
                   file:write( str.."{"..lookup[v].."},"..charE )
                elseif stype == "string" then
                   file:write( str..exportstring( v )..","..charE )
                elseif stype == "number" then
                   file:write( str..tostring( v )..","..charE )
                end
             end
          end
       end
       file:write( "},"..charE )
    end
    file:write( "}" )
    file:close()
 end

 --// The Load Function
 function table.load( sfile )
    local ftables,err = loadfile( sfile )
    if err then return _,err end
    local tables = ftables()
    for idx = 1,#tables do
       local tolinki = {}
       for i,v in pairs( tables[idx] ) do
          if type( v ) == "table" then
             tables[idx][i] = tables[v[1]]
          end
          if type( i ) == "table" and tables[i[1]] then
             table.insert( tolinki,{ i,tables[i[1]] } )
          end
       end
       -- link indices
       for _,v in ipairs( tolinki ) do
          tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
       end
    end
    return tables[1]
 end
------------------------------------
--Takes a key value pair table as the parameter
--and converts it to a CSV string, able to be exported later to file
local function GetCSVString(table)
    local escTbl = { [[\r]], [[\n]], [[,]], [["]] }
    local _keys, _values = {}, {}
    local result = ""
    for k, v in pairs(table) do
        if k ~= nil and v ~= nil then
            _keys[#_keys+1] = k
            _values[#_values+1] = v
        end
    end
    for i, key in ipairs(_keys) do
        local tmp = key
        for i, char in ipairs(escTbl) do
            if string.match(tmp, char) then
                tmp = "\""..tmp.."\""
                break
            end
        end
        result = result..tmp..","
    end
    result = result:sub(1,-2)
    result = result.."\n"
    for i, value in ipairs(_values) do
        local tmp = value
        if type(tmp) == "number" then tmp = tostring(tmp) end
        local charCount = 0
        for j = 1, #tmp do
            local char = tmp:sub(j+charCount,j+charCount)
            if char == [["]] then
                tmp = tmp:sub(1,j)..[["]]..tmp:sub(j+1)
                charCount = charCount + 1
            end
        end
        for i, char in ipairs(escTbl) do
            if string.match(tmp, char) then
                tmp = "\""..tmp.."\""
                break
            end
        end
        result = result..tmp..","
    end
    result = result:sub(1,-2)
    return result
end

--Seperates an entire path into [--FilePath, -FileName, -Extension]
--https://stackoverflow.com/questions/5243179/what-is-the-neatest-way-to-split-out-a-path-name-into-its-components-in-lua
local function DeconstructFilepath(path, cleanFileName, dirChar)
    if not dirChar then dirChar = "\\" end
    local path, name, ext = string.match(path, "(.-)([^"..dirChar.."]-([^%.]+))$")
    if cleanFileName then name = name:sub(1,-#ext-2) end -- removes the extension from the name
    return path, name, ext
end
--Tries to rename the file (or dir) to its exact same name to see if the file exists
local function FileExists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

--Waits X Amount of seconds
local function Wait(second, millisecond)
    local ostime_vrbl = os.time() + second, millisecond
    while os.time() < ostime_vrbl do end
end

--Doesn't exit the loop until either the specified file exists or it reached its retry limit
local function FileTimeout(file, limit)
    local count = 0

    while true do
        local success = FileExists(file)
        if success then return true end
        count = count + 1
        if count >= limit then return false end
        Wait(0.25)
    end
end

--GlobalData, accessed through every profile
local GlobalData = {
    SelectedProfile = "Standard",
    Profiles = { "Standard", },
}
local GlobalDataPath = "Toolbox_Global.tbl"
local GlobalDataFullPath = SavePath_Prefix..GlobalDataPath

--Ensures that the folder that the save data gets saved into exists.
local Save_Path, Save_Name, Save_Ext = DeconstructFilepath(GlobalDataFullPath, true, "/")
if not FileExists(Save_Path) then io.popen("mkdir \""..Save_Path.."\"") end
local toolboxFolderCreation = FileTimeout(SavePath_Prefix, 10)

--Creates a new global data file if it doesnt exist or loads one if it does
if not FileExists(GlobalDataFullPath) then 
    io.popen("type nul > "..GlobalDataFullPath) --creates the global.tbl file
    table.save(GlobalData, GlobalDataFullPath) --saves the standard default table into it
else
    --Global.tbl already exists
    GlobalData = table.load(GlobalDataFullPath) --loads in the global data
end

--Combines the SavePath_Prefix dir and file
local SaveProfile = "Toolbox_"..GlobalData.SelectedProfile.."_SaveData.tbl"
local SavePath = SavePath_Prefix..SaveProfile

--Ensures that the SavePath is correct
SavePath = SavePath:gsub('\\','/')
------------------

--Loads table data into the data variable at SavePath if the file exists
if FileExists(SavePath) then Data = table.load(SavePath) end

 --Loads in last used variables and others at startup
 if Data.UI_Timer_Elapsed then UI_Timer_Elapsed = Data.UI_Timer_Elapsed end
 if Data.RenderName and UseLastRenderNameWhenStarting then RenderName = Data.RenderName end
 if Data.RenderPath and UseLastRenderDirWhenStarting then RenderDir = Data.RenderPath end
 if Data.TargetMinutes and UseLastTargetMinuteWhenStarting then DefaultTargetMinute = Data.TargetMinutes end

 --Saves the current project and timeline, updates every ten second loop
 if proj then Data.Project = proj:GetName() end
 if timeline then Data.Timeline = timeline:GetName() end

 --Gets The File Name From The Entire FilePath Minus ".lua" At The End.
local function GetFilename(path)   
    local start, finish = path:find('[%w%s!-={-|]+[_%.].+')   
    return path:sub(start,#path-4) 
end

--Shortens the filepath to max 20 characters, shows the last parts since it's most important to know
--If less than or equal to 20 characters, it will show the entire path
local function GetLastFolderInPath(path)
    local limit = 28
    if #path >= limit then
        path = string.reverse(path)
        path = path:sub(1,limit)
        return "..."..string.reverse(path)
    end
    return path
end

--Gets the amount of files with a certain name in a directory
function GetFileCount(path, fileName, extra_number)
    local count = 0

    --just removing the last / from the 'selectedPath' to make the command
    local text = path:sub(1, -2)

    local Dir_CMD = "dir \""..text.."\" /b"

    for file in io.popen(Dir_CMD):lines() do 

        local fixed_cap = file:sub(1,#fileName)
        
        if (fixed_cap == fileName) then
            count = count + 1
        end
    end

    return count+extra_number
end

-- Return the first index with the given value (or nil if not found).
local function IndexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

local function TableContains(table, value)
    for i, v in ipairs(table) do
        if v == value then return true end
    end
    return false
end


--Takes a filePath and a table (and converts the data to the .csv format) and writes it to file with the current date as name (dd_mm_yyyy-hh:mm:ss)
local function SaveTableToDataFile(filePath, Data)
    local CSV = GetCSVString(Data)

    local full_Path = filePath.."ToolboxData-"..(os.date("%d_%m_%Y-%X")):gsub(":","_")..".csv"

    local _file = io.open(full_Path, "w")
    _file:write(CSV)
    _file:close()
end 

--Removes The 01:00:00 That Davinki Usually Starts at For Calculations
local function RemoveStartFrame(frame)
    frame = frame - timeline:GetStartFrame()
    return frame
end

--Takes in seconds and formats it to a more readable, great format HH:MM:SS
local function disp_time(time, includeHours)
    local hours = math.floor(math.fmod(time, 86400)/3600)
    local minutes = math.floor(math.fmod(time,3600)/60)
    local seconds = math.floor(math.fmod(time,60))
    local _formatString = "%02d:%02d"
    if (includeHours) then 
        _formatString = _formatString..":%02d" 
        return string.format(_formatString,hours,minutes,seconds)
    end
    return string.format(_formatString,minutes,seconds)
end

--Splits the string at seperator, only used for GetCurrentFrame
local function String_Split(content, sep)
	local segments = {}
	for segment in (content .. sep):gmatch("(.-)" .. sep) do
	  segments[#segments + 1] = segment
	end
	return segments
end

--Gets the current frame where the playhead is at in the timeline
local function GetCurrentFrame()
    local Framerate = timeline:GetSetting("timelineFrameRate")
	local Timecode = timeline:GetCurrentTimecode()
	local Segments = String_Split(Timecode, ":")
	
	local Frame = tonumber(Segments[1])*60
	Frame = (Frame+tonumber(Segments[2]))*60
	Frame = (Frame+tonumber(Segments[3]))*Framerate
	Frame = Frame+tonumber(Segments[4])
	
    Frame = RemoveStartFrame(Frame)

	return Frame
end

--Basic Math Clamp Function
function clamp(x, min, max)
    if x < min then return min end
    if x > max then return max end
    return x
end

--Progression Bar Variables:
local EndFrame_Start = 0
local MarkerFrame = 0
local EndMarkerFrame = 0

--Data For The Start Marker
local ProgressMarker = {
    ["color"] = "Green",
    ["name"] = "Start Marker",
    ["note"] = "A Marker Used For The Start Of The Video",
}
--Data For The End Marker
local ProgressMarker_End = {
    ["color"] = "Red",
    ["name"] = "End Marker",
    ["note"] = "A Marker used For The End Of The Video",
}

--Adds the StartMarker To where the current playhead is at in timeline
local function AddStartMarker()
    timeline:DeleteMarkerByCustomData(StartMarkerData)

    local Current_Playhead = GetCurrentFrame()
    timeline:AddMarker(Current_Playhead, ProgressMarker.color, ProgressMarker.name, ProgressMarker.note, 1, StartMarkerData)
    MarkerFrame = Current_Playhead
end

--Adds the EndMarker To where the current playhead is at in timeline
local function AddEndMarker()
    timeline:DeleteMarkerByCustomData(EndMarkerData)

    local Current_Playhead = GetCurrentFrame()
    timeline:AddMarker(Current_Playhead, ProgressMarker_End.color, ProgressMarker_End.name, ProgressMarker_End.note, 1, EndMarkerData)
    EndMarkerFrame = Current_Playhead
end

--This is ran before the GUI Window, This looks for the StartMarker and adds the frame id to MarkerFrame
local function AddMarkerFrameAtStart()
    if not timeline then return end
    MarkerFrame = RemoveStartFrame(timeline:GetStartFrame())
    if timeline:GetMarkerByCustomData(StartMarkerData) then
        local allMarkers = timeline:GetMarkers()
        for frame, info in pairs(allMarkers) do
            if info.customData == StartMarkerData then MarkerFrame = frame end
        end
    end
end

--This is ran before the GUI Window, This looks for the EndMarker and adds the frame id to EndMarkerFrame
local function AddEndMarkerFrameAtStart()
    if not timeline then return end
    EndMarkerFrame = RemoveStartFrame(timeline:GetEndFrame())
    if timeline:GetMarkerByCustomData(EndMarkerData) then
        local allMarkers = timeline:GetMarkers()
        for frame, info in pairs(allMarkers) do
            if info.customData == EndMarkerData then EndMarkerFrame = frame end
        end
    end
end

--Makes a HTML Image based visual loading bar based on the percentage given and the min/max values
local function ProgressBarHTML(percentage)
    --Loading bar is composed of 'SegmentMax' amount of small 5x17 pixel images encoded in base64 to use via HTML <img>
    local ProgressOn = [[<img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAARCAIAAACaSvE/AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsEAAA7BAbiRa+0AAAAXSURBVChTYzT4H8SABJigNAyMLD4DAwCpGwGjQLhtDQAAAABJRU5ErkJggg=='/>]]
    local ProgressOff = [[<img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAARCAIAAACaSvE/AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsEAAA7BAbiRa+0AAAAXSURBVChTY5SSkmJAAkxQGgZGFp+BAQBlZABwKLhTYQAAAABJRU5ErkJggg=='/>]]

    local HTML = ""

    local SegmentMin = 0
    local SegmentMax = 100

    if percentage ~= SegmentMin then
        for on = 1, percentage do
            HTML = HTML..ProgressOn
        end
    end

    if percentage ~= SegmentMax then
        for off = 1, (SegmentMax - percentage) do
            HTML = HTML..ProgressOff
        end
    end
    
    return HTML
end

--"Global" Counter Variable For The GUI Counter
local Counter_1 = 0
local Counter_2 = 0
if Data.Counter_1 then Counter_1 = Data.Counter_1 end
if Data.Counter_2 then Counter_2 = Data.Counter_2 end

--Updates The GUI Counter
local function UpdateCounter(itm)
    itm.Counter_1.Text = tostring(Counter_1)
    Data.Counter_1 = Counter_1

    itm.Counter_2.Text = tostring(Counter_2)
    Data.Counter_2 = Counter_2

    local difference = 0
    if Counter_1 < Counter_2 then difference = Counter_2 - Counter_1 else difference = Counter_1 - Counter_2 end
    itm.Counter_1_Label.Text = "Diff:   "..tostring(difference)
    itm.Counter_2_Label.Text = "Sum: "..tostring(Counter_1+Counter_2)
end

--Starts The Video Progressbar, Takes the last frame in the timeline and counts it as the "start" (0%)
local function StartVideoProgress()
    EndFrame_Start = RemoveStartFrame(timeline:GetEndFrame())
end

--Calculates the Target "Frame ID" based on user input and timeline framerate
local function GetTargetFrame(itm)
    return (tonumber(itm.Progression_TargetMinutes.Text)*60)*timeline:GetSetting("timelineFrameRate")
end 

--Get the current video progress compared to the start marker (if not found, start of timeline),
--and the EndFrame_Start to calculate the percentage
local function GetVideoProgress(itm)
    if itm.Progression_TargetMinutes.Text == "" then return end
    local targetFrame = GetTargetFrame(itm)
    if MarkerFrame ~= 0 then targetFrame = targetFrame + MarkerFrame end
    
    local FrameDiff = EndFrame_Start - targetFrame
    local CurrentFrameDiff = RemoveStartFrame(timeline:GetEndFrame()) - targetFrame
    local CurrentPlaceInProgress = 100-(CurrentFrameDiff/FrameDiff*100)

    CurrentPlaceInProgress = clamp(CurrentPlaceInProgress, 0, 100)
    CurrentPlaceInProgress = math.floor(CurrentPlaceInProgress)

    itm.VideoProgressionLabel.Text = "Video Progress: "..CurrentPlaceInProgress.."%"
    itm.VideoProgressionHTMLBar.HTML = ProgressBarHTML(CurrentPlaceInProgress)
end

--Calculates how much of the TargetFrames you have filled up, counts at the playhead.
local function GetContentFilledProgress(itm)
    local StartFrame = RemoveStartFrame(timeline:GetStartFrame())
    if timeline:GetMarkerByCustomData(StartMarkerData) then StartFrame = MarkerFrame end 

    local PlayheadFrame = GetCurrentFrame()

    local targetFrame = StartFrame + GetTargetFrame(itm)

    local FrameDiff = targetFrame - StartFrame
    local CurrentPlaceInProgress = (PlayheadFrame-StartFrame)/FrameDiff*100

    CurrentPlaceInProgress = clamp(CurrentPlaceInProgress, 0, 100)
    CurrentPlaceInProgress = math.floor(CurrentPlaceInProgress)

    itm.ContentFilledLabel.Text = "Content Filled: "..CurrentPlaceInProgress.."%"
    itm.ContentFilledHTMLBar.HTML = ProgressBarHTML(CurrentPlaceInProgress)
end

--Updates the big UI Timecode, counts from the start of the timeline but counts from the start marker if found.
local function UpdateUITimecode(itm)
    local StartFrame = RemoveStartFrame(timeline:GetStartFrame())

    if timeline:GetMarkerByCustomData(StartMarkerData) then StartFrame = MarkerFrame end 

    local PlayheadFrame = GetCurrentFrame()

    local Seconds = math.max((PlayheadFrame - StartFrame)/timeline:GetSetting("timelineFrameRate"),0)
    itm.TimeFromStartAtPlayHead.Text = disp_time(Seconds, true)
end

--Gets how much content (from the raw cut) you have edited down.
local function ContentProccessed(itm)
    local FrameDiff = EndFrame_Start - RemoveStartFrame(timeline:GetEndFrame())
    local Seconds = math.max(FrameDiff/timeline:GetSetting("timelineFrameRate"),0)

    itm.ProccessedFootage.Text = "Proccessed: "..disp_time(Seconds, true)
end

--Adds script main buttons/reset buttons via indexes.
--Also adds saved script names if data is found
local function AddScriptBox(ui, boxIndex)
    local ScriptText = "No Script Selected"
    if Data["Script_"..boxIndex.."_Name"] then ScriptText = Data["Script_"..boxIndex.."_Name"] end

    local box = ui:HGroup{
        ui:Button{
            ID = "ScriptReset_"..boxIndex,
            Text = "X",
            FixedSize = {40, 40},
            Alignment = {
                AlignVCenter = true,
            },
        },
        ui:Button{
            ID = "Script_"..boxIndex,
            Text = ScriptText,
            FixedSize = {175, 40},
            Alignment = {
                AlignVCenter = true,
            },
        },
    }
    return box
end

--Adds folder main buttons/reset buttons via indexes.
--Also adds saved folder paths if data is found
local function AddFolderBox(ui, boxIndex)
    local FolderText = "No Folder Selected"
    if Data["Folder_"..boxIndex.."_Name"] then FolderText = Data["Folder_"..boxIndex.."_Name"] end

    local box = ui:HGroup{
        ui:Button{
            ID = "FolderReset_"..boxIndex,
            Text = "X",
            FixedSize = {20, 20},
            Alignment = {
                AlignVCenter = true,
                AlignHCenter = true,
            },
        },
        ui:Button{
            ID = "Folder_"..boxIndex,
            Text = FolderText,
            FixedSize = {190, 20},
            Alignment = {
                AlignVCenter = true,
                AlignHCenter = true,
            },
        },
    }
    return box
end

--Gets the total amount of clips in the timeline, counts only track one if choosen (variable at the top)
local function GetTotalClipCount()
    if OnlyCountTrackOne then return #timeline:GetItemListInTrack("video", 1) end

    local trackCount = timeline:GetTrackCount("video")
    local totalClips = 0

    for trackIndex = 1, trackCount do
        local ItemList = timeline:GetItemListInTrack("video", trackIndex)

        for k, item in ipairs(ItemList) do
            local endFrame = RemoveStartFrame(item:GetEnd())
                if endFrame > MarkerFrame then totalClips = totalClips + 1 end
        end
    end

    return totalClips
end

--Finds the Frame ID of the start marker, Only used for the TenSecondUpdate
local function FindStartMarker()
    local allMarkers = timeline:GetMarkers()
    
    for frame,info in pairs(allMarkers) do
        if info.customData == StartMarkerData then MarkerFrame = frame break end
    end
end

--Finds the Frame ID of the end marker, Only used for the TenSecondUpdate
local function FindEndMarker()
    local allMarkers = timeline:GetMarkers()

    for frame,info in pairs(allMarkers) do
        if info.customData == EndMarkerData then EndMarkerFrame = frame break end
    end
end

--Returns true/false based on if the StartMarker exists on the timeline
local function CheckIfStartMarkerExists()
    if timeline:GetMarkerByCustomData(StartMarkerData) then return true end
    return false
end

--Returns true/false based on if the EndMarker exists on the timeline
local function CheckIfEndMarkerExists()
    if timeline:GetMarkerByCustomData(EndMarkerData) then return true end
    return false
end

--Updates:
--*Updates the current timeline
--*Timeline framerate in UI
--*Window title project-timeline name
--*The Total Clip Count in UI
local function TenSecondUpdate(itm, win)
    timeline = proj:GetCurrentTimeline()
    
    FindStartMarker()
    FindEndMarker()

    itm.TimelineFramerate.Text = "Timeline Framerate: "..timeline:GetSetting("timelineFrameRate")
    win.WindowTitle = WindowTitleStart..'\''..proj:GetName().."-"..timeline:GetName()..'\''

    local clipCount = GetTotalClipCount()
    itm.ClipCountInTimeline.Text = ClipCountText..clipCount

    --Updates the Data's project and timeline names
    if proj then Data.Project = proj:GetName() end
    if timeline then Data.Timeline = timeline:GetName() end
    Data.ClipCount = clipCount
end

--Fixes the visual parts of the UI Timer at startup, deals with the loaded data
local function FixUITimerAtStartup(itm)
    if UI_Timer_Elapsed == 0 then 
        itm.TimerText.Text = "--:--:--"
    else
        itm.TimerText.Text = disp_time(UI_Timer_Elapsed, true)
    end
end

--Updates the timer, uses os.clock to be more accurate
local function UpdateTimer(itm)
    UI_Timer_Elapsed = os.clock() - UI_Timer_OSClock
    itm.TimerText.Text = disp_time(UI_Timer_Elapsed, true)
    Data.UI_Timer_Elapsed = UI_Timer_Elapsed
end

--UI Timer, Start/Stop Function
local function MainTimer(ui, itm)
    if IsTimerRunning then 
        UI_Timer_Elapsed = os.clock() - UI_Timer_OSClock
        itm.Timer_StartStop.Text = "Start Timer"
        IsTimerRunning = false
    else 
        UI_Timer_OSClock = os.clock() - UI_Timer_Elapsed
        itm.Timer_StartStop.Text = "Stop Timer"
        IsTimerRunning = true
    end
end

--Just stops the timer, used for the render job button.
local function StopMainTimer(itm)
    UI_Timer_Elapsed = os.clock() - UI_Timer_OSClock
    itm.Timer_StartStop.Text = "Start Timer"
    IsTimerRunning = false
end

local function StartMainTimer(itm)
    UI_Timer_OSClock = os.clock() - UI_Timer_Elapsed
    itm.Timer_StartStop.Text = "Stop Timer"
    IsTimerRunning = true
end

--If there is a CSV Folder Path, save the data to it and display a visual message
local function CSVHandleButton(itm)
    if Data.CSVFolderPath then
        SaveTableToDataFile(Data.CSVFolderPath, Data)
        itm.CSVSave_SideLabel.Text = "Saved CSV To File"
        itm.CSVSave_SideLabel.Visible = true
    end
end

--Incase you decide to render multiple clips of the same name within the same render session
local NotYetRenderedCount = 0

--Makes sure that no file can be exported with the same name (adds a number to the name, before the .ext)
--There is some scenarios where you can export an already existing file if you delete render jobs/files during script use
--Might fix that at some point but this is good enough for now.
local function AddRenderNameSuffixNumber(RenderDirectory, RenderFileName)
    local fileName_Attempts = 0
    local fileCount = 0
    while true do
        local path, name, ext = DeconstructFilepath(RenderDirectory..RenderFileName, true)

        local combinedPathName = path..name
        local path = combinedPathName.."_"..fileCount.."."..ext

        if not FileExists(path) then 
            return name.."_"..(fileCount+NotYetRenderedCount).."."..ext
        end

        fileCount = GetFileCount(path, name.."_"..fileCount, fileName_Attempts)
        fileName_Attempts = fileName_Attempts + 1
    end
end

--Adds a render job with the current settings and preset
local function AddRenderJob(itm)
    local frameStart = timeline:GetStartFrame()
    if CheckIfStartMarkerExists() then frameStart = timeline:GetStartFrame() + MarkerFrame end

    local frameEnd = timeline:GetEndFrame()
    if CheckIfEndMarkerExists() then frameEnd = timeline:GetStartFrame() + EndMarkerFrame end

    --Ensures that you cant render without the Render Directory text field being filled up, even if Data contains the path
    local RenderDirectory = ""
    if itm.RenderPath.Text ~= "" then RenderDirectory = itm.RenderPath.Text else return end

    --Ensures that you cant render without the Render Name text field being filled up, even if Data contains the name
    local RenderFileName = ""
    if itm.RenderCustomName.Text ~= "" then RenderFileName = itm.RenderCustomName.Text else return end

    RenderFileName = AddRenderNameSuffixNumber(RenderDirectory, RenderFileName)

    local settings = {
        SelectAllFrames = false,
        TargetDir = RenderDirectory,
        MarkIn = frameStart,
        MarkOut = frameEnd,
        CustomName = RenderFileName,
    }
    proj:SetRenderSettings(settings)
    
    proj:AddRenderJob()
    NotYetRenderedCount = #proj:GetRenderJobList()
    if SwitchBackToEditPage then resolve:OpenPage("edit") end
end

local function AddCounterBox(ui, boxIndex, leftLabel)

    local counterBox = ui:HGroup{
        Weight = 0,
        ui:Button{
            ui:VGap(5),
            ID = "Counter_"..boxIndex.."_Reset",
            Text = "Reset",
            FixedSize = { 55, 25 },
            Alignment = {
                AlignHCenter = true,
            },
        },
        ui:Button{
            ID = "Counter_"..boxIndex.."_PlusOne",
            Text = "+1",
            FixedSize = { 50, 25 },
        },
        ui:Button{
            ID = "Counter_"..boxIndex.."_MinusOne",
            Text = "-1",
            FixedSize = { 50, 25 },
        },
        ui:HGap(4),
        ui:Label{
            ID = "Counter_"..boxIndex.."",
            Text = "0        ",
            Font = ui:Font{
                PixelSize = 20,
                Bold = true,
            },
            Geometry = { 80, 120, 300, 200 },
            Weight = 0,
        },
        ui:HGap(3),
        leftLabel,
    }
    return counterBox
end

--Adds all the UI elements into one window and returns it.
local function WindowElements(disp, ui)
    local width, height = 600, 646 + NoteSize --611
    local TopBoxWidth, TopBoxHeight = 325, 200

    --The one and only allowed "ui:Timer"
    HeadTimer = ui:Timer({ 
        ID = "HeadTimer", 
        Interval = MainTimerInterval,
    })

    --Ensures that if no timeline exists, it gets the "default?" timeline name
    local TimelineWindowName = "Timeline 1"
    if timeline then TimelineWindowName = timeline:GetName() end
    
    local Counter_1_Label = ui:Label{
        ID = "Counter_1_Label",
        Text = "Diff:          ",
        Font = ui:Font{
            PixelSize = 15,
        },
        Geometry = { 80, 120, 300, 200 },
        Weight = 0,
    }
    local Counter_2_Label = ui:Label{
        ID = "Counter_2_Label",
        Text = "Sum:        ",
        Font = ui:Font{
            PixelSize = 15,
        },
        Geometry = { 80, 120, 300, 200 },
        Weight = 0,
    }

    local win = disp:AddWindow({
        ID = 'MainWindow',
        --Sets the window title to the current project and timeline
        WindowTitle = WindowTitleStart..'\''..proj:GetName().."-"..TimelineWindowName..'\'',

        Geometry = {750, 450, width, height},
        Spacing = 10,
        
        ui:VGroup{
            ID = 'root',
            HeadTimer,
            ui:HGroup{
                Weight = 0,
                ui:VGroup{
                    ID = "LeftButtons",
                    Weight = 0,
                    --Script and folder buttons
                    ui:VGroup{
                        ID = "Scripts_And_Folders",
                        Weight = 0,
    
                        --Add all the script buttons via indexes
                        AddScriptBox(ui, 1),
                        AddScriptBox(ui, 2),
                        AddScriptBox(ui, 3),
                        AddScriptBox(ui, 4),
                        AddScriptBox(ui, 5),
                        AddScriptBox(ui, 6),
    
                        --Seperator between script/folder
                        ui:Label{
                            ID = "Script_Folder",
                            Text = "──────────────────────────",
                            Alignment = {
                                AlignVCenter = true,
                            },
                        },
                        
                        --Add all the folder buttons via indexes
                        AddFolderBox(ui, 1),
                        AddFolderBox(ui, 2),
                        AddFolderBox(ui, 3),
                        AddFolderBox(ui, 4),
                    },
                },
                ui:VGroup{
                    ID = "RightSide",
                    Weight = 0,

                    --Main Information frame, uses HTML to get a nicer background for easier text readability
                    ui:TextEdit{
                        ID = "Frame",
                        ReadOnly = true,
                        FixedSize = {TopBoxWidth, TopBoxHeight},
                        --hej ris
                        HTML = "<style>div{background-color:#1A1A1A;height:300px;width:200px}</style><div><br><br><br><br><br><br><br><br><br><br></div>", 

                        ui:Label{
                            ID = "TimeFromStartAtPlayHead_Label",
                            Text = "Start > Playhead",
                            Font = ui:Font{
                                PixelSize = 15,
                            },
                            Geometry = { 0, 7, TopBoxWidth, TopBoxHeight},
                            Alignment = {
                                AlignVCenter = false,
                                AlignHCenter = true,
                            },
                        },
                        ui:Label{
                            ID = "TimeFromStartAtPlayHead",
                            Text = "00:00:00",
                            Weight = 0,
                            Font = ui:Font{
                                PixelSize = 40,
                                Bold = true,
                            },
                            Geometry = { 0, 20, TopBoxWidth, TopBoxHeight },
                            Alignment = {
                                AlignVCenter = false,
                                AlignHCenter = true,
                            },
                        },

                        ui:Label{
                            ID = "TimelineFramerate",
                            Text = "Timeline Framerate: --",
                            Font = ui:Font{
                                PixelSize = 15,
                                Bold = true,
                            },
                            Geometry = { 0, 75, TopBoxWidth, TopBoxHeight },
                            Alignment = {
                                AlignVCenter = false,
                                AlignHCenter = true,
                            },
                        },

                        ui:Label{
                            ID = "ClipCountInTimeline",
                            Text = "Total Amount Of Clips: --",
                            Font = ui:Font{
                                PixelSize = 15,
                                Bold = true,
                            },
                            Geometry = { 0, 100, TopBoxWidth, TopBoxHeight },
                            Alignment = {
                                AlignVCenter = false,
                                AlignHCenter = true,
                            },
                        },

                        ui:Label{
                            ID = "TimerText",
                            Text = "--:--:--",
                            Font = ui:Font{
                                PixelSize = 40,
                                Bold = true,
                            },
                            Geometry = { 0, 120, TopBoxWidth, TopBoxHeight },
                            Alignment = {
                                AlignVCenter = false,
                                AlignHCenter = true,
                            },
                        },
                    },

                    --Three buttons under Main Information
                    ui:HGroup{
                        Weight = 0,
                        ui:Button{
                            ID = "Timer_StartStop",
                            Text = "Start Timer",
                        },
                        ui:Button{
                            ID = "Timer_Reset",
                            Text = "Reset Timer",
                        },
                        ui:Button{
                            ID = "Timer_Combo",
                            Text = "Start Editing",
                        },
                    },

                    --Counter UI Group
                    ui:VGroup{
                        AddCounterBox(ui, 1, Counter_1_Label),
                        AddCounterBox(ui, 2, Counter_2_Label),
                    },
                    
                    --Add Start/End Markers
                    ui:HGroup{
                        Weight = 0,
                        ui:Button{
                            ID = "AddStartMarker",
                            Text = "Add Start Marker",
                        },
                        ui:Button{
                            ID = "AddEndMarker",
                            Text = "Add End Marker",
                        },
                    },

                    ui:VGap(3),

                    --Render UI Group:
                    ui:HGroup{
                        Weight = 0,
                        ui:Button{
                            ID = "Render_Button",
                            Text = "Add Render Job",
                        },
                        ui:Button{
                            ID = "FolderRenderPath",
                            Text = ".../",
                            FixedSize = { 40, 20 }
                        },
                        ui:ComboBox{
                            ID = "RenderPresets",
                            Text = "Render Preset",
                        },
                    },
                    ui:HGroup{
                        Weight = 0,
                        ui:LineEdit{
                            ID = "RenderPath",
                            Text = RenderDir,
                            PlaceholderText = "Target Dir",
                        },
                        ui:LineEdit{
                            ID = "RenderCustomName",
                            Text = RenderName,
                            ClearButtonEnabled = true,
                            PlaceholderText = "VideoName.Extension",
                            FixedSize = { 153, 20 }
                        }
                    }
                },
            },

            --TargetMinutes, Start Progression & Proccessed Group
            ui:HGroup{
                ID = 'progress_group',
                Weight = 0,

                ui:LineEdit{
                    ID = "Progression_TargetMinutes",
                    Text = DefaultTargetMinute,
                    PlaceholderText = "Length",
                    FixedSize = {50, 20},
                },
                ui:Button{
                    ID = "Progression_Start",
                    Text = "Start Progressbar",
                    FixedSize = {125, 25},
                },
                ui:Label{
                    ID = "ProccessedFootage",
                    Text = "Proccessed: --:--:--",
                    Font = ui:Font{
                        PixelSize = 20,
                        Bold = true,
                    },
                    Alignment = {
                        AlignHCenter = true,
                    },
                },
            },

            --Loading Bars with only HTML and their Label title
            ui:VGroup{
                ID = "LoadingBarsAtBottom",
                ui:HGap(15),
                Weight = 0,

                --Video Progression
                ui:Label{
                    ID = "VideoProgressionLabel",
                    Text = "Video Progress: --%",
                    Alignment = {AlignLeft = true},
                    Font = ui:Font{
                        Bold = true,
                    },
                },
                ui:TextEdit{
                    ID = "VideoProgressionHTMLBar",
                    ReadOnly = true,
                    FixedSize = { 520, 30 },
                },

                --Content Filled Progression
                ui:Label{
                    ID = "ContentFilledLabel",
                    Text = "Content Filled: --%",
                    Alignment = {AlignLeft = true},
                    Font = ui:Font{
                        Bold = true,
                    },
                },
                ui:TextEdit{
                    ID = "ContentFilledHTMLBar",
                    ReadOnly = true,
                    FixedSize = {520, 30 },
                },
            },
            --Note UI Things:
            ui:Label{
                ID = "NotesLabel",
                Text = "Notes:",
                Alignment = {AlignLeft = true},
                Font = ui:Font{
                    Bold = true,
                },
            },
            ui:TextEdit{
                ID = "Notes",
                Text = Data.Notes,
                PlaceholderText = "Write your notes in here!",
                FixedSize = { width-50, NoteSize },
            },
            --CSV UI Things:
            ui:HGroup{
                ui:Button{
                    ID = "SaveDataToCSV_Button",
                    Text = "Save To CSV",
                    Alignment = { AlignLeft = true },
                    FixedSize = {100, 20},
                },
                ui:HGap(5),
                ui:Button{
                    ID = "OpenCSVFolder_Button",
                    Text = "CSV Folder",
                    FixedSize = {100, 20},
                },
                ui:Button{
                    ID = "CSVFolderReset_Button",
                    Text = "X",
                    FixedSize = { 20, 20},
                },
                ui:HGap(5),
                ui:Label{
                    ID = "CSVSave_SideLabel",
                    Text = "Saved CSV To File",
                    Visible = false,
                },
                ui:Button{
                    ID = "OpenSavePath_Button",
                    Text = "Open SavePath",
                    
                    Alignment = { AlignRight = true },
                    FixedSize = {100, 20},
                },
                ui:HGap(25),
            },
            ui:VGap(5),
            --Profile Buttons etc.
            ui:HGroup{
                ui:Label{
                    ID = "ProfileCosmetic_Text",
                    Text = "Change Profile >",
                    FixedSize = {100, 20},
                },
                ui:ComboBox{
                    ID = "Profiles_Combobox",
                    Text = "Profiles",
                    FixedSize = {130, 20},
                },
                ui:HGap(5),
                ui:Button{
                    ID = "RemoveProfile_Button",
                    Text = "Del",
                    FixedSize = { 30, 20 },
                },
                ui:LineEdit{
                    ID = "NewProfileName_LineEdit",
                    PlaceholderText = "Profile Name",
                    FixedSize = {130, 20},
                },
                ui:Button{
                    ID = "CreateNewProfile_Button",
                    Text = "Create New Profile",
                    FixedSize = {130, 20},
                },
            },
        },
    })

    return win
end

--Adds all the current render presets in your davinki to a combo box (drop-down)
local function AddRenderPresetsToCombo(itm)
    local renderPresetList = proj:GetRenderPresetList()

    for index, preset in ipairs(renderPresetList) do itm.RenderPresets:AddItem(preset) end
end

--Adds all the current profiles in GlobalData to a combo box (drop-down)
local function AddProfilesToCombo(itm)
    itm.Profiles_Combobox:Clear() --makes sure its empty before adding everything.
    for i, profile in ipairs(GlobalData.Profiles) do itm.Profiles_Combobox:AddItem(profile) end

    local index = IndexOf(GlobalData.Profiles, GlobalData.SelectedProfile)
    if index == nil then index = 0 else index = index -1 end

    itm.Profiles_Combobox.CurrentIndex = index
end

--Handles UI-Element Buttons Etc.
local function WindowDynamics(win, itm, ui, disp)

    --Saves the updates target minute to Data
    function win.On.Progression_TargetMinutes.TextChanged(ev)
        Data.TargetMinutes = itm.Progression_TargetMinutes.Text
    end

    --Starts Counting The Video Progression
    function win.On.Progression_Start.Clicked(ev)
        StartVideoProgress()
    end

    --Starts/Stops The Timer
    function win.On.Timer_StartStop.Clicked(ev)
        MainTimer(ui, itm)
    end

    --Resets All The Variables And The Timer Completely
    function win.On.Timer_Reset.Clicked(ev)
        IsTimerRunning = false
        UI_Timer_Elapsed = 0
        Data.UI_Timer_Elapsed = 0
        UI_Timer_OSClock = 0
        itm.TimerText.Text = "--:--:--"
        itm.Timer_StartStop.Text = "Start Timer"
    end

    --Handles The "Start Editing" Button, Basically Clicks Multiple Buttons In One
    function win.On.Timer_Combo.Clicked(ev)
        if not IsEditing then
            AddStartMarker()
            StartVideoProgress()
            StartMainTimer(itm)
            itm.Timer_Combo.Text = "Stop Editing"
            IsEditing = true
        else
            AddEndMarker()
            CSVHandleButton(itm)
            StopMainTimer(itm)
            AddRenderJob(itm)
            itm.Timer_Combo.Text = "Start Editing"
            IsEditing = false
        end
    end

    --Handles Render UI Elements--

    --Loads The Current Preset Index When It Changes
    function win.On.RenderPresets.CurrentIndexChanged(ev)
        local currentBoxIndex = itm.RenderPresets.CurrentIndex + 1
        local renderPresetList = proj:GetRenderPresetList()
        Data.RenderPresetIndex = currentBoxIndex

        proj:LoadRenderPreset(renderPresetList[currentBoxIndex])
        if SwitchBackToEditPage then resolve:OpenPage("edit") end
    end

    --Change Profile
    function win.On.Profiles_Combobox.CurrentIndexChanged(ev)
        if GlobalData.SelectedProfile == GlobalData.Profiles[itm.Profiles_Combobox.CurrentIndex+1] then return end

        --Save the current script before reloading
        table.save(Data, SavePath)

        --Changes the global data profile and saves it for the reload
        GlobalData.SelectedProfile = GlobalData.Profiles[itm.Profiles_Combobox.CurrentIndex+1]
        table.save(GlobalData, GlobalDataFullPath)

        --Exits the UI Loop and sets restarting to true
        restartScript = true
        disp:ExitLoop()
    end

    --Creates a new profile and saves it
    function win.On.CreateNewProfile_Button.Clicked(ev)
        if not itm.NewProfileName_LineEdit.Text or itm.NewProfileName_LineEdit.Text == "Standard" or TableContains(GlobalData.Profiles, itm.NewProfileName_LineEdit.Text) or itm.NewProfileName_LineEdit.Text == "" then return end
        local profileName = itm.NewProfileName_LineEdit.Text

        table.insert(GlobalData.Profiles, profileName)
        table.save(GlobalData, GlobalDataFullPath)

        --Copies the current settings to the new profile when creating one if CopyPreviousProfile is enabled
        if CopyPreviousProfile then 
            local newDataFile = "Toolbox_"..profileName.."_SaveData.tbl"
            table.save(Data, SavePath_Prefix..newDataFile)
        end

        AddProfilesToCombo(itm)
    end

    --Removes a profile and delete its data
    function win.On.RemoveProfile_Button.Clicked(ev)
         if not itm.NewProfileName_LineEdit.Text or itm.NewProfileName_LineEdit.Text == "Standard" then return end
         local profileName = itm.NewProfileName_LineEdit.Text

         local profileIndex = IndexOf(GlobalData.Profiles, profileName)
         if profileIndex == nil then return end
         table.remove(GlobalData.Profiles, profileIndex)
         table.save(GlobalData, GlobalDataFullPath)

         local ResetDataFile = "Toolbox_"..itm.NewProfileName_LineEdit.Text.."_SaveData.tbl"
         table.save({}, SavePath_Prefix..ResetDataFile)

         if GlobalData.SelectedProfile == profileName then Data = {} end

         AddProfilesToCombo(itm)
    end

    --Adds The Current Settings And Render Settings As a New Job
    function win.On.Render_Button.Clicked(ev)
        AddRenderJob(itm)
    end

    --Prompts The User For a Folder Path
    function win.On.FolderRenderPath.Clicked(ev)
        local selectedPath = tostring(fu:RequestDir(RenderDir))
        RenderDir = selectedPath
        itm.RenderPath.Text = RenderDir
        Data.RenderPath = RenderDir
    end
    
    --Specifies The Render File Name (With Extension)
    function win.On.RenderCustomName.TextChanged(ev)
        RenderName = itm.RenderCustomName.Text
        Data.RenderName = RenderName
    end
    --#####

    --Counter Button Handling--
    --Counter_1:
    function win.On.Counter_1_PlusOne.Clicked(ev)
        Counter_1 = Counter_1 + 1
        UpdateCounter(itm)
    end

    function win.On.Counter_1_MinusOne.Clicked(ev)
        Counter_1 = Counter_1 - 1
        UpdateCounter(itm)
    end

    function win.On.Counter_1_Reset.Clicked(ev)
        Counter_1 = 0
        UpdateCounter(itm)
    end

    --Counter_2:
    function win.On.Counter_2_PlusOne.Clicked(ev)
        Counter_2 = Counter_2 + 1
        UpdateCounter(itm)
    end

    function win.On.Counter_2_MinusOne.Clicked(ev)
        Counter_2 = Counter_2 - 1
        UpdateCounter(itm)
    end

    function win.On.Counter_2_Reset.Clicked(ev)
        Counter_2 = 0
        UpdateCounter(itm)
    end
    --#####

    --Handles Add Start Marker Button
    function win.On.AddStartMarker.Clicked(ev)
        AddStartMarker()
    end

    --Handles Add End Marker Button
    function win.On.AddEndMarker.Clicked(ev)
        AddEndMarker()
    end

    --#####
    --Script Buttons--

    --Handles The Script Buttons And Runs The Current Script, If No Script Is Set: It Asks For a .Lua File
    local function ScriptMainButton(WhoScript, WhoScriptName)
        itm[WhoScript].Enabled = false
        if not Data[WhoScript] then 
            Data[WhoScript] = tostring(fu:RequestFile('Scripts:/Edit', "", {FReqB_SeqGather = true, FReqS_Filter = "Open LUA Files (*.lua)|*.lua", FReqS_Title = "Choose .lua file"})) 
            Data[WhoScriptName] = GetFilename(Data[WhoScript])
            itm[WhoScript].Text = Data[WhoScriptName]
            itm[WhoScript].Enabled = true
            return --Don't wanna run the script when setting it.
        end
        dofile(Data[WhoScript])
        itm[WhoScript].Enabled = true
    end

    --Resets The Current Script Button And It's Data
    local function ScriptResetButton(WhoScript, WhoScriptName)
        if Data[WhoScript] then 
            Data[WhoScript] = nil 
            Data[WhoScriptName] = nil
            itm[WhoScript].Text = "No Script Selected"
        end
    end

    --Creates 6 Button Functions For Button Handling & Button Reset
    for i = 1, 6 do
        local scriptName = "Script_"..i
        win.On[scriptName].Clicked = function(ev)
            ScriptMainButton(ev.who, ev.who.."_Name")
        end
        win.On["ScriptReset_"..i].Clicked = function(ev)
            ScriptResetButton(scriptName, scriptName.."_Name")
        end
    end
    --#####
    --Folder Buttons

    --Handles the folder buttons and opens the current folder, if no folder is set: it asks for the directory
    local function FolderMainButton(WhoFolder, WhoFolderName)
        if not Data[WhoFolder] then
            Data[WhoFolder] = tostring(fu:RequestDir('Scripts:/Edit'))
            Data[WhoFolderName] = GetLastFolderInPath(Data[WhoFolder])
            itm[WhoFolder].Text = Data[WhoFolderName]
            return --Don't wanna open the folder when setting it.
        end
        io.popen([[explorer "]]..Data[WhoFolder]..[["]])
    end

    --resets the current folder button and it's data
    local function FolderResetButton(WhoFolder, WhoFolderName)
        if Data[WhoFolder] then
            Data[WhoFolder] = nil
            Data[WhoFolderName] = nil
            itm[WhoFolder].Text = "No Folder Selected"
        end
    end

    for i = 1, 4 do
        local folderName = "Folder_"..i
        win.On[folderName].Clicked = function(ev)
            FolderMainButton(ev.who, ev.who.."_Name")
        end
        win.On["FolderReset_"..i].Clicked = function(ev)
            FolderResetButton(folderName, folderName.."_Name")
        end
    end

    --Handles the CSV save button interaction
    function win.On.SaveDataToCSV_Button.Clicked(ev)
        CSVHandleButton(itm)
    end

    --Handles the CSV folder buttons and opens the folder, if no folder is set: it asks for the directory
    function win.On.OpenCSVFolder_Button.Clicked(ev)
        if not Data.CSVFolderPath then
                Data.CSVFolderPath = tostring(fu:RequestDir('Scripts:/Edit')) 
            return --Don't wanna open the folder when setting it.
        end
        io.popen([[explorer "]]..Data.CSVFolderPath..[["]])
    end

    --resets the CSV folder data
    function win.On.CSVFolderReset_Button.Clicked(ev)
        if Data.CSVFolderPath then 
            Data.CSVFolderPath = nil

            itm.CSVSave_SideLabel.Text = "Reset CSV Folder Path"
            itm.CSVSave_SideLabel.Visible = true
        end
    end

    --Saves the notes to Data
    function win.On.Notes.TextChanged(ev)
        Data.Notes = itm.Notes.PlainText
    end

    --Opens the folder and selects the Save Data File
    function win.On.OpenSavePath_Button.Clicked(ev)
        io.popen([[explorer /select, "]]..SavePath:gsub("/","\\")..[["]])
    end

end

local function CreateWindow()
    --UI Setup
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)

    --Creates All The UI Elements
    local win = WindowElements(disp, ui)
    local itm = win:GetItems()

    --Close The Window And Save The Data
    function win.On.MainWindow.Close(ev)
        table.save(Data, SavePath)
    	disp:ExitLoop()
    end

    --Init Function Call So It Updates Directly When Opening The Program
    TenSecondUpdate(itm, win)
    GetVideoProgress(itm)
    GetContentFilledProgress(itm)
    ContentProccessed(itm)
    UpdateUITimecode(itm)

    --Add Combo Items To Render Preset
    AddRenderPresetsToCombo(itm)
    --Sets the index to default
    itm.RenderPresets.CurrentIndex = RenderPresetDefaultIndex

    --Add Profiles to the profiles combo
    AddProfilesToCombo(itm)

    --Update Things Inside Of This
    local ProgressionCurrentTimer = 0
    local TenSecondCurrentTimer = 0

    function disp.On.Timeout(ev)
        --These things should only be ran "once" but inside the timeout, it just works this way okay
        if not FirstTimerRan then
            if timeline then Data.ClipCount = GetTotalClipCount() end
            resolve:OpenPage("edit")
            SwitchBackToEditPage = true
            UpdateCounter(itm)
            FixUITimerAtStartup(itm)
            if Data.RenderPresetIndex and UseLastPresetWhenStarting then itm.RenderPresets.CurrentIndex = Data.RenderPresetIndex - 1 end
        end

        ProgressionCurrentTimer = ProgressionCurrentTimer + 1
        TenSecondCurrentTimer = TenSecondCurrentTimer + 1

        --GUI Timer If It's Running
        if IsTimerRunning then UpdateTimer(itm) end

        --Functions Only Happening Each ProgressionRollover*100 (1 Seconds)
        if ProgressionCurrentTimer >= ProgressionRollover then
            ProgressionCurrentTimer = 0 -- Reset

            GetVideoProgress(itm)
            GetContentFilledProgress(itm)
            ContentProccessed(itm)
        end

        --Functions Only Happening Each TenSecondTimerRollover*100 (10 Seconds)
        if TenSecondCurrentTimer >= TenSecondTimerRollover then
            TenSecondCurrentTimer = 0 -- Reset
            TenSecondUpdate(itm, win)

            --Removes the visibility of the side label for CSV
            if itm.CSVSave_SideLabel.Visible then itm.CSVSave_SideLabel.Visible = false end
        end
        
        NotYetRenderedCount = #proj:GetRenderJobList()

        UpdateUITimecode(itm)
        FirstTimerRan = true
    end

    -- Handles all the element events
    WindowDynamics(win, itm, ui, disp)

    HeadTimer:Start()

    --GUI Loop
    win:Show()
    disp:RunLoop()
    win:Hide()
end

-- Main Entry Point
local function Main()
    --Setup before Creating the UI
    AddMarkerFrameAtStart()
    AddEndMarkerFrameAtStart()

    --Creates all the UI and respons to the user 
    --and never exits this unless UI is closed
    CreateWindow()
end

Main()

--"Restarts" the script
if restartScript then 
    restartScript = false
    goto Start 
end

::EndScript::
