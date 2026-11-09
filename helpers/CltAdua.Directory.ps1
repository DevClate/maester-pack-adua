function Get-CltAduaConnection {
    <#
    .SYNOPSIS
    Returns what Connect-CltAduaLdap kept: the LDAP connection, the search base and the session cache.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $state = Get-MtConnectionState -Service 'CLT.ADUA.Ldap'
    if (-not $state -or -not $state.Connection) { throw 'Active Directory is not connected. Run Connect-Maester -Service CLT.ADUA.Ldap first.' }
    return $state
}

function ConvertTo-CltAduaLdapFilterValue {
    <#
    .SYNOPSIS
    Escapes a value for use inside an LDAP filter (RFC 4515).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $Value)

    $builder = [System.Text.StringBuilder]::new()
    foreach ($character in $Value.ToCharArray()) {
        switch ($character) {
            '(' { [void]$builder.Append('\28') }
            ')' { [void]$builder.Append('\29') }
            '*' { [void]$builder.Append('\2a') }
            '\' { [void]$builder.Append('\5c') }
            ([char]0) { [void]$builder.Append('\00') }
            default { [void]$builder.Append($character) }
        }
    }
    return $builder.ToString()
}

function Invoke-CltAduaLdapSearch {
    <#
    .SYNOPSIS
    Runs a paged LDAP search on the CLT.ADUA.Ldap connection and returns one dictionary per entry.

    .DESCRIPTION
    Each dictionary has distinguishedName plus the requested attributes, keyed as requested: $null when the
    entry has no value, a string for one value, or a string array for several. objectGUID is returned as a GUID
    string. Pages of 1000 entries are read until the server has no more, so directories larger than the
    server's MaxPageSize are read in full.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        # The DN to search under.
        [string] $SearchBase,

        # The LDAP filter.
        [string] $Filter,

        # The attributes to return.
        [string[]] $Attributes,

        # Base, OneLevel or Subtree.
        [ValidateSet('Base', 'OneLevel', 'Subtree')]
        [string] $Scope = 'Subtree',

        # Entries per page.
        [ValidateRange(1, 5000)]
        [int] $PageSize = 1000
    )

    $connection = (Get-CltAduaConnection).Connection
    $request = [System.DirectoryServices.Protocols.SearchRequest]::new($SearchBase, $Filter, [System.DirectoryServices.Protocols.SearchScope]$Scope, [string[]]$Attributes)
    $paging = [System.DirectoryServices.Protocols.PageResultRequestControl]::new($PageSize)
    $paging.IsCritical = $false
    [void]$request.Controls.Add($paging)

    do {
        $response = [System.DirectoryServices.Protocols.SearchResponse]$connection.SendRequest($request)
        foreach ($entry in $response.Entries) {
            $item = [ordered]@{ distinguishedName = [string]$entry.DistinguishedName }
            foreach ($wanted in $Attributes) {
                if ($wanted -ieq 'distinguishedName') { continue }
                $item[$wanted] = $null
                foreach ($returned in $entry.Attributes.AttributeNames) {
                    if ("$returned" -ine $wanted) { continue }
                    $attribute = $entry.Attributes[[string]$returned]
                    # @() around the if: assigning an if's output unrolls a one-value array into a bare string.
                    $values = @(if ($wanted -ieq 'objectGUID') {
                            $attribute.GetValues([byte[]]) | ForEach-Object { ([guid]::new([byte[]]$_)).Guid }
                        } else {
                            $attribute.GetValues([string])
                        })
                    $item[$wanted] = if ($values.Count -eq 1) { [string]$values[0] } elseif ($values.Count -gt 1) { [string[]]$values } else { $null }
                }
            }
            $item
        }
        $cookie = $null
        foreach ($control in $response.Controls) {
            if ($control -is [System.DirectoryServices.Protocols.PageResultResponseControl]) { $cookie = $control.Cookie }
        }
        $paging.Cookie = $cookie
    } while ($cookie -and $cookie.Length -gt 0)
}

