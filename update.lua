require "import"
local json = require "cjson"
import "java.lang.Integer"
import "java.lang.Long"
import "android.speech.RecognizerIntent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "com.androlua.*"
import "android.net.Uri"
import "android.content.Intent"
import "java.util.Locale"
import "android.app.AlertDialog"
import "android.widget.LinearLayout"
import "android.widget.ScrollView"
import "android.widget.TextView"
import "android.widget.EditText"
import "android.widget.Switch"
import "android.widget.Button"
import "android.widget.Spinner"
import "android.widget.ArrayAdapter"
import "android.view.WindowManager"
import "android.content.DialogInterface"
import "android.view.View"
import "android.widget.AdapterView"
import "android.widget.CompoundButton"
import "android.content.Context"
import "android.view.accessibility.AccessibilityNodeInfo"
import "android.view.inputmethod.InputMethodManager"
import "android.view.inputmethod.EditorInfo"
import "android.view.accessibility.AccessibilityEvent"
import "java.net.URLEncoder"
import "android.net.NetworkCapabilities"
import "android.text.InputType"
import "java.util.regex.Pattern"
import "java.util.regex.Matcher"
import "java.lang.String"
import "android.widget.ListView"
import "android.widget.CheckBox"
import "android.widget.Toast"
import "android.text.TextWatcher"
import "android.provider.Settings"
import "android.os.Handler"
import "android.os.Looper"
import "java.lang.Runnable"
import "android.os.Build"
import "android.content.pm.PackageManager"

local currentVersion = "1.0"
local versionUrl = "https://raw.githubusercontent.com/hafiztasleem85-cmyk/advanced-typer-/refs/heads/main/virgin.txt"
local notesUrl = "https://raw.githubusercontent.com/hafiztasleem85-cmyk/advanced-typer-/refs/heads/main/Notes.json"
local updateUrl = "https://raw.githubusercontent.com/hafiztasleem85-cmyk/advanced-typer-/refs/heads/main/update.lua"

local currentPluginPath = debug.getinfo(1, "S").source
if currentPluginPath:sub(1, 1) == "@" then
    currentPluginPath = currentPluginPath:sub(2)
end

local activeSpeechRecognizer = nil

local function safeStop(speechRecognizer)
    if speechRecognizer ~= nil then
        speechRecognizer.stopListening()
        speechRecognizer.destroy()
    end
    _G.advanceTyperActiveMic = nil
end

local function isUpdateAvailable(current, online)
    local function splitVersion(ver)
        local parts = {}
        for part in string.gmatch(tostring(ver), "%d+") do
            table.insert(parts, tonumber(part))
        end
        return parts
    end
    local cParts = splitVersion(current)
    local oParts = splitVersion(online)
    for i = 1, math.max(#cParts, #oParts) do
        local c = cParts[i] or 0
        local o = oParts[i] or 0
        if o > c then return true end
        if o < c then return false end
    end
    return false
end

local function checkUpdate()
    local timestamp = tostring(os.time())
    Http.get(versionUrl .. "?t=" .. timestamp, nil, "utf-8", nil, function(code, res)
        if code == 200 and res then
            local onlineVersion = res:gsub("%s+", "")
            if isUpdateAvailable(currentVersion, onlineVersion) then
                Http.get(notesUrl .. "?t=" .. timestamp, nil, "utf-8", nil, function(codeNotes, resNotes)
                    local updateMessage = "नया अपडेट मौजूद है"
                    if codeNotes == 200 and resNotes then
                        updateMessage = resNotes
                    end
                    local builder = AlertDialog.Builder(service)
                    builder.setTitle("Update Available")
                    builder.setMessage(updateMessage)
                    builder.setNegativeButton("Update Now", function()
                        service.speak("अपडेट हो रहा है, इंतज़ार करें")
                        Http.get(updateUrl .. "?t=" .. timestamp, nil, "utf-8", nil, function(code2, res2)
                            if code2 == 200 and res2 then
                                local tempPath = currentPluginPath .. ".temp_update"
                                local openStatus, f = pcall(io.open, tempPath, "w")
                                if openStatus and f then
                                    pcall(function() f:write(res2) end)
                                    pcall(function() f:close() end)
                                    local success = false
                                    local fileExists = io.open(currentPluginPath, "r")
                                    if fileExists then
                                        fileExists:close()
                                        local delSuccess = pcall(function() os.remove(currentPluginPath) end)
                                        if delSuccess then
                                            local renameSuccess = pcall(function() os.rename(tempPath, currentPluginPath) end)
                                            if renameSuccess then
                                                success = true
                                            end
                                        end
                                    else
                                        local renameSuccess = pcall(function() os.rename(tempPath, currentPluginPath) end)
                                        if renameSuccess then
                                            success = true
                                        end
                                    end
                                    if not success then
                                        pcall(function() os.remove(tempPath) end)
                                    end
                                    if success then
                                        service.speak("प्लगइन कामयाबी के साथ अपडेट हो गया है")
                                        Handler(Looper.getMainLooper()).postDelayed(Runnable({run = function() pcall(function() dofile(currentPluginPath) end) end}), 1000)
                                    else
                                        service.speak("अपडेट महफूज़ करने में दिक्कत आई")
                                    end
                                else
                                    service.speak("अपडेट महफूज़ करने में दिक्कत आई")
                                end
                            else
                                service.speak("अपडेट डाउनलोड नहीं আসতে सका")
                            end
                        end)
                    end)
                    builder.setPositiveButton("Maybe Later", nil)
                    local dialog = builder.create()
                    if Build.VERSION.SDK_INT >= 22 then 
                        dialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY) 
                    else 
                        dialog.getWindow().setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT) 
                    end
                    if activeSpeechRecognizer then
                        safeStop(activeSpeechRecognizer)
                    end
                    dialog.show()
                    dialog.getButton(DialogInterface.BUTTON_NEGATIVE).setAllCaps(false)
                    dialog.getButton(DialogInterface.BUTTON_POSITIVE).setAllCaps(false)
                end)
            end
        end
    end)
end

local configPath = "/storage/emulated/0/解说/AdvanceTyperConfig.json"

