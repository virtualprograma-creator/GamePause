$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Seguridad.ps1"
$cases=@(
 @('steam','C:\Program Files (x86)\Steam\steam.exe',$false),
 @('Discord','C:\Users\Demo\AppData\Local\Discord\Discord.exe',$false),
 @('svchost','C:\Windows\System32\svchost.exe',$false),
 @('EpicGamesLauncher','C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe',$true),
 @('EpicGamesLauncher','C:\Windows\EpicGamesLauncher.exe',$false),
 @('chrome','C:\Program Files\Google\Chrome\Application\chrome.exe',$true),
 @('chrome','C:\Temp\chrome.exe',$false)
)
foreach($c in $cases){if((Test-GameCandidate $c[0] $c[1]) -ne $c[2]){throw "Proteccion fallida: $($c[0]) $($c[1])"}}
'Protecciones verificadas: 7 casos'

$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Seguridad.ps1"
$forceCases=@(
 @('steam','C:\Program Files (x86)\Steam\steam.exe',$false),
 @('Discord','C:\Users\Demo\AppData\Local\Discord\Discord.exe',$false),
 @('chrome','C:\Program Files\Google\Chrome\Application\chrome.exe',$false),
 @('ChatGPT','C:\Program Files\WindowsApps\OpenAI.Codex_1\app\ChatGPT.exe',$false),
 @('WhatsApp.Root','C:\Program Files\WindowsApps\5319275A.WhatsAppDesktop_1\WhatsApp.Root.exe',$true),
 @('WsToastNotification','C:\Users\Demo\AppData\Local\Wondershare\Wondershare NativePush\WsToastNotification.exe',$true),
 @('WsNativePushService','C:\Users\Demo\AppData\Local\Wondershare\Wondershare NativePush\WsNativePushService.exe',$false),
 @('LightingService','C:\Program Files (x86)\LightingService\LightingService.exe',$false),
 @('Widgets','C:\Temp\Widgets.exe',$false)
)
foreach($c in $forceCases){if((Test-GameForceCandidate $c[0] $c[1]) -ne $c[2]){throw "Proteccion de cierre forzado fallida: $($c[0])"}}
'Protecciones de cierre forzado verificadas: 9 casos'