function Get-CltAduaUserAttribute {
    <#
    .SYNOPSIS
    Returns the LDAP attributes every test reads, so the directory is read once per session for all of them.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return @(
        'distinguishedName', 'objectGUID', 'sAMAccountName', 'userPrincipalName', 'displayName', 'userAccountControl',
        'isCriticalSystemObject', 'givenName', 'sn', 'title', 'department', 'company', 'employeeID', 'employeeNumber',
        'employeeType', 'manager', 'streetAddress', 'l', 'st', 'postalCode', 'c', 'co', 'physicalDeliveryOfficeName',
        'telephoneNumber', 'otherTelephone', 'mobile', 'otherMobile', 'facsimileTelephoneNumber', 'homePhone', 'mail'
    ) + @(Get-CltAduaExtensionAttributeName)
}

function Get-CltAduaSearchBase {
    <#
    .SYNOPSIS
    Returns where users are read from: GlobalSettings."CLT.ADUA.SearchBase" (one or more DNs), else the connection's search base.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $configured = @(Get-CltAduaSettingList -Name 'CLT.ADUA.SearchBase')
    if ($configured.Count) { return $configured }
    return @((Get-CltAduaConnection).SearchBase)
}

function Get-CltAduaDirectoryUser {
    <#
    .SYNOPSIS
    Reads every enabled or disabled user account from the search bases once per session, and returns them as objects.

    .DESCRIPTION
    Only normal user accounts are read (objectCategory person, userAccountControl NORMAL_ACCOUNT), so computers,
    contacts, trust accounts and managed service accounts are never checked. Users found under two overlapping
    search bases are returned once. The result is kept in the connection's cache, so all the tests in a run
    share one read of the directory.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = Get-CltAduaConnection
    $bases = @(Get-CltAduaSearchBase)
    # GlobalSettings."CLT.ADUA.LdapFilter" narrows the users further, such as (mail=*) for mail-enabled users only.
    $extra = [string](Get-CltAduaSetting -Name 'CLT.ADUA.LdapFilter' -Default '')
    $extra = $extra.Trim()
    if ($extra -and -not ($extra.StartsWith('(') -and $extra.EndsWith(')'))) { $extra = "($extra)" }
    $filter = "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=512)$extra)"
    $key = "users|$filter|" + ($bases -join '|')
    if ($state.Cache.ContainsKey($key)) { return $state.Cache[$key] }

    $attributes = Get-CltAduaUserAttribute
    $multiValued = 'otherTelephone', 'otherMobile'
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $users = [System.Collections.Generic.List[object]]::new()
    foreach ($base in $bases) {
        $entries = Invoke-CltAduaLdapSearch -SearchBase $base -Attributes $attributes -Filter $filter
        foreach ($entry in $entries) {
            $id = if ($entry['objectGUID']) { [string]$entry['objectGUID'] } else { [string]$entry['distinguishedName'] }
            if (-not $seen.Add($id)) { continue }
            $user = [ordered]@{}
            foreach ($name in $attributes) {
                $value = $entry[$name]
                # The comma keeps a one-value list a list; an if's output would otherwise unroll it.
                $user[$name] = if ($multiValued -contains $name) { , [string[]]@($value | Where-Object { $null -ne $_ }) } elseif ($value -is [array]) { [string]$value[0] } else { $value }
            }
            $uac = 0
            [void][int]::TryParse([string]$entry['userAccountControl'], [ref]$uac)
            # ACCOUNTDISABLE is bit 0x2 of userAccountControl.
            $user['Enabled'] = -not ($uac -band 2)
            $users.Add([pscustomobject]$user)
        }
    }

    $result = $users.ToArray()
    $state.Cache[$key] = $result
    return $result
}

function Test-CltAduaSystemAccount {
    <#
    .SYNOPSIS
    Returns $true for accounts that never have HR attributes: built-in accounts (Administrator, Guest, krbtgt),
    Microsoft Entra Connect sync accounts, and Exchange system and health mailboxes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param($User)

    if ("$($User.isCriticalSystemObject)" -ieq 'TRUE') { return $true }
    $sam = "$($User.sAMAccountName)"
    foreach ($pattern in 'krbtgt*', 'MSOL_*', 'AAD_*', 'Sync_*', 'HealthMailbox*', 'SM_*', 'DefaultAccount', 'WDAGUtilityAccount') {
        if ($sam -like $pattern) { return $true }
    }
    return $false
}

