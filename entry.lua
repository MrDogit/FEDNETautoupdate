log( "FEDNET Autoupdate log:\n")
_G.FEDNET = {}

FEDNET.key_data = { 	
["00L"] = 	"6d8e4q16v4dbmz5", 
["00R"] = 	"v4qwg30d1az3jz4",
["01L"] =	"al7p3drz1c46hbw",
["01R"] =	"f7w2b5cxl75zjup",
["02L"] =	"52sq5zfamu3pbdg",
["02R"] =	"so7tcf7lifqwg1e",
["03"] =	"sbml8ez4barkxz6",
["04"] =	"aa3oyfjk4aruebw",
["05"] =	"iaif8vkqwqnq179",
["06"] =	"skbumvfcubl8tw4",
["07"] =	"vvisy3ltrqdx08n",
["08"] =	"pug7rklvwmhtfec",
["09"] =	"bdgrg0s5tp6abml",
["11"] =	"4xn8536sbghqwig",
["12L"] =	"e7e1dewk0j6ky8f",
["12R"] =	"rql6kxfcasyl3vy",
}

local mod_folder = ModPath
local file_info_url = "https://www.mediafire.com/api/1.5/file/get_info.php?quick_key="
local hash_table_path = SavePath .. "FEDNET_hash.xml"
local settings_path = SavePath .. "FEDNET_settings.json"

FEDNET.settings = {}

function FEDNETClbk(clss, func, a, b, c, ...) -- Thanks to BeardLib developers
    local f = clss[func]
    if not f then
        log("Function named " .. tostring(func) .. "was not found in the given class")
        return function() end
    end
    if a ~= nil then
        if c ~= nil then
            local args = {...}
            return function(...) return f(clss, a, b, c, unpack(list_add(args, ...))) end
        elseif b ~= nil then
            return function(...) return f(clss, a, b, ...) end
        else
            return function(...) return f(clss, a, ...) end
        end
    else
        return function(...) return f(clss, ...) end
    end
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
					log("[ERROR] [FEDNET Inv] Error while loading, Setting types don't match")
					corrupted = corrupted or true
				end
			end
		end

		local settings = json.decode(file:read("*all"))
		parse_settings(self.settings, settings, {})
		file:close()
	else
		log("[ERROR] [FEDNET Inv] Error while loading, settings file could not be opened (" .. settings_path .. ")")
	end
	if corrupted then
		self:Save()
		log("[ERROR] [FEDNET Inv] Settings file appears to be corrupted, resaving...")
	end
end

function FEDNET:Save()
	if table.size(self.settings or {}) > 0 then
		local file = io.open(settings_path, "w+")
		if file then
			file:write(json.encode(self.settings))
			file:close()
		else
			log("[ERROR] [FEDNET Inv] Error while saving, settings file could not be opened (" .. settings_path .. ")")
		end
	else
		log("[ERROR] [FEDNET Inv] Error while saving, settings table appears to be empty...")
	end
end

function FEDNET:info_page(current_key)
	dohttpreq(file_info_url .. current_key, FEDNETClbk( self, "clbk_info_page" ))
	if not FEDNET:check_hash(key_00L, hash_00L) then
		log("Hash false")
		FEDNET:start_download(current_key)
	else
		log("Hash true")
	end
end

function FEDNET:clbk_info_page(page)
	page = tostring(page)
	local net_hash = tostring(string.match(page, '<hash>(%w+)</hash>')) -- Thanks to Dr_Newbie
	local file = io.open(hash_table_path, "r")
	local file_string = tostring(file:read("*a"))
	local local_hash = tostring(string.match(file_string, '<' .. current_hash .. '>(%w+)</' .. current_hash ..'>'))
	-- self.check_hash
	io.close(file)
end

function FEDNET:check_hash (current_key, current_hash)
	dohttpreq(file_info_url .. current_key,
		function (page)
			page = tostring(page)
			local hash = tostring(string.match(page, '<hash>(%w+)</hash>')) -- Thanks to Dr_Newbie
			local file = io.open(hash_table_path, "r")
			local file_string = tostring(file:read("*a"))
			local local_hash = tostring(string.match(file_string, '<' .. current_hash .. '>(%w+)</' .. current_hash ..'>'))
			io.close(file)
			if hash == local_hash then
				log("hash == local_hash")
				return true
			else
				log("hash != local_hash")
				return false
			end
		end
	)
