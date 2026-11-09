function Connect-CltAduaLdap {
    <#
    .SYNOPSIS
    Connects to Active Directory over LDAP for the devclate.ad-user-attributes tests. Read-only.

    .DESCRIPTION
    Connect-Maester -Service CLT.ADUA.Ldap calls it. Its parameters come from -ServiceSetting, from
    Connections."CLT.ADUA.Ldap" in maester-config.json, or from MAESTER_CLT_ADUA_LDAP_<NAME> environment variables.

    It uses System.DirectoryServices.Protocols, which ships with PowerShell 7, so it runs on Windows, macOS and
    Linux. On macOS and Linux it also needs the OpenLDAP client library (libldap), and Negotiate or Kerberos needs
    a Kerberos ticket (kinit) for the account.

    TlsMode Auto tries LDAPS (636), then StartTLS (389), then, for Negotiate or Kerberos only, a signed and sealed
    connection on 389. Basic authentication is refused without LDAPS or StartTLS, because it sends the password
    in clear text otherwise.

    The connection stays open for the PowerShell session; Disconnect-Maester -Service CLT.ADUA.Ldap closes it.

    .EXAMPLE
    Connect-Maester -Service CLT.ADUA.Ldap

    On a domain-joined Windows computer: the current user, the computer's domain, TlsMode Auto.

    .EXAMPLE
    Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{ Server = 'dc01.contoso.com'; AuthType = 'Basic'; TlsMode = 'Ldaps'; Credential = (Get-Credential) }

    From macOS or Linux without Kerberos: a simple bind over LDAPS.
    #>
    [CmdletBinding()]
    param(
        # Domain controller or domain DNS name. Blank uses the server Connect-Maester -Service ActiveDirectory found, then the computer's domain.
        [string] $Server,

        # LDAP port; 0 uses 636 for LDAPS and 389 otherwise.
        [ValidateRange(0, 65535)]
        [int] $Port = 0,

        # Auto tries Ldaps, then StartTls, then (Negotiate or Kerberos only) a signed and sealed connection on 389.
        [ValidateSet('Auto', 'Ldaps', 'StartTls', 'None')]
        [string] $TlsMode = 'Auto',

        # Negotiate and Kerberos use the current user, or Credential; Basic needs Credential and TLS.
        [ValidateSet('Negotiate', 'Kerberos', 'Basic')]
        [string] $AuthType = 'Negotiate',

        # The account to bind as; blank binds as the current user (Negotiate or Kerberos only).
        [System.Management.Automation.PSCredential] $Credential,

        # Where users are read from; blank uses the domain root. GlobalSettings."CLT.ADUA.SearchBase" overrides it.
        [string] $SearchBase,

        # Accept any LDAPS or StartTLS certificate. Windows only; for test domains.
        [bool] $SkipCertificateCheck = $false,

        # Seconds to wait for each LDAP request.
        [ValidateRange(5, 3600)]
        [int] $TimeoutSeconds = 120
    )

    if ([string]::IsNullOrWhiteSpace($Server)) { $Server = Get-CltAduaDefaultServer }
    if ([string]::IsNullOrWhiteSpace($Server)) {
        throw ('CLT.ADUA.Ldap: no domain controller was given and none could be found. Connect with ' +
            "-ServiceSetting @{ Server = 'dc01.contoso.com' }, or set Connections.""CLT.ADUA.Ldap"".Server in maester-config.json.")
    }
    if ($AuthType -eq 'Basic' -and -not $Credential) { throw 'CLT.ADUA.Ldap: AuthType Basic needs a Credential.' }
    if ($AuthType -eq 'Basic' -and $TlsMode -eq 'None') {
        throw 'CLT.ADUA.Ldap: AuthType Basic sends the password in clear text without TLS. Use TlsMode Ldaps, StartTls or Auto.'
    }
    if ($SkipCertificateCheck -and -not $IsWindows) {
        throw ('CLT.ADUA.Ldap: SkipCertificateCheck works on Windows only. On macOS and Linux, trust the domain CA instead ' +
            '(TLS_CACERT in ldap.conf, or the LDAPTLS_CACERT environment variable).')
    }

    $modes = if ($TlsMode -ne 'Auto') { @($TlsMode) } elseif ($AuthType -eq 'Basic') { @('Ldaps', 'StartTls') } else { @('Ldaps', 'StartTls', 'None') }
    $failures = [System.Collections.Generic.List[string]]::new()
    $connection = $null
    $selected = $null
    foreach ($mode in $modes) {
        $modePort = if ($Port -gt 0) { $Port } elseif ($mode -eq 'Ldaps') { 636 } else { 389 }
        try {
            $connection = New-CltAduaLdapConnection -Server $Server -Port $modePort -TlsMode $mode -AuthType $AuthType -Credential $Credential -SkipCertificateCheck $SkipCertificateCheck -TimeoutSeconds $TimeoutSeconds
            $selected = $mode
            break
        } catch {
            $failures.Add("${mode} (port $modePort): $($_.Exception.Message)")
        }
    }
    if (-not $connection) {
        throw "CLT.ADUA.Ldap: could not connect to $Server. Tried $($failures -join '; ')"
    }

    $rootDse = Read-CltAduaRootDse -Connection $connection
    $base = if (-not [string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase.Trim() } else { $rootDse.DefaultNamingContext }
    if ([string]::IsNullOrWhiteSpace($base)) {
        $connection.Dispose()
        throw "CLT.ADUA.Ldap: $Server did not report a default naming context. Set SearchBase, such as 'DC=contoso,DC=com'."
    }
    $domain = ConvertTo-CltAduaDnsName -DistinguishedName $(if ($rootDse.DefaultNamingContext) { $rootDse.DefaultNamingContext } else { $base })
    $account = if ($Credential) { $Credential.UserName } elseif ($env:USERNAME) { "$env:USERDOMAIN\$env:USERNAME".TrimStart('\') } else { "$env:USER (Kerberos ticket)" }

    Set-MtConnectionState -Tenant $domain -Account $account -Value @{
        Connection           = $connection
        Server               = $Server
        DnsHostName          = $rootDse.DnsHostName
        TlsMode              = $selected
        AuthType             = $AuthType
        SearchBase           = $base
        DefaultNamingContext = $rootDse.DefaultNamingContext
        # Where Get-CltAduaSchemaExtensionAttribute checks which extension attributes the forest has.
        SchemaNamingContext  = $rootDse.SchemaNamingContext
        # The tests share one read of the directory per session; helpers keep it here.
        Cache                = @{}
    }
}

function Test-CltAduaLdap {
    <#
    .SYNOPSIS
    Returns $true when Connect-CltAduaLdap has connected in this session. Tests that need CLT.ADUA.Ldap do not run otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtConnectionState
    [bool]($state -and $state.Connection)
}

function Disconnect-CltAduaLdap {
    <#
    .SYNOPSIS
    Closes the LDAP connection and forgets it.
    #>
    [CmdletBinding()]
    param()

    $state = Get-MtConnectionState
    if ($state -and $state.Connection) { $state.Connection.Dispose() }
    Clear-MtConnectionState
}

function Get-CltAduaDefaultServer {
    <#
    .SYNOPSIS
    Returns the server Connect-Maester -Service ActiveDirectory resolved in this session, else the computer's domain, else nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (Get-Command -Name Get-MtSession -ErrorAction SilentlyContinue) {
        $ad = (Get-MtSession)['ADConnection']
        if ($ad -and $ad['Connected'] -and $ad['ResolvedServer']) { return [string]$ad['ResolvedServer'] }
    }
    if ($env:USERDNSDOMAIN) { return [string]$env:USERDNSDOMAIN }
    return $null
}

function New-CltAduaLdapConnection {
    <#
    .SYNOPSIS
    Opens and binds one LDAP connection with the given TLS mode, or throws.
    #>
    [CmdletBinding()]
    [OutputType([System.DirectoryServices.Protocols.LdapConnection])]
    param(
        [string] $Server,
        [int] $Port,
        [ValidateSet('Ldaps', 'StartTls', 'None')]
        [string] $TlsMode,
        [ValidateSet('Negotiate', 'Kerberos', 'Basic')]
        [string] $AuthType,
        [System.Management.Automation.PSCredential] $Credential,
        [bool] $SkipCertificateCheck,
        [int] $TimeoutSeconds
    )

    $identifier = [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]::new($Server, $Port, $false, $false)
    $connection = if ($Credential) {
        [System.DirectoryServices.Protocols.LdapConnection]::new($identifier, $Credential.GetNetworkCredential())
    } else {
        [System.DirectoryServices.Protocols.LdapConnection]::new($identifier)
    }
    try {
        $connection.AuthType = [System.DirectoryServices.Protocols.AuthType]$AuthType
        $connection.Timeout = [timespan]::FromSeconds($TimeoutSeconds)
        $connection.SessionOptions.ProtocolVersion = 3
        $connection.SessionOptions.ReferralChasing = [System.DirectoryServices.Protocols.ReferralChasingOptions]::None
        if ($SkipCertificateCheck) {
            $connection.SessionOptions.VerifyServerCertificate = [System.DirectoryServices.Protocols.VerifyServerCertificateCallback] { param($LdapConnection, $Certificate) $true }
        }
        switch ($TlsMode) {
            'Ldaps' { $connection.SessionOptions.SecureSocketLayer = $true }
            'StartTls' { $connection.SessionOptions.StartTransportLayerSecurity($null) }
            'None' {
                # Kerberos signing and sealing; on macOS and Linux the SASL layer negotiates them itself.
                if ($IsWindows) {
                    $connection.SessionOptions.Signing = $true
                    $connection.SessionOptions.Sealing = $true
                }
            }
        }
        $connection.Bind()
        return $connection
    } catch {
        $connection.Dispose()
        throw
    }
}

function Read-CltAduaRootDse {
    <#
    .SYNOPSIS
    Reads the default and schema naming contexts and the DNS host name from the server's RootDSE.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [System.DirectoryServices.Protocols.LdapConnection] $Connection
    )

    $request = [System.DirectoryServices.Protocols.SearchRequest]::new('', '(objectClass=*)', [System.DirectoryServices.Protocols.SearchScope]::Base, [string[]]@('defaultNamingContext', 'dnsHostName', 'namingContexts', 'schemaNamingContext'))
    $response = [System.DirectoryServices.Protocols.SearchResponse]$Connection.SendRequest($request)
    $entry = @($response.Entries)[0]
    $default = @(Get-CltAduaEntryString -Entry $entry -Name 'defaultNamingContext')[0]
    if (-not $default) { $default = @(Get-CltAduaEntryString -Entry $entry -Name 'namingContexts' | Where-Object { $_ -match '^DC=' })[0] }
    [pscustomobject]@{
        DefaultNamingContext = [string]$default
        DnsHostName          = [string]@(Get-CltAduaEntryString -Entry $entry -Name 'dnsHostName')[0]
        SchemaNamingContext  = [string]@(Get-CltAduaEntryString -Entry $entry -Name 'schemaNamingContext')[0]
    }
}

function Get-CltAduaEntryString {
    <#
    .SYNOPSIS
    Returns the string values of one attribute of an LDAP search result entry, matching the name without regard to case.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [System.DirectoryServices.Protocols.SearchResultEntry] $Entry,
        [string] $Name
    )

    if (-not $Entry) { return @() }
    foreach ($attributeName in $Entry.Attributes.AttributeNames) {
        if ("$attributeName" -ieq $Name) { return @($Entry.Attributes[[string]$attributeName].GetValues([string])) }
    }
    return @()
}

function ConvertTo-CltAduaDnsName {
    <#
    .SYNOPSIS
    Turns DC=contoso,DC=com into contoso.com.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $DistinguishedName)

    $parts = foreach ($rdn in ($DistinguishedName -split '(?<!\\),')) {
        if ($rdn.Trim() -match '^DC=(.+)$') { $Matches[1] }
    }
    return (@($parts) -join '.')
}
