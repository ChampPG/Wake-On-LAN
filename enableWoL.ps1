##################
#    Enabler     #
#  Paul Gleason  #
#Work in Progress#
##################

<#
Description: This script is made to enable Wake-on-LAN functionality within Windows 10.
#>

param (
    # `.\enableWoL.ps1 -help` will call the help output
    [switch] $help, 
    # `.\enableWoL.ps1 -location <location_name>` will call use that locations csv file
    [validateset ("F202", "<location_name>", "<location_name>")] [string] $location)

if ($help)
{
    Write-Host " 
    --- enableWoL.ps1 help commands ---
    !!! Running this script you need admin for it work. !!!

    -help : shows help commands
    -location <location_name> : select location file default is mac.csv
        ex: enableWoL.ps1 -location F202
    "
}
else
{
    function Set-WakeEnabled{
        # Just if statement from: https://vanbrenk.blogspot.com/2021/02/enable-wake-on-lan-with-powershell-and.html
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {            
            Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"            
            Break            
        }         
        
        $nic = Get-NetAdapter | Where-Object {($_.MediaConnectionState -eq "Connected") -and (($_.name -match "Ethernet") -or ($_.name -match "local area connection"))}
        $nicPowerWake = Get-WmiObject MSPower_DeviceWakeEnable -Namespace root\wmi | Where-Object {$_.instancename -match [regex]::escape($nic.PNPDeviceID) }
        
        If ($nicPowerWake.Enable -eq $true){
            # All good here
            write-output "MSPower_DeviceWakeEnable is TRUE"
        }
        Else{
            write-output "MSPower_DeviceWakeEnable is FALSE. Setting to TRUE..."
            $nicPowerWake.Enable = $True
            $nicPowerWake.psbase.Put()
        }

        $nicMagicPacket = Get-WmiObject MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root\wmi | Where-Object {$_.instancename -match [regex]::escape($nic.PNPDeviceID) }
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

    # Call WakeEnable Function
    Set-WakeEnabled

    # Get Adapter
    $nic = Get-NetAdapter | Where-Object {($_.MediaConnectionState -eq "Connected") -and (($_.name -match "Ethernet") -or ($_.name -match "local area connection"))}
    # Get Mac Address in raw form
    $temphostmac = (($nic | Select-Object MacAddress | Format-Wide | Out-String).split("`n") -match '\S').Trim() -replace "`0", ""
    # Format Mac Address from XX-XX-XX-XX-XX-XX to XX:XX:XX:XX:XX:XX
    $hostmac = $temphostmac.replace("-",":")
    # Grab hostname of machine
    $hostname = hostname

    # Make data and path global
    $global:data = "null"
    $global:path = "null"

    # Location switch statement
    switch($location){
        # 'template' {
        #     $data = Import-csv ".\template.csv"
        #     $path = ".\template.csv"
        #  }
        # 'template_network' {
        #     $data = Import-csv "\\<server>\<share>.csv"
        #     $path = "\\<server>\<share>.csv"
        # }
        
        # For debugging/One time use
        'SETUP' {
            $data = Import-csv ".\mac.csv"
            $path = ".\mac.csv"
        }
        # Fallback for no location selected
        Default{
            Write-Host "Bad location name..."
            Break
        }
    }

    # Arrays for hostnames and Mac Addresses from csv
    $MACAddresses=@()
    $HostNames=@()

    # Adds Mac Addresses and hostnames to arrays above
    $data | ForEach-Object {
        $MACAddresses += $_.MacAddress
        $HostNames += $_.Hostname
    }
    
    # Check to see if hostname is in the file
    foreach ($csvhost in $HostNames){
        if ($hostname -match $csvhost){
            $foundHostName=$true
        }
    }

    # Check to see if Mac Address is in the file
    foreach ($csvmac in $MACAddresses){
        if ($hostmac -match $csvmac){
            $foundMacAddress=$true
        }
    }

    # If hostname and Mac Address not in csv
    if (!$foundHostName -And !$foundMacAddress)
    {
        Write-Host "Computer wasn't in the list."
        # Add hostname and Mac Address if not in csv file
        add-content -path $path -value "`r`n$hostname,$hostmac"

        # TESTING BELOW:
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
        # As Joe Eastman once said "devops is fake it till you make it"
        # $newLine = "{0},{1}" -f $hostname,$hostmac
        # $newLine | add-content -path $path
        # write-host $newLine
        # $newLine = New-Object PsObject -Property @{ Hostname = $hostname ; MacAddress = $hostmac } 
        # $data += $newLine
        # Export-Csv $path -inputobject $newLine -Append -Force

    }
    # If hostname is not in csv but Mac Address is in the file
    elseif (!$foundHostName -And $foundMacAddress)
    {
        Write-Host "Hostname wasn't found but MacAddress was."
        # Code below from: https://itpro.outsidesys.com/2017/10/21/powershell-change-values-in-csv-data/

        # Gets row index of where the Mac Address in the file matches the hosts Mac Address
        $RowIndex = [array]::IndexOf($data.MacAddress,$hostmac)
        # Make location where hostname and $hostname match the value of $hostname
        $data[$RowIndex].Hostname = $hostname
        # Sort and Export csv file
        $data | Sort-Object Hostname | Select-Object Hostname, MacAddress | Export-Csv -path $path -nti
    }
    # If hostname is in the csv but Mac Address is not in the file
    elseif ($foundHostName -And !$foundMacAddress)
    {
        Write-Host "Hostname was found but MacAddress wasn't."
        # Gets row index of where the hostname in the file matches the hosts hostname
        $RowIndex = [array]::IndexOf($data.Hostname,$hostname)
        # Make location where Mac Address and $hostmac match the value of $hostmac
        $data[$RowIndex].MacAddress = $hostmac
        # Sort and Export csv file
        $data | Sort-Object Hostname | Select-Object Hostname, MacAddress | Export-Csv -path $path -nti
    }
    # If hostname and Mac Address found in file
    elseif ($foundHostName -And $foundMacAddress)
    {
        Write-Host "Hostname and MacAddress were found"
        # Sort and Export csv file
        $data | Sort-Object Hostname | Select-Object Hostname, MacAddress | Export-Csv -path $path -nti
    }
}