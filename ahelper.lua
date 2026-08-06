local encoding = require "encoding"
encoding.default = "CP1251"
u8 = encoding.UTF8

script_name("Advance Helper")
script_author("Louis_Montblanc")

require "lib.moonloader"
local sampev = require "lib.samp.events"

local json = require "dkjson"

local CONFIG_DIR = getWorkingDirectory() .. "\\config"

createDirectory(CONFIG_DIR)

local CONFIG_PATH = CONFIG_DIR .. "\\AdvanceHelper.json"

local playerMenuLastItem = nil

local config = {}

local messages = {}

local helperEnabled
local repairEnabled
local fuelEnabled
local flowersEnabled
local maskSkinId
local spawnSkinId
local advertEnabled
local advertNick

local function split(str, sep)
    local result = {}

    if not str or str == "" then
        return result
    end

    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(result, part)
    end

    return result
end

local function join(tbl)
    return table.concat(tbl or {}, "|")
end

local requests = require("requests")

local UPDATE_URL = "https://raw.githubusercontent.com/freimaurerey/Advance-Helper/main/version.json"

local function defaultConfig()
    return {
		version = "unknown",
	
        settings = {
            helper = true,
            repair = true,
            fuel = true,
			flowers = true,
			maskSkinId = "",
			spawnSkinId = "",
            advert = false,
            advertNick = ""
        },

        advert = {
			["0"] = {},
			["5"] = {},
			["10"] = {},
			["15"] = {},
			["20"] = {},
			["25"] = {},
			["30"] = {},
			["35"] = {},
			["40"] = {},
			["45"] = {},
			["50"] = {},
			["55"] = {}
		}
    }
end

local function loadConfig()
    local file = io.open(CONFIG_PATH, "r")

    if not file then
        config = defaultConfig()
        return
    end

    local text = file:read("*a")
    file:close()

    local data, _, err = json.decode(text)

	if err or type(data) ~= "table" then
		config = defaultConfig()
		return
	end

    config = data

	config.version = config.version or "unknown"
    config.settings = config.settings or {}
    config.advert = config.advert or {}

    local def = defaultConfig()

    for k, v in pairs(def.settings) do
        if config.settings[k] == nil then
            config.settings[k] = v
        end
    end
end

local function saveConfig()
	config.settings = config.settings or {}
	config.advert = config.advert or {}

    config.settings.helper = helperEnabled
    config.settings.repair = repairEnabled
    config.settings.fuel = fuelEnabled
	config.settings.flowers = flowersEnabled
	config.settings.maskSkinId = maskSkinId
	config.settings.spawnSkinId = spawnSkinId
    config.settings.advert = advertEnabled
    config.settings.advertNick = advertNick

    for minute = 0,55,5 do
        config.advert[tostring(minute)] = messages[minute] or {}
    end

    local file = io.open(CONFIG_PATH, "w")
	if not file then
		return
	end
	
    local text = json.encode(config, { indent = true })

	if text then
		file:write(text)
	end
	
    file:close()
end

loadConfig()

helperEnabled = config.settings.helper ~= false
repairEnabled = config.settings.repair ~= false
fuelEnabled = config.settings.fuel ~= false
flowersEnabled = config.settings.flowers ~= false
maskSkinId = tostring(config.settings.maskSkinId or "")
spawnSkinId = tostring(config.settings.spawnSkinId or "")
advertEnabled = config.settings.advert or false
advertNick = config.settings.advertNick or ""

for minute = 0,55,5 do
    local key = tostring(minute)

	if type(config.advert[key]) ~= "table" then
		config.advert[key] = {}
	end

	messages[minute] = config.advert[key]
end

local DIALOG_MENU = 5555
local DIALOG_MINUTES = 5556
local DIALOG_NICK = 5557
local DIALOG_MESSAGES = 5558
local DIALOG_MASK_SKIN = 5559
local DIALOG_ADVERT = 5562
local DIALOG_ENVIRONMENT = 5563
local DIALOG_FOR_TASKS = 5564
local DIALOG_SKINS = 5560
local DIALOG_SPAWN_SKIN = 5561
local DIALOG_UPDATE = 5565

local selectedMinute = 0

local MAX_REPAIR_PRICE = 1
local MAX_FUEL_LITERS = 1