function ConvertTo-CltAduaGuidFilter {
    <#
    .SYNOPSIS
    Turns a GUID into the escaped bytes an objectGUID LDAP filter needs.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([guid] $Guid)

    return (-join ($Guid.ToByteArray() | ForEach-Object { '\{0:x2}' -f $_ }))
}

function Get-CltAduaGroupMember {
    <#
    .SYNOPSIS
    Finds a group by DN, objectGUID, sAMAccountName or DOMAIN\name and returns the DNs of its user members,
    including nested members (Found is $false when no group matches).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The group's distinguished name, objectGUID, sAMAccountName, or DOMAIN\sAMAccountName.
        [string] $Group
    )

    $state = Get-CltAduaConnection
    $name = $Group.Trim()
    $key = "group|$name"
    if ($state.Cache.ContainsKey($key)) { return $state.Cache[$key] }

    $root = if ($state.DefaultNamingContext) { $state.DefaultNamingContext } else { $state.SearchBase }
    $guid = [guid]::Empty
    $match = if ([guid]::TryParse($name, [ref]$guid)) {
        "(objectGUID=$(ConvertTo-CltAduaGuidFilter -Guid $guid))"
    } elseif ($name -match '^[A-Za-z]+=.+,') {
        "(distinguishedName=$(ConvertTo-CltAduaLdapFilterValue -Value $name))"
    } else {
        "(sAMAccountName=$(ConvertTo-CltAduaLdapFilterValue -Value ($name -replace '^[^\\]+\\', '')))"
    }
    $groups = @(Invoke-CltAduaLdapSearch -SearchBase $root -Filter "(&(objectCategory=group)$match)" -Attributes 'distinguishedName')

    $members = foreach ($found in $groups) {
        # LDAP_MATCHING_RULE_IN_CHAIN returns nested members too.
        $inChain = "(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=$(ConvertTo-CltAduaLdapFilterValue -Value $found['distinguishedName'])))"
        foreach ($member in (Invoke-CltAduaLdapSearch -SearchBase $root -Filter $inChain -Attributes 'distinguishedName')) { [string]$member['distinguishedName'] }
    }

    $result = [pscustomobject]@{ Found = ($groups.Count -gt 0); Members = [string[]]@($members) }
    $state.Cache[$key] = $result
    return $result
}

function New-CltAduaExclusionSet {
    <#
    .SYNOPSIS
    Builds a set of user identifiers from users and groups, and lists the groups that were not found.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # sAMAccountNames, DOMAIN\names, user principal names, distinguished names or objectGUIDs.
        [string[]] $Users,

        # Groups by DN, objectGUID or sAMAccountName; their members, including nested members, are added.
        [string[]] $Groups
    )

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($user in $Users) {
        if ([string]::IsNullOrWhiteSpace($user)) { continue }
        [void]$set.Add(($user.Trim() -replace '^[^\\=]+\\', ''))
    }
    foreach ($group in $Groups) {
        if ([string]::IsNullOrWhiteSpace($group)) { continue }
        $found = Get-CltAduaGroupMember -Group $group
        if (-not $found.Found) { $missing.Add($group.Trim()); continue }
        foreach ($dn in $found.Members) { [void]$set.Add($dn) }
    }
    return [pscustomobject]@{ Set = $set; MissingGroups = $missing.ToArray() }
}

function Test-CltAduaInSet {
    <#
    .SYNOPSIS
    Returns $true when the user's DN, sAMAccountName, user principal name or objectGUID is in the set.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        $User,
        [System.Collections.Generic.HashSet[string]] $Set
    )

    foreach ($id in $User.distinguishedName, $User.sAMAccountName, $User.userPrincipalName, $User.objectGUID) {
        if ($id -and $Set.Contains([string]$id)) { return $true }
    }
    return $false
}