local baseLanguages = {
    {"Hindi", "hi-IN", "hi"},
    {"Urdu (IN)", "ur-IN", "ur"},
    {"English (India)", "en-IN", "en"},
    {"Afrikaans", "af-ZA", "af"},
    {"Albanian", "sq-AL", "sq"},
    {"Amharic", "am-ET", "am"},
    {"Arabic", "ar-SA", "ar"},
    {"Assamese", "as-IN", "as"},
    {"Azerbaijani", "az-AZ", "az"},
    {"Bangla (Bangladesh)", "bn-BD", "bn"},
    {"Bangla (India)", "bn-IN", "bn"},
    {"Bhojpuri", "bho-IN", "bho"},
    {"Bodo", "brx-IN", "brx"},
    {"Bosnian", "bs-BA", "bs"},
    {"Bulgarian", "bg-BG", "bg"},
    {"Burmese", "my-MM", "my"},
    {"Cantonese (Hong Kong)", "yue-Hant-HK", "yue"},
    {"Catalan", "ca-ES", "ca"},
    {"Chinese (China)", "zh-CN", "zh-CN"},
    {"Chinese (Taiwan)", "zh-TW", "zh-TW"},
    {"Croatian", "hr-HR", "hr"},
    {"Czech", "cs-CZ", "cs"},
    {"Danish", "da-DK", "da"},
    {"Dogri", "doi-IN", "doi"},
    {"Dutch (Belgium)", "nl-BE", "nl"},
    {"Dutch (Netherlands)", "nl-NL", "nl"},
    {"English (Australia)", "en-AU", "en"},
    {"English (Canada)", "en-CA", "en"},
    {"English (Ireland)", "en-IE", "en"},
    {"English (Nigeria)", "en-NG", "en"},
    {"English (Singapore)", "en-SG", "en"},
    {"English (UK)", "en-GB", "en"},
    {"English (US)", "en-US", "en"},
    {"Estonian", "et-EE", "et"},
    {"Filipino", "fil-PH", "tl"},
    {"Finnish", "fi-FI", "fi"},
    {"French (Canada)", "fr-CA", "fr"},
    {"French (France)", "fr-FR", "fr"},
    {"German", "de-DE", "de"},
    {"Greek", "el-GR", "el"},
    {"Gujarati", "gu-IN", "gu"},
    {"Hausa", "ha-NG", "ha"},
    {"Hebrew", "he-IL", "he"},
    {"Hungarian", "hu-HU", "hu"},
    {"Icelandic", "is-IS", "is"},
    {"Indonesian", "id-ID", "id"},
    {"Italian", "it-IT", "it"},
    {"Japanese", "ja-JP", "ja"},
    {"Javanese", "jv-ID", "jv"},
    {"Kannada", "kn-IN", "kn"},
    {"Kashmiri", "ks-IN", "ks"},
    {"Kazakh", "kk-KZ", "kk"},
    {"Khmer", "km-KH", "km"},
    {"Konkani", "kok-IN", "kok"},
    {"Korean", "ko-KR", "ko"},
    {"Lao", "lo-LA", "lo"},
    {"Latvian", "lv-LV", "lv"},
    {"Lithuanian", "lt-LT", "lt"},
    {"Maithili", "mai-IN", "mai"},
    {"Malay", "ms-MY", "ms"},
    {"Malayalam", "ml-IN", "ml"},
    {"Manipuri", "mni-IN", "mni"},
    {"Marathi", "mr-IN", "mr"},
    {"Nepali", "ne-NP", "ne"},
    {"Norwegian", "no-NO", "no"},
    {"Odia", "or-IN", "or"},
    {"Pashto", "ps-PK", "ps"},
    {"Persian", "fa-IR", "fa"},
    {"Polish", "pl-PL", "pl"},
    {"Portuguese (Brazil)", "pt-BR", "pt"},
    {"Portuguese (Portugal)", "pt-PT", "pt"},
    {"Punjabi", "pa-IN", "pa"},
    {"Romanian", "ro-RO", "ro"},
    {"Russian", "ru-RU", "ru"},
    {"Sanskrit", "sa-IN", "sa"},
    {"Santali", "sat-IN", "sat"},
    {"Serbian", "sr-RS", "sr"},
    {"Sindhi", "sd-IN", "sd"},
    {"Sinhala", "si-LK", "si"},
    {"Slovak", "sk-SK", "sk"},
    {"Slovenian", "sl-SI", "sl"},
    {"Somali", "so-SO", "so"},
    {"Spanish (Spain)", "es-ES", "es"},
    {"Spanish (US)", "es-US", "es"},
    {"Sundanese", "su-ID", "su"},
    {"Swahili", "sw-KE", "sw"},
    {"Swedish", "sv-SE", "sv"},
    {"Tamil", "ta-IN", "ta"},
    {"Telugu", "te-IN", "te"},
    {"Thai", "th-TH", "th"},
    {"Turkish", "tr-TR", "tr"},
    {"Ukrainian", "uk-UA", "uk"},
    {"Urdu (Pakistan)", "ur-PK", "ur"},
    {"Uzbek", "uz-UZ", "uz"},
    {"Vietnamese", "vi-VN", "vi"},
    {"Welsh", "cy-GB", "cy"},
    {"Zulu", "zu-ZA", "zu"}
}

local function readConfig()
    local status, file = pcall(io.open, configPath, "r")
    if status and file then
        local content = file:read("*a")
        pcall(function() file:close() end)
        local parseStatus, res = pcall(json.decode, content)
        if parseStatus and res and type(res) == "table" then
            if res.details == nil then res.details = {} end
            if res.translate == nil then res.translate = false end
            if res.micIndex == nil then res.micIndex = 0 end
            if res.targetIndex == nil then res.targetIndex = 2 end
            if res.offlineIndex == nil then res.offlineIndex = 0 end
            if res.dictionary == nil then res.dictionary = {} end
            if res.dictionaryEnabled == nil then res.dictionaryEnabled = true end
            if res.pinnedLanguages == nil then res.pinnedLanguages = {} end
            if res.customCommands == nil then 
                res.customCommands = {"name", "mobile", "address", "email"} 
            end
            if res.hideWelcome == nil then res.hideWelcome = false end
            return res
        end
    end
    return {translate = false, details = {}, micIndex = 0, targetIndex = 2, offlineIndex = 0, customCommands = {"name", "mobile", "address", "email"}, dictionary = {}, dictionaryEnabled = true, pinnedLanguages = {}, hideWelcome = false}
end

local function writeConfig(data)
    _G.advanceTyperCompiledDict = nil
    local status, file = pcall(io.open, configPath, "w")
    if status and file then
        pcall(function() file:write(json.encode(data)) end)
        pcall(function() file:close() end)
    else
        service.speak("File saving error. Please check storage.")
    end
end

local function getCommandText(key)
    if key == "name" then return "my name" end
    if key == "mobile" then return "my mobile number" end
    if key == "address" then return "my address" end
    if key == "email" then return "my email" end
    return key
end

local function playAudioTutorial()
    Toast.makeText(service, "Loading, please wait, this plugin created by Taslim Razaa.", Toast.LENGTH_SHORT).show()
    local audioUrl = "https://raw.githubusercontent.com/hafiztasleem85-cmyk/advanced-typer-/refs/heads/main/Advanced%20typer%20tutorial.m4a"
    local intent = Intent(Intent.ACTION_VIEW)
    intent.setDataAndType(Uri.parse(audioUrl), "audio/*")
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    local success, err = pcall(function()
        service.startActivity(intent)
    end)
    if not success then
        local browserIntent = Intent(Intent.ACTION_VIEW)
        browserIntent.setData(Uri.parse(audioUrl))
        browserIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        pcall(function()
            service.startActivity(browserIntent)
        end)
        local alert = AlertDialog.Builder(service)
        alert.setMessage("Downloading Tutorial. We couldn't find a supported online media player on your device. For your convenience, the complete Advanced Typer audio tutorial is now being downloaded directly to your phone. Please check your File Manager to listen to it offline.")
        alert.setPositiveButton("OK", nil)
        local d = alert.create()
        if Build.VERSION.SDK_INT >= 22 then 
            d.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY) 
        else 
            d.getWindow().setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT) 
        end
        d.show()
        d.getButton(DialogInterface.BUTTON_POSITIVE).setAllCaps(false)
        d.getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(View.OnClickListener{
            onClick = function(view)
                d.dismiss()
            end
        })
    end
