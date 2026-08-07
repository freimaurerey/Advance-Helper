local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

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

local repairEnabled
local fuelEnabled
local flowersEnabled
local rentCarId
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

local download_status = require("moonloader").download_status	

local UPDATE_URL = "https://raw.githubusercontent.com/freimaurerey/Advance-Helper/main/version.json?t=" .. tostring(os.clock())

local function defaultConfig()
    return {
		version = "unknown",
	
        settings = {
            repair = true,
            fuel = true,
			flowers = true,
			rentCarId = "",
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

    config.settings.repair = repairEnabled
    config.settings.fuel = fuelEnabled
	config.settings.flowers = flowersEnabled
	config.settings.rentCarId = rentCarId
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

repairEnabled = config.settings.repair ~= false
fuelEnabled = config.settings.fuel ~= false
flowersEnabled = config.settings.flowers ~= false
rentCarId = tostring(config.settings.rentCarId or "")
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
local DIALOG_RENT_CAR = 5566
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
        "{4A90E2}Возможности:",
		"Автопринятие ремонта (1$)\t" .. status(repairEnabled),
		"Автопринятие заправки (1 л)\t" .. status(fuelEnabled),
		"Автоматическая аренда\t" .. (rentCarId ~= "" and "{ffffff}" .. rentCarId or "{FF4444}ВЫКЛ"),
		"\t",
		"{4A90E2}Взаимодействия со скинами\t{4A90E2}>>>",
		"{4A90E2}Возможности для заданий (/tasks)\t{4A90E2}>>>",
		"{4A90E2}Управление рассылкой\t{4A90E2}>>>",
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

local function startRentProcess()
    lua_thread.create(function()
        local target_veh = tonumber(rentCarId)
        if not target_veh or target_veh < 1 or target_veh > 14 then
            sampAddChatMessage("{4A90E2}[Advance Helper]{FFFFFF} Ошибка: не корректно выбран ID авто (1-14)", -1)
            rentActive = false
            return
        end
        
        sampSendChat("/x")
        
        wait(800)

        local forward_clicks = (target_veh - 1) % 14
        local backward_clicks = (15 - target_veh) % 14

        if forward_clicks <= backward_clicks then
            for i = 1, forward_clicks do
                sampSendClickTextdraw(116)
                wait(200)
            end
        else
            for i = 1, backward_clicks do
                sampSendClickTextdraw(117)
                wait(200)
            end
        end

        wait(300)

        sampSendClickTextdraw(119)
    end)
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
        table.insert(rows, "{FFFFFF}• " .. tostring(change))
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

local function utf8_to_cp1251(str)
    local charmap = {
        [208] = {[129]=168,[144]=192,[145]=193,[146]=194,[147]=195,[148]=196,[149]=197,[150]=198,[151]=199,[152]=200,[153]=201,[154]=202,[155]=203,[156]=204,[157]=205,[158]=206,[159]=207,[160]=208,[161]=209,[162]=210,[163]=211,[164]=212,[165]=213,[166]=214,[167]=215,[168]=216,[169]=217,[170]=218,[171]=219,[172]=220,[173]=221,[174]=222,[175]=223,[176]=224,[177]=225,[178]=226,[179]=227,[180]=228,[181]=229,[182]=230,[183]=231,[184]=232,[185]=233,[186]=234,[187]=235,[188]=236,[189]=237,[190]=238,[191]=239},
        [209] = {[128]=240,[129]=241,[130]=242,[131]=243,[132]=244,[133]=245,[134]=246,[135]=247,[136]=248,[137]=249,[138]=250,[139]=251,[140]=252,[141]=253,[142]=254,[143]=255,[145]=184}
    }
    local res = {}
    local i = 1
    while i <= #str do
        local c1 = str:byte(i)
        if charmap[c1] and i < #str then
            local c2 = str:byte(i + 1)
            if charmap[c1][c2] then
                table.insert(res, string.char(charmap[c1][c2]))
                i = i + 2
            else
                table.insert(res, string.char(c1))
                i = i + 1
            end
        else
            table.insert(res, string.char(c1))
            i = i + 1
        end
    end
    return table.concat(res)
end

local isCheckingUpdate = false

local function checkForUpdates()
    if isCheckingUpdate then return end
    isCheckingUpdate = true

    lua_thread.create(function()
        local jsonPath = os.tmpname()
        if doesFileExist(jsonPath) then os.remove(jsonPath) end

        -- Добавляем timestamp к URL против кэширования сервера
        local urlWithCache = UPDATE_URL .. "?t=" .. os.time()

        downloadUrlToFile(urlWithCache, jsonPath, function(_, status)
            if status == download_status.STATUS_ENDDOWNLOADDATA then
                local file = io.open(jsonPath, "r")
                if not file then
                    if doesFileExist(jsonPath) then os.remove(jsonPath) end
                    isCheckingUpdate = false
                    return
                end

                local text = file:read("*a")
                file:close()
                if doesFileExist(jsonPath) then os.remove(jsonPath) end

                -- Читаем JSON через UTF-8 декодер
                local data, _, err = json.decode(u8(text))
                if err or type(data) ~= "table" or not data.version or not data.script then
                    isCheckingUpdate = false
                    return
                end

                if config.version == "unknown" then
                    config.version = data.version
                    saveConfig()
                    isCheckingUpdate = false
                    return
                end

                if not isNewerVersion(data.version, config.version) then
                    sampAddChatMessage("{4A90E2}Используется актуальная версия Advance Helper", -1)
                    isCheckingUpdate = false
                    return
                end

                sampAddChatMessage(
                    string.format("{4A90E2}Доступно обновление до v%s. Начинается загрузка...", data.version),
                    -1
                )

                -- Разгружаем сетевой поток с помощью микропаузы
                lua_thread.create(function()
                    wait(200)

                    local tempScriptPath = os.tmpname()
                    if doesFileExist(tempScriptPath) then os.remove(tempScriptPath) end

                    downloadUrlToFile(data.script, tempScriptPath, function(_, status2)
                        if status2 == download_status.STATUS_ENDDOWNLOADDATA then
                            local downloadedFile = io.open(tempScriptPath, "rb")
                            if downloadedFile then
                                local scriptContent = downloadedFile:read("*a")
                                downloadedFile:close()
                                if doesFileExist(tempScriptPath) then os.remove(tempScriptPath) end

                                if #scriptContent > 0 then
									scriptContent = utf8_to_cp1251(scriptContent)

                                    local currentScriptFile = io.open(thisScript().path, "wb")
                                    if currentScriptFile then
                                        currentScriptFile:write(scriptContent)
                                        currentScriptFile:close()

                                        config.version = data.version
                                        saveConfig()

                                        sampAddChatMessage(
                                            string.format("{4A90E2}Обновление до v%s успешно установлено!", data.version),
                                            -1
                                        )

                                        showChangelogDialog(data)

                                        lua_thread.create(function()
                                            wait(500)
                                            thisScript():reload()
                                        end)
                                        return
                                    end
                                end
                            end

                            sampAddChatMessage("{4A90E2}Ошибка при сохранении файла обновления", -1)
                            isCheckingUpdate = false
                        end
                    end)
                end)
            end
        end)
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

function buildMessageId(text)
    local clean = text:gsub("{......}", "")

    local nick = clean:match("^%d+%.%s+([%w_]+)")
    if not nick then
        nick = clean:match("^([%w_]+)")
    end

    local id = tonumber(clean:match("[iI][dD]%s*(%d+)"))

    if not nick or id == nil then
        return nil
    end

    local level = sampGetPlayerScore(id)
    local ping = sampGetPlayerPing(id)
    local playerColor = sampGetPlayerColor(id)

    local hex = string.format("%06X", bit.band(playerColor, 0xFFFFFF))

    local newText = text

    newText = newText:gsub(
        nick,
        string.format("{%s}%s{FFFFFF}", hex, nick),
        1
    )

    newText = newText:gsub("id ", "")
    newText = newText:gsub("%(гол. чат%)", "V")
    newText = newText:gsub("c Launcher", "Launch")
    newText = newText:gsub("c Mobile", "Mobile")
    newText = newText:gsub("%-?%s*тел%.%s*%{%x+}%s*(%d+)", "{ffcc00}[%1]")
    newText = newText:gsub("%s%s+", " ")
    newText = newText:gsub("| аккаунт (%d+)", "[%1]")

    newText = string.format(
        "%s{66CC66} [lvl %d | %d ms]",
        newText,
        level,
        ping
    )

    return newText
end

function sampev.onSendCommand(cmd)
    if cmd:lower():match("^/id") then
        waitingId = true
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

    sampRegisterChatCommand("ah", showMenu)
	
	sampRegisterChatCommand("x", function()
        if rentCarId == "" then
			sampSendChat("/x")
            sampAddChatMessage("{ffff00}Вы можете включить функцию авто-аренды транспорта в {ffffff}/ah", -1)
            return
        end

        if rentActive then
            sampAddChatMessage("{4A90E2}[Advance Helper]{FFFFFF} Процесс аренды уже запущен!", -1)
            return
        end

        rentActive = true
        startRentProcess()
    end)

    sampAddChatMessage(
		string.format(
			"{4A90E2}Advance Helper успешно инициализирован. Текущая версия: {FFFFFF}%s. {C8C8C8}[Используйте /ah{C8C8C8}]",
			config.version
		),
		-1
	)
	
	lua_thread.create(function()
		local lastMinute = -1

		while true do
			wait(1000)
			
			if isSampAvailable() and advertEnabled then
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
								if not isSampAvailable() or not advertEnabled then
									break
								end

								if msg ~= "" then
									sampSendChat(msg)
								end

								wait(2000)
							end

							sampAddChatMessage(
								string.format("{4A90E2}[Advance Helper]{FFFFFF} Рассылка за %02d минуту выполнена", minute),
								-1
							)		
							
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
				if list == 1 then
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

				elseif list == 2 then
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
					
				elseif list == 3 then
					sampShowDialog(
						DIALOG_RENT_CAR,
						"{00C853}Выбор транспорта для аренды",
						"{FFFFFF}Введите порядковый номер авто для автоматической аренды.\n\n" ..
						"{FFD54F}Список доступного транспорта (1 - 14):{FFFFFF}\n" ..
						" 1. Faggio       2. Manana      3. Clover\n" ..
						" 4. Hustler      5. Sadler      6. Hermes\n" ..
						" 7. Picador      8. Perenniel   9. Tampa\n" ..
						"10. Majestic    11. Bobcat     12. Glendale\n" ..
						"13. Slamvan     14. Stallion\n\n" ..
						"Оставьте поле пустым, чтобы {FF5252}отключить{FFFFFF} авто-аренду.",
						"Сохранить",
						"Отмена",
						DIALOG_STYLE_INPUT
					)
					
				elseif list == 5 then
					showSkinsMenu()
					
				elseif list == 6 then
					showForTasksMenu()
					
				elseif list == 7 then
					showAdvertMenu()
					
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
			
			local result, button, _, input = sampHasDialogRespond(DIALOG_RENT_CAR)

			if result and button == 1 then
				input = input:gsub("%s+", "")

				if input == "" then
					rentCarId = ""
				elseif tonumber(input) then
					rentCarId = input
				else
					sampAddChatMessage(
						"{4A90E2}[Advance Helper]{FFFFFF} ID авто должен быть числом",
						-1
					)
				end

				if input == "" or tonumber(input) then
					saveConfig()

					sampAddChatMessage(
						string.format(
							"{4A90E2}[Advance Helper]{FFFFFF} Авто для аренды установлен: %s",
							rentCarId == "" and "{FF4444}ВЫКЛ" or "{4A90E2}" .. rentCarId
						),
						-1
					)

					wait(0)
					showMenu()
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
	-- -------------------------------------------------------------
    -- /x
    -- -------------------------------------------------------------
	if rentCarId ~= "" and id == 694 then
        sampSendDialogResponse(id, 1, -1, "")
		
		rentActive = false
		
		sampAddChatMessage(
			string.format("{4A90E2}[Advance Helper]{FFFFFF} Транспорт %s арендован", rentCarId),
			-1
		)	
		
        return false
    end
	
	-- -------------------------------------------------------------
    -- /unrent
    -- -------------------------------------------------------------
	if rentCarId ~= "" and id == 738 then
        sampSendDialogResponse(id, 1, -1, "")
		
        return false
    end

	-- -------------------------------------------------------------
    -- /wanted
    -- -------------------------------------------------------------
    if id == 317 then
        local newLines = {}

        for line in text:gmatch("[^\r\n]+") do
            local nick = line:match("^([%w_]+)")
            local player_id = tonumber(line:match("%(id%s*(%d+)%)"))

            if player_id and nick then
                local level = sampGetPlayerScore(player_id) or 0
                local playerColor = sampGetPlayerColor(player_id)
                local hex = string.format("%06X", bit.band(playerColor, 0xFFFFFF))

                -- Заменяем Nick_Name на {HEX}Nick_Name{FFFFFF} [lvl X]
                local coloredNickWithLvl = string.format("{%s}%s{FFFFFF} {66CC66}[lvl %d]{FFFFFF}", hex, nick, level)
                
                line = line:gsub(nick, coloredNickWithLvl, 1)
            end

            table.insert(newLines, line)
        end

        return {
            id,
            style,
            title,
            button1,
            button2,
            table.concat(newLines, "\n")
        }
    end

    -- -------------------------------------------------------------
	-- /mm
	-- -------------------------------------------------------------
    if id ~= 27 then return end

    local count = 0
    for _ in (text .. "\n"):gmatch("(.-)\n") do count = count + 1 end
    playerMenuLastItem = count

    text = text .. string.format("\n{4A90E2}%d. Настройки Advance Helper", playerMenuLastItem + 1)
    return { id, style, title, button1, button2, text }
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
	-- -------------------------------------------------------------
    -- stop /x cycle if unrent
    -- -------------------------------------------------------------
	local unrent_msg = text:match("чтобы разорвать текущий договор аренды")
	if rentCarId ~= "" and unrent_msg then
        rentActive = false
		
		sampAddChatMessage(
			string.format(
				"{ffff00}Отмените текущую аренду транспорта с помощью команды {FFFFFF}/unrent"
			),
			-1
		)
		
        return false
    end

	
	local clean = text:gsub("{......}", "")
	
	-- -------------------------------------------------------------
	-- /setmark
	-- -------------------------------------------------------------
	local wanted_id = text:match("%[(%d+)%].-был обнаружен")
    if wanted_id then
        autoIdRequest = true
        lua_thread.create(function()
            wait(100)
            sampSendChat("/id " .. wanted_id)
        end)
    end

	-- -------------------------------------------------------------
	-- /id
	-- -------------------------------------------------------------
	if waitingId then
		if clean:find("Использование команды:") 
			or clean:find("Совпадений не найдено") 
			or clean:find("Поиск id игрока:") 
			or clean:find("Поиск ника игрока:") then
			
			waitingId = false
			return
		end

		if clean:match("^[%w_]+%s+[iI][dD]%s*%d+") or clean:match("^%d+%.%s+[%w_]+%s+[iI][dD]%s*%d+") then
			local newText = buildMessageId(text)
			
			if not clean:match("^%d+%.") then
				waitingId = false
			end

			if newText then
				return { color, newText }
			end
		end

		if clean:find("Показаны первые") then
			waitingId = false
			return
		end
	end
	
	-- -------------------------------------------------------------
	-- skin after mask
    -- -------------------------------------------------------------
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
