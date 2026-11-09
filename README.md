![AD User Attributes, a Maester Pack by DevClate](assets/banner.png)

# AD User Attributes for Maester

A [Maester Pack](https://maester.dev/docs/packs/) that checks that **Active Directory** users have the attributes your HR processes, Microsoft Entra Connect sync and the address book depend on, that those values are formatted consistently, and that they use your approved values and office locations.

It is the Active Directory counterpart of the [User Attributes pack](https://github.com/DevClate/maester-pack-ua) (`CLT.UA`) for Microsoft Entra ID. Run both to catch a bad value at the source (AD) and see where it lands (Entra ID).

> **Requirements:** PowerShell 7.4 or later and the Maester 3.x prerelease (`Install-PSResource -Name Maester -Prerelease`). No ActiveDirectory (RSAT) module is needed: the pack reads AD over LDAP itself, so it also runs on macOS and Linux.
>
> **Trust:** Maester reviews a pack before installation and pins the approved files, but it does not sandbox PowerShell. This pack only reads Active Directory; its code still runs in your Maester session with access to your local environment. Review the install summary and the pack's declared access in [maester-pack.json](maester-pack.json) before approving it.

## Quick start

```powershell
Install-PSResource -Name Maester -Prerelease -TrustRepository -Scope CurrentUser
Import-Module Maester -MinimumVersion 3.0.0 -MaximumVersion 3.99.99 -Force
Install-MtPack DevClate/maester-pack-adua
Connect-Maester -Service CLT.ADUA.Ldap          # domain-joined Windows: current user, current domain
Invoke-Maester -Pack CLT.ADUA -SkipBuiltIn
```

From another domain, a non-domain-joined machine, macOS or Linux, name the DC and how to sign in (see [Connecting](#connecting)):

```powershell
Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{
    Server = 'dc01.contoso.com'; AuthType = 'Basic'; TlsMode = 'Ldaps'; Credential = (Get-Credential)
}
```

## Tests

### Attributes are set

| ID | Title | Attribute | Severity |
| --- | --- | --- | --- |
| MP.CLT.ADUA.1001 | All Active Directory users have a manager. | `manager` | Medium |
| MP.CLT.ADUA.1002 | All Active Directory users have a job title. | `title` | Low |
| MP.CLT.ADUA.1003 | All Active Directory users have a department. | `department` | Low |
| MP.CLT.ADUA.1004 | All Active Directory users have an employee ID. | `employeeID` | Medium |
| MP.CLT.ADUA.1005 | All Active Directory users have a company name. | `company` | Low |
| MP.CLT.ADUA.1006 | All Active Directory users have a complete office address. | `streetAddress`, `l`, `st`, `postalCode`, `co` | Low |
| MP.CLT.ADUA.1007 | All Active Directory users have a business phone. | `telephoneNumber` | Low |
| MP.CLT.ADUA.1008 | All Active Directory users have a mobile phone. | `mobile` | Low |
| MP.CLT.ADUA.1009 | All Active Directory users have a fax number. | `facsimileTelephoneNumber` | Info |
| MP.CLT.ADUA.1010 | All Active Directory users have an office location. | `physicalDeliveryOfficeName` | Low |

MP.CLT.ADUA.1007–1010 check fields that many organisations deliberately leave blank, so they carry the tag `Optional`. Leave them all out with `-ExcludeTag Optional`, or turn one off in `maester-config.json`, for example `{ "Id": "MP.CLT.ADUA.1009", "Enabled": false, "Reason": "Fax not used" }`.

### Attributes are formatted correctly

| ID | Title | Severity |
| --- | --- | --- |
| MP.CLT.ADUA.1011 | Every Active Directory employee ID belongs to only one user. | Medium |
| MP.CLT.ADUA.1012 | Active Directory phone numbers use international E.164 format. | Low |
| MP.CLT.ADUA.1013 | Active Directory name, job and location attributes have no stray spaces. | Low |
| MP.CLT.ADUA.1014 | Active Directory country values use an approved spelling. | Low |

### Attributes use approved values

| ID | Title | Attribute | Severity |
| --- | --- | --- | --- |
| MP.CLT.ADUA.1015 | Active Directory departments are on the approved list. | `department` | Low |
| MP.CLT.ADUA.1016 | Active Directory job titles are on the approved list. | `title` | Low |
| MP.CLT.ADUA.1017 | Active Directory company names are on the approved list. | `company` | Low |
| MP.CLT.ADUA.1018 | Active Directory street addresses are on the approved list. | `streetAddress` | Low |
| MP.CLT.ADUA.1019 | Active Directory cities are on the approved list. | `l` | Low |
| MP.CLT.ADUA.1020 | Active Directory states or provinces are on the approved list. | `st` | Low |
| MP.CLT.ADUA.1021 | Active Directory postal codes are on the approved list. | `postalCode` | Low |
| MP.CLT.ADUA.1022 | Active Directory business phone numbers are on the approved list. | `telephoneNumber` | Low |
| MP.CLT.ADUA.1023 | Active Directory user addresses match an approved office location. | address fields and `company` | Low |

### Extension attributes

| ID | Title | Attribute | Severity |
| --- | --- | --- | --- |
| MP.CLT.ADUA.1024 | All Active Directory users have the extension attributes your organisation requires. | `extensionAttribute1`–`15`, `msDS-cloudExtensionAttribute1`–`20` | Low |
| MP.CLT.ADUA.1025 | Active Directory extension attribute values are on the approved list. | `extensionAttribute1`–`15`, `msDS-cloudExtensionAttribute1`–`20` | Low |

These two are **families**: each extension attribute gets its own result row, such as `MP.CLT.ADUA.1024.extensionAttribute3` or `MP.CLT.ADUA.1024.msDS-cloudExtensionAttribute3`, which you can turn off or configure on its own. Attributes nobody uses get no row, so a directory that doesn't use them sees nothing. See [Extension attributes](#extension-attributes-1).

MP.CLT.ADUA.1014 (country spelling) reads the same approved values. Until you set approved values, these tests report **Investigate** and list the values they find, so your first run gives you the list to start from. See [Approved values](#approved-values).

## Choosing which tests run

| To | Use |
| --- | --- |
| Leave out business phone, mobile, fax and office location (MP.CLT.ADUA.1007–1010) | `Invoke-Maester -Pack CLT.ADUA -SkipBuiltIn -ExcludeTag Optional` |
| Run only the formatting tests | `Invoke-Maester -Pack CLT.ADUA -SkipBuiltIn -Tag Format` |
| Run AD and Entra ID side by side | `Invoke-Maester -Pack CLT.ADUA, CLT.UA -SkipBuiltIn` |
| Run only the extension attribute tests | `Invoke-Maester -Pack CLT.ADUA -SkipBuiltIn -Tag ExtensionAttributes` |
| Turn a test off for good | `{ "Id": "MP.CLT.ADUA.1005", "Enabled": false, "Reason": "Single company" }` in `TestSettings` |

Tags used by this pack: `ADUserAttributes` (all), `Presence`, `Format`, `Validation`, `Optional`, `Governance`, `Address`, `Phone`, `Fax`, `ExtensionAttributes`.

## Connecting

The pack has its own read-only LDAP connector, `CLT.ADUA.Ldap`, built on `System.DirectoryServices.Protocols` (part of PowerShell 7). Its tests are opt-in: until you connect it, they do not run, so adding the pack never fills a Graph-only report with skipped tests.

```powershell
Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{ Server = 'dc01.contoso.com' }
Get-MtConnectionState -Service CLT.ADUA.Ldap -Detailed     # who and which domain
Disconnect-Maester -Service CLT.ADUA.Ldap
```

| Setting | Default | What it does |
| --- | --- | --- |
| `Server` | the server `Connect-Maester -Service ActiveDirectory` found, else the computer's domain | Domain controller or domain DNS name. |
| `Port` | `636` for LDAPS, `389` otherwise | LDAP port. |
| `TlsMode` | `Auto` | `Auto` tries `Ldaps`, then `StartTls`, then (Negotiate or Kerberos only) a Kerberos-signed and sealed connection on 389 (`None`). |
| `AuthType` | `Negotiate` | `Negotiate` or `Kerberos` use the signed-in user (or `Credential`); `Basic` is a simple bind and needs `Credential` and TLS. |
| `Credential` | none | The account to bind as. Any domain user can read the attributes this pack checks, unless read access has been restricted. |
| `SearchBase` | the domain root | Where users are read from. `GlobalSettings` → `"CLT.ADUA.SearchBase"` overrides it with one or more OUs. |
| `SkipCertificateCheck` | `false` | Accept any LDAPS or StartTLS certificate. Windows only; for test domains. |
| `TimeoutSeconds` | `120` | How long each LDAP request may take. |

Settings come from `-ServiceSetting`, from `Connections."CLT.ADUA.Ldap"` in `maester-config.json`, or from `MAESTER_CLT_ADUA_LDAP_<NAME>` environment variables (`MAESTER_CLT_ADUA_LDAP_SERVER`, ...). Basic authentication without TLS is refused, because it would send the password in clear text.

**macOS and Linux:** install the OpenLDAP client library (`libldap`), and either get a Kerberos ticket first (`kinit user@CONTOSO.COM`, then `AuthType = 'Negotiate'`) or use `AuthType = 'Basic'` over LDAPS. Trust your domain's CA in `/etc/ldap/ldap.conf` (`TLS_CACERT`), or set `LDAPTLS_CACERT` **before** starting PowerShell; a variable set inside PowerShell does not reach the LDAP library. See [TESTING.md](TESTING.md#11-troubleshooting) for the `libldap-2.5.so.0` message on newer distributions.

## Which users are checked

By default every test checks **enabled normal user accounts** (`objectCategory=person`, `objectClass=user`, `userAccountControl` NORMAL_ACCOUNT), so computers, contacts, trust accounts and managed service accounts are never checked. MP.CLT.ADUA.1011 also checks disabled accounts.

These accounts are always left out, because they never have HR attributes: critical system objects (`Administrator`, `Guest`, `krbtgt`), `krbtgt_*`, Microsoft Entra Connect accounts (`MSOL_*`, `AAD_*`, `Sync_*`), Exchange `HealthMailbox*` and `SM_*` accounts, `DefaultAccount` and `WDAGUtilityAccount`.

The directory is read **once per session**: the first test reads every user (in pages of 1000), and the others use that copy.

### Leaving users out

Users are left out at three levels, and the levels add up: a test's own list never replaces the others.

| Level | Set in `maester-config.json` | Applies to |
| --- | --- | --- |
| OUs | `GlobalSettings` → `"CLT.ADUA.ExcludedOUs"` (DNs; sub-OUs included) | Every test in this pack |
| Pack-wide | `GlobalSettings` → `"CLT.ADUA.ExcludedUsers"` and `"CLT.ADUA.ExcludedGroups"` | Every test in this pack |
| This test | `TestSettings` → `ExcludedUsers` and `ExcludedGroups` | Only that test |

Users can be given as `sAMAccountName`, `DOMAIN\sAMAccountName`, user principal name, distinguished name or `objectGUID`. Groups can be given as `sAMAccountName`, distinguished name or `objectGUID`; their nested members are left out too (through `LDAP_MATCHING_RULE_IN_CHAIN`), but not users whose *primary* group it is (such as Domain Users). A group that cannot be found is named in the result, so a typo never silently leaves nobody out. Each result ends with a summary:

> Left out 14 users:
>
> - 6 in an excluded OU (CLT.ADUA.ExcludedOUs)
> - 5 by the pack-wide exclusions (CLT.ADUA.ExcludedUsers and CLT.ADUA.ExcludedGroups)
> - 3 by this test's ExcludedUsers and ExcludedGroups

```json
{
  "GlobalSettings": {
    "CLT.ADUA.SearchBase": ["OU=Staff,DC=contoso,DC=com"],
    "CLT.ADUA.ExcludedOUs": ["OU=Service Accounts,OU=Staff,DC=contoso,DC=com"],
    "CLT.ADUA.ExcludedUsers": ["svc-scanner", "CONTOSO\\svc-backup"],
    "CLT.ADUA.ExcludedGroups": ["Shared Mailbox Accounts"]
  },
  "TestSettings": [
    { "Id": "MP.CLT.ADUA.1004", "Parameters": { "ExcludedGroups": ["Contractors"] } }
  ]
}
```

### Pack settings

| `GlobalSettings` key | Default | What it does |
| --- | --- | --- |
| `CLT.ADUA.SearchBase` | the connection's search base | One or more OU DNs to read users from. |
| `CLT.ADUA.LdapFilter` | none | An extra LDAP filter ANDed onto the user query, such as `(mail=*)` for mail-enabled users only, or `(employeeType=Employee)`. |
| `CLT.ADUA.ExcludedOUs` | none | OUs whose users are left out of every test. |
| `CLT.ADUA.ExcludedUsers` | none | Users to leave out of every test. |
| `CLT.ADUA.ExcludedGroups` | none | Groups whose members are left out of every test. |
| `CLT.ADUA.AllowedValues` | none (falls back to `CLT.UA.AllowedValues`) | Approved values for MP.CLT.ADUA.1014–1023 and 1025: lists by attribute (including `extensionAttribute1`–`15` and `msDS-cloudExtensionAttribute1`–`20`), and office `locations`. |
| `CLT.ADUA.RequiredExtensionAttributes` | none | Extension attributes every user must have, as names or short forms (`"extensionAttribute1"` or `"1"`; `"msDS-cloudExtensionAttribute4"` or `"cloud4"`). Once set, MP.CLT.ADUA.1024 checks only these. |
| `CLT.ADUA.ExtensionAttributeNames` | none | What each extension attribute holds, shown in titles and results, such as `{ "cloud1": "Cost centre" }`. |
| `CLT.ADUA.AllowedValuesFile` | none (falls back to `CLT.UA.AllowedValuesFile`) | Path to a JSON file with more approved values, in the same shape or the 2.x `validation.json` shape. A relative path starts from the folder the run starts in. |

## Approved values

The approved-value tests (MP.CLT.ADUA.1015–1023, and MP.CLT.ADUA.1014 for countries) compare each user's value with a list you approve. Blank values are not checked by these tests; the presence tests check those.

**One list for both packs.** Keys can be LDAP names (`department`, `title`, `company`, `streetAddress`, `l`, `st`, `postalCode`, `co`, `c`, `telephoneNumber`, `physicalDeliveryOfficeName`) or the Microsoft Graph names the User Attributes pack uses (`jobTitle`, `companyName`, `city`, `state`, `country`, `businessPhones`, `officeLocation`, and `zipCode` for postal code). When neither `CLT.ADUA.AllowedValues` nor `CLT.ADUA.AllowedValuesFile` is set, this pack reads `CLT.UA.AllowedValues` and `CLT.UA.AllowedValuesFile`, so a configuration you already have for `CLT.UA` works here unchanged.

| Where | Good for |
| --- | --- |
| **`CLT.ADUA.AllowedValues` in `GlobalSettings`** (or `CLT.UA.AllowedValues`) | One place for every list and your office locations. |
| **`CLT.ADUA.AllowedValuesFile`** | Keeping the lists in their own file, for example one HR exports, or a 2.x `validation.json`. Its values add to `CLT.ADUA.AllowedValues`. |
| **A test's own `AllowedValues`** (or `AllowedCountries` on 1014) | A one-off list for one test. It replaces the shared values for that test only. |

```json
{
  "GlobalSettings": {
    "CLT.ADUA.AllowedValues": {
      "department": ["IT", "Finance", "Human Resources"],
      "title": ["Chief Executive Officer", "IT Manager", "Accountant"],
      "co": ["United States", "Canada"],
      "locations": [
        { "name": "Seattle HQ", "streetAddress": "1 Main Street", "l": "Redmond", "st": "WA",
          "postalCode": "98052", "co": "United States", "company": "Contoso Ltd",
          "telephoneNumber": "+14255550100" }
      ]
    }
  }
}
```

- **Locations count as lists too.** The values in `locations` are approved values of each attribute, so your offices' cities and postal codes don't need listing twice. MP.CLT.ADUA.1023 also checks that a user's fields belong to the **same** location, and shows the closest location and the fields that differ.
- **Letter case matters** by default (`Finance` is not `finance`). Set a test's `CaseSensitive` to `false` to ignore case.
- **First run:** with no approved values set, each test reports **Investigate** with a table of the values in use and how many users have each. Copy the correct ones into the config, then run again to see what to fix.

### Test parameters

Every test takes these parameters:

| Parameter | What it does |
| --- | --- |
| `ExcludedUsers` | More users to leave out of this test, on top of the levels above. |
| `ExcludedGroups` | More groups whose members are left out of this test. |
| `IncludeDisabled` | Also check disabled accounts. |
| `MaxRows` | Most users or rows a result lists (default `100`). The result says how many were left out; set `0` to list them all. |

Test-specific parameters:

| Test | Parameter | Default |
| --- | --- | --- |
| MP.CLT.ADUA.1001 | `ExcludedJobTitles` | `CEO`, `Chief Executive Officer` |
| MP.CLT.ADUA.1006 | `Fields` | `streetAddress`, `l`, `st`, `postalCode`, `co` (can add `c`, `physicalDeliveryOfficeName`) |
| MP.CLT.ADUA.1011 | `IgnoreLeadingZeros` | `false` |
| MP.CLT.ADUA.1012 | `Attributes`, `PhonePattern`, `AllowExtension`, `AllowSpaces` | `telephoneNumber`, `mobile`; `^\+[1-9]\d{6,14}$`; `true`; `false` |
| MP.CLT.ADUA.1013 | `Attributes` | name, job and location attributes (can add `extensionAttribute1`–`15` and `msDS-cloudExtensionAttribute1`–`20`) |
| MP.CLT.ADUA.1014 | `Attribute`, `AllowedCountries`, `CaseSensitive` | `co`; none (uses the approved values, else lists the values found); `true` |
| MP.CLT.ADUA.1015–1022 | `AllowedValues`, `CaseSensitive` | none (uses the approved values); `true` |
| MP.CLT.ADUA.1025 (per row) | `AllowedValues`, `CaseSensitive` | none (uses `CLT.ADUA.AllowedValues` → the attribute's name); `true` |
| MP.CLT.ADUA.1023 | `Fields`, `CaseSensitive` | `streetAddress`, `l`, `st`, `postalCode`, `co`, `company` (can add `c`, `telephoneNumber`, `physicalDeliveryOfficeName`); `true` |

## Extension attributes

Active Directory has two sets of free-form extension attributes. Which one your forest has depends on its schema, and the pack covers both:

| Set | Comes with | Synced to Microsoft Entra ID |
| --- | --- | --- |
| `extensionAttribute1`–`15` | The **Exchange schema** (Exchange calls them CustomAttribute1–15) | By default, as `onPremisesExtensionAttributes` |
| `msDS-cloudExtensionAttribute1`–`20` | The **Windows Server 2012 schema** and later; no Exchange needed | Only when selected as [directory extensions](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-sync-feature-directory-extensions) in Microsoft Entra Connect |

A forest that never had Exchange has no `extensionAttribute*` at all. `Set-ADUser -Replace @{ extensionAttribute1 = '...' }` then fails with *The specified directory service attribute or value does not exist*, and the cloud set is the one to use. To check which set you have:

```powershell
$schema = (Get-ADRootDSE).schemaNamingContext
Get-ADObject -SearchBase $schema -Filter "lDAPDisplayName -eq 'extensionAttribute1'"            # a result = Exchange schema present
Get-ADObject -SearchBase $schema -Filter "lDAPDisplayName -eq 'msDS-cloudExtensionAttribute1'"  # a result = 2012 schema or later
```

Only your organisation knows what the attributes hold, so the two tests start by showing you what is in use:

| | First run (nothing configured) | Once configured |
| --- | --- | --- |
| **MP.CLT.ADUA.1024** filled in | A row for each attribute at least one user has, reporting **Investigate** with how many users have it (or **Passed** if all do). | Rows only for `CLT.ADUA.RequiredExtensionAttributes`, each failing with the users that have no value. |
| **MP.CLT.ADUA.1025** approved values | A row for each attribute in use, reporting **Investigate** with the values found. | Each row checks the values against that attribute's list in `CLT.ADUA.AllowedValues`. |

The pack reads the forest's schema when it first needs it. If the config names an attribute the schema doesn't have, such as `extensionAttribute1` in a forest without Exchange, that row reports **Investigate** and says why, instead of failing every user.

In the settings, attributes can be written in full or short: `1`–`15` or `ea1` for the Exchange set, `cloud1`–`cloud20` or `cea1` for the cloud set. Quote the cloud names in PowerShell hashtables, because of the hyphen.

```json
{
  "GlobalSettings": {
    "CLT.ADUA.RequiredExtensionAttributes": ["msDS-cloudExtensionAttribute1", "cloud2"],
    "CLT.ADUA.ExtensionAttributeNames": { "cloud1": "Cost centre", "cloud2": "Employee type" },
    "CLT.ADUA.AllowedValues": {
      "msDS-cloudExtensionAttribute2": ["Employee", "Contractor", "Intern"]
    }
  },
  "TestSettings": [
    { "Id": "MP.CLT.ADUA.1025.msDS-cloudExtensionAttribute1", "Enabled": false, "Reason": "Cost centre codes are validated in HR" },
    { "Id": "MP.CLT.ADUA.1025.msDS-cloudExtensionAttribute7", "Parameters": { "AllowedValues": ["HQ", "Remote"], "CaseSensitive": false } }
  ]
}
```

- Rows are turned off or configured by their own ID (`MP.CLT.ADUA.1025.msDS-cloudExtensionAttribute7`); a setting on `MP.CLT.ADUA.1025` applies to every row.
- An attribute that holds a unique value per user (a badge number) doesn't suit approved values: turn its 1025 row off.
- MP.CLT.ADUA.1013 (stray spaces) can check them too: add them to its `Attributes`.

## Permissions

The pack only reads. The account it binds as needs **read access to user and group objects** in the search bases: `title`, `department`, `company`, `employeeID`, `manager`, the address and phone attributes, `extensionAttribute1`–`15`, `msDS-cloudExtensionAttribute1`–`20`, the schema's attribute definitions (to see which extension attributes exist), `userAccountControl`, and group membership for `ExcludedGroups`. Authenticated Users can read all of these by default. It does not use Microsoft Graph and asks for no Graph scopes.

## How AD attributes map to the User Attributes pack

| This pack | AD attribute | Entra ID property | User Attributes pack |
| --- | --- | --- | --- |
| MP.CLT.ADUA.1001 | `manager` | manager | MP.CLT.UA.1002 |
| MP.CLT.ADUA.1002 | `title` | jobTitle | MP.CLT.UA.1003 |
| MP.CLT.ADUA.1003 | `department` | department | MP.CLT.UA.1004 |
| MP.CLT.ADUA.1004 | `employeeID` | employeeId | MP.CLT.UA.1005 |
| MP.CLT.ADUA.1005 | `company` | companyName | MP.CLT.UA.1007 |
| MP.CLT.ADUA.1006 | `streetAddress`, `l`, `st`, `postalCode`, `co` | streetAddress, city, state, postalCode, country | MP.CLT.UA.1008 |
| MP.CLT.ADUA.1007 | `telephoneNumber` | businessPhones | MP.CLT.UA.1014 |
| MP.CLT.ADUA.1008 | `mobile` | mobilePhone | MP.CLT.UA.1015 |
| MP.CLT.ADUA.1009 | `facsimileTelephoneNumber` | faxNumber | MP.CLT.UA.1016 |
| MP.CLT.ADUA.1010 | `physicalDeliveryOfficeName` | officeLocation | MP.CLT.UA.1017 |
| MP.CLT.ADUA.1011 | `employeeID` (unique) | employeeId (unique) | MP.CLT.UA.1010 |
| MP.CLT.ADUA.1012 | phone attributes | phone properties | MP.CLT.UA.1011 |
| MP.CLT.ADUA.1013 | text attributes | text properties | MP.CLT.UA.1012 |
| MP.CLT.ADUA.1014 | `co` or `c` | country | MP.CLT.UA.1013 |
| MP.CLT.ADUA.1015–1022 | approved values | approved values | MP.CLT.UA.1018–1025 |
| MP.CLT.ADUA.1023 | approved location | approved location | MP.CLT.UA.1026 |
| MP.CLT.ADUA.1024–1025 | `extensionAttribute1`–`15`; `msDS-cloudExtensionAttribute1`–`20` | onPremisesExtensionAttributes; directory extensions | none yet |

Not carried over, because Active Directory has no equivalent: usage location (MP.CLT.UA.1001), employee hire date (1006) and guest sponsors (1009).

## Developing

See **[TESTING.md](TESTING.md)** for the full guide: getting a pack-enabled Maester, offline checks, connecting from each platform, running tests while you develop, installing locally for a full report, and seeding a test OU. The short version:

```powershell
Test-MtPack .                                   # the checks Install-MtPack runs, without installing
Connect-Maester -Service CLT.ADUA.Ldap
Invoke-MtTest -Path .                           # run the pack from this folder
Invoke-MtTest -Path ./tests/Test.MP.CLT.ADUA.1012.ps1 -Parameter @{ AllowSpaces = $true }
```

## Versions and releases

`Install-MtPack DevClate/maester-pack-adua` installs the newest GitHub release, or the `main` branch while the repository has no release. The repository includes the demo pack's workflows: `check-pack.yml` checks every push and pull request, and `bump-version.yml` and `release.yml` publish a release for each merged pull request once the repository variable `PACK_RELEASES` is `true`. Until then, raise `Version` in `maester-pack.json` by hand. Every change is written under `## Unreleased` in [CHANGELOG.md](CHANGELOG.md). Report security problems as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
