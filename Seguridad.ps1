function Test-GameCandidate([string]$Name,[string]$Path) {
 if (-not $Path -or $Path -match '\\Windows\\') { return $false }
 $rules=@{
 'WhatsApp.Root'='\\WindowsApps\\[^\\]*WhatsApp[^\\]*\\';
 'WhatsApp'='\\(WindowsApps\\[^\\]*WhatsApp[^\\]*|WhatsApp)\\';
 'PhoneExperienceHost'='\\WindowsApps\\Microsoft\.YourPhone_';
 'Battle.net'='\\Battle\.net\\';
 'EpicGamesLauncher'='\\Epic Games\\Launcher\\';
 'EADesktop'='\\Electronic Arts\\EA Desktop\\';
 'EALauncher'='\\Electronic Arts\\EA Desktop\\';
 'chrome'='\\Google\\Chrome\\Application\\chrome\.exe$';
 'ChatGPT'='\\WindowsApps\\OpenAI\.(Codex|ChatGPT)_';
 'NVIDIA Overlay'='\\NVIDIA Corporation\\';
 'GameBar'='\\WindowsApps\\Microsoft\.XboxGamingOverlay_';
 'WsToastNotification'='\\Wondershare\\Wondershare NativePush\\WsToastNotification\.exe$';
 'AdobeCollabSync'='\\Adobe\\Acrobat DC\\Acrobat\\AdobeCollabSync\.exe$';
 'Widgets'='\\WindowsApps\\MicrosoftWindows\.Client\.WebExperience_';
 'WidgetService'='\\WindowsApps\\MicrosoftWindows\.Client\.WebExperience_';
 'XboxGameBarWidgets'='\\WindowsApps\\Microsoft\.GamingApp_'
 }
 return ($rules.ContainsKey($Name) -and $Path -match $rules[$Name])
}

function Test-GameForceCandidate([string]$Name,[string]$Path) {
 $forceNames=@('WhatsApp.Root','WhatsApp','PhoneExperienceHost','NVIDIA Overlay','GameBar','XboxGameBarWidgets','Widgets','WidgetService','WsToastNotification','AdobeCollabSync')
 return ($Name -in $forceNames -and (Test-GameCandidate $Name $Path))
}
