. "$PSScriptRoot\Seguridad.ps1"
function Get-GameGroups {
 @(
  @{Label='WhatsApp';Names=@('WhatsApp.Root','WhatsApp');Default=$true},
  @{Label='Enlace Movil';Names=@('PhoneExperienceHost');Default=$true},
  @{Label='Battle.net';Names=@('Battle.net');Default=$true},
  @{Label='Epic Games';Names=@('EpicGamesLauncher');Default=$true},
  @{Label='EA';Names=@('EADesktop','EALauncher');Default=$true},
  @{Label='NVIDIA Overlay (sin grabacion)';Names=@('NVIDIA Overlay');Default=$false},
  @{Label='Game Bar (sin grabacion)';Names=@('GameBar','XboxGameBarWidgets');Default=$false},
  @{Label='Widgets de Windows';Names=@('Widgets','WidgetService');Default=$true},
  @{Label='Notificaciones Wondershare';Names=@('WsToastNotification');Default=$true},
  @{Label='Sincronizador Adobe Acrobat';Names=@('AdobeCollabSync');Default=$false},
  @{Label='Chrome (guarda tu trabajo)';Names=@('chrome');Default=$false},
  @{Label='Codex / ChatGPT (termina esta sesion)';Names=@('ChatGPT');Default=$false}
 )
}
function Read-GameProfiles([string]$File) {
 $profiles=@{}
 if(-not (Test-Path -LiteralPath $File)){return $profiles}
 $obj=Get-Content -LiteralPath $File -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
 if($null -eq $obj -or $obj -is [array] -or $obj -isnot [pscustomobject]){throw 'Formato de perfiles invalido'}
 $known=@((Get-GameGroups) | ForEach-Object {$_.Names})
 foreach($prop in $obj.PSObject.Properties){
  if([string]::IsNullOrWhiteSpace($prop.Name) -or $prop.Name.Length -gt 80){throw 'Nombre de perfil invalido'}
  if($prop.Value -isnot [array]){throw 'Selecciones de perfil invalidas'}
  $profiles[$prop.Name]=@($prop.Value | Where-Object {$_ -is [string] -and $_ -in $known} | Select-Object -Unique)
 }
 return $profiles
}
function Save-GameProfile([string]$File,[string]$Name,[string[]]$Selected) {
 $Name=$Name.Trim()
 if(-not $Name -or $Name.Length -gt 80){throw 'Escribe un nombre de entre 1 y 80 caracteres'}
 $profiles=Read-GameProfiles $File
 $known=@((Get-GameGroups) | ForEach-Object {$_.Names})
 $profiles[$Name]=@($Selected | Where-Object {$_ -in $known} | Select-Object -Unique)
 $dir=Split-Path -Parent $File; [void](New-Item -ItemType Directory -Path $dir -Force)
 $tmp=Join-Path $dir ('perfil-'+[guid]::NewGuid()+'.tmp')
 try { $profiles | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $tmp -Encoding UTF8; Move-Item -LiteralPath $tmp -Destination $File -Force } finally {if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp}}
}
function Get-GameInventory {
 $session=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
 foreach($p in Get-Process){try {
  if($p.SessionId -eq $session -and (Test-GameCandidate $p.ProcessName $p.Path)){
   [pscustomobject]@{Id=$p.Id;Name=$p.ProcessName;Path=$p.Path;StartTime=$p.StartTime;SessionId=$p.SessionId;RAM_MB=[math]::Round($p.WorkingSet64/1MB)}
  }
 }catch{}}
}
function Test-GameIdentity($Snapshot,$Process,[int]$SessionId) {
 return ($Process.Id -eq $Snapshot.Id -and $Process.StartTime -eq $Snapshot.StartTime -and $Process.Path -eq $Snapshot.Path -and $Process.ProcessName -eq $Snapshot.Name -and $Process.SessionId -eq $SessionId -and (Test-GameCandidate $Process.ProcessName $Process.Path))
}
function New-GameResult([string]$Status,[string]$Message,[bool]$Restore=$false) {
 [pscustomobject]@{Status=$Status;Message=$Message;Restore=$Restore}
}
function Invoke-GameClose($Snapshot,[bool]$Force,[int]$SessionId,
 [scriptblock]$GetById={param($idp) Get-Process -Id $idp -ErrorAction Stop},
 [scriptblock]$Stop={param($proc) Stop-Process -InputObject $proc -Force -ErrorAction Stop}) {
 try {$p=& $GetById $Snapshot.Id}catch{return New-GameResult 'Gone' 'Ya no esta en ejecucion'}
 try {
  if(-not (Test-GameIdentity $Snapshot $p $SessionId)){return New-GameResult 'Protected' 'Omitido por seguridad'}
  $canForce=$Force -and (Test-GameForceCandidate $p.ProcessName $p.Path)
  $requested=$false
  if($p.MainWindowHandle -ne 0){$requested=$p.CloseMainWindow(); if($requested){[void]$p.WaitForExit(500)}}
  if($p.HasExited){return New-GameResult 'Closed' 'Cerrado y confirmado' $requested}
  if($canForce){
   $current=& $GetById $Snapshot.Id
   if(-not (Test-GameIdentity $Snapshot $current $SessionId)){return New-GameResult 'Protected' 'Omitido por seguridad'}
   & $Stop $current
   if($current.WaitForExit(1500)){return New-GameResult 'Closed' 'Finalizado y confirmado' $true}
   return New-GameResult 'Pending' 'Cierre forzado pendiente de confirmar'
  }
  if($requested){return New-GameResult 'Pending' 'Cierre solicitado; sigue abierto'}
  return New-GameResult 'NoWindow' 'Sin cierre aceptado; salir desde su aplicacion o bandeja'
 }catch{return New-GameResult 'Error' 'No se pudo cerrar; puede estar protegido o haber salido'}
}
function Add-GameRestore($Queue,$Entry) {
 if(-not (Test-GameCandidate $Entry.Name $Entry.Path)){return}
 if(-not @($Queue | Where-Object {$_.Path -eq $Entry.Path}).Count){$Queue.Add($Entry)}
}
function Confirm-GamePending($Entry,[int]$SessionId,
 [scriptblock]$GetById={param($idp) Get-Process -Id $idp -ErrorAction Stop}) {
 try {$p=& $GetById $Entry.Id}catch{return ($_.FullyQualifiedErrorId -match '^NoProcessFoundForGivenId')}
 return (-not (Test-GameIdentity $Entry $p $SessionId))
}
function Start-GameApplication($Entry) {
 if(-not (Test-GameCandidate $Entry.Name $Entry.Path)){throw 'Aplicacion no permitida'}
 if($Entry.Path -match '\\WindowsApps\\'){
  $pkg=Get-AppxPackage | Where-Object {$_.InstallLocation -and $Entry.Path.StartsWith($_.InstallLocation+'\',[StringComparison]::OrdinalIgnoreCase)} | Select-Object -First 1
  if(-not $pkg){throw 'Paquete no disponible'}
  $manifest=Get-AppxPackageManifest -Package $pkg.PackageFullName
  $relative=$Entry.Path.Substring($pkg.InstallLocation.Length+1)
  $app=@($manifest.Package.Applications.Application | Where-Object {$_.Executable -eq $relative}) | Select-Object -First 1
  if(-not $app){throw 'No se encontro una entrada de inicio para este componente'}
  Start-Process -FilePath explorer.exe -ArgumentList ('shell:AppsFolder\'+$pkg.PackageFamilyName+'!'+$app.Id) -ErrorAction Stop
 }else {
  if(-not (Test-Path -LiteralPath $Entry.Path -PathType Leaf)){throw 'Archivo no disponible'}
  Start-Process -FilePath $Entry.Path -ErrorAction Stop
 }
}
function Invoke-GameRestore($Entry,
 [scriptblock]$Start={param($entry) Start-GameApplication $entry},
 [scriptblock]$Running={param($name) @(Get-Process -Name $name -ErrorAction SilentlyContinue)}) {
 if(-not (Test-GameCandidate $Entry.Name $Entry.Path)){return New-GameResult 'Protected' 'Restauracion omitida por seguridad'}
 try {
  $matches=@(& $Running $Entry.Name)
  foreach($p in $matches){if($p.Path -eq $Entry.Path -and $p.SessionId -eq [System.Diagnostics.Process]::GetCurrentProcess().SessionId){return New-GameResult 'AlreadyRunning' 'Ya esta abierta'}}
  & $Start $Entry
  return New-GameResult 'Started' 'Inicio solicitado; no recupera trabajo anterior'
 }catch{return New-GameResult 'Error' 'No se pudo abrir automaticamente; abre la aplicacion manualmente'}
}
