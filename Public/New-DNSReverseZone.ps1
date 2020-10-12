function New-DNSReverseZone {
    <#
    .SYNOPSIS
        Creates a reverse DNS zone on a remote Windows system.

    .DESCRIPTION
        Creates a reverse DNS zone on a remote Windows system.
        A PS session is used to perform this remotely.
        A CIM connection would be preferable but this gets tricky with pre 1803 systems and non native DNS CMDlets with PowerShell 7.
        A remote PS session maintains compability across all versions.

    .PARAMETER hostName
        The hostname of the system to target.

    .PARAMETER netId
        The network ID for the zone to create.

    .PARAMETER maskLength
        The subnet mask length.

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
        [string]$netId,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$maskLength,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing target system " + $hostName)

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
            param($netID,$maskLength)
            Add-DnsServerPrimaryZone -NetworkID ($netID + "/" + $maskLength) -ReplicationScope "Forest"
        } # cmdtext


        ## Create reverse lookup zone on target system
        Write-Verbose ("Creating reverse DNS zone on target system.")

        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($hostName)) {
                Invoke-Command -Session $psSession -ScriptBlock $cmdText -ArgumentList $netID,$maskLength -ErrorAction Stop | Out-Null
                Write-Verbose ("DNS zone on target system created.")
            } # if

        } # try
        catch {
            Write-Debug ("Failed to create DNS zone.")
            throw ("Failed to create DNS zone. " + $_.exception.message)
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