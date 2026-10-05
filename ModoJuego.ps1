param([switch]$PreviewOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Seguridad.ps1"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$groups=@(
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
$inventory=@(Get-Process | Where-Object {try {Test-GameCandidate $_.ProcessName $_.Path} catch {$false}})
$startTimes=@{}; foreach($item in $inventory){try{$startTimes[$item.Id]=$item.StartTime}catch{}}
if($PreviewOnly){$inventory | Select-Object ProcessName,Id,Path; return}
$form=New-Object Windows.Forms.Form
$form.Text='Modo juego - Steam + Discord'
$form.Size=New-Object Drawing.Size(690,580)
$form.StartPosition='CenterScreen'
$info=New-Object Windows.Forms.Label
$info.Location=New-Object Drawing.Point(18,15)
$info.Size=New-Object Drawing.Size(640,66)
$info.Text="Steam, Discord, Windows, antivirus y controladores se conservan.`nSelecciona aplicaciones para solicitar su cierre normal. Guarda tu trabajo.`nEl cierre forzado es opcional y limitado; no se detienen servicios."
$form.Controls.Add($info)
$list=New-Object Windows.Forms.CheckedListBox
$list.Location=New-Object Drawing.Point(18,85)
$list.Size=New-Object Drawing.Size(640,200)
$list.CheckOnClick=$true
$active=@()
foreach($g in $groups){$ps=@($inventory | Where-Object {$_.ProcessName -in $g.Names}); if($ps.Count){$g.Processes=$ps; $active += $g; $mb=[math]::Round(($ps.WorkingSet64 | Measure-Object -Sum).Sum/1MB); [void]$list.Items.Add("$($g.Label) - $mb MB ($($ps.Count) procesos)",[bool]$g.Default)}}
$form.Controls.Add($list)
$button=New-Object Windows.Forms.Button
$button.Text='Cerrar seleccionadas'
$button.Location=New-Object Drawing.Point(18,300)
$button.Size=New-Object Drawing.Size(290,34)
$form.Controls.Add($button)
$force=New-Object Windows.Forms.CheckBox
$force.Text='Forzar cierre de apps opcionales (Chrome y Codex: solo cierre normal)'
$force.Location=New-Object Drawing.Point(18,342)
$force.Size=New-Object Drawing.Size(640,25)
$force.Checked=$false
$form.Controls.Add($force)
$result=New-Object Windows.Forms.TextBox
$result.Location=New-Object Drawing.Point(18,377)
$result.Size=New-Object Drawing.Size(640,150)
$result.Multiline=$true
$result.ReadOnly=$true
$result.ScrollBars='Vertical'
$form.Controls.Add($result)
$button.Add_Click({
 $button.Enabled=$false
 $lines=New-Object 'System.Collections.Generic.List[string]'
 foreach($index in @($list.CheckedIndices)){
  foreach($original in $active[$index].Processes){
   try {
    $p=Get-Process -Id $original.Id -ErrorAction Stop
    if(-not $startTimes.ContainsKey($original.Id) -or $p.StartTime -ne $startTimes[$original.Id] -or -not (Test-GameCandidate $p.ProcessName $p.Path)){ $lines.Add("Omitido por seguridad: $($original.ProcessName)"); continue }
        if($force.Checked -and (Test-GameForceCandidate $p.ProcessName $p.Path)){
     if($p.SessionId -ne [System.Diagnostics.Process]::GetCurrentProcess().SessionId){$lines.Add("Omitido: pertenece a otra sesion ($($p.ProcessName))");continue}
     if($p.MainWindowHandle -ne 0){[void]$p.CloseMainWindow(); [void]$p.WaitForExit(500)}
     if($p.HasExited){$lines.Add("Cerrado: $($original.ProcessName)");continue}
     $current=Get-Process -Id $original.Id -ErrorAction Stop
     if($current.StartTime -ne $startTimes[$original.Id] -or -not (Test-GameForceCandidate $current.ProcessName $current.Path)){$lines.Add("Omitido por seguridad: $($original.ProcessName)");continue}
     Stop-Process -InputObject $current -Force -ErrorAction Stop
     if($current.WaitForExit(1500)){$lines.Add("Finalizado: $($original.ProcessName)")}else{$lines.Add("Cierre pendiente: $($original.ProcessName)")}
     continue
    }
    if($p.MainWindowHandle -eq 0){$lines.Add("Sin ventana; salir desde la bandeja: $($p.ProcessName)");continue}
    if($p.CloseMainWindow()){$lines.Add("Cierre solicitado: $($p.ProcessName)")}else{$lines.Add("No acepto cierre: $($p.ProcessName)")}
   } catch {$lines.Add("No disponible o protegido: $($original.ProcessName)")}
  }
 }
 if(-not $lines.Count){$lines.Add('No seleccionaste aplicaciones para cerrar.')}
 $result.Text=($lines -join "`r`n")+"`r`nUna solicitud no garantiza que la aplicacion haya salido."
 try { $logDir=Join-Path $PSScriptRoot 'Registros'; [void](New-Item -ItemType Directory -Path $logDir -Force); $result.Text | Set-Content (Join-Path $logDir ((Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt')) -Encoding UTF8 } catch {$result.AppendText("`r`nNo se pudo guardar el registro.")}
 $button.Enabled=$true
})
if(-not $active.Count){$result.Text='No hay aplicaciones de la lista disponibles para cerrar.'}
[void]$form.ShowDialog()
