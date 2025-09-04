$clean3.add_Click({
    $Window.Hide()
    Clear-Host

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Este script debe ejecutarse como administrador." -ForegroundColor Red
        $Window.Show()
        return
    }

    # Crear ventana de progreso
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "Reset de Windows Update"
    $progressForm.Size = New-Object System.Drawing.Size(450,120)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.Topmost = $true
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.MaximizeBox = $false
    $progressForm.MinimizeBox = $false

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = '20,40'
    $progressBar.Size = '400,25'
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $progressForm.Controls.Add($progressBar)

    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Location = '20,10'
    $progressLabel.Size = '400,20'
    $progressLabel.Text = "Iniciando..."
    $progressForm.Controls.Add($progressLabel)

    $progressForm.Show()
    $progressForm.Refresh()

    # Definir pasos
    $steps = @(
        @{Action="Deteniendo servicios..."; Value=10},
        @{Action="Borrando cachés y SoftwareDistribution..."; Value=30},
        @{Action="Borrando Catroot2 y logs..."; Value=45},
        @{Action="Procesando pending.xml..."; Value=55},
        @{Action="Limpiando DNS..."; Value=60},
        @{Action="Restableciendo permisos de servicios..."; Value=70},
        @{Action="Re-registrando DLLs de Windows Update..."; Value=85},
        @{Action="Reiniciando Winsock y proxy..."; Value=90},
        @{Action="Eliminando políticas y actualizando..."; Value=95},
        @{Action="Iniciando servicios y finalizando..."; Value=100}
    )

    $services = @("bits", "wuauserv", "cryptsvc", "msiserver")

    foreach ($step in $steps) {
        $progressBar.Value = $step.Value
        $progressLabel.Text = $step.Action
        $progressForm.Refresh()
        Start-Sleep -Milliseconds 200

        switch ($step.Action) {
            "Deteniendo servicios..." {
                foreach ($svc in $services) { Try { Stop-Service -Name $svc -Force -ErrorAction Stop } Catch { Write-Warning "No se pudo detener $svc" } }
            }
            "Borrando cachés y SoftwareDistribution..." {
                $sd = "C:\Windows\SoftwareDistribution"
                if (Test-Path $sd) { Remove-Item -Path "$sd\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            "Borrando Catroot2 y logs..." {
                $catroot2 = "C:\Windows\System32\Catroot2"
                $catroot2bak = "C:\Windows\System32\Catroot2.bak"
                if (Test-Path $catroot2bak) { Remove-Item -Recurse -Force $catroot2bak }
                if (Test-Path $catroot2) { Rename-Item -Path $catroot2 -NewName "Catroot2.bak" }
                $wuLogs = "C:\Windows\Logs\WindowsUpdate"
                if (Test-Path $wuLogs) { Remove-Item -Path "$wuLogs\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            "Procesando pending.xml..." {
                $pending = "C:\Windows\winsxs\pending.xml"
                if (Test-Path $pending) {
                    Takeown /f $pending
                    attrib -r -s -h $pending
                    Rename-Item -Path $pending -NewName "pending.xml.bak"
                }
            }
            "Limpiando DNS..." { ipconfig /flushdns | Out-Null }
            "Restableciendo permisos de servicios..." {
                sc.exe sdset bits "D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)" | Out-Null
                sc.exe sdset wuauserv "D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)" | Out-Null
            }
            "Re-registrando DLLs de Windows Update..." {
                $dlls = @(
                    "atl.dll","urlmon.dll","mshtml.dll","shdocvw.dll","browseui.dll","jscript.dll","vbscript.dll",
                    "scrrun.dll","msxml.dll","msxml3.dll","msxml6.dll","actxprxy.dll","softpub.dll","wintrust.dll",
                    "dssenh.dll","rsaenh.dll","gpkcsp.dll","sccbase.dll","slbcsp.dll","cryptdlg.dll","oleaut32.dll",
                    "ole32.dll","shell32.dll","initpki.dll","wuapi.dll","wuaueng.dll","wuaueng1.dll","wucltui.dll",
                    "wups.dll","wups2.dll","wuweb.dll","qmgr.dll","qmgrprxy.dll","wucltux.dll","muweb.dll","wuwebv.dll"
                )
                foreach ($dll in $dlls) { regsvr32.exe /s $dll }
            }
            "Reiniciando Winsock y proxy..." {
                netsh winsock reset | Out-Null
                netsh winsock reset proxy | Out-Null
            }
            "Eliminando políticas y actualizando..." {
                $regPaths = @(
                    "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
                    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate",
                    "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate"
                )
                foreach ($reg in $regPaths) {
                    Try {
                        & reg delete "$reg" /f
                        Write-Host "Se eliminó correctamente: $reg"
                    } Catch {
                        Write-Host ("Error eliminando {0}: {1}" -f $reg, $_.Exception.Message) -ForegroundColor Red
                    }
                }
                gpupdate /force | Out-Null
            }
            "Iniciando servicios y finalizando..." {
                foreach ($svc in $services) { Try { Start-Service -Name $svc -ErrorAction Stop } Catch { Write-Warning "No se pudo iniciar $svc" } }
            }
        }
    }

    $progressForm.Close()

    # Ventana de reinicio personalizada
    $Win2 = Create-CustomWindow -Width 320 -Height 100 -Fondo '#aeb2cd' -Title 'Reinicio necesario' -iconUrl $git'icons/restart.ico'
    $confirmNO = Create-CombinedImage -Window $Win2 -top 15 -left 80 -ancho 100 -filter '#e0e0e0' -Sfilter '#bbbbbb' -text 'Cancelar' 
    $confirmNO = set-Hand -p $confirmNO
    $confirmYES = Create-CombinedImage -Window $Win2 -top 15 -left 190 -ancho 100 -filter '#fab7b9' -Sfilter '#c14e51' -text 'Confirmar'
    $confirmYES = set-Hand -p $confirmYES

    $confirmNO.add_Click({ $Win2.Close() })
    $confirmYES.add_Click({
        Clear-Host
        $Win2.Close()
        $Window.Close()
        Write-Host "Reiniciando el equipo.."
        Restart-Computer -Force
    })

    $Win2.Add_Shown({ $Win2.Activate() })
    $Win2.ShowDialog()

    $Window.Show()
})
