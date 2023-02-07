#################
#  Wake on Lan  #
#  Paul Gleason #
#    Wake Up    #
#################

param ([switch] $help, [validateset ("F202", "I117", "J310")] [string] $lab)

if ($help)
{
    Write-Host " 
    --- wakeup.ps1 help commands ---

    -help : shows help commands
    -lab <lab> : select lab file default is mac.csv
        ex: wakeupWoL.ps1 -lab F202
    "
}
else
{

    # wake up function
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

    switch($lab){
        'I117' {$data = Import-csv "I117.csv"}
        'J310' {$data = Import-csv "J310.csv"}
        'F202' {$data = Import-csv "F202.csv"}

        Default{
            $data = Import-csv "mac.csv"
            # Write-Host "Bad lab name..."
        }
    
    }
    # $data = Import-csv "\\trex2021\Application Sources\Utilities\Wake On Lan\mac.csv"

    foreach ($macaddresses in $data.MacAddress){
        Invoke-WakeOnLan -MacAddress $macaddresses -Verbose
    }

}