end

local function showSettings()
    local conf = readConfig()
    local builder = AlertDialog.Builder(service)
    builder.setTitle("Advance Typer. This plugin created by. Taslim Razaa")
    
    local scroll = ScrollView(service)
    local rootLayout = LinearLayout(service)
    rootLayout.setOrientation(1)
    rootLayout.setPadding(40, 40, 40, 40)
    
    local pageMain = LinearLayout(service)
    pageMain.setOrientation(1)
    
    local pageDetail = LinearLayout(service)
    pageDetail.setOrientation(1)
    pageDetail.setVisibility(8)
    
    local pageDictionary = LinearLayout(service)
    pageDictionary.setOrientation(1)
    pageDictionary.setVisibility(8)
    
    local pageOffline = LinearLayout(service)
    pageOffline.setOrientation(1)
    pageOffline.setVisibility(8)
    
    rootLayout.addView(pageMain)
    rootLayout.addView(pageDetail)
    rootLayout.addView(pageDictionary)
    rootLayout.addView(pageOffline)
    scroll.addView(rootLayout)
    builder.setView(scroll)
    
    local mainDialog = builder.create()
    mainDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    
    local function showLanguageSelectorDialog(callback, currentIndex)
        local alertBuilder = AlertDialog.Builder(service)
        local layout = LinearLayout(service)
        layout.setOrientation(1)
        layout.setPadding(20, 20, 20, 20)
        
        local searchInput = EditText(service)
        searchInput.setHint("Search " .. tostring(#baseLanguages) .. " language")
        searchInput.setInputType(InputType.TYPE_CLASS_TEXT)
        searchInput.setImeOptions(EditorInfo.IME_ACTION_SEARCH)
        
        searchInput.setOnEditorActionListener(TextView.OnEditorActionListener{
            onEditorAction = function(v, actionId, event)
                if actionId == EditorInfo.IME_ACTION_SEARCH then
                    local imm = service.getSystemService(Context.INPUT_METHOD_SERVICE)
                    if imm then
                        imm.hideSoftInputFromWindow(v.getWindowToken(), 0)
                    end
                    return true
                end
                return false
            end
        })
        
        layout.addView(searchInput)
        
        local listView = ListView(service)
        listView.setChoiceMode(ListView.CHOICE_MODE_SINGLE)
        layout.addView(listView)
        alertBuilder.setView(layout)
        
        local langDialog = alertBuilder.create()
        langDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        
        local currentDisplayList = {}
        
        local function updateList(query)
            query = string.lower(query or "")
            local pinned = {}
            local unpinned = {}
            
            local pinnedCodes = {}
            for _, code in ipairs(conf.pinnedLanguages) do
                pinnedCodes[code] = true
            end
            
            local codeMap = {}
            for i, langData in ipairs(baseLanguages) do
                codeMap[langData[2]] = {langData, i - 1}
            end

            for _, code in ipairs(conf.pinnedLanguages) do
                if codeMap[code] then
                    local name = string.lower(codeMap[code][1][1])
                    if query == "" or string.find(name, query, 1, true) then
                        table.insert(pinned, codeMap[code])
                    end
                end
            end
            
            for i, langData in ipairs(baseLanguages) do
                if not pinnedCodes[langData[2]] then
                    local name = string.lower(langData[1])
                    if query == "" or string.find(name, query, 1, true) then
                        table.insert(unpinned, {langData, i - 1})
                    end
                end
            end
            
            currentDisplayList = {}
            local listData = {}
            local checkedPosition = -1
            
            for i, item in ipairs(pinned) do
                table.insert(currentDisplayList, item)
                table.insert(listData, item[1][1] .. " Pinned")
                if item[2] == currentIndex then checkedPosition = i - 1 end
            end
            
            for i, item in ipairs(unpinned) do
                table.insert(currentDisplayList, item)
                table.insert(listData, item[1][1])
                if item[2] == currentIndex then checkedPosition = #pinned + i - 1 end
            end
            
            local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_single_choice, listData)
            listView.setAdapter(adapter)
            if checkedPosition >= 0 then
                listView.setItemChecked(checkedPosition, true)
            end
        end
        
        searchInput.addTextChangedListener(TextWatcher{
            onTextChanged = function(s, start, before, count)
                updateList(tostring(s))
            end,
            beforeTextChanged = function(s, start, count, after) end,
            afterTextChanged = function(s) end
        })
        
        listView.setOnItemClickListener(AdapterView.OnItemClickListener{
            onItemClick = function(parent, view, position, id)
                local selectedItem = currentDisplayList[position + 1]
                callback(selectedItem[1], selectedItem[2])
                langDialog.dismiss()
            end
        })
        
        listView.setOnItemLongClickListener(AdapterView.OnItemLongClickListener{
            onItemLongClick = function(parent, view, position, id)
                local selectedItem = currentDisplayList[position + 1]
                local langCode = selectedItem[1][2]
                local langName = selectedItem[1][1]
                
                local isPinned = false
                local pinnedIndex = 0
                for i, code in ipairs(conf.pinnedLanguages) do
                    if code == langCode then
                        isPinned = true
                        pinnedIndex = i
                        break
                    end
                end
                
                if isPinned then
                    table.remove(conf.pinnedLanguages, pinnedIndex)
                    service.speak(langName .. " unpinned")
                else
                    table.insert(conf.pinnedLanguages, langCode)
                    service.speak(langName .. " pinned")
                end
                
                writeConfig(conf)
                updateList(tostring(searchInput.getText()))
                return true
            end
        })
        
        updateList("")
        langDialog.show()
        
        langDialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
        langDialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    end

    local titleMic = TextView(service)
    titleMic.setText("Select voice dictation language, Note: You can change the dictation language directly without opening this menu. Just say \"Switch language\" followed by the language name (e.g., \"Switch language Hindi\"). Please note that this voice command currently supports English, Hindi, Urdu, and Arabic.")
    titleMic.setPadding(0, 10, 0, 10)
    pageMain.addView(titleMic)
    
    local btnSelectMicLang = Button(service)
    local micLangName = (conf.micIndex < #baseLanguages and baseLanguages[conf.micIndex + 1][1] or "select language")
    btnSelectMicLang.setText(micLangName)
    btnSelectMicLang.setAllCaps(false)
    pageMain.addView(btnSelectMicLang)
    
    local swTranslate = Switch(service)
    swTranslate.setText("Auto translation mode   ")
    swTranslate.setChecked(conf.translate)
    swTranslate.setPadding(0, 30, 0, 20)
    pageMain.addView(swTranslate)
    
    local titleTarget = TextView(service)
    titleTarget.setText("Select language for translation")
    titleTarget.setPadding(0, 20, 0, 10)
    pageMain.addView(titleTarget)
    
    local btnSelectTargetLang = Button(service)
    local targetLangName = (conf.targetIndex < #baseLanguages and baseLanguages[conf.targetIndex + 1][1] or "select language")
    btnSelectTargetLang.setText(targetLangName)
    btnSelectTargetLang.setAllCaps(false)
    pageMain.addView(btnSelectTargetLang)
    
    if not conf.translate then
        titleTarget.setVisibility(8)
        btnSelectTargetLang.setVisibility(8)
    end
    
    local swDictionary = Switch(service)
    swDictionary.setText("Smart Dictionary   ")
    swDictionary.setChecked(conf.dictionaryEnabled)
    swDictionary.setPadding(0, 30, 0, 20)
    pageMain.addView(swDictionary)
    
    local btnDictionary = Button(service)
    btnDictionary.setText("Manage Dictionary")
    btnDictionary.setAllCaps(false)
    pageMain.addView(btnDictionary)
    
    if not conf.dictionaryEnabled then
        btnDictionary.setVisibility(8)
    end
    
    local btnOffline = Button(service)
    btnOffline.setText("Offline Voice Typing")
    btnOffline.setAllCaps(false)
    pageMain.addView(btnOffline)
    
    local btnDetail = Button(service)
    btnDetail.setText("Personal Detail and Command")
    btnDetail.setAllCaps(false)
    pageMain.addView(btnDetail)
    
    local btnContact = Button(service)
    btnContact.setText("Contact the Developer")
    btnContact.setAllCaps(false)
    pageMain.addView(btnContact)
    
    local btnHowToUse = Button(service)
    btnHowToUse.setText("How to use")
    btnHowToUse.setAllCaps(false)
    pageMain.addView(btnHowToUse)
    
    local btnExit = Button(service)
    btnExit.setText("Exit")
    btnExit.setAllCaps(false)
    pageMain.addView(btnExit)
    
    btnSelectMicLang.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            showLanguageSelectorDialog(function(langData, originalPosition)
                conf.micIndex = originalPosition
                writeConfig(conf)
                btnSelectMicLang.setText(langData[1])
            end, conf.micIndex)
        end
    })
    
    btnSelectTargetLang.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            showLanguageSelectorDialog(function(langData, originalPosition)
                conf.targetIndex = originalPosition
                writeConfig(conf)
                btnSelectTargetLang.setText(langData[1])
            end, conf.targetIndex)
        end
    })
    
    swTranslate.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
        onCheckedChanged = function(buttonView, isChecked)
            conf.translate = isChecked
            if isChecked then
                titleTarget.setVisibility(0)
                btnSelectTargetLang.setVisibility(0)
            else
                titleTarget.setVisibility(8)
                btnSelectTargetLang.setVisibility(8)
            end
            writeConfig(conf)
        end
    })
    
    swDictionary.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
        onCheckedChanged = function(buttonView, isChecked)
            conf.dictionaryEnabled = isChecked
            if isChecked then
                btnDictionary.setVisibility(0)
            else
                btnDictionary.setVisibility(8)
            end
            writeConfig(conf)
        end
    })
    
    btnOffline.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            pageMain.setVisibility(8)
            pageOffline.setVisibility(0)
            service.speak("Offline voice typing open")
        end
    })
    
    btnContact.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            local intent = Intent(Intent.ACTION_VIEW)
            intent.setData(Uri.parse("https://wa.me/919795801895"))
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            mainDialog.dismiss()
        end
    })
    
    btnHowToUse.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            local alert = AlertDialog.Builder(service)
            alert.setMessage("Thank you for choosing Advanced Typer. To make things easy and clear for you, the complete instruction guide has been carefully recorded as an audio tutorial. You do not need to read long manuals. Just click the 'Play Audio Tutorial' button below, sit back, and listen to the step-by-step guide.")
            alert.setNegativeButton("Play Audio Tutorial", nil)
            alert.setPositiveButton("Go Back", nil)
            
            local d = alert.create()
            if Build.VERSION.SDK_INT >= 22 then 
                d.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY) 
            else 
                d.getWindow().setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT) 
            end
            d.show()
            d.getButton(DialogInterface.BUTTON_NEGATIVE).setAllCaps(false)
            d.getButton(DialogInterface.BUTTON_POSITIVE).setAllCaps(false)
            
            d.getButton(DialogInterface.BUTTON_NEGATIVE).setOnClickListener(View.OnClickListener{
                onClick = function(view)
                    d.dismiss()
                    mainDialog.dismiss()
                    playAudioTutorial()
                end
            })
            
            d.getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(View.OnClickListener{
                onClick = function(view)
                    d.dismiss()
                end
            })
        end
    })
    
    btnExit.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            mainDialog.dismiss()
        end
    })
    
    local titleDetailsForm = TextView(service)
    titleDetailsForm.setText("Personal Detail Form")
    titleDetailsForm.setPadding(0, 0, 0, 20)
    titleDetailsForm.setTextSize(18)
    pageDetail.addView(titleDetailsForm)
    
    local fieldsContainer = LinearLayout(service)
    fieldsContainer.setOrientation(1)
    pageDetail.addView(fieldsContainer)
    
    local btnAddCommand = Button(service)
    btnAddCommand.setText("Add More Command")
    btnAddCommand.setAllCaps(false)
    pageDetail.addView(btnAddCommand)
    
    local btnManageCommand = Button(service)
    btnManageCommand.setText("Manage Shortcut Command")
    btnManageCommand.setAllCaps(false)
    pageDetail.addView(btnManageCommand)
    
    local btnSave = Button(service)
    btnSave.setText("Save")
    btnSave.setAllCaps(false)
    pageDetail.addView(btnSave)
    
    local btnBack = Button(service)
    btnBack.setText("Go Back")
    btnBack.setAllCaps(false)
    pageDetail.addView(btnBack)
    
    local editBoxes = {}
    
    local function loadFields()
        fieldsContainer.removeAllViews()
        editBoxes = {}
        for _, key in ipairs(conf.customCommands) do
            local cmdText = getCommandText(key)
            
            local tv = TextView(service)
            tv.setText("Command: " .. cmdText)
            tv.setPadding(0, 10, 0, 0)
            fieldsContainer.addView(tv)
            
            local ed = EditText(service)
            ed.setText(conf.details[key] or "")
            ed.setHint(cmdText)
            if key == "email" then
                ed.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS)
            elseif key == "mobile" then
                ed.setInputType(InputType.TYPE_CLASS_NUMBER)
            else
                ed.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_CAP_WORDS + InputType.TYPE_TEXT_FLAG_MULTI_LINE)
            end
            fieldsContainer.addView(ed)
            editBoxes[key] = ed
        end
    end
    
    local function showManageCommandsDialog()
        local alert = AlertDialog.Builder(service)
        alert.setTitle("Manage Commands")
        
        local adapterList = {}
        local keyMap = {}
        for i, cmdKey in ipairs(conf.customCommands) do
            local dispName = getCommandText(cmdKey)
            table.insert(adapterList, dispName)
            table.insert(keyMap, cmdKey)
        end
        
        local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, adapterList)
        alert.setAdapter(adapter, DialogInterface.OnClickListener{
            onClick = function(dialog, which)
                local selectedKey = keyMap[which + 1]
                local selectedDispName = adapterList[which + 1]
                
                local optAlert = AlertDialog.Builder(service)
                optAlert.setTitle(selectedDispName)
                local opts = {"Rename", "Delete"}
                local optAdapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, opts)
                
                optAlert.setAdapter(optAdapter, DialogInterface.OnClickListener{
                    onClick = function(optDialog, optWhich)
                        if optWhich == 0 then
                            local renAlert = AlertDialog.Builder(service)
                            renAlert.setTitle("Rename Command")
                            local renInput = EditText(service)
                            renInput.setText(selectedDispName)
                            renInput.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_CAP_WORDS)
                            renAlert.setView(renInput)
                            renAlert.setPositiveButton("OK", nil)
                            renAlert.setNegativeButton("Cancel", nil)
                            renAlert.setOnCancelListener(DialogInterface.OnCancelListener{
                                onCancel = function(d)
                                    showManageCommandsDialog()
                                end
                            })
                            
                            local renDialog = renAlert.create()
                            renDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
                            renDialog.show()
                            
                            renDialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                            renDialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
                            
                            local renOk = renDialog.getButton(DialogInterface.BUTTON_POSITIVE)
                            renOk.setOnClickListener(View.OnClickListener{
                                onClick = function(view)
                                    local newName = renInput.getText().toString()
                                    if newName == "" then
                                        service.speak("Please type a name")
                                    else
                                        local oldVal = conf.details[selectedKey]
                                        if selectedKey ~= newName then
                                            conf.details[newName] = oldVal
                                            conf.details[selectedKey] = nil
                                            for i, c in ipairs(conf.customCommands) do
                                                if c == selectedKey then
                                                    conf.customCommands[i] = newName
                                                    break
                                                end
                                            end
                                        end
                                        writeConfig(conf)
                                        loadFields()
                                        renDialog.dismiss()
                                        service.speak("Renamed")
                                        showManageCommandsDialog()
                                    end
                                end
                            })
                            
                            local renCancel = renDialog.getButton(DialogInterface.BUTTON_NEGATIVE)
                            renCancel.setOnClickListener(View.OnClickListener{
                                onClick = function(view)
                                    renDialog.dismiss()
                                    showManageCommandsDialog()
                                end
                            })
                            
                        elseif optWhich == 1 then
                            conf.details[selectedKey] = nil
                            for i, c in ipairs(conf.customCommands) do
                                if c == selectedKey then
                                    table.remove(conf.customCommands, i)
                                    break
                                end
                            end
                            writeConfig(conf)
                            loadFields()
                            service.speak("Deleted")
                            showManageCommandsDialog()
                        end
                    end
                })
                
                optAlert.setNegativeButton("Cancel", DialogInterface.OnClickListener{
                    onClick = function(d, w)
                        showManageCommandsDialog()
                    end
                })
                optAlert.setOnCancelListener(DialogInterface.OnCancelListener{
                    onCancel = function(d)
                        showManageCommandsDialog()
                    end
                })
                
                local optD = optAlert.create()
                optD.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
                optD.show()
            end
        })
        
        alert.setNegativeButton("Go Back", nil)
        
        local listDialog = alert.create()
        listDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        listDialog.show()
        listDialog.getButton(DialogInterface.BUTTON_NEGATIVE).setAllCaps(false)
    end
    
    btnDetail.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            loadFields()
            pageMain.setVisibility(8)
            pageDetail.setVisibility(0)
            service.speak("Personal detail open")
            titleDetailsForm.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
        end
    })
    
    btnAddCommand.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            service.speak("Add new command")
            for key, ed in pairs(editBoxes) do
                conf.details[key] = ed.getText().toString()
            end
            
            local alert = AlertDialog.Builder(service)
            alert.setTitle("Add New Command")
            local input = EditText(service)
            input.setHint("Please type command")
            input.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_CAP_WORDS)
            alert.setView(input)
            alert.setPositiveButton("OK", nil)
            alert.setNegativeButton("Cancel", nil)
            
            local cmdDialog = alert.create()
            cmdDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
            cmdDialog.show()
            
            cmdDialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
            cmdDialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
            
            local okBtn = cmdDialog.getButton(DialogInterface.BUTTON_POSITIVE)
            okBtn.setOnClickListener(View.OnClickListener{
                onClick = function(view)
                    local newCmd = input.getText().toString()
                    if newCmd == "" then
                        service.speak("Please type command first")
                    else
                        table.insert(conf.customCommands, newCmd)
                        conf.details[newCmd] = ""
                        writeConfig(conf)
                        loadFields()
                        cmdDialog.dismiss()
                    end
                end
            })
        end
    })
    
    btnManageCommand.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            for key, ed in pairs(editBoxes) do
                local val = ed.getText().toString()
                if val ~= "" then
                    conf.details[key] = val
                else
                    conf.details[key] = nil
                end
            end
            writeConfig(conf)
            showManageCommandsDialog()
        end
    })
    
    btnSave.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            local imm = service.getSystemService(Context.INPUT_METHOD_SERVICE)
            if imm then
                imm.hideSoftInputFromWindow(v.getWindowToken(), 0)
            end
            for key, ed in pairs(editBoxes) do
                local val = ed.getText().toString()
                if val ~= "" then
                    conf.details[key] = val
                else
                    conf.details[key] = nil
                end
            end
            writeConfig(conf)
            service.speak("Settings saved")
            pageDetail.setVisibility(8)
            pageMain.setVisibility(0)
            titleMic.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
        end
    })
    
    btnBack.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            local imm = service.getSystemService(Context.INPUT_METHOD_SERVICE)
            if imm then
                imm.hideSoftInputFromWindow(v.getWindowToken(), 0)
            end
            pageDetail.setVisibility(8)
            pageMain.setVisibility(0)
            service.speak("Main menu")
            titleMic.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
        end
    })
    
    local titleDictForm = TextView(service)
    titleDictForm.setText("Smart Dictionary")
    titleDictForm.setPadding(0, 0, 0, 20)
    titleDictForm.setTextSize(18)
    pageDictionary.addView(titleDictForm)
    
    local btnAddDictWord = Button(service)
    btnAddDictWord.setText("Add New Word")
    btnAddDictWord.setAllCaps(false)
    pageDictionary.addView(btnAddDictWord)
    
    local dictListContainer = LinearLayout(service)
    dictListContainer.setOrientation(1)
    dictListContainer.setPadding(0, 20, 0, 20)
    pageDictionary.addView(dictListContainer)
    
    local btnBackDict = Button(service)
    btnBackDict.setText("Go Back")
    btnBackDict.setAllCaps(false)
    pageDictionary.addView(btnBackDict)
    
    local loadDictList
    
    local function showDictDialog(oldW, oldR)
        local isEdit = (oldW ~= nil and oldW ~= "")
        local alert = AlertDialog.Builder(service)
        if isEdit then
            alert.setTitle("Edit Word")
        else
            alert.setTitle("Add New Word")
        end
        
        local layout = LinearLayout(service)
        layout.setOrientation(1)
        layout.setPadding(40, 20, 40, 20)
        
        local inputWrong = EditText(service)
        inputWrong.setHint("Wrong Word")
        if isEdit then inputWrong.setText(oldW) end
        layout.addView(inputWrong)
        
        local inputRight = EditText(service)
        inputRight.setHint("Correct Word")
        if isEdit then inputRight.setText(oldR) end
        layout.addView(inputRight)
        
        alert.setView(layout)
        alert.setPositiveButton("Save", nil)
        alert.setNegativeButton("Cancel", nil)
        
        local cmdDialog = alert.create()
        cmdDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        cmdDialog.show()
        
        cmdDialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
        cmdDialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        
        local okBtn = cmdDialog.getButton(DialogInterface.BUTTON_POSITIVE)
        okBtn.setOnClickListener(View.OnClickListener{
            onClick = function(view)
                local w = inputWrong.getText().toString():match("^%s*(.-)%s*$") or ""
                local r = inputRight.getText().toString():match("^%s*(.-)%s*$") or ""
                if w == "" or r == "" then
                    service.speak("Please type both words")
                else
                    if isEdit and w ~= oldW then
                        conf.dictionary[oldW] = nil
                    end
                    conf.dictionary[w] = r
                    writeConfig(conf)
                    loadDictList()
                    cmdDialog.dismiss()
                    service.speak("Saved")
                end
            end
        })
    end
    
    loadDictList = function()
        dictListContainer.removeAllViews()
        for w, r in pairs(conf.dictionary) do
            local tv = TextView(service)
            tv.setText("Wrong: " .. w .. "\nCorrect: " .. r)
            tv.setTextSize(16)
            tv.setPadding(0, 20, 0, 20)
            tv.setFocusable(true)
            tv.setClickable(true)
            tv.setOnClickListener(View.OnClickListener{
                onClick = function(v)
                    local alert = AlertDialog.Builder(service)
                    alert.setTitle("Options")
                    local options = {"Edit", "Delete", "Go Back"}
                    local adapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, options)
                    alert.setAdapter(adapter, DialogInterface.OnClickListener{
                        onClick = function(dialogInterface, which)
                            if which == 0 then
                                showDictDialog(w, r)
                            elseif which == 1 then
                                conf.dictionary[w] = nil
                                writeConfig(conf)
                                loadDictList()
                                service.speak("Deleted")
                            else
                                dialogInterface.dismiss()
                            end
                        end
                    })
                    local d = alert.create()
                    d.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
                    d.show()
                end
            })
            dictListContainer.addView(tv)
        end
    end
    
    btnDictionary.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            loadDictList()
            pageMain.setVisibility(8)
            pageDictionary.setVisibility(0)
            service.speak("Smart dictionary open")
            titleDictForm.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
        end
    })
    
    btnAddDictWord.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            showDictDialog(nil, nil)
        end
    })
    
    btnBackDict.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            pageDictionary.setVisibility(8)
            pageMain.setVisibility(0)
            service.speak("Main menu")
            titleMic.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
        end
    })
    
    local titleOfflineForm = TextView(service)
    titleOfflineForm.setText("Offline Voice Typing")
    titleOfflineForm.setPadding(0, 0, 0, 20)
    titleOfflineForm.setTextSize(18)
    pageOffline.addView(titleOfflineForm)
    
    local textOfflineDesc = TextView(service)
    textOfflineDesc.setText("Offline voice typing lets you type without an internet connection. The system will automatically switch to offline mode when there is no internet, and it will switch back to online mode when the internet is available. \n\nTo use this feature, there are two mandatory conditions:\n1. You must download the voice package for your language from your device settings using the Download Package button below.\n2. You must select the exact same language in the dropdown menu below that you have downloaded in your system settings. For example, if you downloaded the English India package, you must select English India here. Selecting English US will prevent offline typing from working.")
    textOfflineDesc.setPadding(0, 0, 0, 20)
    textOfflineDesc.setTextSize(16)
    pageOffline.addView(textOfflineDesc)
    
    local btnSelectOfflineLang = Button(service)
    local offlineLangName = (conf.offlineIndex < #baseLanguages and baseLanguages[conf.offlineIndex + 1][1] or "select language")
    btnSelectOfflineLang.setText(offlineLangName)
    btnSelectOfflineLang.setAllCaps(false)
    pageOffline.addView(btnSelectOfflineLang)
    
    local btnDownloadPackage = Button(service)
    btnDownloadPackage.setText("Download Package")
    btnDownloadPackage.setAllCaps(false)
    pageOffline.addView(btnDownloadPackage)
    
    local btnBackOffline = Button(service)
    btnBackOffline.setText("Go Back")
    btnBackOffline.setAllCaps(false)
    pageOffline.addView(btnBackOffline)
    
    btnSelectOfflineLang.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            showLanguageSelectorDialog(function(langData, originalPosition)
                conf.offlineIndex = originalPosition
                writeConfig(conf)
                btnSelectOfflineLang.setText(langData[1])
            end, conf.offlineIndex)
        end
    })
    
    btnDownloadPackage.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            local success, err = pcall(function()
                local intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                service.startActivity(intent)
            end)
            if not success then
                local intent2 = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                intent2.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                service.startActivity(intent2)
            end
            mainDialog.dismiss()
        end
    })
    
    btnBackOffline.setOnClickListener(View.OnClickListener{
        onClick = function(v)
            pageOffline.setVisibility(8)
            pageMain.setVisibility(0)
            service.speak("Main menu")
            titleMic.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
        end
    })
    
    mainDialog.show()
    mainDialog.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
    mainDialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    titleMic.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
