#requires -Version 5.1
<# Run only in your disposable Windows lab VM. Promotion and domain join change the VM. #>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Promote','Directory','JoinClient','Verify')]
    [string]$Stage,
    [string]$DomainName = 'ad.example.test',
    [string]$NetbiosName = 'LAB',
    [string]$DcAddress = '192.168.56.10',
    [string]$InterfaceAlias = 'Ethernet'
)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open Windows PowerShell as administrator inside the lab VM.'
}

switch ($Stage) {
    'Promote' {
        if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
            throw 'Promotion requires Windows Server, not a Windows client.'
        }
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Install AD DS and create forest $DomainName; restart required")) {
            $dsrm = Read-Host 'Enter a unique DSRM recovery password' -AsSecureString
            Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
            Import-Module ADDSDeployment
            Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetbiosName `
                -InstallDns -SafeModeAdministratorPassword $dsrm -NoRebootOnCompletion
            Write-Warning 'Promotion is not complete until this VM restarts. Restart-Computer when ready.'
        }
    }
    'Directory' {
        Import-Module ActiveDirectory
        $domain = Get-ADDomain
        if ($domain.DNSRoot -ne $DomainName) { throw 'Connected domain does not match DomainName.' }
        $root = $domain.DistinguishedName
        $ou = "OU=LabUsers,$root"
        $groupName = 'Lab-Helpdesk'
        if ($PSCmdlet.ShouldProcess($DomainName, 'Create LabUsers OU, Lab-Helpdesk group, and alex.example user')) {
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'LabUsers'" -SearchBase $root -SearchScope OneLevel)) {
                New-ADOrganizationalUnit -Name LabUsers -Path $root -ProtectedFromAccidentalDeletion $true
            }
            if (-not (Get-ADGroup -Filter "SamAccountName -eq '$groupName'")) {
                New-ADGroup -Name $groupName -SamAccountName $groupName -GroupScope Global -GroupCategory Security -Path $ou
            }
            if (-not (Get-ADUser -Filter "SamAccountName -eq 'alex.example'")) {
                $password = Read-Host 'Enter a unique temporary password for alex.example' -AsSecureString
                New-ADUser -Name 'Alex Example' -GivenName Alex -Surname Example `
                    -SamAccountName alex.example -UserPrincipalName "alex.example@$DomainName" `
                    -Path $ou -AccountPassword $password -Enabled $true -ChangePasswordAtLogon $true
            }
            $members = @(Get-ADGroupMember -Identity $groupName | Select-Object -ExpandProperty SamAccountName)
            if ($members -notcontains 'alex.example') {
                Add-ADGroupMember -Identity $groupName -Members alex.example
            }
            Write-Output 'Directory objects configured. Lab-Helpdesk grants no administrative rights by itself.'
        }
    }
    'JoinClient' {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Set DNS to $DcAddress and join $DomainName")) {
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DcAddress
            Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV | Out-Host
            $credential = Get-Credential -Message 'Enter lab domain administrator credentials'
            Add-Computer -DomainName $DomainName -Credential $credential
            Write-Warning 'Restart the client VM, then test domain sign-in.'
        }
    }
    'Verify' {
        Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain
        Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses
        Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV
        if (Get-Module -ListAvailable ActiveDirectory) {
            Import-Module ActiveDirectory
            Get-ADDomain | Select-Object DNSRoot, DomainMode
            Get-ADUser alex.example -Properties Enabled, PasswordLastSet | Select-Object SamAccountName, Enabled, PasswordLastSet
            Get-ADGroupMember Lab-Helpdesk | Select-Object Name, SamAccountName
        }
    }
}
