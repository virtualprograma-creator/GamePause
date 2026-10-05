param([switch]$PreviewOnly,[switch]$SmokeTest,[string]$ScreenshotPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Core.ps1"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if($PreviewOnly){Get-GameInventory;return}
[Windows.Forms.Application]::EnableVisualStyles()
$script:groups=@(Get-GameGroups)
$script:inventory=@()
$script:restoreQueue=New-Object 'System.Collections.Generic.List[object]'
$script:pending=New-Object 'System.Collections.Generic.List[object]'
$script:sessionId=[System.Diagnostics.Process]::GetCurrentProcess().SessionId
$script:profileFile=Join-Path $PSScriptRoot 'Datos\Perfiles.json'
$form=New-Object Windows.Forms.Form
$form.Text='GamePause v1.1.0'
$form.ClientSize=New-Object Drawing.Size(800,700)
$form.StartPosition='CenterScreen'
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
function New-Label($Text,$X,$Y,$Width,$Height){$c=New-Object Windows.Forms.Label;$c.Text=$Text;$c.Location=New-Object Drawing.Point($X,$Y);$c.Size=New-Object Drawing.Size($Width,$Height);$form.Controls.Add($c);return $c}
function New-Button($Text,$X,$Y,$Width){$c=New-Object Windows.Forms.Button;$c.Text=$Text;$c.Location=New-Object Drawing.Point($X,$Y);$c.Size=New-Object Drawing.Size($Width,32);$form.Controls.Add($c);return $c}
[void](New-Label "Steam, Discord, juegos, antivirus, servicios y controladores se conservan.`nGuarda tu trabajo. El cierre forzado puede interrumpir llamadas, grabacion o sincronizacion." 16 12 765 42)
[void](New-Label 'Perfil / nombre del juego:' 16 64 175 22)
$profile=New-Object Windows.Forms.ComboBox
$profile.Location=New-Object Drawing.Point(192,61)
$profile.Size=New-Object Drawing.Size(290,26)
$profile.MaxLength=80
$form.Controls.Add($profile)
$load=New-Button 'Cargar perfil' 492 59 130
$save=New-Button 'Guardar perfil' 632 59 150
[void](New-Label 'Los perfiles guardan selecciones, tambien para aplicaciones que ahora no estan abiertas.' 16 101 765 23)
$list=New-Object Windows.Forms.CheckedListBox
$list.Location=New-Object Drawing.Point(16,128)
$list.Size=New-Object Drawing.Size(766,244)
$list.CheckOnClick=$true
$form.Controls.Add($list)
$force=New-Object Windows.Forms.CheckBox
$force.Text='Forzar cierre de apps opcionales (Chrome, Codex y lanzadores: solo cierre normal)'
$force.Location=New-Object Drawing.Point(16,381)
$force.Size=New-Object Drawing.Size(766,26)
$force.Checked=$false
$form.Controls.Add($force)
$close=New-Button 'Cerrar seleccionadas' 16 419 225
$refresh=New-Button 'Actualizar / confirmar' 250 419 245
$restore=New-Button 'Restaurar cerradas (0)' 505 419 277
$summary=New-Label '' 16 464 766 25
$result=New-Object Windows.Forms.TextBox
$result.Location=New-Object Drawing.Point(16,496)
$result.Size=New-Object Drawing.Size(766,176)
$result.Multiline=$true
$result.ReadOnly=$true
$result.ScrollBars='Vertical'
$form.Controls.Add($result)
[void](New-Label 'Restauracion disponible mientras esta ventana permanezca abierta. No recupera trabajo sin guardar.' 16 677 766 22)
function Write-GameLog([string]$Text){
 $result.AppendText((Get-Date -Format 'HH:mm:ss')+'  '+$Text+"`r`n")
 try{$dir=Join-Path $PSScriptRoot 'Registros';[void](New-Item -ItemType Directory -Path $dir -Force);Add-Content -LiteralPath (Join-Path $dir ((Get-Date -Format 'yyyyMMdd')+'.txt')) -Value ((Get-Date -Format 's')+' '+$Text) -Encoding UTF8}catch{}
}
function Get-SelectedNames {
 $names=@();foreach($index in @($list.CheckedIndices)){$names+=@($script:groups[$index].Names)};return $names
}
function Set-SelectedNames([string[]]$Names){
 for($i=0;$i -lt $script:groups.Count;$i++){$on=@($script:groups[$i].Names | Where-Object {$_ -in $Names}).Count -gt 0;$list.SetItemChecked($i,$on)}
}
function Update-RestoreButton {$restore.Text="Restaurar cerradas ($($script:restoreQueue.Count))";$restore.Enabled=$script:restoreQueue.Count -gt 0}
function Confirm-Pending {
 foreach($entry in @($script:pending.ToArray())){
  if(Confirm-GamePending $entry $script:sessionId){Add-GameRestore $script:restoreQueue $entry;[void]$script:pending.Remove($entry);Write-GameLog "$($entry.Name): salida confirmada tras la solicitud"}
 }
 Update-RestoreButton
}
function Refresh-GameList([string[]]$Selection){
 $script:inventory=@(Get-GameInventory)
 $list.Items.Clear()
 foreach($g in $script:groups){
  $ps=@($script:inventory | Where-Object {$_.Name -in $g.Names})
  $mb=[math]::Round(($ps.RAM_MB | Measure-Object -Sum).Sum)
  $suffix='no abierta';if($ps.Count){$suffix="$mb MB - $($ps.Count) procesos"}
  [void]$list.Items.Add("$($g.Label) - $suffix")
 }
 Set-SelectedNames $Selection
 $summary.Text="$($script:inventory.Count) procesos opcionales detectados. $($script:pending.Count) cierres pendientes de confirmar."
 Update-RestoreButton
}
function Refresh-ProfileNames {
 $current=$profile.Text
 $script:profiles=Read-GameProfiles $script:profileFile
 $profile.Items.Clear()
 foreach($name in @($script:profiles.Keys | Sort-Object)){[void]$profile.Items.Add($name)}
 $profile.Text=$current
}
$load.Add_Click({try{
 Refresh-ProfileNames
 $name=$profile.Text.Trim()
 if(-not $script:profiles.ContainsKey($name)){throw 'Selecciona un perfil guardado'}
 Set-SelectedNames $script:profiles[$name]
 $force.Checked=$false
 Write-GameLog "Perfil cargado: $name. El cierre forzado sigue desactivado."
}catch{Write-GameLog $_.Exception.Message}})
$save.Add_Click({try{
 $name=$profile.Text.Trim()
 Save-GameProfile $script:profileFile $name @(Get-SelectedNames)
 Refresh-ProfileNames
 $profile.Text=$name
 Write-GameLog "Perfil guardado: $name"
}catch{Write-GameLog ('No se guardo el perfil: '+$_.Exception.Message)}})
$refresh.Add_Click({try{$selection=@(Get-SelectedNames);Confirm-Pending;Refresh-GameList $selection}catch{Write-GameLog ('No se pudo actualizar: '+$_.Exception.Message)}})
$close.Add_Click({
 $close.Enabled=$false;$restore.Enabled=$false;$refresh.Enabled=$false
 try{
  $selected=@(Get-SelectedNames)
  $targets=@($script:inventory | Where-Object {$_.Name -in $selected})
  if(-not $targets.Count){Write-GameLog 'No hay aplicaciones seleccionadas abiertas.'}
  foreach($entry in $targets){
   $outcome=Invoke-GameClose $entry $force.Checked $script:sessionId
   Write-GameLog "$($entry.Name) [$($entry.Id)]: $($outcome.Message)"
   if($outcome.Status -eq 'Closed' -and $outcome.Restore){Add-GameRestore $script:restoreQueue $entry}
   if($outcome.Status -eq 'Pending' -and -not @($script:pending | Where-Object {$_.Id -eq $entry.Id -and $_.StartTime -eq $entry.StartTime}).Count){$script:pending.Add($entry)}
  }
  Confirm-Pending
  Refresh-GameList $selected
 }catch{Write-GameLog ('No se pudo completar: '+$_.Exception.Message)}finally{$close.Enabled=$true;$refresh.Enabled=$true;Update-RestoreButton}
})
$restore.Add_Click({
 $restore.Enabled=$false
 try{
  foreach($entry in @($script:restoreQueue.ToArray())){
   $outcome=Invoke-GameRestore $entry
   Write-GameLog "$($entry.Name): $($outcome.Message)"
   if($outcome.Status -in @('Started','AlreadyRunning')){[void]$script:restoreQueue.Remove($entry)}
  }
  Refresh-GameList @(Get-SelectedNames)
 }catch{Write-GameLog ('No se pudo restaurar: '+$_.Exception.Message)}finally{Update-RestoreButton}
})
$defaults=@($script:groups | Where-Object Default | ForEach-Object {$_.Names})
Refresh-GameList $defaults
try{Refresh-ProfileNames}catch{Write-GameLog ('No se pueden leer perfiles; se conserva el archivo: '+$_.Exception.Message)}
$timer=New-Object Windows.Forms.Timer
$timer.Interval=2000
$timer.Add_Tick({try{Confirm-Pending}catch{}})
$form.Add_Shown({$timer.Start()})
$form.Add_FormClosed({$timer.Stop();$timer.Dispose()})
if($SmokeTest){
 $smokeTimer=New-Object Windows.Forms.Timer
 $smokeTimer.Interval=1000
 $smokeTimer.Add_Tick({$smokeTimer.Stop();$form.Close()})
  $form.Add_Shown({
  if($ScreenshotPath){$bmp=New-Object Drawing.Bitmap($form.Width,$form.Height);try{$form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bmp.Save($ScreenshotPath,[Drawing.Imaging.ImageFormat]::Png)}finally{$bmp.Dispose()}}
  $smokeTimer.Start()
 })
}
[void]$form.ShowDialog()
if($SmokeTest){$smokeTimer.Dispose();Write-Output 'Interfaz iniciada y cerrada sin operar sobre aplicaciones'}