function Get-CltAduaUser {
    <#
    .SYNOPSIS
    Returns the users a devclate.ad-user-attributes test checks (Users), and a note for the result that says
    who was left out and why (Note).

    .DESCRIPTION
    Starts from Get-CltAduaDirectoryUser, then leaves out: disabled accounts unless IncludeDisabled is set;
    built-in, sync and Exchange system accounts; users under GlobalSettings."CLT.ADUA.ExcludedOUs"; the
    pack-wide GlobalSettings."CLT.ADUA.ExcludedUsers" and "CLT.ADUA.ExcludedGroups"; and the test's own
    ExcludedUsers and ExcludedGroups. The lists add up: a test's own exclusions never replace the others.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Also return disabled accounts.
        [bool] $IncludeDisabled = $false,

        # The test's own users to leave out (sAMAccountName, UPN, DN or objectGUID).
        [string[]] $ExcludedUsers,

        # The test's own groups whose members, including nested members, are left out.
        [string[]] $ExcludedGroups
    )

    $ous = @(Get-CltAduaSettingList -Name 'CLT.ADUA.ExcludedOUs' | ForEach-Object { ($_ -replace ',\s+', ',').TrimStart(',') })
    $sources = @(
        [pscustomobject]@{ Name = 'pack-wide'; Exclusion = (New-CltAduaExclusionSet -Users (Get-CltAduaSettingList -Name 'CLT.ADUA.ExcludedUsers') -Groups (Get-CltAduaSettingList -Name 'CLT.ADUA.ExcludedGroups')) }
        [pscustomobject]@{ Name = 'this test'; Exclusion = (New-CltAduaExclusionSet -Users $ExcludedUsers -Groups $ExcludedGroups) }
    )
    $counts = @{ 'OU' = 0; 'pack-wide' = 0; 'this test' = 0 }

    $kept = foreach ($user in @(Get-CltAduaDirectoryUser)) {
        if (-not $user) { continue }
        if (-not $IncludeDisabled -and -not $user.Enabled) { continue }
        if (Test-CltAduaSystemAccount -User $user) { continue }
        $dn = "$($user.distinguishedName)"
        if ($ous | Where-Object { $dn.EndsWith(",$_", [System.StringComparison]::OrdinalIgnoreCase) }) { $counts['OU']++; continue }
        $leftOut = $false
        foreach ($source in $sources) {
            if (Test-CltAduaInSet -User $user -Set $source.Exclusion.Set) { $counts[$source.Name]++; $leftOut = $true; break }
        }
        if ($leftOut) { continue }
        $user
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $total = $counts['OU'] + $counts['pack-wide'] + $counts['this test']
    if ($total) {
        $noun = if ($total -eq 1) { 'user' } else { 'users' }
        $lines.Add("Left out $total ${noun}:")
        $lines.Add('')
        if ($counts['OU']) { $lines.Add("- $($counts['OU']) in an excluded OU (CLT.ADUA.ExcludedOUs)") }
        if ($counts['pack-wide']) { $lines.Add("- $($counts['pack-wide']) by the pack-wide exclusions (CLT.ADUA.ExcludedUsers and CLT.ADUA.ExcludedGroups)") }
        if ($counts['this test']) { $lines.Add("- $($counts['this test']) by this test's ExcludedUsers and ExcludedGroups") }
    }
    $missing = @($sources | ForEach-Object { $_.Exclusion.MissingGroups } | Where-Object { $_ } | Select-Object -Unique)
    if ($missing.Count) {
        if ($lines.Count) { $lines.Add('') }
        $names = @($missing | ForEach-Object { '`' + $_ + '`' }) -join ', '
        $lines.Add("These excluded groups were not found, so they left nobody out: $names.")
    }
    $note = if ($lines.Count) { "`n`n" + ($lines -join "`n") } else { '' }

    return [pscustomobject]@{ Users = @($kept); Note = $note }
}

function Get-CltAduaPopulation {
    <#
    .SYNOPSIS
    Returns the words used in results for the users a test checked, such as "enabled users".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([bool] $IncludeDisabled = $false)

    if ($IncludeDisabled) { return 'users' }
    return 'enabled users'
}
