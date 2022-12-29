# DaVinci Toolbox
Your left hand in editing!  
Packed with a bunch of small (but useful and powerful) features.  
Over 1600 Lines Of Lua Code, Tailored Towards More Casual Editing.  
Everything is saved and loaded between script restarts.  

*Only works on windows currently*

**Includes Features Like:**
- 6 Savable Script Buttons
- 4 Savable Folder Buttons
- Information UI  
 Current Playhead Timecode  
 Timeline Framerate  
 Total Amount Of Clips  
- Accurate Timer
- Two Counters (And Their Difference And Sum)
- Start And End Marker Buttons
- Render Buttons  
 Choose Render Preset  
 Choose Render Name  
 Choose Render Filepath  
 Add Render Job  
- Proccessed Increment Label
- Video Progression (Loading Bar)
- Content Filled (Loading Bar)
- Notes
- Save To CSV
- Save Profiles (Saves Your Current Data)

## Installation
Download the newest release or clone the repo.  
Place the .lua file inside `%appdata%\Roaming\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\`  
Find the script inside DaVinci Resolve, Under Workspace>Scripts>Toolbox

It's that easy.   
No Further Setup Required
## UI Breakdown

### Savable Script Buttons
These six buttons is able to run other lua script files.  
If no script is assigned, clicking the "No Script Selected"  
Will prompt you to select a new .lua file to assign to that button.  
Clicking the "X" besides the run button will reset the script it was assigned to.  

### Savable Folder Buttons
These four buttons is able to open folders.  
If no folder is assigned, clicking the "No Folder Selected"  
Will prompt you to select a new folder to assign to that button.  
Clicking the "X" besides the open button will reset the folder it was assigned to.  

### Information UI
This dark-grey box contains useful information while editing.  

At the top is the current timecode.  
This counts from the start of the timeline (Or start marker if one exists)  
And to your current playhead.

Below that is the timeline framerate,  
this is used to calculate many things in the script  
And useful to see incase it's wrong  

And then it's the total amount of clips in the current timeline.  
It will count all video tracks (unless "OnlyCountTrackOne" is set to true).

And at the bottom of the box there is the timer.  
It's very accurate and can be Started/Paused and reset right below it.

There is also a "Start Editing" button right below the box which will  
when clicked, basically click "Start Timer", "Add Start Marker" and "Start Progressbar"  
At the same time. Useful for when you are starting to edit and want to activate everything.  

### Two Counters
These two function the same.  
You have a reset, +1 and -1 for both.  
And a difference and sum labels right of them.

### Start And End Marker Buttons
These markers can't be place manually and must be placed with the script buttons.  
These will be used to calculate a range of things.  
The start marker is meant to be the start of your video (If it's not at the start of the timeline)  
And the end marker is the same but for the end, but incase you don't have anything at the end,  
it won't really matter if the end marker is there.

### Render Buttons
If your render exports are simple enough,  
You will never have to use the render tab again (Except the actual "Render" button)  

Add render job will take the current render settings and add a new render job with them.  
The ".../" button will prompt you to select a render filepath where the final export will be located at.  
The dropdown right next is all your current render presets (Even custom ones), Select one to use it.  
Under the "Add render job" button is the render filepath,  
it will be automatically written to if you used the ".../" button, otherwise it can manually be filled in.  
And lastly, the last text box is for the export file name (With it's correct extension)  

### Proccessed Increment Label
When you click "Start Progressbar" it will take the last frame of the timeline,  
And for every frame you remove from that point will count towards this label in HH:MM:SS

### Video Progression
This includes four UI elements:  
The "Length" text box (Default to 8) is the amount of minutes you want your final edit to be.  
And clicking "Start Progressbar" will take the last frame of the timeline,  
and calculate from the start of the timeline (or start marker if there is one)  
And 8 minutes into the timeline, and the "Video Progression" percentange  
Will change for every frame you cut down until you reach 100% (The target minutes)  
This will also be displayed in a 100 segment loading bar right beneath the percentage

### Content Filled
This works similar to the other loading bar,  
This counts from the start of the timeline (Or start marker if there is one) as 0%  
And the last frame of the timeline (or end marker if there is one) as 100%  
And take your current playheads position as the percentage.  
This lets you see how close you are to your end marker.

### Notes
A simple text box only used to store notes in

### Save To CSV
The "Save To CSV" button wont work unless you have given it a valid filepath.  
The button right next to it, "CSV Folder". When pressed prompt you to select a folder.  
And everytime you Save To CSV, it will create a new file with the current date and time in that folder.  

### Save Profiles
At the bottom you can choose multiple profiles.  
Enter profile name to remove it or to create a new one.  
The script will refresh itself when changing profile.  

## Settings
Settings for the script is changed at the top of the .lua file itself.  
- SavePath (string)  
This setting determines where all the save data for the script will be saved at  
Default: `os.getenv('APPDATA')..[[/Blackmagic Design/DaVinci Resolve/Toolbox_SaveData.tbl]]`
- OnlyCountTrackOne (bool)  
This determines if the total amount of clip calculation will only use track one or all tracks  
Default: `false`

- RenderDir (string)  
This is the default render filepath  
Default: `""`
- UseLastRenderDirWhenStarting (bool)  
If true, it will use the last used render directory when starting, if false it will use RenderDir  
Default: `true`

- RenderName (string)  
This is the default render name  
Default: `Video.mp4`
- UseLastRenderNameWhenStarting (bool)  
If true, it will use the last used render name when starting, if false it will use RenderName  
Default: `true`

- RenderPresetDefaultIndex (int)  
This is the default preset index in the UI preset drop-down  
Default: `5`
- UseLastPresetWhenStarting (bool)  
If true, it will use the last used render preset index when starting, if false it will use RenderPresetDefaultIndex  
Default: `true`

- DefaultTargetMinute (int)  
This is the default target minutes for video progression  
Default: `8`
- UseLastTargetMinuteWhenStarting (bool)  
If true, it will use the last used target minute when starting, if false it will use DefaultTargetMinute  
Default: `true`

- NoteSize (int)  
This determines how big the notes text box is at startup  
Default: `100`

- CopyPreviousProfile (bool)  
This determines if it's gonna copy your current profile data to the new one when creating one  
Default: `true`

**Version 1.2.4 [Public Release] 2022-12-29  14:08 CET**
