##################
#     Wake Up    #
#  Paul Gleason  #
#Work in Progress#
##################

<#
Description: This script is made to call the Invoke-WakeOnLan to wake all machines on specified location csv files.
#>

param (
    # `.\wakeupWoL.ps1 -help` will call the help output
    [switch] $help, 
    # `.\wakeupWoL.ps1 -location <location_name>` will call use that locations csv file
    [validateset ("F202", "<location_name>", "<location_name>")] [string] $location)

if ($help)
{
    Write-Host " 
    --- wakeupWoL.ps1 help commands ---

    -help : shows help commands
    -location <location_name> : select location file default is mac.csv
        ex: wakeupWoL.ps1 -location F202
    "
}
else
{

    # wake up function
    # Function from: https://powershell.one/code/11.html
    function Invoke-WakeOnLan{
    param
    (
        # one or more MACAddresses
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        # mac address must be a following this regex pattern:
        [ValidatePattern('^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$')]
        [string[]]
        $MacAddress 
    )
    
    begin{
        # instantiate a UDP client:
        $UDPclient = [System.Net.Sockets.UdpClient]::new()
    }
    process{
        foreach($_ in $MacAddress){
        try {
            $currentMacAddress = $_
            
            # get byte array from mac address:
            $mac = $currentMacAddress -split '[:-]' |
            # convert the hex number into byte:
            ForEach-Object {
                [System.Convert]::ToByte($_, 16)
            }
    
            #region compose the "magic packet"
            
            # create a byte array with 102 bytes initialized to 255 each:
            $packet = [byte[]](,0xFF * 102)
            
            # leave the first 6 bytes untouched, and
            # repeat the target mac address bytes in bytes 7 through 102:
            6..101 | Foreach-Object { 
            # $_ is indexing in the byte array,
            # $_ % 6 produces repeating indices between 0 and 5
            # (modulo operator)
            $packet[$_] = $mac[($_ % 6)]
            }
            
            #endregion
            
            # connect to port 400 on broadcast address:
            $UDPclient.Connect(([System.Net.IPAddress]::Broadcast),4000)
            
            # send the magic packet to the broadcast address:
            $null = $UDPclient.Send($packet, $packet.Length)
            Write-Verbose "sent magic packet to $currentMacAddress..."
        }
            catch{
                Write-Warning "Unable to send ${mac}: $_"
            }
        }
    }
        end{
            # release the UDF client and free its memory:
            $UDPclient.Close()
            $UDPclient.Dispose()
        }
    }

    # Location switch statement
    switch($location){
        # 'template' {
        #     $data = Import-csv ".\template.csv"
        #  }
        # 'template_network' {
        #     $data = Import-csv "\\<server>\<share>.csv"
        # }

        # For debugging/One time use
        'SETUP' {
            $data = Import-csv "mac.csv"
        }
        # Fallback for no location selected
        Default{
            Write-Host "Bad location name..."
            Break
        }
    
    }

    # foreach Mac Address in the csv files
    foreach ($macaddresses in $data.MacAddress){
        # Call each Mac Address to wake up
        Invoke-WakeOnLan -MacAddress $macaddresses -Verbose
    }

}