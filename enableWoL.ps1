#################
#  Wake on Lan  #
#  Paul Gleason #
#    Enable     #
#################

param ([switch] $help, $lab)


if ($help)
{
    Write-Host " 
    --- wakeup.ps1 help commands ---
    !!! Running this script you need admin for it work. !!!

    -help : shows help commands
    -lab <lab> : select lab file default is mac.csv
        ex: enableWoL.ps1 -lab F202
    "
}
else
{
    function Set-WakeEnabled{
    $nic = Get-NetAdapter | ? {($_.MediaConnectionState -eq "Connected") -and (($_.name -match "Ethernet") -or ($_.name -match "local area connection"))}
    $nicPowerWake = Get-WmiObject MSPower_DeviceWakeEnable -Namespace root\wmi | where {$_.instancename -match [regex]::escape($nic.PNPDeviceID) }
    If ($nicPowerWake.Enable -eq $true){
        # All good here
        write-output "MSPower_DeviceWakeEnable is TRUE"
    }
    Else{
        write-output "MSPower_DeviceWakeEnable is FALSE. Setting to TRUE..."
        $nicPowerWake.Enable = $True
        $nicPowerWake.psbase.Put()
    }

    $nicMagicPacket = Get-WmiObject MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root\wmi | where {$_.instancename -match [regex]::escape($nic.PNPDeviceID) }
    If ($nicMagicPacket.EnableWakeOnMagicPacketOnly -eq $true){
        # All good here
        write-output "EnableWakeOnMagicPacketOnly is TRUE"
    }
    Else{
        write-output "EnableWakeOnMagicPacketOnly is FALSE. Setting to TRUE..."
        $nicMagicPacket.EnableWakeOnMagicPacketOnly = $True
        $nicMagicPacket.psbase.Put()
    }

    $RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    $Name = 'HiberbootEnabled'
    $RegValue = Get-ItemPropertyValue -Path $RegistryPath -Name $Name

    if ($RegValue -eq "1"){
    $Value = '0'
    Set-ItemProperty -Path $RegistryPath -Name $Name -Value $Value
    }

    if ($RegValue -eq "0"){
    write-output "HiberbootEnabled is set to 0"
    }else{
    write-output "HiberbootEnabled is set to 1. Retrying to set value"
    }
    }


    Set-WakeEnabled

    $nic = Get-NetAdapter | ? {($_.MediaConnectionState -eq "Connected") -and (($_.name -match "Ethernet") -or ($_.name -match "local area connection"))}

    $temphostmac = (($nic | Select-Object MacAddress | Format-Wide | Out-String).split("`n") -match '\S').Trim() -replace "`0", ""
    $hostmac = $temphostmac.replace("-",":")
    $hostname = hostname

    # Get-Content .\mac-list.txt | foreach {if ($_-match $hostmac){$foundit=$true}; If (!$foundit){ $hostmac >> .\mac-list.txt}}

    $global:data = "null"
    $global:path = "null"

    switch($lab){
        'I117' {
            $data = Import-csv ".\I117.csv"
            $path = ".\I117.csv"
            }
        'J310' {
            $data = Import-csv ".\J310.csv"
            $path = ".\J310.csv"
            }
        'F202' {
            $data = Import-csv ".\F202.csv"
            $path = ".\F202.csv"
            }
        'SETUP' {
            $data = Import-csv ".\mac.csv"
            $path = "mac.csv"
            }

        Default{
            $data = Import-csv "mac.csv"
            $path = ".\mac.csv"
            # Write-Host $data
        }
    }

    # Write-Host $lab
    Write-Host $data

    $MACAddresses=@()
    $HostNames=@()

    $data | ForEach-Object {
        $MACAddresses += $_.MacAddress
        $HostNames += $_.Hostname
    }
    
    foreach ($csvhost in $HostNames){
        if ($hostname -match $csvhost){
            $foundHostName=$true
        }
    }

    foreach ($csvmac in $MACAddresses){
        if ($hostmac -match $csvmac){
            $foundMacAddress=$true
        }
    }

    if (!$foundHostName -And !$foundMacAddress)
    {
        Write-Host "Computer wasn't in the list."
        add-content -path $path -value "`r`n$hostname,$hostmac"


        # $data | Sort Hostname | Select Hostname, MacAddress | Export-Csv -path $path -nti

        # $Name = $hostname
        # $Mac = $hostmac
        # $hash = @{
        #      "Hostname" =  $Name
        #      "MacAddress" = $Mac
        # }

        # $newRow = New-Object PsObject -Property $hash
        # Export-Csv $path -inputobject "`r`n"$newRow -append -Force
        # $newRow | Add-Content -Path $path
        # "`r`n$hostname,$hostmac" | Out-File -FilePath $path -Append -Force
        # "`r`n$hostname,$hostmac" | Select Hostname,MacAddress | Export-Csv -path $path  -Append -Force
        
        # $newLine = "{0},{1}" -f $hostname,$hostmac
        # $newLine | add-content -path $path
        # write-host $newLine
        # $newLine = New-Object PsObject -Property @{ Hostname = $hostname ; MacAddress = $hostmac } 
        # $data += $newLine
        # Export-Csv $path -inputobject $newLine -Append -Force

    }
    elseif (!$foundHostName -And $foundMacAddress)
    {
        Write-Host "Hostname wasn't found but MacAddress was."
        # As Joe Eastman once said "devops is fake it till you make it"
        # https://itpro.outsidesys.com/2017/10/21/powershell-change-values-in-csv-data/
        $RowIndex = [array]::IndexOf($data.MacAddress,$hostmac)
        $data[$RowIndex].Hostname = $hostname
        $data | Sort Hostname | Select Hostname, MacAddress | Export-Csv -path $path -nti
    }
    elseif ($foundHostName -And !$foundMacAddress)
    {
        Write-Host "Hostname was found but MacAddress wasn't."
        $RowIndex = [array]::IndexOf($data.Hostname,$hostname)
        $data[$RowIndex].MacAddress = $hostmac
        $data | Sort Hostname | Select Hostname, MacAddress | Export-Csv -path $path -nti
    }
    elseif ($foundHostName -And $foundMacAddress)
    {
        Write-Host "Hostname and MacAddress were found"
        $data | Sort Hostname | Select Hostname, MacAddress | Export-Csv -path $path -nti
    }
}