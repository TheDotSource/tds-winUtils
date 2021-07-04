function Set-localWSMan {
    <#
    .SYNOPSIS
        Add a remote host as a trusted host on the local system.

    .DESCRIPTION
        Add a remote host as a trusted host on the local system.
        Host will not be added if it is already on the trusted hosts list.

    .PARAMETER trustedHost
        Hostname or IP of the host to add.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-localWSMan -trustedHost testhost.local

        Add testhost.local to trusted hosts list.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$trustedHost
    )

    begin {
        Write-Verbose ("Function start.")
    } # begin


    process {

        ## Get list of existing WSMan trusted hosts
        Write-Verbose ("Getting existing trusted hosts list.")

        try {
            $existingHosts = (Get-WSManInstance -ResourceURI winrm/config/client -ErrorAction Stop).TrustedHosts
            Write-Verbose ("Got trusted hosts list from local system.")
        } # try
        catch {
            throw ("Failed to get local trusted hosts list. " + $_.exception.message)
        } # catch


        ## Check if this host is already in trusted hosts, if not add it to the list.
        if ($existingHosts.Contains($trustedHost)) {

            Write-Verbose ("Host " + $trustedHost + " is already a trusted host. No further action is necessary.")
        }
        else {

            ## Add this host to trusted hosts.
            $newHosts = (($existingHosts + "," + $trustedHost)).trim(",")

            Write-Verbose ("Adding host " + $trustedHost + " to trusted hosts list.")

            if ($PSCmdlet.ShouldProcess($trustedHost)) {
                try {
                    Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts=$newHosts} -ErrorAction Stop | Out-Null
                    Write-Verbose ("Host added.")
                } # try
                catch {
                    throw ("Failed to add host to trusted hosts. " + $_.exception.message)
                } # catch
            } # if

        } # else

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function