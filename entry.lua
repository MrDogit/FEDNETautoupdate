log( "FEDNET Autoupdate log:\n") -- debug
_G.FEDNET = {}

FEDNET.key_data = { 	
["file00L"] = 	"6d8e4q16v4dbmz5", 
["file00R"] = 	"v4qwg30d1az3jz4",
["file01L"] =	"al7p3drz1c46hbw",
["file01R"] =	"f7w2b5cxl75zjup",
["file02L"] =	"52sq5zfamu3pbdg",
["file02R"] =	"so7tcf7lifqwg1e",
["file03"] =	"sbml8ez4barkxz6",
["file04"] =	"aa3oyfjk4aruebw",
["file05"] =	"iaif8vkqwqnq179",
["file06"] =	"skbumvfcubl8tw4",
["file07"] =	"vvisy3ltrqdx08n",
["file08"] =	"pug7rklvwmhtfec",
["file09"] =	"bdgrg0s5tp6abml",
["file11"] =	"4xn8536sbghqwig",
["file12L"] =	"e7e1dewk0j6ky8f",
["file12R"] =	"rql6kxfcasyl3vy",
}

local mod_folder = ModPath
local file_info_url = "https://www.mediafire.com/api/1.5/file/get_info.php?quick_key="
local hash_file_path = SavePath .. "FEDNET_hash.json"
local settings_path = SavePath .. "FEDNET_settings.json"

FEDNET.settings = {}
FEDNET.downloads = {}

function FEDNETClbk(clss, func, a, b, c, d, ...) -- Thanks to BeardLib developers
    local f = clss[func]
    if not f then
        log("[ERROR] [FEDNET autoupdate] Function named " .. tostring(func) .. "was not found in the given class")
        return function() end
    end
    if a ~= nil then
        if d ~= nil then
            local args = {...}
            return function(...) return f(clss, a, b, c, d, unpack(list_add(args, ...))) end
        elseif c ~= nil then
            return function(...) return f(clss, a, b, c, ...) end
        elseif b ~= nil then
            return function(...) return f(clss, a, b, ...) end
        else
            return function(...) return f(clss, a, ...) end
        end
    else
        return function(...) return f(clss, ...) end
    end
end

function pairsByKeys(t, f) -- Tnanks lua.org
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

function FEDNET:Default_settings()
	FEDNET.settings = {
		file00 = 1,
		file01 = 1,
		file02 = 1,
		file03 = true,
		file04 = true,
		file05 = true,
		file06 = true,
		file07 = true,
		file08 = true,
		file09 = true,
		file11 = false,
		file12 = 3,
	}
end

