function New-DNSRecord {
    <#
    .SYNOPSIS
        Creates a reverse DNS record and PTR on a remote Windows system.

    .DESCRIPTION
        Creates a reverse DNS record and PTR on a remote Windows system.
        A PS session is used to perform this remotely.
        A CIM connection would be preferable but this gets tricky with pre 1803 systems and non native DNS CMDlets with PowerShell 7.
        A remote PS session maintains compability across all versions.

    .PARAMETER hostName
        The remote target system.

    .PARAMETER aRecord
        The A Record name to create.

    .PARAMETER dnsZone
        The DNS zone to create the record in.

    .PARAMETER ip
        The IP address of the A record.

    .PARAMETER Credential
        PowerShell credential object to authenticate to the remote system.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-DNSReverseZone -hostName testdc01.lab.local -netId 10.10.10.0 -maskLength 24 -Credential $creds

        Create a reverse lookup zone 10.10.10.0/24 on testdc01.lab.local

    .LINK

    .NOTES
        01       05/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$hostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$aRecord,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$dnsZone,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ip,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing target system " + $hostName)

        ## Check if this hostName is a plain hostname or has been passed as an FQDN
        if ($aRecord.split(".").count -gt 1) {
            Write-Warning ("The specified aRecord appears to be an FQDN. It will be truncated to just a hostname.")
            $aRecord = $aRecord.split(".")[0]

            Write-Verbose ("Truncated hostname is " + $aRecord)
        } # if

        ## Create PS session to remote system
        Write-Verbose ("Creating remote PS session.")

        try {
            $psSession = New-PSSession -ComputerName $hostName -Credential $Credential -ErrorAction Stop
            Write-Verbose ("PS session created.")
        } # try
        catch {
            Write-Debug ("Failed to create PS session.")
            throw ("Failed to create PS session. " + $_.exception.message)
        } # catch

        ## Set script block for remote command
        $cmdText = {
            param($aRecord,$dnsZone,$ip)
            Add-DnsServerResourceRecordA -Name $aRecord -ZoneName $dnsZone -AllowUpdateAny -IPv4Address $ip -CreatePtr
        } # cmdtext


        ## Create DNS record on target system
        Write-Verbose ("Creating DNS record on target system.")

        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($hostName)) {
                Invoke-Command -Session $psSession -ScriptBlock $cmdText -ArgumentList $aRecord,$dnsZone,$ip -ErrorAction Stop | Out-Null
                Write-Verbose ("DNS record on target system created for " + $aRecord)
            } # if

        } # try
        catch {
            Write-Debug ("Failed to create DNS record.")
            throw ("Failed to create DNS record. " + $_.exception.message)
        } # catch

        ## Destroy PS session
        Write-Verbose ("Destroying PS session.")

        try {
            $psSession | Remove-PSSession -ErrorAction Stop
            Write-Verbose ("PS session destroyed.")
        } # try
        catch {
            Write-Debug ("Failed to destroy PS session.")
            Write-Warning ("Failed to destroy PS session. " + $_.exception.message)
        } # catch


    } # process

    end {
            Write-Verbose ("Function end.")
    } # end

} # function