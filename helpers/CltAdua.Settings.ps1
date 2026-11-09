function Get-CltAduaSetting {
    <#
    .SYNOPSIS
    Returns a GlobalSettings value from maester-config.json, or Default when it is not set or cannot be read.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The setting's name, such as CLT.ADUA.ExcludedUsers.
        [string] $Name,

        # The value to return when the setting is not set.
        $Default
    )

    if (-not (Get-Command -Name Get-MtSetting -ErrorAction SilentlyContinue)) { return $Default }
    $value = Get-MtSetting -Name $Name -Default $Default
    if ($null -eq $value) { return $Default }
    return $value
}

function Get-CltAduaSettingList {
    <#
    .SYNOPSIS
    Returns a GlobalSettings value as a list of non-blank strings, whether the config holds one string or a list.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        # The setting's name, such as CLT.ADUA.ExcludedGroups.
        [string] $Name
    )

    $list = foreach ($item in @(Get-CltAduaSetting -Name $Name -Default @())) {
        if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item)) { ([string]$item).Trim() }
    }
    return @($list)
}

function Get-CltAduaObjectValue {
    <#
    .SYNOPSIS
    Returns a property of an object or dictionary from JSON, matching the name without regard to case, or $null.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # A PSCustomObject or a dictionary.
        $InputObject,

        # The property name.
        [string] $Name
    )

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) { if ("$key" -ieq $Name) { return $InputObject[$key] } }
        return $null
    }
    $property = $InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if ($property) { return $property.Value }
    return $null
}

function ConvertTo-CltAduaStringList {
    <#
    .SYNOPSIS
    Flattens a value from JSON (a string, a list, or a list of single-property objects) into non-blank strings.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        # The value to flatten.
        $Value,

        # For a list of objects (as in the 2.x validation.json), the property to read from each, such as title.
        [string] $ItemProperty
    )

    $list = foreach ($item in @($Value)) {
        if ($null -eq $item) { continue }
        if ($item -is [string]) { $item; continue }
        if ($ItemProperty) { foreach ($inner in @(Get-CltAduaObjectValue -InputObject $item -Name $ItemProperty)) { if ($null -ne $inner) { [string]$inner } } }
    }
    return @($list | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
