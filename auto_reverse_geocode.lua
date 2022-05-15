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

local MODULE_NAME = "auto_reverse_geocode"

local dt = require "darktable"
local du = require "lib/dtutils"
local filelib = require "lib/dtutils.file"
dt.print_log('loading auto_reverse_geocode (git)')

du.check_min_api_version("7.0.0", MODULE_NAME) 

-- return data structure for script_manager
local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

local PS = dt.configuration.running_os == "windows" and "\\" or "/"
local gettext = dt.gettext
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain(MODULE_NAME,dt.configuration.config_dir..PS .. "lua" .. PS .. "locale" .. PS)

local function _(msgid)
    return gettext.dgettext(MODULE_NAME, msgid)
end

-- run command and retrieve stdout
local function run_command_and_get_stdout(cmd)
   dt.print_log(cmd)
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
   local nominatim_script = dt.preferences.read(MODULE_NAME, "reverse_geocode_python_script", "file")
   if nominatim_script == "" then
      dt.print_log(_("reverse geocode python script script not configured"))
      dt.print(_("reverse geocode python script script not configured"))
      return
   end
   local location_prefix = dt.preferences.read(MODULE_NAME, "reverse_geocode_location_prefix", "string")
   if location_prefix == "" then
      dt.print_log(_("reverse geocode location prefix not configured. defaulting to 'where"))
      dt.print(_("reverse geocode location prefix not configured. defaulting to 'where"))
      location_prefix = 'where'
   end
   local nominatim_language = dt.preferences.read(MODULE_NAME, "reverse_geocode_nominatim_language", "string")
   if nominatim_language == "" then
      dt.print_log(_("reverse geocode nominatim language not configured. defaulting to 'en"))
      dt.print(_("reverse geocode nominatim language not configured. defaulting to 'en"))
      nominatim_language = 'en'
   end
   local cmd = nominatim_script.." --prefix "..location_prefix.." --lang "..nominatim_language.." "..image.latitude..' '..image.longitude;
   local location = run_command_and_get_stdout(cmd)
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
  local startsecs = os.clock()  -- make sure that a 1 second interval is maintained
  for _,image in pairs(images) do
    images_submitted = images_submitted + 1
    images_processed = images_processed + auto_reverse_geocode_one_image(image)
  end
  dt.print("Applied auto reverse_geocode to " .. images_processed .. " out of " .. images_submitted .. " image(s)")
end

local function destroy()
  dt.destroy_event(MODULE_NAME, "shortcut")
  dt.destroy_event(MODULE_NAME, "post-import-image")
end

-- ----------------------------------------------- Registering events ---
dt.register_event(MODULE_NAME, "shortcut", auto_reverse_geocode_apply,
       "Reverse geocode coordinates to get location")

dt.register_event(MODULE_NAME, "post-import-image",
  auto_reverse_geocode_one_image_event)

-- ------------------------------------- register the new preferences ---
dt.preferences.register(MODULE_NAME, "reverse_geocode_python_script", "file", 
                        _("auto_reverse_geocode: python script for reverse geocoding"), 
                        _("select executable python script for reverse geocoding")  , "")

dt.preferences.register(MODULE_NAME, "reverse_geocode_location_prefix", "string", 
                        _("auto_reverse_geocode: prefix for hierarchical location string"), 
                        _("Determine the location string prefix. Defaults to 'where'.")  , "")

dt.preferences.register(MODULE_NAME, "reverse_geocode_nominatim_language", "string", 
                        _("auto_reverse_geocode: language for Nominatim-retrieved adresses"), 
                        _("Determine the language for the retrieved adresses.")  , "")


script_data.destroy = destroy
return script_data
