# Testing and running the AD User Attributes pack

How to check, run and develop `devclate.ad-user-attributes` (code `CLT.ADUA`) on Windows, macOS or Linux.

## Contents

1. [What you need](#1-what-you-need)
2. [Install Maester with pack support](#2-install-maester-with-pack-support)
3. [Put the pack in your own repository](#3-put-the-pack-in-your-own-repository)
4. [Check the pack without a domain](#4-check-the-pack-without-a-domain)
5. [Connect to Active Directory](#5-connect-to-active-directory)
6. [Run tests while you develop](#6-run-tests-while-you-develop)
7. [Run it the way users will (install and report)](#7-run-it-the-way-users-will-install-and-report)
8. [Run it with the User Attributes pack](#8-run-it-with-the-user-attributes-pack)
9. [Optional: seed a test OU with known problems](#9-optional-seed-a-test-ou-with-known-problems)
10. [Publishing](#10-publishing)
11. [Troubleshooting](#11-troubleshooting)

Folder names used below:

```powershell
$PackDir = 'C:\Code\maester-pack-adua'    # this pack
$DevDir  = 'C:\Code\maester-pack-dev'     # Invoke-PackLogicTests.ps1, outside the pack
$Run     = 'C:\Code\maester-run'          # where you run Maester and keep maester-config.json
```

## 1. What you need

| | Windows | macOS | Linux |
| --- | --- | --- | --- |
| PowerShell | 7.4 or later | 7.4 or later | 7.4 or later |
| LDAP library | built in | built in | OpenLDAP client (`libldap`), usually installed |
| Sign-in | domain-joined: nothing; otherwise `Credential` | `kinit`, or Basic over LDAPS | `kinit` (krb5-user), or Basic over LDAPS |
| Network | a DC on 636 (LDAPS) or 389 | same | same |

No ActiveDirectory (RSAT) module is needed to run the pack. The remediation steps in the test pages use `Set-ADUser` from RSAT, because that is where most admins fix values.

## 2. Install Maester with pack support

```powershell
Install-PSResource -Name Maester -Prerelease -TrustRepository -Scope CurrentUser
Import-Module Maester -MinimumVersion 3.0.0 -MaximumVersion 3.99.99 -Force
Get-Command Test-MtPack, Install-MtPack      # both must exist
```

If the Gallery preview does not have `Test-MtPack` yet, use a read-only copy of Maester's `main` branch, which has pack support:

```powershell
git clone --depth 1 https://github.com/maester365/maester C:\Code\maester-src
git -C C:\Code\maester-src remote set-url --push origin no-push
Import-Module C:\Code\maester-src\powershell\Maester.psd1 -Force
(Get-Module Maester).Path                    # must point into maester-src
```

## 3. Put the pack in your own repository

Extract `maester-pack-adua.zip` to `$PackDir`, then:

```powershell
Set-Location $PackDir
git init -b main
git add .
git commit -m 'AD User Attributes pack 0.1.0'
gh repo create DevClate/maester-pack-adua --public --source . --push
```

Keep the owner `DevClate`: the manifest's `Publisher` is `devclate`, and Maester refuses a pack whose publisher is not the repository owner. Keep `Invoke-PackLogicTests.ps1` in `$DevDir`, **outside** the pack: it builds code at run time, which would raise the pack's risk from Low to Medium.

## 4. Check the pack without a domain

```powershell
Set-Location $PackDir

# 1. Every check Install-MtPack runs, without installing
Test-MtPack .
#    Expect: IsValid True, Risk Low, no Errors or Findings, 25 TestIds

# 2. Each test's metadata
Get-MtTest -Path .\tests | Sort-Object Id | Format-Table Id, IsValid, Severity, Errors -AutoSize
#    Expect: 25 rows, all IsValid True

# 3. Each test's logic, against made-up users, with LDAP replaced by fixtures
pwsh -NoProfile -File $DevDir\Invoke-PackLogicTests.ps1 -PackPath $PackDir
#    Expect: "132 ok, 0 failure(s)"
```

The logic tests cover pass, fail, Investigate and Skipped results, every exclusion level, disabled accounts, system accounts, multi-valued attributes, the approved-value fallback to `CLT.UA.AllowedValues`, and each test-specific parameter. When you add a test, add `Assert-Case` lines for it to that script.

## 5. Connect to Active Directory

**Domain-joined Windows**, as yourself:

```powershell
Connect-Maester -Service CLT.ADUA.Ldap
```

**Windows, another domain or a different account:**

```powershell
Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{ Server = 'dc01.fabrikam.com'; Credential = (Get-Credential FABRIKAM\maester-read) }
```

**macOS or Linux with Kerberos:**

```bash
kinit maester-read@CONTOSO.COM
pwsh
```

```powershell
Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{ Server = 'dc01.contoso.com'; AuthType = 'Kerberos' }
```

**macOS or Linux with a simple bind** (LDAPS required). Trust the domain CA first, in `/etc/ldap/ldap.conf` (`TLS_CACERT /path/to/contoso-ca.pem`) or with `LDAPTLS_CACERT` exported in the shell **before** `pwsh` starts:

```powershell
Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{ Server = 'dc01.contoso.com'; AuthType = 'Basic'; TlsMode = 'Ldaps'; Credential = (Get-Credential 'maester-read@contoso.com') }
```

Check the connection:

```powershell
Get-MtConnectionState -Service CLT.ADUA.Ldap -Detailed | Format-List Service, Tenant, Account
```

To keep the settings, put them in `maester-config.json` (never the password):

```json
{ "Connections": { "CLT.ADUA.Ldap": { "Server": "dc01.contoso.com", "TlsMode": "Ldaps", "SearchBase": "OU=Staff,DC=contoso,DC=com" } } }
```

## 6. Run tests while you develop

```powershell
Set-Location $PackDir

# The whole pack
Invoke-MtTest -Path .

# One test, and the Markdown it writes to the report
$r = Invoke-MtTest -Path .\tests\Test.MP.CLT.ADUA.1001.ps1
$r.ResultDetail.TestResult

# One test with parameters (only when exactly one test is selected)
Invoke-MtTest -Path .\tests\Test.MP.CLT.ADUA.1012.ps1 -Parameter @{ AllowSpaces = $true; Attributes = 'telephoneNumber', 'otherTelephone' }
Invoke-MtTest -Path .\tests\Test.MP.CLT.ADUA.1002.ps1 -Parameter @{ MaxRows = 0 }
```

The tests share one read of the directory per session. After changing users in AD, disconnect and connect again to read them afresh.

## 7. Run it the way users will (install and report)

```powershell
Set-Location $Run
Install-MtPack $PackDir                        # type CLT.ADUA to approve
Get-MtPack                                     # Status Ready, Risk Low
Connect-Maester -Service CLT.ADUA.Ldap
Invoke-Maester -Pack CLT.ADUA -SkipBuiltIn     # opens the HTML report
```

`Install-MtPack DevClate/maester-pack-adua` installs from GitHub instead, once the repository exists.

## 8. Run it with the User Attributes pack

Both packs can be installed together (`CLT.ADUA` and `CLT.UA` do not clash), and they read the same approved values when you keep them in `CLT.UA.AllowedValues`:

```powershell
Install-MtPack DevClate/maester-pack-ua
Connect-Maester                                  # Graph, for CLT.UA
Connect-Maester -Service CLT.ADUA.Ldap           # AD, for CLT.ADUA
Invoke-Maester -Pack CLT.ADUA, CLT.UA -SkipBuiltIn
```

A value that fails in both is wrong at the source; one that fails only in Entra ID points to a sync rule or a cloud-only edit.

## 9. Optional: seed a test OU with known problems

In a **test domain**, with RSAT on Windows, create users that each break one rule, then point the pack at that OU:

```powershell
Import-Module ActiveDirectory
$ou = New-ADOrganizationalUnit -Name 'MaesterADUA' -Path (Get-ADDomain).DistinguishedName -PassThru -ProtectedFromAccidentalDeletion $false
$common = @{ Path = $ou.DistinguishedName; Enabled = $true; AccountPassword = (Read-Host -AsSecureString 'Password for the test users') }
New-ADUser @common -Name 'ADUA Good'       -SamAccountName adua.good   -Title 'Accountant' -Department 'Finance' -Company 'Contoso Ltd' -EmployeeID 'E1' -OfficePhone '+14255550100' -MobilePhone '+14255550101' -StreetAddress '1 Main Street' -City 'Redmond' -State 'WA' -PostalCode '98052' -OtherAttributes @{ co = 'United States'; c = 'US'; countryCode = 840 }
New-ADUser @common -Name 'ADUA NoTitle'    -SamAccountName adua.notitle -Department 'Finance' -EmployeeID 'E2'
New-ADUser @common -Name 'ADUA DupId'      -SamAccountName adua.dupid  -Title 'Accountant' -EmployeeID 'E1'
New-ADUser @common -Name 'ADUA BadPhone'   -SamAccountName adua.phone  -Title 'Accountant' -OfficePhone '(425) 555-0100'
New-ADUser @common -Name 'ADUA Spaces'     -SamAccountName adua.spaces -Title 'Accountant ' -Department 'Finance'
New-ADUser @common -Name 'ADUA Country'    -SamAccountName adua.usa    -Title 'Accountant' -OtherAttributes @{ co = 'USA'; 'msDS-cloudExtensionAttribute2' = 'Employee' }
New-ADUser @common -Name 'ADUA ExtAttr'    -SamAccountName adua.ea     -Title 'Accountant' -OtherAttributes @{ 'msDS-cloudExtensionAttribute2' = 'contractor' }
```

```powershell
Connect-Maester -Service CLT.ADUA.Ldap -ServiceSetting @{ SearchBase = $ou.DistinguishedName }
Invoke-Maester -Pack CLT.ADUA -SkipBuiltIn
```

Expect 1002 to list `adua.notitle`, 1011 to list `E1` twice, 1012 the `(425)` number, 1013 the trailing space, 1014 to report Investigate for `United States` and `USA`, and 1024 and 1025 to show one `msDS-cloudExtensionAttribute2` row each (Investigate), listing `Employee` and `contractor`. (Use `extensionAttribute2` instead if the test forest has the Exchange schema and you want to test that set.) Clean up with `Get-ADUser -SearchBase $ou.DistinguishedName -Filter * | Remove-ADUser -Confirm:$false; Remove-ADOrganizationalUnit $ou -Confirm:$false`.

## 10. Publishing

1. Decide the release model once: track `main` (raise `Version` by hand), or turn on release-per-PR with `gh variable set PACK_RELEASES --body true -R DevClate/maester-pack-adua`, apply `.github/rulesets/main.json`, and create the labels `release:major`, `release:minor`, `release:patch` and `release:none`.
2. Make releases immutable in the repository settings.
3. After the first release, publish once at [packs.maester.cloud/publish](https://packs.maester.cloud/publish) to register the pack's `Guid` and `Code` (`CLT.ADUA`) to DevClate. Later releases are picked up automatically.

New tests go after the highest ID (MP.CLT.ADUA.1026 next). Never reuse or renumber an ID, and never change the `Guid` or `Code`.

## 11. Troubleshooting

| Message | Cause and fix |
| --- | --- |
| `Unable to load shared library 'libldap-2.5.so.0'` (Linux) | .NET in PowerShell 7.5 looks for OpenLDAP 2.5, while newer distributions such as Ubuntu 24.04 ship 2.6 as `libldap.so.2`. Link it: `sudo ln -s /lib/x86_64-linux-gnu/libldap.so.2 /lib/x86_64-linux-gnu/libldap-2.5.so.0` (adjust the folder for your distribution and architecture). |
| `The LDAP server is unavailable` with LDAPS or StartTLS (macOS or Linux) | Usually the certificate: the LDAP library does not trust the DC's certificate, or the server name doesn't match it. Connect with the name in the certificate (often the DC's FQDN, not its IP address), and trust the CA in `/etc/ldap/ldap.conf` (`TLS_CACERT`). On some distributions .NET still rejects a valid chain; in a **test** domain only, start PowerShell with `LDAPTLS_REQCERT=allow` to confirm that this is the cause. |
| `LDAPTLS_CACERT` has no effect | It must be set before `pwsh` starts. A value set inside PowerShell (`$env:LDAPTLS_CACERT = ...`) does not reach the native LDAP library on macOS or Linux. |
| `The supplied credential is invalid` | Wrong user name or password. For Basic, use the UPN (`user@contoso.com`) or DOMAIN\name. |
| `AuthType Basic sends the password in clear text without TLS` | Basic needs `TlsMode` `Ldaps`, `StartTls` or `Auto`. |
| Negotiate fails on macOS or Linux | Get a ticket first (`kinit`, check with `klist`), and connect with the DC's FQDN so Kerberos can find its service principal. |
| `SkipCertificateCheck works on Windows only` | On macOS and Linux, trust the CA instead (above). |
| Tests show as not run | The connector is opt-in: run `Connect-Maester -Service CLT.ADUA.Ldap` first. |
| A result says an excluded group was not found | The name in `ExcludedGroups` matched no group. Use the group's `sAMAccountName` (pre-Windows 2000 name) or its full DN. |
| MP.CLT.ADUA.1024 or 1025 shows `NoInstances` | No user has a value in any extension attribute, and none are listed in `CLT.ADUA.RequiredExtensionAttributes` or `CLT.ADUA.AllowedValues`, so there is nothing to check. |
| An extension attribute row says it *does not exist in this forest's Active Directory schema* | The config names an attribute the schema doesn't have. `extensionAttribute1`–`15` need the Exchange schema; `msDS-cloudExtensionAttribute1`–`20` need the Windows Server 2012 schema or later. Check with `Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -Filter "lDAPDisplayName -eq 'extensionAttribute1'"` (no result means it doesn't exist), then use the other set. |
| `Set-ADUser ... extensionAttribute1 ...` fails with *The specified directory service attribute or value does not exist* | Same cause: the forest has no Exchange schema. Use `msDS-cloudExtensionAttribute1`–`20`, quoted: `Set-ADUser <user> -Replace @{ 'msDS-cloudExtensionAttribute1' = 'CC-4100' }`. |
| Changes in AD do not show | The directory is read once per session. `Disconnect-Maester -Service CLT.ADUA.Ldap`, connect again, and rerun. |