end

local function tryMyMemory(encodedText, targetLangCode, speechRecognizer)
    local urlMyMemory = "https://api.mymemory.translated.net/get?q=" .. encodedText .. "&langpair=autodetect|" .. targetLangCode
    Http.get(urlMyMemory, nil, "utf-8", nil, function(code, responseText)
        if code == 200 and type(responseText) == "string" and responseText ~= "" then
            local successDecode, response = pcall(json.decode, responseText)
            if successDecode and response and response.responseData and response.responseData.translatedText then
                local translatedText = response.responseData.translatedText
                if response.responseStatus == 200 and not string.find(translatedText, "MYMEMORY") and not string.find(translatedText, "LIMIT EXCEEDED") then
                    translatedText = translatedText:gsub("^%s*(.-)%s*$", "%1") .. " "
                    local currentNode = service.getEditText()
                    if currentNode then
                        if not currentNode.isFocused() then
                            currentNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                        end
                        service.insertText(currentNode, translatedText)
                        service.speak(translatedText)
                    end
                    safeStop(speechRecognizer)
                    return
                end
            end
        end
        service.speak("Translation failed. Please try again later.")
        safeStop(speechRecognizer)
    end)
end

local function startListening(node)
    if _G.advanceTyperActiveMic then
        safeStop(_G.advanceTyperActiveMic)
    end

    if Build.VERSION.SDK_INT >= 23 then
        local permissionCheck = service.checkSelfPermission("android.permission.RECORD_AUDIO")
        if permissionCheck ~= PackageManager.PERMISSION_GRANTED then
            service.speak("Please check your microphone permission in settings.")
            return
        end
    end
    
    local conf = readConfig()
    if conf.micIndex < 0 or conf.micIndex >= #baseLanguages then conf.micIndex = 0 end
    if conf.targetIndex < 0 or conf.targetIndex >= #baseLanguages then conf.targetIndex = 2 end
    if conf.offlineIndex < 0 or conf.offlineIndex >= #baseLanguages then conf.offlineIndex = 0 end
    
    local connectivityManager = service.getSystemService(Context.CONNECTIVITY_SERVICE)
    local isConnected = false
    if connectivityManager then
        local status, network = pcall(function() return connectivityManager.getActiveNetwork() end)
        if status and network then
            local capStatus, capabilities = pcall(function() return connectivityManager.getNetworkCapabilities(network) end)
            if capStatus and capabilities and capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) then
                if Build.VERSION.SDK_INT >= 23 then
                    if capabilities.hasCapability(16) then
                        isConnected = true
                    end
                else
                    isConnected = true
                end
            end
        else
            local networkInfo = connectivityManager.getActiveNetworkInfo()
            if networkInfo and networkInfo.isConnected() then
                isConnected = true
            end
        end
    end
    
    local activeLangCode = baseLanguages[conf.micIndex + 1][2]
    if not isConnected then
        activeLangCode = baseLanguages[conf.offlineIndex + 1][2]
    end
    local targetLangCode = baseLanguages[conf.targetIndex + 1][3]
    
    local compiledDictionary = {}
    if _G.advanceTyperCompiledDict then
        compiledDictionary = _G.advanceTyperCompiledDict
    else
        if conf.dictionaryEnabled and conf.dictionary then
            for wrongWord, rightWord in pairs(conf.dictionary) do
                local w = wrongWord:match("^%s*(.-)%s*$") or wrongWord
                local r = rightWord:match("^%s*(.-)%s*$") or rightWord
                if w ~= "" then
                    local patternStr = "(?i)(?<=^|[\\s\\p{Punct}])" .. Pattern.quote(w) .. "(?=[\\s\\p{Punct}]|$)"
                    table.insert(compiledDictionary, {
                        pattern = Pattern.compile(patternStr),
                        replacement = Matcher.quoteReplacement(String(r))
                    })
                end
            end
        end
        _G.advanceTyperCompiledDict = compiledDictionary
    end
    
    local recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, activeLangCode)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, service.getPackageName())
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, Long(10000))
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, Long(10000))
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, Long(10000))

    local speechRecognizer = SpeechRecognizer.createSpeechRecognizer(service)
    _G.advanceTyperActiveMic = speechRecognizer
    activeSpeechRecognizer = speechRecognizer

    local speechListener = RecognitionListener{
        onResults = function(results)
            local data = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if data and data.size() > 0 then
                local recognizedText = tostring(data.get(0))

                local jRecognizedTextForCmd = recognizedText:match("^%s*(.-)%s*$") or ""
                jRecognizedTextForCmd = string.lower(jRecognizedTextForCmd:gsub("%s+", " "))

                local langMap = {
                    ["english"] = "en-IN",
                    ["انگریزی"] = "en-IN",
                    ["انگلش"] = "en-IN",
                    ["انجلش"] = "en-IN",
                    ["إنجليزي"] = "en-IN",
                    ["इंग्लिश"] = "en-IN",
                    ["अंग्रेजी"] = "en-IN",
                    ["hindi"] = "hi-IN",
                    ["ہندی"] = "hi-IN",
                    ["هندي"] = "hi-IN",
                    ["हिंदी"] = "hi-IN",
                    ["urdu"] = "ur-IN",
                    ["اردو"] = "ur-IN",
                    ["أردو"] = "ur-IN",
                    ["اوردو"] = "ur-IN",
                    ["उर्दू"] = "ur-IN",
                    ["arabic"] = "ar-SA",
                    ["arabi"] = "ar-SA",
                    ["عربی"] = "ar-SA",
                    ["عربي"] = "ar-SA",
                    ["عربک"] = "ar-SA",
                    ["अरबी"] = "ar-SA"
                }
                
                local triggers = {"switch language ", "स्विच लैंग्वेज ", "سوئچ لینگویج ", "سوچ لینگویج ", "تبديل اللغة ", "سويتش سويتش ", "سويتش ", "سويس لانج ", "سويتش لانج ", "سويت ", "سويت لانجز "}
                local requestedLangCode = nil

                for _, trigger in ipairs(triggers) do
                    if string.sub(jRecognizedTextForCmd, 1, string.len(trigger)) == trigger then
                        local langName = string.sub(jRecognizedTextForCmd, string.len(trigger) + 1)
                        langName = langName:match("^%s*(.-)%s*$")
                        if langMap[langName] then
                            requestedLangCode = langMap[langName]
                            break
                        end
                    end
                end

                if requestedLangCode then
                    local foundLangIndex = -1
                    for i, langData in ipairs(baseLanguages) do
                        if langData[2] == requestedLangCode then
                            foundLangIndex = i - 1
                            break
                        end
                    end
                    if foundLangIndex >= 0 then
                        conf.micIndex = foundLangIndex
                        writeConfig(conf)
                        service.speak("Language changed")
                        safeStop(speechRecognizer)
                        return
                    end
                end

                if conf.dictionaryEnabled and #compiledDictionary > 0 then
                    local jText = String(recognizedText)
                    for _, item in ipairs(compiledDictionary) do
                        local matcher = item.pattern.matcher(jText)
                        jText = String(matcher.replaceAll(item.replacement))
                    end
                    recognizedText = tostring(jText)
                end

                if not conf.translate then
                    local detailCommands = {
                        ["my name"] = conf.details["name"],
                        ["my mobile number"] = conf.details["mobile"],
                        ["my address"] = conf.details["address"],
                        ["my email"] = conf.details["email"],
                        ["माय नेम"] = conf.details["name"],
                        ["माय মোবাইল नंबर"] = conf.details["mobile"],
                        ["माय एड्रेस"] = conf.details["address"],
                        ["माय ईमेल"] = conf.details["email"]
                    }
                    
                    for _, key in ipairs(conf.customCommands) do
                        if key ~= "name" and key ~= "mobile" and key ~= "address" and key ~= "email" then
                            detailCommands[key] = conf.details[key]
                        end
                    end

                    local jRecognizedText = recognizedText:match("^%s*(.-)%s*$") or ""
                    jRecognizedText = string.lower(jRecognizedText:gsub("%s+", " "))
                    for k, v in pairs(detailCommands) do
                        if v and v ~= "" then
                            local jK = tostring(k):match("^%s*(.-)%s*$") or ""
                            jK = string.lower(jK:gsub("%s+", " "))
                            if jRecognizedText == jK then
                                recognizedText = v
                                break
                            end
                        end
                    end
                end

                if conf.translate then
                    if not isConnected then
                        service.speak("No internet connection")
                        safeStop(speechRecognizer)
                        return
                    end

                    local encodedText = URLEncoder.encode(recognizedText, "UTF-8")

                    local urlGoogle = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" .. targetLangCode .. "&dt=t&q=" .. encodedText
                    local headers = {
                        ["User-Agent"] = "Mozilla/5.0 (Android 14; Mobile; rv:122.0) Gecko/122.0 Firefox/122.0"
                    }

                    Http.get(urlGoogle, nil, "utf-8", headers, function(code, responseText)
                        if code == 200 and type(responseText) == "string" and responseText ~= "" then
                            local successDecode, response = pcall(json.decode, responseText)
                            if successDecode and type(response) == "table" and type(response[1]) == "table" then
                                local translatedText = ""
                                for _, item in ipairs(response[1]) do
                                    if type(item) == "table" and type(item[1]) == "string" then
                                        translatedText = translatedText .. item[1]
                                    end
                                end
                                translatedText = translatedText:gsub("^%s*(.-)%s*$", "%1") .. " "
                                local currentNode = service.getEditText()
                                if currentNode then
                                    if not currentNode.isFocused() then
                                        currentNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                                    end
                                    service.insertText(currentNode, translatedText)
                                    service.speak(translatedText)
                                end
                                safeStop(speechRecognizer)
                                return
                            end
                        end
                        tryMyMemory(encodedText, targetLangCode, speechRecognizer)
                    end)
                else
                    local existingText = ""
                    if node.getText() then
                        existingText = tostring(node.getText())
                    end
                    
                    pcall(function()
                        local hint = node.getHintText()
                        if hint ~= nil and existingText == tostring(hint) then
                            existingText = ""
                        end
                    end)
                    
                    local trimmedExisting = existingText:gsub("[ \t]+$", "")
                    local selStart = -1
                    pcall(function() selStart = node.getTextSelectionStart() end)
                    
                    recognizedText = recognizedText:match("^%s*(.-)$") or recognizedText
                    
                    if string.len(recognizedText) > 0 then
                        local firstByte = string.byte(recognizedText, 1)
                        if firstByte and ((firstByte >= 65 and firstByte <= 90) or (firstByte >= 97 and firstByte <= 122)) then
                            local firstChar = string.sub(recognizedText, 1, 1)
                            local rest = string.sub(recognizedText, 2)
                            recognizedText = string.lower(firstChar) .. rest
                        end
                    end
                    
                    recognizedText = recognizedText .. " "
                    if not node.isFocused() then
                        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    end
                    service.insertText(node, recognizedText)
                    service.speak(recognizedText)
                    safeStop(speechRecognizer)
                end
            else
                service.speak("Sorry! I Did Not Understand This Message")
                safeStop(speechRecognizer)
            end
        end,
        onError = function(errorCode)
            if not isConnected then
                local errText = "Sorry, the offline package for your selected language is not available. Please download it from settings using the Download Package button."
                if errorCode == SpeechRecognizer.ERROR_NO_MATCH or errorCode == SpeechRecognizer.ERROR_SPEECH_TIMEOUT then
                    errText = "Sorry! I Did Not Understand Your Message"
                end
                safeStop(speechRecognizer)
                Handler().postDelayed(Runnable{
                    run = function()
                        service.speak(errText)
                    end
                }, 400)
                return
            end
            
            local errorMessages = {
                [SpeechRecognizer.ERROR_NO_MATCH] = "Sorry! I Did Not Understand Your Message",
                [SpeechRecognizer.ERROR_SPEECH_TIMEOUT] = "Speech timeout.",
                [SpeechRecognizer.ERROR_CLIENT] = "Client error.",
                [SpeechRecognizer.ERROR_NETWORK] = "Network error.",
                [SpeechRecognizer.ERROR_NETWORK_TIMEOUT] = "Network timeout.",
                [SpeechRecognizer.ERROR_SERVER] = "Server error.",
                [SpeechRecognizer.ERROR_AUDIO] = "Audio error.",
                [SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS] = "Insufficient permissions."
            }
            local errorMessage = errorMessages[errorCode] or "An unexpected error occurred."
            service.speak(errorMessage)
            safeStop(speechRecognizer)
        end
    }

    speechRecognizer.setRecognitionListener(speechListener)
    speechRecognizer.startListening(recognizerIntent)