end

function FEDNET:start_download(current_key)
	dohttpreq(file_info_url .. current_key,
		function(info_page)
			info_page = tostring(info_page)
			local hash = tostring(string.match(page, '<hash>(%w+)</hash>')) -- Thanks to Dr_Newbie
			local download_url = tostring(string.match(info_page, '<normal_download>(.+)</normal_download>'))
			local filename = tostring(string.match(info_page, '<filename>(.+)</filename>'))
			dohttpreq(download_url,
				function(page)
					page = tostring(page)
					local zip_url = tostring(string.match(page, '"Download file" href="(.+)" id="downloadButton">'))
					dohttpreq(zip_url, FEDNETClbk( self, "clbk_download_finished" ), FEDNETClbk( self, "clbk_download_progress"))
				end
			)
		end
	)
end

function FEDNET:clbk_info_page(html)
	local html = tostring(html)
	hash = tostring(string.match(html, '<hash>(%w+)</hash>')) -- Thanks to Dr_Newbie
	download_url = tostring(string.match(html, '<normal_download>(.+)</normal_download>'))
	filename = tostring(string.match(html, '<filename>(.+)</filename>'))
end

function FEDNET:clbk_download_finished(zip, http_id) -- Thanks to BLT developers
	log(http_id .. " download completed successfully")
	local temp_zip = tostring(http_id) .. ".zip"
	local temp_assets = "assets/mod_overrides/FEDNET_autoupdate/"
	local overrides_path = "assets/mod_overrides/"
	-- local cleanup = function() SystemFS:delete_file(temp_assets) end
	
	-- cleanup()
	local f = io.open(temp_zip, "wb+")
	if f then
		f:write(zip)
		f:close()
	end
	
	log("Unzip temp")
	unzip(temp_zip, temp_assets)
	log("Unziped temp")
	-- SystemFS:delete_file(temp_zip)
	
	for i, folder in ipairs(SystemFS:list(temp_assets, true)) do
		log("folder: " .. folder)
		-- file.delete_file(overrides)
		if not file.MoveDirectory(temp_assets .. folder, overrides_path .. folder) then
			log("[ERROR] [FEDNET Inv] Failed to rename!")
		end
	end
	-- cleanup()
end
	

function FEDNET:clbk_download_progress(http_id, bytes, total_bytes)
	log( http_id .. " Downloaded: " .. tostring(bytes) .. " / " .. tostring(total_bytes) .. " bytes")
end


function FEDNET:start_autoupdate()
	local options_file = io.open(settings_path, "r")
	if options_file then
		for i, option in pairs(self.settings) do
			log("i: " .. i .. " option: " .. tostring(option) .. type(option))
			if type(option) == "number" then
				if i == "file00" and option ~= 3 then
					log("START DOWNLOADING(!) " .. i .. " with option: " .. option)
					break
				elseif not option == 3 then
					log("START DOWNLOADING " .. i .. " with option: " .. option)
				end
			elseif type(option) == "boolean" and option == true then
				log("START DOWNLOADING " .. i)
			end
			log("i: " .. i .. " option: " .. tostring(option))
		end
	else
		log("First start?")
		self:Save()
	end
end

	-- FEDNET:start_download(key_00L)
FEDNET:Default_settings()
FEDNET:Load()
FEDNET:start_autoupdate()

-- Init settings menu
local FEDNET_menu_id = "FEDNET_menu"
Hooks:Add("MenuManagerSetupCustomMenus", "MenuManagerSetupCustomMenus_FEDNET", function(menu_manager, nodes)
    MenuHelper:NewMenu( FEDNET_menu_id )
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "MenuManagerPopulateCustomMenus_FEDNET", function(menu_manager, nodes)
	
	local all_btns = {
		{["file00"] = {"Full", "Partial", "Off"}},
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
			log(item:name())
			for _, file in pairs(all_btns) do
				if type(file) == "table" then
					for i in pairs(file) do
						if item:name() == "file00" then
							item:set_enabled(true)
							break
						elseif item:name() == i and FEDNET.settings.file00 == 1 then
							item:set_enabled(false)
						else
							item:set_enabled(true)
						end
					end
				else
					if item:name() == file and FEDNET.settings.file00 == 1 then
						item:set_enabled(false)
					else
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
		log("Saved!")
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

log( "\nEnd of FEDNET Autoupdate log" )