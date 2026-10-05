$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Core.ps1"
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
$testDir=Join-Path ([IO.Path]::GetTempPath()) ('gamepause-test-'+[guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $testDir)
try {
 $file=Join-Path $testDir 'Perfiles.json'
 $profiles=Read-GameProfiles $file
 Assert ($profiles.Count -eq 0) 'Archivo nuevo debe dar perfiles vacios'
 Save-GameProfile $file 'CS2' @('WhatsApp','chrome','steam','svchost')
 $profiles=Read-GameProfiles $file
 Assert ($profiles['CS2'].Count -eq 2) 'Perfil debe excluir nombres no permitidos'
 Save-GameProfile $file 'CS2' @()
 Assert ((Read-GameProfiles $file)['CS2'].Count -eq 0) 'Perfil vacio debe conservarse'
 '{invalid' | Set-Content $file
 $failed=$false;try{Save-GameProfile $file 'Otro' @('chrome')}catch{$failed=$true}
 Assert $failed 'Archivo corrupto no debe sobrescribirse'
 Assert ((Get-Content $file -Raw) -match 'invalid') 'Archivo corrupto debe conservarse'
 $snap=[pscustomobject]@{Id=123;Name='WhatsApp.Root';Path='C:\Program Files\WindowsApps\5319275A.WhatsAppDesktop_1\WhatsApp.Root.exe';StartTime=[datetime]'2026-01-01';SessionId=1}
 $fake=[pscustomobject]@{Id=123;ProcessName=$snap.Name;Path=$snap.Path;StartTime=$snap.StartTime;SessionId=1;MainWindowHandle=1;HasExited=$false}
 $fake | Add-Member ScriptMethod CloseMainWindow {$true}
 $fake | Add-Member ScriptMethod WaitForExit {param($ms) $this.HasExited}
 $get={param($idp) $fake}.GetNewClosure()
 $r=Invoke-GameClose $snap $false 1 $get {throw 'No debe forzar'}
 Assert ($r.Status -eq 'Pending') 'No afirmar cierre antes de observar salida'
 $fake.StartTime=$snap.StartTime.AddSeconds(1)
 Assert ((Invoke-GameClose $snap $true 1 $get {throw 'No debe forzar'}).Status -eq 'Protected') 'Proteger PID reutilizado'
 $fake.StartTime=$snap.StartTime;$fake.SessionId=2
 Assert ((Invoke-GameClose $snap $true 1 $get {throw 'No debe forzar'}).Status -eq 'Protected') 'Proteger otra sesion'
 $fake.SessionId=1
 $stop={param($proc) $proc.HasExited=$true}
 $r=Invoke-GameClose $snap $true 1 $get $stop
 Assert ($r.Status -eq 'Closed') 'Confirmar cierre forzado observado'
 Assert $r.Restore 'Cierre confirmado debe habilitar restauracion'
 $fake.HasExited=$false
 $fake | Add-Member ScriptMethod CloseMainWindow {$this.HasExited=$true; $true} -Force
 Assert ((Invoke-GameClose $snap $false 1 $get $stop).Status -eq 'Closed') 'Confirmar cierre normal observado'
 $queue=New-Object 'System.Collections.Generic.List[object]'
 Add-GameRestore $queue $snap; Add-GameRestore $queue $snap
 Assert ($queue.Count -eq 1) 'No duplicar restauraciones de la misma aplicacion'
 $bad=[pscustomobject]@{Name='steam';Path='C:\Program Files (x86)\Steam\steam.exe'}
 Assert ((Invoke-GameRestore $bad {throw 'No ejecutar'} { @() }).Status -eq 'Protected') 'Restaurar solo lista permitida'
 Assert ((Invoke-GameRestore $snap {throw 'No duplicar'} {param($name) @([pscustomobject]@{Path=$snap.Path;SessionId=[System.Diagnostics.Process]::GetCurrentProcess().SessionId})}.GetNewClosure()).Status -eq 'AlreadyRunning') 'No duplicar apps abiertas'
 $state=[pscustomobject]@{Started=$false}
 $start={param($entry) $state.Started=$true}.GetNewClosure()
 Assert ((Invoke-GameRestore $snap $start { @() }).Status -eq 'Started') 'Restauracion solicita inicio'
 Assert $state.Started 'Restauracion ejecuta lanzador'
 $fake.HasExited=$false
 $fake | Add-Member ScriptMethod CloseMainWindow {$true} -Force
 Assert (-not (Confirm-GamePending $snap 1 $get)) 'No confirmar pendiente activo'
 Assert (Confirm-GamePending $snap 1 {param($idp) Get-Process -Id 2147483647 -ErrorAction Stop}) 'Confirmar proceso desaparecido'
 $fake.StartTime=$snap.StartTime.AddSeconds(1)
 Assert (Confirm-GamePending $snap 1 $get) 'PID nuevo confirma salida del original'
 $fake.StartTime=$snap.StartTime
 $fake.MainWindowHandle=0
 Assert ((Invoke-GameClose $snap $false 1 $get {throw 'No debe forzar'}).Status -eq 'NoWindow') 'Sin ventana no debe finalizar por defecto'
 $chrome=[pscustomobject]@{Id=123;Name='chrome';Path='C:\Program Files\Google\Chrome\Application\chrome.exe';StartTime=$snap.StartTime;SessionId=1}
 $fake.ProcessName='chrome';$fake.Path=$chrome.Path;$fake.MainWindowHandle=1
 Assert ((Invoke-GameClose $chrome $true 1 $get {throw 'Chrome no debe forzarse'}).Status -eq 'Pending') 'Chrome solo cierre normal aun con fuerza activada'
 Assert ((Invoke-GameRestore $snap {throw 'Inicio fallido'} { @() }).Status -eq 'Error') 'Fallo de restauracion debe informarse'
 Assert (-not (Confirm-GamePending $snap 1 {throw 'Consulta fallida'})) 'Error de consulta no confirma salida'
 Assert ((Invoke-GameRestore $snap $start {param($name) @([pscustomobject]@{Path=$snap.Path;SessionId=-1})}.GetNewClosure()).Status -eq 'Started') 'Una instancia de otra sesion no bloquea restauracion'
 'Core: 24 comprobaciones verificadas sin cerrar aplicaciones reales'
} finally {if(Test-Path $testDir){Get-ChildItem -LiteralPath $testDir -File | Remove-Item; Remove-Item -LiteralPath $testDir}}