local defaultTimePatch = nil

local function patchSampTime(enable)
    if enable and defaultTimePatch == nil then
        defaultTimePatch = readMemory(sampGetBase() + 0x9C0A0, 4, true)
        writeMemory(sampGetBase() + 0x9C0A0, 4, 0x000008C2, true)
    elseif not enable and defaultTimePatch ~= nil then
        writeMemory(sampGetBase() + 0x9C0A0, 4, defaultTimePatch, true)
        defaultTimePatch = nil
    end
end

local function status(v)
    return v and "{00CC66}ВКЛ" or "{FF4444}ВЫКЛ"
end

local function showMenu()
	local text = table.concat({
        "{4A90E2}Параметр\tСостояние",
		"Advance Helper\t" .. status(helperEnabled),
        "{4A90E2}Возможности:",
		"Автопринятие ремонта (1$)\t" .. status(repairEnabled),
		"Автопринятие заправки (1 л)\t" .. status(fuelEnabled),
		"{4A90E2}Взаимодействия со скинами\t{4A90E2}>>>",
		"{4A90E2}Возможности для заданий (/tasks)\t{4A90E2}>>>",
		"{4A90E2}Управление рассылкой\t{4A90E2}>>>",
		-- "{4A90E2}Управление временем и погодой\t{4A90E2}>>>",
    }, "\n")

    sampShowDialog(
        DIALOG_MENU,
        string.format("{4A90E2}Advance Helper [%s]", config.version),
        text,
        "Изменить",
		"Закрыть",
        DIALOG_STYLE_TABLIST_HEADERS
    )
end

local function showAdvertMenu()
    local text = table.concat({
        "{4A90E2}Параметр\tСостояние",
		"Рассылка\t" .. status(advertEnabled),
		"{4A90E2}Редактировать тексты\t{4A90E2}>>>",
		"{808080}Никнейм\t" .. (advertNick ~= "" and "{4A90E2}" .. advertNick or "{808080}Любой"),
    }, "\n")

    sampShowDialog(
        DIALOG_ADVERT,
        "{4A90E2}Управление рассылкой",
        text,
        "Выбрать",
		"Закрыть",
        DIALOG_STYLE_TABLIST_HEADERS
    )
end

local function showForTasksMenu()
    local text = table.concat({
        "{4A90E2}Параметр\tСостояние",
		"Запрос цветов\t" .. status(flowersEnabled),
    }, "\n")

    sampShowDialog(
        DIALOG_FOR_TASKS,
        string.format("{4A90E2}Возможности для заданий", config.version),
        text,
        "Изменить",
		"Закрыть",
        DIALOG_STYLE_TABLIST_HEADERS
    )
end

local function showSkinsMenu()
    local text = table.concat({
        "{4A90E2}Параметр\tСостояние",
		"Скин после маски ({4A90E2}Advance Platinum{ffffff})\t" .. (maskSkinId ~= "" and "{ffffff}" .. maskSkinId or "{FF4444}ВЫКЛ"),
		"Скин после спавна ({4A90E2}Advance Platinum{ffffff})\t" .. (spawnSkinId ~= "" and "{ffffff}" .. spawnSkinId or "{FF4444}ВЫКЛ"),
    }, "\n")

    sampShowDialog(
        DIALOG_SKINS,
        string.format("Взаимодействия со скинами", config.version),
        text,
        "Изменить",
		"Закрыть",
        DIALOG_STYLE_TABLIST_HEADERS
    )
end