function FEDNET:Load() -- Thanks to Kamikaze94
	local corrupted = false
	local file = io.open(settings_path, "r")
	if file then
		local function parse_settings(table_dst, table_src, setting_path)
			for k, v in pairs(table_src) do
				if type(table_dst[k]) == type(v) then
					if type(v) == "table" then
						table.insert(setting_path, k)
						parse_settings(table_dst[k], v, setting_path)
						table.remove(setting_path, #setting_path)
					else
						table_dst[k] = v
					end
				else
					log("[ERROR] [FEDNET autoupdate] Error while loading, Setting types don't match")
					corrupted = corrupted or true
				end
			end
		end

		local settings = json.decode(file:read("*all"))
		parse_settings(self.settings, settings, {})
		file:close()
	else
		log("[ERROR] [FEDNET autoupdate] Error while loading, settings file could not be opened (" .. settings_path .. "). Supposedly this is the first launch")
	end
	if corrupted then
		self:Save()
		log("[ERROR] [FEDNET autoupdate] Settings file appears to be corrupted, resaving...")
	end
end

function FEDNET:Save()
	if table.size(self.settings or {}) > 0 then
		local file = io.open(settings_path, "w+")
		if file then
			file:write(json.encode(self.settings))
			file:close()
		else
			log("[ERROR] [FEDNET autoupdate] Error while saving, settings file could not be opened (" .. settings_path .. ")")
		end
	else
		log("[ERROR] [FEDNET autoupdate] Error while saving, settings table appears to be empty...")
	end
end

-- function FEDNET:null()
-- end

function FEDNET:Clbk_download_progress(http_id, bytes, total_bytes) -- debug
	log( http_id .. " Downloaded: " .. tostring(bytes) .. " / " .. tostring(total_bytes) .. " bytes") -- debug
end -- debug

function FEDNET:Clbk_download_finished(option, hash, folder_name, zip) -- Thanks to BLT developers
	log(option .. " (" .. folder_name .. ".zip) downloaded successfully") -- debug
	-- log("option: " .. tostring(option) .. " hash: " .. tostring(hash) .. " folder_name: " .. tostring(folder_name) .. " zip: " .. tostring(zip)) -- debug

	local temp = "mods/downloads/" .. option .. "/"
	local temp_zip = temp .. option .. ".zip"
	local overrides_path = "assets/mod_overrides/"
	local failed = false
	local cleanup = function() SystemFS:delete_file(string.sub(temp, 1, #temp - 1 )) end
	
	cleanup()
	SystemFS:make_dir(temp)
	local f = io.open(temp_zip, "wb+")
	if f then
		f:write(zip)
		f:close()
	end
	
	log("Unzip temp") -- debug
	unzip(temp_zip, temp)
	log("Unziped temp") -- debug
	
	for _, folder in ipairs(SystemFS:list(overrides_path, true)) do
		if folder == folder_name then
			file.MoveDirectory(overrides_path .. folder .. "/", temp .. folder_name .. "_old/")
		end
	end
	if not file.MoveDirectory(temp .. folder_name .. "/", overrides_path .. folder_name .. "/") then
		log("[ERROR] [FEDNET autoupdate] Failed to copy '" .. temp .. folder_name .. "/' to '" .. overrides_path .. folder_name .. "/'")
		failed = true
		file.MoveDirectory(temp .. folder_name .. "_old/", overrides_path .. folder_name .. "/")
	end
	cleanup()
	-- null(option, failed) -- TODO: add deleting over folders (full cleanup)
end

function FEDNET:Clbk_info_page(option, local_hash, page)
	log("Search through info page for " .. option) -- debug
	-- log("\noption: " .. option .. "\nlocal_hash: " .. local_hash .. "\npage: " .. page) -- debug
	local page = tostring(page)
	local hash = tostring(string.match(page, '<hash>(%w+)</hash>')) -- Thanks to Dr_Newbie
	local download_url = tostring(string.match(page, '<normal_download>(.+)</normal_download>'))
	local folder_name = tostring(string.match(page, '<filename>(.+)</filename>'))
	local folder_name = string.sub(folder_name, 1, #folder_name - 4 )
	-- log("\nhash: " .. hash .. "\nlocal_hash: " .. local_hash) -- debug
	table.insert(self.downloads, {[option] = folder_name}) -- TODO: add deleting over  folders
	if hash ~= local_hash then
		log("hash ~= local_hash") -- debug
		dohttpreq(download_url,	function(page)
			page = tostring(page)
			local zip_url = tostring(string.match(page, '"Download file" href="(.+)" id="downloadButton">'))
			dohttpreq(zip_url, FEDNETClbk( self, "Clbk_download_finished", option, hash, folder_name ), FEDNETClbk( self, "Clbk_download_progress")) -- debug (Clbk_download_progress)
		end)
	else -- debug
		-- log("hash == local_hash") -- debug
	end
end

function FEDNET:Find_hash(option, value)
	log("Find hash for " .. option) -- debug
	if value then
		if value == 1 then
			option = option .. "L"
		elseif value == 2 then
			option = option .. "R"
		end
	end
	-- table.insert(self.downloads, {[option] = ""}) -- TODO: add deleting over  folders
	local local_hash = ""
	local hash_file = io.open(hash_file_path , "r")
	if hash_file then
		local local_hash_file = json.decode(hash_file:read("*all"))
		for local_option, hash in pairs(local_hash_file) do
			if local_option == option then
				local_hash = hash
			end
		end
		hash_file:close()
	else
		log("[ERROR] [FEDNET autoupdate] Error while loading, hash file could not be opened (" .. hash_file_path .. "). Supposedly this is the first launch")
	end
	for tablekey, quick_key in pairs(self.key_data) do
		if option == tablekey then
			dohttpreq(file_info_url .. quick_key, FEDNETClbk(self, "Clbk_info_page", option, local_hash))
		end
	end
end

function FEDNET:Start_autoupdate()
	local options_file = io.open(settings_path, "r")
	if options_file then
		options_file:close()
		for option, value in pairsByKeys(self.settings) do
			if type(value) == "number" then
				if option == "file00" and value ~= 3 then
					log("Find hash(!) " .. option .. " with value: " .. value) -- debug
					self:Find_hash(option, value)
					break
				elseif value ~= 3 then
					log("Find hash " .. option .. " with value: " .. value) -- debug
					self:Find_hash(option, value)
				end
			elseif type(value) == "boolean" and value == true then
				log("Find hash " .. option) -- debug
					self:Find_hash(option)
			end
		end
	else
		log("[INFO] [FEDNET autoupdate] Supposedly this is the first launch")
		self:Save()
	end
end

FEDNET:Default_settings()
FEDNET:Load()
FEDNET:Start_autoupdate()

-- Init settings menu
local FEDNET_menu_id = "FEDNET_menu"
Hooks:Add("MenuManagerSetupCustomMenus", "MenuManagerSetupCustomMenus_FEDNET", function(menu_manager, nodes)
    MenuHelper:NewMenu( FEDNET_menu_id )
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "MenuManagerPopulateCustomMenus_FEDNET", function(menu_manager, nodes)
	
	local all_btns = {
		{["file00"] = {"file00L", "file00R", "file00off"}},
		{["file01"] = {"file01L", "file01R", "file01off"}},
		{["file02"] = {"file02L", "file02R", "file02off"}},
		"file03",
		"file04",
		"file05",
		"file06",
		"file07",
		"file08",
		"file09",
		"file11",
		{["file12"] = {"file12L", "file12R", "file12off"}},
	}
	
	function enable_btn()
		local menu = MenuHelper:GetMenu(FEDNET_menu_id) -- Thanks to Hoppip
		for _, item in pairs(menu and menu._items_list or {}) do
			for _, file in pairs(all_btns) do
				if type(file) == "table" then
					for i in pairs(file) do
						if item:name() == "file00" then
							item:set_enabled(true)
							break
						elseif item:name() == i and FEDNET.settings.file00 ~= 3 then
							item:set_enabled(false)
						elseif item:name() == i then
							item:set_enabled(true)
						end
					end
				else
					if item:name() == file and FEDNET.settings.file00 ~= 3 then
						item:set_enabled(false)
					elseif item:name() == file then
						item:set_enabled(true)
					end
				end
			end
		end
	end
	
	for i, btn in pairs(all_btns) do
		if type(btn) == "table" then
			for multi_btn, options in pairs(btn) do
				MenuHelper:AddMultipleChoice({
					id = multi_btn,
					title = multi_btn .. "_title",
					desc = multi_btn .. "_desc",
					callback = multi_btn .. "_clbk",
					items = options,
					value = FEDNET.settings[multi_btn],
					menu_id = FEDNET_menu_id,
					priority = -i,
					disabled_color = Color(0.6, 0.6, 0.6),
				})
				MenuCallbackHandler[multi_btn .. "_clbk"] = function(this, item)
					FEDNET.settings[tostring(item:name())] = item:value()
					if multi_btn == "file00" then
						enable_btn()
					end
				end
			end
		else
			MenuHelper:AddToggle({
				id = btn,
				title = btn .. "_title",
				desc = btn .. "_desc",
				callback = btn .. "_clbk",
				value = FEDNET.settings[btn],
				menu_id = FEDNET_menu_id,
				priority = -i,
				disabled_color = Color(0.6, 0.6, 0.6),
			})
			MenuCallbackHandler[btn .. "_clbk"] = function(this, item)
				local value = (tostring(item:value()) == "on") and true or false
				FEDNET.settings[tostring(item:name())] = value
			end
		end
	end
end)

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenus_FEDNET", function(menu_manager, nodes)
	local back_clbk = "FEDNET_back_clbk"
	MenuCallbackHandler[back_clbk] = function(node)
		log("[INFO] [FEDNET autoupdate] Saved!")
		FEDNET:Save()
	end
	nodes[FEDNET_menu_id] = MenuHelper:BuildMenu( FEDNET_menu_id, { back_callback = back_clbk })
    MenuHelper:AddMenuItem( nodes.blt_options, FEDNET_menu_id, "FEDNET_name", "FEDNET_desc" )
	enable_btn()
end)

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_FEDNET", function(loc)
		local lang = "english"
		for _, filename in pairs(file.GetFiles(mod_folder .. "loc/")) do
			local str = filename:match('^(.*).json$')
			if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
				lang = str
				loc:load_localization_file(mod_folder .. "loc/" .. lang .. ".json")
				break
			end
		end
	end
)

log( "End of FEDNET Autoupdate log\n" ) -- debug