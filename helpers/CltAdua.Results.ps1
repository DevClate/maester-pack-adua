function Add-CltAduaResult {
    <#
    .SYNOPSIS
    Writes a test's result with Add-MtTestResultDetail, followed by the note from Get-CltAduaUser about who was left out.
    #>
    [CmdletBinding()]
    param(
        # The result text, in Markdown.
        [string] $Result,

        # The note from Get-CltAduaUser, or empty.
        [string] $Note,

        # Report the result as Investigate.
        [switch] $Investigate
    )

    Add-MtTestResultDetail -Result ($Result + $Note) -Investigate:$Investigate
}

function Test-CltAduaIsBlank {
    <#
    .SYNOPSIS
    Returns $true when a value is null, empty, white space, or a list with no non-blank items.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param($Value)

    if ($null -eq $Value) { return $true }
    if ($Value -is [string]) { return [string]::IsNullOrWhiteSpace($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [System.Collections.IDictionary]) {
        foreach ($item in $Value) {
            if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item)) { return $false }
        }
        return $true
    }
    return [string]::IsNullOrWhiteSpace([string]$Value)
}

function Get-CltAduaUserLabel {
    <#
    .SYNOPSIS
    Returns how a user is named in results: display name and sAMAccountName, because display names are often shared.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param($User)

    $account = if ($User.sAMAccountName) { "$($User.sAMAccountName)" } elseif ($User.userPrincipalName) { "$($User.userPrincipalName)" } else { '' }
    if (-not $account) {
        # Neither name is set: use the RDN value, such as Smith\, John from CN=Smith\, John,OU=...
        $rdn = @("$($User.distinguishedName)" -split '(?<!\\),', 2)[0]
        $account = $rdn -replace '^[A-Za-z]+=', ''
    }
    if ($User.displayName -and "$($User.displayName)" -ne $account) { return "$($User.displayName) ($account)" }
    return $account
}

function Get-CltAduaParentContainer {
    <#
    .SYNOPSIS
    Returns the OU or container a DN is in, such as OU=Sales,OU=Staff,DC=contoso,DC=com.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $DistinguishedName)

    $parts = $DistinguishedName -split '(?<!\\),', 2
    if ($parts.Count -lt 2) { return '' }
    return $parts[1]
}

function Get-CltAduaMoreRowsNote {
    <#
    .SYNOPSIS
    Returns the line under a capped list that says how many were left out and how to list them all.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [int] $Shown,
        [int] $Total
    )

    return ("Showing the first $Shown of $Total. To list them all, set **MaxRows** to ``0`` for this test in " +
        "maester-config.json, or run it with ``Invoke-MtTest -Id <test ID> -Parameter @{ MaxRows = 0 }``.")
}

function Format-CltAduaTable {
    <#
    .SYNOPSIS
    Builds a Markdown table from objects, escaping pipes and line breaks, and showing at most MaxRows rows (0 for all).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object[]] $Rows,
        [string[]] $Columns,
        [int] $MaxRows = 100
    )

    $shown = if ($MaxRows -gt 0) { @($Rows | Select-Object -First $MaxRows) } else { @($Rows) }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| ' + ($Columns -join ' | ') + ' |')
    $lines.Add('|' + (' --- |' * $Columns.Count))
    foreach ($row in $shown) {
        $cells = foreach ($column in $Columns) { ("$($row.$column)" -replace '\|', '\|') -replace '\r?\n', ' ' }
        $lines.Add('| ' + ($cells -join ' | ') + ' |')
    }
    if ($Rows.Count -gt $shown.Count) {
        $lines.Add('')
        $lines.Add((Get-CltAduaMoreRowsNote -Shown $shown.Count -Total $Rows.Count))
    }
    return ($lines -join "`n")
}

function Invoke-CltAduaPresenceCheck {
    <#
    .SYNOPSIS
    Reports the users that have no value in Attribute, and returns $true when there are none.

    .DESCRIPTION
    Shared by the presence tests. Lists failing users in a table with their name, account and OU, at most
    MaxRows of them (0 lists them all), so a value most users lack does not fill the report. Skips the test
    when no users are left to check after exclusions.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [object[]] $Users,

        # The LDAP attribute that must have a value.
        [string] $Attribute,

        # How the value is named in results, such as "a job title".
        [string] $Label,

        # How the checked users are named in results, such as "enabled users".
        [string] $Population,

        # Most users to list in the result; 0 lists them all.
        [int] $MaxRows = 100,

        # The note from Get-CltAduaUser about who was left out, added to the end of the result.
        [string] $Note
    )

    if ($Users.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "There are no $Population to check after exclusions."
    }

    $missing = @($Users | Where-Object { Test-CltAduaIsBlank $_.$Attribute })
    if ($missing.Count -eq 0) {
        Add-CltAduaResult -Note $Note -Result "Well done. All $($Users.Count) $Population have $Label (``$Attribute``)."
        return $true
    }

    $rows = foreach ($user in $missing) {
        [pscustomobject]@{
            'User'                = Get-CltAduaUserLabel -User $user
            'User principal name' = "$($user.userPrincipalName)"
            'OU'                  = Get-CltAduaParentContainer -DistinguishedName $user.distinguishedName
        }
    }
    $table = Format-CltAduaTable -Rows @($rows) -Columns 'User', 'User principal name', 'OU' -MaxRows $MaxRows
    Add-CltAduaResult -Note $Note -Result "$($missing.Count) of $($Users.Count) $Population do not have $Label (``$Attribute``).`n`n$table"
    return $false
}

function ConvertTo-CltAduaValueRow {
    <#
    .SYNOPSIS
    Turns one value and the users that have it into a table row: the value, how many users, and up to three of them.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A dictionary entry: Key is the value, Value the list of users.
        $Entry,

        # The heading of the value column, such as Department.
        [string] $Column
    )

    $row = [ordered]@{}
    $row[$Column] = "``$($Entry.Key)``"
    $row['Users'] = $Entry.Value.Count
    $row['Examples'] = (@($Entry.Value | Select-Object -First 3 | ForEach-Object { if ($_.sAMAccountName) { "$($_.sAMAccountName)" } else { Get-CltAduaUserLabel -User $_ } }) -join ', ')
    return [pscustomobject]$row
}