end

local function executePluginAction()
    local node = service.getEditText()
    if node then
        startListening(node)
    else
        showSettings()
    end
    checkUpdate()
end

local confMain = readConfig()
if confMain.hideWelcome == false then
    local alert = AlertDialog.Builder(service)
    alert.setMessage("Welcome to Advanced Typer, exclusively developed by Taslim Razaa. We are thrilled to have you here! To ensure you get the most out of every feature, we have put together a highly detailed and comprehensive audio guide. Listening to this complete tutorial will make your experience much smoother and help you master the plugin. If you have already listened to the tutorial, please click the 'OK' button to start using the plugin. Thank you for choosing Advanced Typer!")
    
    local layout = LinearLayout(service)
    layout.setOrientation(1)
    layout.setPadding(40, 20, 40, 20)
    local cb = CheckBox(service)
    cb.setText("Don't show again")
    layout.addView(cb)
    alert.setView(layout)
    
    alert.setPositiveButton("OK", nil)
    alert.setNegativeButton("Play Audio Tutorial", nil)
    
    local d = alert.create()
    if Build.VERSION.SDK_INT >= 22 then 
        d.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY) 
    else 
        d.getWindow().setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT) 
    end
    d.show()
    d.getButton(DialogInterface.BUTTON_NEGATIVE).setAllCaps(false)
    d.getButton(DialogInterface.BUTTON_POSITIVE).setAllCaps(false)
    
    d.getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(View.OnClickListener{
        onClick = function(v)
            if cb.isChecked() then
                confMain.hideWelcome = true
                writeConfig(confMain)
            end
            d.dismiss()
            executePluginAction()
        end
    })
    
    d.getButton(DialogInterface.BUTTON_NEGATIVE).setOnClickListener(View.OnClickListener{
        onClick = function(v)
            d.dismiss()
            playAudioTutorial()
        end
    })
else
    executePluginAction()
end

return true