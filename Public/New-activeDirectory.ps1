function New-activeDirectory {
    <#
    .SYNOPSIS
        Configure a new Active Directory instance on a remote Windows system.

    .DESCRIPTION
        Configure a new Active Directory instance on a remote Windows system.
            * Install the Active Directory role.
            * Configure a new Active Directory instance.
            * Restart the remote system.
            * Wait for the Active Directory to become available.

    .PARAMETER hostName
        The remote Windows system to target.

    .PARAMETER domainFQDN
        The FQDN of the new Active Directory domain.

    .PARAMETER domainNetbios
        The Netbios name of the new Active Directory domain.

    .PARAMETER Credential
        A suitable credential for installing Active Directory.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$hostName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$domainFQDN,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$domainNetbios,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        ## Create remote PS session to target system
        Write-Verbose ("Creating remote PowerShell session to " + $hostName)

        try {
            $psSession = New-PSSession -ComputerName $hostName -Credential $Credential
            Write-Verbose ("Remote session created.")
        } # try
        catch {
            Write-Debug ("Failed to create remote session.")
            throw ("Failed to create remote PowerShell session." + $_.exception.message)
        } # catch


        ## Install ADDS Windows feature
        Write-Verbose ("Installing Active Directory binaries on remote system.")

        try {
            Install-WindowsFeature -Name AD-Domain-Services -ComputerName $hostName -Credential $Credential | Out-Null
            Write-Verbose ("Binaries installed.")
        } # try
        catch {
            Write-Debug ("Failed to install Active Directory binaries.")
            throw ("Failed to install Active Directory binaries. " + $_.exception.message)
        } # catch


        ## Set script block for remote execution
        $cmdText =
        {
        param($safeModePass,$domainFQDN,$domainNetbios)

        ## Disable progress bar for this remote session
        $ProgressPreference = "SilentlyContinue"

        Install-ADDSForest -SafeModeAdministratorPassword $safeModePass -CreateDnsDelegation:$false -DatabasePath “C:\Windows\NTDS” -DomainMode “7” -DomainName $domainFQDN `
        -DomainNetbiosName $domainNetbios -ForestMode “7” -InstallDns:$true -LogPath “C:\Windows\NTDS” -NoRebootOnCompletion:$false -SysvolPath “C:\Windows\SYSVOL” -Force:$true -WarningAction SilentlyContinue
        }


        ## Execute command in remote session
        Write-Verbose ("Beginning remote installation of Active Directory.")

        try {
            $cmdResult = Invoke-Command -Session $psSession -ScriptBlock $cmdText -ArgumentList $Credential.password,$domainFQDN,$domainNetbios
            Write-Verbose ("Installation complete.")
        } # try
        catch {
            throw ("Failed to install ADDS. " + $_.exception.message)
        } # catch


        ## Check that install status is successful
        if (!($cmdResult.status -eq "Success")) {

            throw ("Status returned by remote system was " + $cmdResult.status)
        } # if

        Write-Verbose ("Waiting for Active Directory installation to complete.")

        ## Slepp for 2 minutes before polling Active Directory
        Start-Sleep 120

        ## Wait for AD to become available by testing for local computer AD object
        ## Set script block
        $scriptBlock = {Get-ADComputer -Identity $env:COMPUTERNAME -ErrorAction Stop}


        ## Set initial counter
        $i = 0

        ## Poll AD until it becomes available
        Write-Verbose ("Waiting for Active Directory to become available.")

        do{

            try {
                $adResult = Invoke-Command -ScriptBlock $scriptBlock -ComputerName $hostName -Credential $Credential -ErrorAction Stop
            } # try
            catch {
                Write-Verbose ("Waiting for Active Directory to become available.")
            } # catch

            $i++
            Start-Sleep 30

        } until (($i -eq 20) -or ($adResult.objectClass -eq "computer"))


        ## Check if retries were exceeded.
        if ($i -eq 20) {
            throw ("Active Directory did not become available within the specified number of retry attempts.")
        } # if

        Write-Verbose ("Active Directory is available and serving requests.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end

} # function