local function isNewerVersion(newVersion, currentVersion)
    local function parse(version)
        local t = {}
        for num in version:gmatch("%d+") do table.insert(t, tonumber(num)) end
        return t
    end

    local new, current = parse(newVersion), parse(currentVersion)
    for i = 1, math.max(#new, #current) do
        local a, b = new[i] or 0, current[i] or 0
        if a > b then return true
        elseif a < b then return false end
    end
    return false
end

local function showChangelogDialog(info)
    local rows = {
        "{FFFFFF}Advance Helper был успешно обновлен до версии {4A90E2}" .. tostring(info.version),
        "",
        "{4A90E2}Что нового:",
        ""
    }

    for _, change in ipairs(info.changelog or {}) do
        -- Перекодируем строку из UTF-8 (json) в CP1251 (samp)
        table.insert(rows, "{FFFFFF}• " .. u8:decode(tostring(change)))
    end

    table.insert(rows, "")
    table.insert(rows, "{808080}Telegram-канал:")
    table.insert(rows, "{4A90E2}t.me/arphelper")

    sampShowDialog(
        DIALOG_UPDATE,
        "{4A90E2}Обновление Advance Helper",
        table.concat(rows, "\n"),
        "Ок",
        "",
        DIALOG_STYLE_MSGBOX
    )
end

local function checkForUpdates()
    lua_thread.create(function()
        local ok, response = pcall(requests.get, UPDATE_URL)
        if not ok or not response or response.status_code ~= 200 then return end

        local data, _, err = json.decode(response.text)
        if err or type(data) ~= "table" then return end

        if config.version == "unknown" then
            config.version = data.version
            saveConfig()
            return
        end
        
        if not isNewerVersion(data.version, config.version) then
            sampAddChatMessage("{4A90E2}Обновлений не обнаружено. Используется актуальная версия Advance Helper", -1)
            return
        end

        sampAddChatMessage(string.format("{4A90E2}Доступно обновление Advance Helper до версии {FFFFFF}%s{4A90E2}. Начинается загрузка", data.version), -1)

        local ok2, script = pcall(requests.get, data.script)
        if not ok2 or not script or script.status_code ~= 200 then
            sampAddChatMessage("{4A90E2}Не удалось загрузить обновление Advance Helper", -1)
            return
        end

        local file = io.open(thisScript().path, "wb")
        if not file then
            sampAddChatMessage("{4A90E2}Не удалось открыть файл скрипта для обновления Advance Helper", -1)
            return
        end

        file:write(u8:decode(script.text))
        file:close()

        -- Сохраняем в конфиг только новую версию без временных данных
        config.version = data.version
        saveConfig()

        sampAddChatMessage(string.format("{4A90E2}Установка обновления Advance Helper завершена. Версия: {FFFFFF}%s", data.version), -1)

        -- Показываем диалог сразу из полученных данных от сервера
        showChangelogDialog(data)

        wait(500)
        thisScript():reload()
    end)
end

function onScriptTerminate(script, quitGame)
    if script ~= thisScript() then return end

    if isSampAvailable() and sampIsDialogActive() then
        if sampGetPlayerDialogId() ~= DIALOG_UPDATE then
            sampCloseCurrentDialogWithButton(0)
        end
    end
end

function main()
    repeat
        wait(0)
    until isSampAvailable()

    repeat
        wait(200)
    until sampIsLocalPlayerSpawned()

    wait(500)

    checkForUpdates()

    sampRegisterChatCommand("ahelper", showMenu)

    sampRegisterChatCommand("ah", function()
        helperEnabled = not helperEnabled
        saveConfig()

        sampAddChatMessage(
            string.format(
                "{4A90E2}[Advance Helper]{FFFFFF} %s",
                helperEnabled and "{00CC66}Активирован{FFFFFF}" or "{FF4444}Деактивирован{FFFFFF}"
            ),
            -1
        )
    end)

    sampAddChatMessage(
		string.format(
			"{4A90E2}Advance Helper успешно инициализирован. Текущая версия: {FFFFFF}%s",
			config.version
		),
		-1
	)

	sampAddChatMessage(
		"{C8C8C8}Команда управления: {FFFFFF}/ah {C8C8C8}| Панель настроек: {FFFFFF}/ahelper",
		-1
	)
	
	lua_thread.create(function()
		local lastMinute = -1

		while true do
			wait(1000)
			
			if isSampAvailable() and helperEnabled and advertEnabled then
				if advertNick ~= "" then
					local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)

					if id == nil then
						goto continue
					end

					local myNick = sampGetPlayerNickname(id)

					if not myNick or myNick:lower() ~= advertNick:lower() then
						goto continue
					end
				end
				
				local t = os.date("*t")
				local minute = t.min

				if minute % 5 == 0 and minute ~= lastMinute then
					lastMinute = minute

					local list = messages[minute]

					if list and #list > 0 then
						lua_thread.create(function()
							for _, msg in ipairs(list) do
								if not isSampAvailable() or not helperEnabled or not advertEnabled then
									break
								end

								if msg ~= "" then
									sampSendChat(msg)
								end

								wait(2000)
							end
						end)
					end
				end
			end
			
			::continue::
		end
	end)

    lua_thread.create(function()
        while true do
            wait(0)

            local result, button, list = sampHasDialogRespond(DIALOG_MENU)

            local changed = false

			if result and button == 1 then
				if list == 0 then
					helperEnabled = not helperEnabled
					saveConfig()
					changed = true

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} %s",
							helperEnabled and "{00CC66}Активирован{FFFFFF}" or "{FF4444}Деактивирован{FFFFFF}"
						),
						-1
					)

				elseif list == 2 then
					repairEnabled = not repairEnabled
					saveConfig()
					changed = true

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Автопринятие ремонта %s",
							repairEnabled and "{00CC66}включено{FFFFFF}" or "{FF4444}выключено{FFFFFF}"
						),
						-1
					)

				elseif list == 3 then
					fuelEnabled = not fuelEnabled
					saveConfig()
					changed = true

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Автопринятие заправки %s",
							fuelEnabled and "{00CC66}включено{FFFFFF}" or "{FF4444}выключено{FFFFFF}"
						),
						-1
					)
					
				elseif list == 4 then
					showSkinsMenu()
					
				elseif list == 5 then
					showForTasksMenu()
					
				elseif list == 6 then
					showAdvertMenu()
					
				elseif list == 7 then
					showEnvironmentMenu()
					
				end
				
				if changed then
					wait(0)
					showMenu()
				end
			end
			
			local result, button, list = sampHasDialogRespond(DIALOG_FOR_TASKS)
			local changed = false

			if result and button == 1 then					
				if list == 0 then
					flowersEnabled = not flowersEnabled
					saveConfig()
					changed = true

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Запрос цветов %s",
							flowersEnabled and "{00CC66}включен{FFFFFF}" or "{FF4444}выключен{FFFFFF}"
						),
						-1
					)
					
					sampAddChatMessage(
						"{4A90E2}После дарения цветов (/present), от вашего лица будет отправляться просьба о возврате цветов",
						-1
					)
				end
				
				if changed then
					wait(0)
					showForTasksMenu()
				end
				
			elseif result and button == 0 then
				showMenu()
				
			end
			
			local result, button, list = sampHasDialogRespond(DIALOG_SKINS)
			local changed = false

			if result and button == 1 then					
				if list == 0 then
					sampShowDialog(
						DIALOG_MASK_SKIN,
						"Скин после маски",
						"{FFFFFF}Введите ID скина.\n\n" ..
						"{4A90E2}Примечание:{FFFFFF} скин будет установлен только\n" ..
						"если ваш персонаж находится {4A90E2}в интерьере{FFFFFF}.\n\n" ..
						"Если оставить поле пустым, функция будет {FF4444}отключена{FFFFFF}.",
						"Сохранить",
						"Отмена",
						DIALOG_STYLE_INPUT
					)
					
				end
					
				if list == 1 then
					sampShowDialog(
						DIALOG_SPAWN_SKIN,
						"Скин после спавна",
						"{FFFFFF}Введите ID скина.\n\n" ..
						"{4A90E2}Примечание:{FFFFFF} скин будет установлен только\n" ..
						"если ваш персонаж находится {4A90E2}в интерьере{FFFFFF}.\n\n" ..
						"Если оставить поле пустым, функция будет {FF4444}отключена{FFFFFF}.",
						"Сохранить",
						"Отмена",
						DIALOG_STYLE_INPUT
					)
				end
				
				if changed then
					wait(0)
					showSkinsMenu()
				end
			
			elseif result and button == 0 then
				showMenu()
				
			end
			
			local result, button, list = sampHasDialogRespond(DIALOG_ADVERT)
			local changed = false

			if result and button == 1 then					
				if list == 0 then
					advertEnabled = not advertEnabled
					saveConfig()
					changed = true

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Рассылка %s",
							advertEnabled and "{00CC66}включена{FFFFFF}" or "{FF4444}выключена{FFFFFF}"
						),
						-1
					)
					
				elseif list == 1 then
					local function buildMinutesList()
						local rows = {
							"{4A90E2}Время\t{4A90E2}Текст"
						}

						for minute = 0, 55, 5 do
							local preview = "{808080}Пусто"

							local list = messages[minute]
							if list and #list > 0 then
								preview = list[1]

								if #preview > 32 then
									preview = preview:sub(1, 32) .. "..."
								end

								preview = "{C0C0A0}" .. preview
							end

							table.insert(rows,
								string.format("%02d\t%s", minute, preview)
							)
						end

						return table.concat(rows, "\n")
					end
					
					sampShowDialog(
						DIALOG_MINUTES,
						"Редактирование текстов",
						buildMinutesList(),
						"Выбрать",
						"Закрыть",
						DIALOG_STYLE_TABLIST_HEADERS
					)
					
				elseif list == 2 then
					sampShowDialog(
						DIALOG_NICK,
						"Ник для рассылки",
						"Введите ник персонажа.\n\nЕсли оставить поле пустым, рассылка будет работать на любом персонаже",
						"Сохранить",
						"Отмена",
						DIALOG_STYLE_INPUT
					)
				end
				
				if changed then
					wait(0)
					showAdvertMenu()
				end
				
			elseif result and button == 0 then
				showMenu()
				
			end
			
			local result, button, list = sampHasDialogRespond(DIALOG_MINUTES)

			if result and button == 1 then
				local minutes = {0,5,10,15,20,25,30,35,40,45,50,55}
				selectedMinute = minutes[list + 1]

				sampShowDialog(
					DIALOG_MESSAGES,
					string.format("Сообщения (%02d минут)", selectedMinute),
					string.format(
						"Введите сообщения для %02d минут.\n\n" ..
						"Разделитель сообщений: |\n" ..
						"Сообщения отправляются с интервалом 2 секунды.\n\n" ..
						"Пример:\n" ..
						"/fm Первое сообщение|/fm Второе сообщение|/jn Третье сообщение\n\n" ..
						"Текущие сообщения:\n%s",
						selectedMinute,
						table.concat(messages[selectedMinute] or {}, "\n")
					),
					"Сохранить",
					"Закрыть",
					DIALOG_STYLE_INPUT
				)
			end
			
			local result, button, _, input = sampHasDialogRespond(DIALOG_NICK)

			if result and button == 1 then
				advertNick = input:gsub("^%s+", ""):gsub("%s+$", "")
				saveConfig()

				sampAddChatMessage(
					string.format(
						"{4A90E2}[Advance Helper]{FFFFFF} Ник рассылки установлен: {00CC66}%s",
						advertNick == "" and "Любой персонаж" or advertNick
					),
					-1
				)

				wait(0)
				showAdvertMenu()
			end
			
			local result, button, _, input = sampHasDialogRespond(DIALOG_MESSAGES)

			if result and button == 1 then
				messages[selectedMinute] = {}

				input = input:gsub("\r", "")

				if not input:find("\n") then
					input = input:gsub("|", "\n")
				end

				for line in input:gmatch("[^\n]+") do
					line = line:gsub("^%s+", ""):gsub("%s+$", "")

					if line ~= "" then
						table.insert(messages[selectedMinute], line)
					end
				end

				saveConfig()

				sampAddChatMessage(
					string.format(
						"{4A90E2}[Advance Helper]{FFFFFF} Сообщения для {4A90E2}%02d{FFFFFF} минут сохранены",
						selectedMinute
					),
					-1
				)

				wait(0)
				showAdvertMenu()
			end
			
			local result, button, _, input = sampHasDialogRespond(DIALOG_MASK_SKIN)

			if result and button == 1 then
				input = input:gsub("%s+", "")

				if input == "" then
					maskSkinId = ""
				elseif tonumber(input) then
					maskSkinId = input
				else
					sampAddChatMessage(
						"{4A90E2}[Advance Helper]{FFFFFF} ID скина должен быть числом",
						-1
					)
				end

				if input == "" or tonumber(input) then
					saveConfig()

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Скин после маски установлен: %s",
							maskSkinId == "" and "{FF4444}ВЫКЛ" or "{4A90E2}" .. maskSkinId
						),
						-1
					)

					sampAddChatMessage(
						"{4A90E2}Функция доступна только игрокам с Advance Platinum (/mm > 12 > 22)",
						-1
					)

					wait(0)
					showSkinsMenu()
				end
			end
				
			local result, button, _, input = sampHasDialogRespond(DIALOG_SPAWN_SKIN)

			if result and button == 1 then
				input = input:gsub("%s+", "")

				if input == "" then
					spawnSkinId = ""
				elseif tonumber(input) then
					spawnSkinId = input
				else
					sampAddChatMessage(
						"{4A90E2}[Advance Helper]{FFFFFF} ID скина должен быть числом",
						-1
					)
				end

				if input == "" or tonumber(input) then
					saveConfig()

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Скин после спавна установлен: %s",
							spawnSkinId == "" and "{FF4444}ВЫКЛ" or "{4A90E2}" .. spawnSkinId
						),
						-1
					)

					sampAddChatMessage(
						"{4A90E2}Функция доступна только игрокам с Advance Platinum (/mm > 12 > 22)",
						-1
					)

					wait(0)
					showSkinsMenu()
				end
			end
        end
    end)
