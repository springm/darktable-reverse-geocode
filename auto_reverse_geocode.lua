--[[
Auto_reverse_geocode

Automatically reverse geocode the coordinates of an image after import and add location tags.

AUTHOR
Markus Spring

INSTALATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR
is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "auto_reverse_geocode"

USAGE
*
* if you want to be able to apply it manually to already imported
  images, define a shortcut (lua shortcuts). As I couldn't find an event for
  when a development is removed, so the autostyle won't be applied again, 
  this shortcut is also helpful then
* import your images, or use the shortcut on your already imported images

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* exiftool

LICENSE
GPLv2

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local filelib = require "lib/dtutils.file"
dt.print_log('loading auto_reverse_geocode')

du.check_min_api_version("7.0.0", "auto_reverse_geocode") 

-- return data structure for script_manager
local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

-- run command and retrieve stdout
local function get_stdout(cmd)
  -- Open the command, for reading
  local fd = assert(io.popen(cmd, 'r'))
  dt.control.read(fd)
  -- slurp the whole file
  local data = assert(fd:read('*a'))

  fd:close()
  -- Replace carriage returns and linefeeds with spaces
  -- data = string.gsub(data, '[\n\r]+', ' ')
  -- Remove spaces at the beginning
  data = string.gsub(data, '^%s+', '')
  -- Remove spaces at the end
  data = string.gsub(data, '%s+$', '')
  return data
end

-- Retrieve the location through reverse_nominatim.py
local function nominatim_location(image)
   local cmd = "/home/springm/projekte/python/reverse_nominatim7.py "..image.latitude..' '..image.longitude;
   local location = get_stdout(cmd)
   dt.print_log(location)
   lines = {}
   for s in location:gmatch("[^\r?\n]+") do
      table.insert(lines, s)
   end
   return lines
end

local function attach_tag( ct, image )
   dt.print_log('trying to attach tag ' .. ct)
   local tagnr = dt.tags.find(ct)
   if tagnr == nil then
      tagnr = dt.tags.create(ct)
      dt.print_log('tag created for ' .. ct)
   end
   dt.tags.attach(tagnr,image)
   dt.print_log('tag ' .. ct .. ' attached')
end

local function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function auto_reverse_geocode_one_image(image)
   local has_where_tag = false
   present_image_tags = dt.tags.get_tags(image)
   for _,pt in ipairs(present_image_tags) do
      if startswith(tostring(pt), 'where|') then
         dt.print_log(image.filename .. ' is already geocoded')
         return 0
      end
   end
   if (image.latitude) and (image.longitude) then
      dt.print_log('reverse geocoding ' .. image.filename .. ' (' .. image.latitude ..','..image.longitude..')')
   else
      dt.print_log(image.filename .. ' has no coordinates')
      return 0
   end
   locstring = nominatim_location(image)
   dt.print_log('Locationstring is '..locstring[1])
   local present_image_tags = {}
   
   ct = locstring[1]
   dt.print_log('Checking tag value ' .. ct)
   -- check if image has tags and attach
   if next(present_image_tags) == nil then
      attach_tag(ct, image)
      -- dt.tags.attach(ct,image)
   else
      for _,pt in ipairs(present_image_tags) do
         -- attach tag only if not already attached
         if pt ~= ct then
            attach_tag(ct, image)
            -- dt.tags.attach(ct,image)
         end
      end
   end
   dt.print_log('Done: '..locstring[1])
   return 1
end

-- Receive the event triggered
local function auto_reverse_geocode_one_image_event(event,image)
   auto_reverse_geocode_one_image(image)
end

local function auto_reverse_geocode_apply(shortcut)
  local images = dt.gui.action_images
  local images_processed = 0
  local images_submitted = 0
  for _,image in pairs(images) do
    images_submitted = images_submitted + 1
    images_processed = images_processed + auto_reverse_geocode_one_image(image)
  end
  dt.print("Applied auto reverse_geocode to " .. images_processed .. " out of " .. images_submitted .. " image(s)")
end

local function destroy()
  dt.destroy_event("auto_reverse_geocode", "shortcut")
  dt.destroy_event("auto_reverse_geocode", "post-import-image")
end

-- Registering event
dt.register_event("auto_reverse_geocode", "shortcut", auto_reverse_geocode_apply,
       "Reverse geocode coordinates to get location")

dt.register_event("auto_reverse_geocode", "post-import-image",
  auto_reverse_geocode_one_image_event)

script_data.destroy = destroy
return script_data
