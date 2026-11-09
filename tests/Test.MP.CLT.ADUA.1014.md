Checks that enabled Active Directory users use one approved spelling for each country. It checks `co` (the country name that Active Directory Users and Computers shows) by default; set `Attribute` to `c` to check the two-letter code instead.

`co` is free text when it is set with PowerShell or an HR import, so `United States`, `USA` and `US` all appear. Microsoft Entra Connect syncs `co` as country, where dynamic groups and reports then treat them as three countries.

Without approved countries (this test's `AllowedCountries`, or **co** in `CLT.ADUA.AllowedValues`), one spelling passes and several report **Investigate** with the spellings in use.

#### Remediation action

1. Decide on one spelling per country, and list them in `maester-config.json`: `{ "GlobalSettings": { "CLT.ADUA.AllowedValues": { "co": ["United States", "Canada"] } } }`.
2. Fix each user listed below in **Active Directory Users and Computers** (**Address** tab > **Country/region**), which sets `c`, `co` and `countryCode` together, or with PowerShell: `Set-ADUser -Identity <sAMAccountName> -Replace @{ c = 'US'; co = 'United States'; countryCode = 840 }`.
3. If an HR import writes the country, fix the mapping there so it writes the approved spelling.

#### Related links

* [Text-Country attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-co)
* [Country-Name attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-c)
* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)

<!--- Results --->
%TestResult%