end

function sampev.onSendSpawn()
   if spawnSkinId ~= "" then
		lua_thread.create(function()
			wait(2000)
			sampSendChat("/setskin " .. spawnSkinId)
			wait(100)
			sampAddChatMessage(
				string.format(
					"{4A90E2}Advance Helper произвел автоматическую установку скина (%s)",
					spawnSkinId
				),
				-1
			)
		end)
	end
end


function sampev.onShowDialog(id, style, title, button1, button2, text)
    if id ~= 27 then return end

    local count = 0
    for _ in (text .. "\n"):gmatch("(.-)\n") do
        count = count + 1
    end

    playerMenuLastItem = count

    text = text .. string.format(
		"\n{4A90E2}%d. Настройки Advance Helper",
		playerMenuLastItem + 1
	)

    return {
        id,
        style,
        title,
        button1,
        button2,
        text
    }
end

function sampev.onSendDialogResponse(id, button, listitem, input)
    if id ~= 27 then return end

    if button == 1 and listitem == playerMenuLastItem then
        lua_thread.create(function()
            wait(200)
            showMenu()
        end)

        return false
    end
end

function sampev.onServerMessage(color, text)
    if not helperEnabled then
        return
    end
	
	do
		if text:find("^Вы надели маску") and maskSkinId ~= "" then
			lua_thread.create(function()
				wait(150)
				sampSendChat("/setskin " .. maskSkinId)
			end)

			return
		end
	end

    do
        local nick, price = text:match("^(%S+) предлагает произвести ремонт Вашего транспорта за (%d+)%$")

        if nick and price and repairEnabled then
            price = tonumber(price)

            if price <= MAX_REPAIR_PRICE then
                sampSendChat("/yes")
            else
                sampSendChat("/no")

                lua_thread.create(function()
                    wait(150)
                    sampSendChat(string.format("/n %s, кидай за 1$", nick))
                end)
            end

            return
        end
    end

    -- ????????
    do
        local nick, liters = text:match("^(%S+) предлагает заправить Ваш транспорт на (%d+) л за %d+%$")

        if nick and liters and fuelEnabled then
            liters = tonumber(liters)

            if liters <= MAX_FUEL_LITERS then
                sampSendChat("/yes")
            else
                sampSendChat("/no")

                lua_thread.create(function()
                    wait(150)
                    sampSendChat(string.format("/n %s, кидай 1 л", nick))
                end)
            end

            return
        end
    end
	
	do
		local nick = text:match("^(%S+) получил от Вас цветы$")

		if nick and flowersEnabled then
			lua_thread.create(function()
				local phrases = {
					"Будьте добры, верните цветы, пожалуйста",
					"Если не сложно, верните цветы",
					"Верните цветы, пожалуйста",
					"Буду благодарен, если вернете цветы",
					"Не забудьте вернуть цветы, пожалуйста"
				}

				sampSendChat(string.format("%s, %s", nick:gsub("_", " "), phrases[math.random(#phrases)]))
				
				wait(1000)

				local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
				if myId then
					sampSendChat(string.format("/n %s, /present %d пожалуйста", nick, myId))
				end
			end)

			return
		end
	end
end
