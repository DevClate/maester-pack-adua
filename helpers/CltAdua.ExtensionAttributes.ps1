function Get-CltAduaExtensionAttributeName {
    <#
    .SYNOPSIS
    Returns the extension attribute names the pack knows, in order: extensionAttribute1-15 (Exchange schema),
    then msDS-cloudExtensionAttribute1-20 (Windows Server 2012 schema and later).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return @(
        1..15 | ForEach-Object { "extensionAttribute$_" }
        1..20 | ForEach-Object { "msDS-cloudExtensionAttribute$_" }
    )
}

function ConvertTo-CltAduaExtensionAttributeName {
    <#
    .SYNOPSIS
    Turns a name or short form from the config into the attribute's LDAP name, or throws.

    .DESCRIPTION
    3, '3', 'ea3' and 'extensionattribute3' become extensionAttribute3 (the Exchange set, 1-15).
    'cloud4', 'cea4' and 'msds-cloudextensionattribute4' become msDS-cloudExtensionAttribute4 (1-20).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The name or short form from the config.
        $Value
    )

    $text = "$Value".Trim()
    if ($text -match '^(?:extensionAttribute|ea)?(\d{1,2})$') {
        $number = [int]$Matches[1]
        if ($number -ge 1 -and $number -le 15) { return "extensionAttribute$number" }
    } elseif ($text -match '^(?:msDS-cloudExtensionAttribute|cloudExtensionAttribute|cloud|cea)(\d{1,2})$') {
        $number = [int]$Matches[1]
        if ($number -ge 1 -and $number -le 20) { return "msDS-cloudExtensionAttribute$number" }
    }
    throw ("'$text' is not an extension attribute. Use extensionAttribute1 to extensionAttribute15 (or 1 to 15), " +
        'or msDS-cloudExtensionAttribute1 to msDS-cloudExtensionAttribute20 (or cloud1 to cloud20).')
}

function Get-CltAduaRequiredExtensionAttribute {
    <#
    .SYNOPSIS
    Returns the extension attributes in GlobalSettings."CLT.ADUA.RequiredExtensionAttributes", in order, each once.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $names = foreach ($item in (Get-CltAduaSettingList -Name 'CLT.ADUA.RequiredExtensionAttributes')) {
        try {
            ConvertTo-CltAduaExtensionAttributeName -Value $item
        } catch {
            throw "CLT.ADUA.RequiredExtensionAttributes: $($_.Exception.Message)"
        }
    }
    return @(Get-CltAduaExtensionAttributeName | Where-Object { $names -contains $_ })
}

function Get-CltAduaExtensionAttributeLabel {
    <#
    .SYNOPSIS
    Returns what an extension attribute holds, from GlobalSettings."CLT.ADUA.ExtensionAttributeNames" (such as Cost centre), or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The extension attribute, such as extensionAttribute1 or msDS-cloudExtensionAttribute4.
        [string] $Attribute
    )

    $map = Get-CltAduaSetting -Name 'CLT.ADUA.ExtensionAttributeNames' -Default $null
    if ($null -eq $map) { return $null }
    $keys = if ($Attribute -match '^extensionAttribute(\d+)$') {
        $Attribute, $Matches[1], "ea$($Matches[1])"
    } elseif ($Attribute -match '^msDS-cloudExtensionAttribute(\d+)$') {
        $Attribute, "cloud$($Matches[1])", "cea$($Matches[1])"
    } else { @($Attribute) }
    foreach ($key in $keys) {
        $value = Get-CltAduaObjectValue -InputObject $map -Name $key
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) { return ([string]$value).Trim() }
    }
    return $null
}

function Get-CltAduaSchemaExtensionAttribute {
    <#
    .SYNOPSIS
    Returns which extension attributes exist in the forest's schema (once per session), or $null when the schema cannot be read.

    .DESCRIPTION
    extensionAttribute1-15 exist only when the Exchange schema has been added to the forest, and
    msDS-cloudExtensionAttribute1-20 only from the Windows Server 2012 schema on. Reads the attributeSchema
    objects in the schema naming context. When the connection did not record the schema naming context, or
    the read fails, it returns $null and every extension attribute is treated as present.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $state = Get-CltAduaConnection
    if ($state.Cache.ContainsKey('schema|extension')) { return $state.Cache['schema|extension'] }

    $result = $null
    if ($state.SchemaNamingContext) {
        $clauses = (Get-CltAduaExtensionAttributeName | ForEach-Object { "(lDAPDisplayName=$_)" }) -join ''
        try {
            $found = @(Invoke-CltAduaLdapSearch -SearchBase $state.SchemaNamingContext -Scope OneLevel -Filter "(&(objectClass=attributeSchema)(|$clauses))" -Attributes 'lDAPDisplayName')
            $names = @($found | ForEach-Object { [string]$_['lDAPDisplayName'] })
            # Return them in the pack's order and spelling.
            $result = @(Get-CltAduaExtensionAttributeName | Where-Object { $names -icontains $_ })
        } catch {
            Write-Verbose "Could not read the schema, so every extension attribute is treated as present: $($_.Exception.Message)"
        }
    }
    $state.Cache['schema|extension'] = $result
    return $result
}

function Test-CltAduaExtensionAttributeInSchema {
    <#
    .SYNOPSIS
    Returns $true when an extension attribute exists in the forest's schema, or when the schema could not be read.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([string] $Attribute)

    $present = Get-CltAduaSchemaExtensionAttribute
    if ($null -eq $present) { return $true }
    return ($present -contains $Attribute)
}

function Get-CltAduaMissingSchemaMessage {
    <#
    .SYNOPSIS
    Returns the result text for an extension attribute that the forest's schema does not have, and what to do about it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Attribute,

        # Where the attribute was named, such as CLT.ADUA.RequiredExtensionAttributes.
        [string] $Source
    )

    $why = if ($Attribute -like 'extensionAttribute*') {
        "``extensionAttribute1``-``15`` come with the Exchange schema, which has not been added to this forest. Use ``msDS-cloudExtensionAttribute1``-``20`` instead, which every forest at the Windows Server 2012 schema or later has"
    } else {
        "``msDS-cloudExtensionAttribute1``-``20`` come with the Windows Server 2012 schema, and this forest's schema is older"
    }
    return ("``$Attribute`` does not exist in this forest's Active Directory schema, so no user can have a value in it, yet it is named in $Source. " +
        "$why. Remove it from $Source, or change it to an attribute this forest has.")
}

function Get-CltAduaExtensionAttributeUsage {
    <#
    .SYNOPSIS
    Returns, for each extension attribute, how many of the users the pack checks have a value in it.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $names = Get-CltAduaExtensionAttributeName
    $counts = @{}
    foreach ($name in $names) { $counts[$name] = 0 }
    foreach ($user in (Get-CltAduaUser).Users) {
        foreach ($name in $names) {
            if (-not (Test-CltAduaIsBlank $user.$name)) { $counts[$name]++ }
        }
    }
    return $counts
}

function Get-CltAduaExtensionAttributeTitle {
    <#
    .SYNOPSIS
    Returns how an extension attribute is named in titles: Cost centre (extensionAttribute1), or just extensionAttribute1.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Attribute,
        [string] $Label
    )

    if ($Label) { return "$Label ($Attribute)" }
    return $Attribute
}

function Get-CltAduaArticle {
    <#
    .SYNOPSIS
    Returns 'an' before a word that starts with a vowel, else 'a'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $Word)

    if ($Word -match '^[aeiouAEIOU]') { return 'an' }
    return 'a'
}
