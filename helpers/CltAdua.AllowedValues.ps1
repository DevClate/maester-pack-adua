function Get-CltAduaAttributeAlias {
    <#
    .SYNOPSIS
    Returns the LDAP attribute for a name used in approved values: the LDAP name itself, or the Microsoft Graph
    name the User Attributes pack (CLT.UA) uses, so one approved-values list serves both packs.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $map = @{
        department = 'department'; title = 'title'; jobTitle = 'title'; company = 'company'; companyName = 'company'
        streetAddress = 'streetAddress'; l = 'l'; city = 'l'; st = 'st'; state = 'st'; postalCode = 'postalCode'; zipCode = 'postalCode'
        co = 'co'; country = 'co'; c = 'c'; telephoneNumber = 'telephoneNumber'; businessPhones = 'telephoneNumber'
        physicalDeliveryOfficeName = 'physicalDeliveryOfficeName'; officeLocation = 'physicalDeliveryOfficeName'
    }
    foreach ($name in Get-CltAduaExtensionAttributeName) { $map[$name] = $name }
    return $map
}

function ConvertTo-CltAduaAllowedLocation {
    <#
    .SYNOPSIS
    Turns an approved location from JSON into a hashtable keyed by LDAP attribute (city becomes l, and so on).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # One location object from the locations list or validation.json validLocations.
        $Location
    )

    $aliases = Get-CltAduaAttributeAlias
    $result = @{ name = [string](Get-CltAduaObjectValue -InputObject $Location -Name 'name') }
    foreach ($alias in $aliases.Keys) {
        $values = @(ConvertTo-CltAduaStringList -Value (Get-CltAduaObjectValue -InputObject $Location -Name $alias))
        if (-not $values.Count) { continue }
        $target = $aliases[$alias]
        if (-not $result.ContainsKey($target)) { $result[$target] = [System.Collections.Generic.List[string]]::new() }
        foreach ($value in $values) { if (-not $result[$target].Contains($value)) { $result[$target].Add($value) } }
    }
    foreach ($key in @($result.Keys)) { if ($key -ne 'name') { $result[$key] = $result[$key].ToArray() } }
    return $result
}

function Read-CltAduaAllowedValueFile {
    <#
    .SYNOPSIS
    Reads the JSON file named by a GlobalSettings value, or returns $null when none is set.

    .DESCRIPTION
    A relative path is resolved from the folder the run started in. The file can use the shape of the
    AllowedValues setting (department, title, ..., locations) or the 2.x validation.json shape (validTitles,
    validDepartments, validLocations with zipCode).
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The setting that names the file, such as CLT.ADUA.AllowedValuesFile.
        [string] $SettingName
    )

    $path = [string](Get-CltAduaSetting -Name $SettingName -Default '')
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $full = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path -Path (Get-Location).Path -ChildPath $path }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "${SettingName}: '$path' was not found (looked for $full). Use an absolute path, or start the run from the folder that holds the file."
    }
    try {
        return (Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -Depth 10)
    } catch {
        throw "${SettingName}: '$full' is not valid JSON: $($_.Exception.Message)"
    }
}

function Get-CltAduaAllowedValueSet {
    <#
    .SYNOPSIS
    Returns the pack-wide approved values: lists by LDAP attribute and approved locations.

    .DESCRIPTION
    Reads GlobalSettings."CLT.ADUA.AllowedValues" and the file in "CLT.ADUA.AllowedValuesFile" together. When
    neither is set, it reads the User Attributes pack's "CLT.UA.AllowedValues" and "CLT.UA.AllowedValuesFile"
    instead, so a configuration written for that pack also works here. Graph names (jobTitle, city, ...) and
    LDAP names (title, l, ...) are both accepted.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $aliases = Get-CltAduaAttributeAlias
    $lists = @{}
    foreach ($target in ($aliases.Values | Select-Object -Unique)) { $lists[$target] = [System.Collections.Generic.List[string]]::new() }
    $locations = [System.Collections.Generic.List[hashtable]]::new()
    $sources = [System.Collections.Generic.List[string]]::new()

    $origins = foreach ($prefix in 'CLT.ADUA', 'CLT.UA') {
        $found = @(
            [pscustomobject]@{ Name = "$prefix.AllowedValues"; Data = (Get-CltAduaSetting -Name "$prefix.AllowedValues" -Default $null) }
            [pscustomobject]@{ Name = "$prefix.AllowedValuesFile"; Data = (Read-CltAduaAllowedValueFile -SettingName "$prefix.AllowedValuesFile") }
        ) | Where-Object { $null -ne $_.Data }
        if ($found) { $found; break }
    }

    foreach ($origin in @($origins)) {
        $sources.Add($origin.Name)
        foreach ($alias in $aliases.Keys) {
            foreach ($value in (ConvertTo-CltAduaStringList -Value (Get-CltAduaObjectValue -InputObject $origin.Data -Name $alias))) { $lists[$aliases[$alias]].Add($value) }
        }
        # The 2.x validation.json names.
        foreach ($value in (ConvertTo-CltAduaStringList -Value (Get-CltAduaObjectValue -InputObject $origin.Data -Name 'validTitles') -ItemProperty 'title')) { $lists['title'].Add($value) }
        foreach ($value in (ConvertTo-CltAduaStringList -Value (Get-CltAduaObjectValue -InputObject $origin.Data -Name 'validDepartments') -ItemProperty 'department')) { $lists['department'].Add($value) }
        $rawLocations = @(Get-CltAduaObjectValue -InputObject $origin.Data -Name 'locations') + @(Get-CltAduaObjectValue -InputObject $origin.Data -Name 'validLocations')
        foreach ($raw in $rawLocations) {
            if ($null -eq $raw -or $raw -is [string]) { continue }
            $location = ConvertTo-CltAduaAllowedLocation -Location $raw
            $locations.Add($location)
            # A location's values are approved values of each attribute too.
            foreach ($field in $location.Keys) { if ($field -ne 'name' -and $lists.ContainsKey($field)) { foreach ($v in $location[$field]) { $lists[$field].Add($v) } } }
        }
    }

    return [pscustomobject]@{ Lists = $lists; Locations = $locations.ToArray(); Source = ($sources -join ' and ') }
}

