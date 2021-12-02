function New-WinUnattend {
    <#
    .SYNOPSIS
        Generate an autounattend file for Windows installation with some basic parameters.

    .DESCRIPTION
        Generate an autounattend file for Windows installation with some basic parameters.

        These are:
            * Image index
            * Computer name
            * Product key
            * Local administrator credential

        Applies a basic partition laytout suitable for UEFI systems.

        Image Index can be determined by using Get-WindowsImage or various other methods.

        IP configuration is applied to the first adapter found on the system.

        Product key can be omiited but this will result in installation failure unless evaluation media is used.

        The unattend will also execute some PowerShell commands at first login to configure the Windows Firewall to allow PowerShell remoting.

    .PARAMETER targetFile
        The output autounattend.xml file location.

    .PARAMETER imageName
        The image name to use during the installation. This must be valid for the selected media.

    .PARAMETER productKey
        Optional. The product key to use during installation. Can be omitted if using Evaluation media.

    .PARAMETER ip
        The IP address to assign.

    .PARAMETER maskLength
        Subnet mask length, for example, 24.

    .PARAMETER maskLength
        IP address of the DNS server to assign to the interface.

    .PARAMETER gateway
        IP address of the default gateway to assign to the interface.

    .PARAMETER computerName
        Optional. The computer name to apply during installation. If ommitted Windows will auto-generate one.

    .PARAMETER matchTimeZone
        Optional. Use the same time zone as the local system.

    .PARAMETER adminCredential
        The username and password for the local administratior account. Warning: passwords in autoUnattend files are NOT encrypted!

    .INPUTS
        None.

    .OUTPUTS
        System.IO.FileInfo. The output autoUnattend file.

    .EXAMPLE
        New-WinUnattend -targetFile D:\sample\autounattend.xml -imageIndex 1 -ip 10.10.1.100 -maskLength 24 -dns 10.10.1.10 -gateway 10.10.1.1 -computerName testdc01 -adminCredential $creds

        Create autoUnattend.xml to install image index 1 with the spcified product key, computer name, local administrator credential and IP configuration.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$targetFile,
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$imageIndex,
        [parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$productKey,
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ip,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$maskLength,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$dns,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$gateway,
        [parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$computerName,
        [parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [Switch]$matchTimeZone,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$adminCredential
      )

    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        ## Define XML template
        $xmlTemp = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>500</Size>
                            <Type>Primary</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>100</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Size>16</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>4</Order>
                            <Extend>true</Extend>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Label>WinRE</Label>
                            <Format>NTFS</Format>
                            <TypeID>de94bba4-06d1-4d40-a16a-bfd50179d6ac</TypeID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                            <Label>System</Label>
                            <Format>FAT32</Format>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>4</Order>
                            <PartitionID>4</PartitionID>
                            <Label>Windows</Label>
                            <Format>NTFS</Format>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
                <WillShowUI>OnError</WillShowUI>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>4</PartitionID>
                    </InstallTo>
                    <WillShowUI>Never</WillShowUI>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>{0}</Value>
                        </MetaData>
                    </InstallFrom>
                </OSImage>
            </ImageInstall>
            <UserData>
                <ProductKey>
                    {1}
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
            </UserData>
            <EnableNetwork>false</EnableNetwork>
        </component>
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-us</UILanguage>
            </SetupUILanguage>
            <UILanguage>en-us</UILanguage>
        </component>
    </settings>
    <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <UserAccounts>
            <AdministratorPassword>
                <Value>{4}</Value>
                <PlainText>true</PlainText>
            </AdministratorPassword>
        </UserAccounts>
        <AutoLogon>
                <Password>
                    <Value>{4}</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>2</LogonCount>
                <Username>{3}</Username>
            </AutoLogon>
            <FirstLogonCommands>
            <SynchronousCommand wcm:action="add">
                <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "Get-NetAdapter | Select-Object -First 1 | New-NetIPAddress –IPAddress {5} –PrefixLength {6} -DefaultGateway {7}"</CommandLine>
                <Order>1</Order>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
                <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "Get-NetAdapter | Select-Object -First 1 | Set-DnsClientServerAddress -ServerAddresses {8}"</CommandLine>
                <Order>2</Order>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
                <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "Get-NetFirewallRule -Name FPS-ICMP4-ERQ-In | Enable-NetFirewallRule"</CommandLine>
                <Order>3</Order>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
                <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "Get-NetFirewallRule -Name WMI-RPCSS-In-TCP | Enable-NetFirewallRule"</CommandLine>
                <Order>4</Order>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
                <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "Get-NetFirewallRule -Name WMI-WINMGMT-In-TCP | Enable-NetFirewallRule"</CommandLine>
                <Order>5</Order>
            </SynchronousCommand>
        </FirstLogonCommands>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>{2}</ComputerName>
            <TimeZone>{9}</TimeZone>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SystemLocale>en-GB</SystemLocale>
            <UILanguage>en-GB</UILanguage>
            <UILanguageFallback>en-GB</UILanguageFallback>
            <UserLocale>en-GB</UserLocale>
        </component>
    </settings>
</unattend>
"@

        ## Validate Windows Product Key, a null value is acceptable for evaluation editions
        Write-Verbose ("Processing product key.")
        if (!$productKey) {
            Write-Warning ("No Windows Product key defined. This can be ignored if using an Evaluation edition.")
        } # if
        ## Use regex to valid key if present.
        elseif ($productKey -notmatch "^([A-Z1-9]{5})-([A-Z1-9]{5})-([A-Z1-9]{5})-([A-Z1-9]{5})-([A-Z1-9]{5})$") {
            throw ("Invalid product key supplied.")
        } # elseif
        else {
            Write-Verbose ("Product key appears to be valid.")

            ## Form the string we need to inject to the XML
            $productKey = ("<Key>" + $productKey + "</Key>")
        } # else


        ## If computer name not supplied, replace with "*" (autogenerate)
        Write-Verbose ("Processing computer name.")

        if (!$computerName) {
            Write-Verbose ("Computer name not supplied, it will be auto-generated.")
            $computerName = "*"
        } # if


        ## Get time zone and locale from local system if specified
        if ($matchTimeZone) {
            Write-Verbose ("Matching time zone to local system.")
            $timeZone = (Get-TimeZone).id
        } # if


        ## Inject values to template.
        Write-Verbose ("Processing template values.")

        try {
            $xmlTemp = $xmlTemp -f $imageIndex, $productKey, $computerName, $adminCredential.UserName, $adminCredential.GetNetworkCredential().Password, $ip, $maskLength, $gateway, $dns, $timeZone
            Write-Verbose ("Completed.")
        } # try
        catch {
            throw ("Failed to process template values. " + $_.exception.message)
        } # catch


        ## Write out completed XML
        Write-Verbose ("Writing completed file to " + $targetFile)

        try {
            if ($PSCmdlet.ShouldProcess($targetFile)) {
                $xmlTemp | Out-File -FilePath $targetFile -Force -ErrorAction Stop

                ## Get the output so we can return an object for it.
                $fileObj = Get-Item -Path $targetFile -ErrorAction Stop
            } # if

            Write-Verbose ("File created.")
        } # try
        catch {
            throw ("Failed to write file. " + $_.exception.message)
        } # catch

        ## Return created file object.
        return $fileObj

    } # process

    end {

    } # end

} # function