function Invoke-CltAduaAllowedValueCheck {
    <#
    .SYNOPSIS
    Checks that every value of Attribute on the users is an approved value, and returns $true when it is.

    .DESCRIPTION
    Shared by the approved-value tests. The approved values come from the test's AllowedValues when it has any,
    else from Get-CltAduaAllowedValueSet (including the values of approved locations). Blank values are not
    checked: the presence tests check those. Without any approved values, the test reports Investigate with
    the values it found, so they can be copied into the config.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The result of Get-CltAduaUser.
        $Set,

        # The LDAP attribute, such as department.
        [string] $Attribute,

        # How the attribute is named in results, such as "department".
        [string] $Label,

        # The heading of the value column, such as Department.
        [string] $Column,

        # How the checked users are named in results, such as "enabled users".
        [string] $Population,

        # The test's own approved values; when set, the pack-wide values are not used.
        [string[]] $AllowedValues,

        # Treat values that differ only in letter case as different.
        [bool] $CaseSensitive = $true,

        # Most rows to list in the result; 0 lists them all.
        [int] $MaxRows = 100
    )

    $article = Get-CltAduaArticle -Word $Label
    # Name the attribute after the label, unless the label is the attribute (extensionAttribute3).
    $named = if ($Label -ceq $Attribute) { '' } else { " (``$Attribute``)" }
    $users = @($Set.Users | Where-Object { -not (Test-CltAduaIsBlank $_.$Attribute) })
    if ($users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "None of the $Population has $article $Label$named set."
    }

    $comparer = if ($CaseSensitive) { [System.StringComparer]::Ordinal } else { [System.StringComparer]::OrdinalIgnoreCase }
    $groups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new($comparer)
    foreach ($user in $users) {
        foreach ($value in @($user.$Attribute)) {
            if (Test-CltAduaIsBlank $value) { continue }
            $text = [string]$value
            if (-not $groups.ContainsKey($text)) { $groups[$text] = [System.Collections.Generic.List[object]]::new() }
            if (-not $groups[$text].Contains($user)) { $groups[$text].Add($user) }
        }
    }

    $own = @($AllowedValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($own.Count) {
        $allowedList = $own
        $source = "this test's AllowedValues"
    } else {
        $shared = Get-CltAduaAllowedValueSet
        $allowedList = @($shared.Lists[$Attribute])
        $source = $shared.Source
    }
    $allowed = [System.Collections.Generic.HashSet[string]]::new($comparer)
    foreach ($value in $allowedList) { [void]$allowed.Add($value) }

    if ($allowed.Count -eq 0) {
        $rows = @($groups.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | ForEach-Object { ConvertTo-CltAduaValueRow -Entry $_ -Column $Column })
        $table = Format-CltAduaTable -Rows $rows -Columns $Column, 'Users', 'Examples' -MaxRows $MaxRows
        Add-CltAduaResult -Note $Set.Note -Investigate -Result ("No approved ${Label} values are set, so the $($groups.Count) values used by $($users.Count) $Population are listed for review. " +
            "Add the correct ones to **CLT.ADUA.AllowedValues** → **$Attribute** under GlobalSettings in maester-config.json (or to this test's **AllowedValues**) so this test can enforce them.`n`n$table")
        return $true
    }

    $rejected = @($groups.GetEnumerator() | Where-Object { -not $allowed.Contains($_.Key) })
    if ($rejected.Count -eq 0) {
        Add-CltAduaResult -Note $Set.Note -Result "Well done. All $($users.Count) $Population with $article $Label use one of the $($allowed.Count) approved values (from $source)."
        return $true
    }

    $affected = [System.Collections.Generic.HashSet[object]]::new()
    foreach ($entry in $rejected) { foreach ($user in $entry.Value) { [void]$affected.Add($user) } }
    $rows = @($rejected | Sort-Object { $_.Value.Count } -Descending | ForEach-Object { ConvertTo-CltAduaValueRow -Entry $_ -Column $Column })
    $table = Format-CltAduaTable -Rows $rows -Columns $Column, 'Users', 'Examples' -MaxRows $MaxRows
    Add-CltAduaResult -Note $Set.Note -Result ("$($affected.Count) of $($users.Count) $Population have $article $Label that is not one of the $($allowed.Count) approved values (from $source). " +
        "$($rejected.Count) value(s) are not approved:`n`n$table")
    return $false
}
