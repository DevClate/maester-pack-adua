Checks that every company name (`company`) set on enabled Active Directory users is one of your approved values. Blank values are not checked here (the presence tests check those).

Company name separates legal entities and contractors in groups and reports. A value typed slightly differently puts the user outside every group, rule and report built on the approved spelling.

The approved values come from **company** in `CLT.ADUA.AllowedValues` under `GlobalSettings` in `maester-config.json`, from the file named in `CLT.ADUA.AllowedValuesFile`, or from this test's own `AllowedValues`, which replaces the shared list for this test only. When neither `CLT.ADUA` setting is set, the User Attributes pack's `CLT.UA.AllowedValues` is used, so one list can serve both packs. Until any are set, this test lists the values it finds and asks you to review them (**Investigate**) instead of failing.

#### Remediation action

1. Review the values listed below and decide which are correct.
2. Add the approved values to `maester-config.json`:

   ```json
   { "GlobalSettings": { "CLT.ADUA.AllowedValues": { "company": ["Contoso Ltd", "Contoso Canada"] } } }
   ```

3. Change the users with a value that is not approved, in **Active Directory Users and Computers** (the user > **Organization** > **Company**) or with PowerShell: `Set-ADUser -Identity <sAMAccountName> -Company 'Contoso Ltd'`.
4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. If a value is correct but not listed, add it to the approved values rather than changing the user.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Company attribute (Active Directory schema)](https://learn.microsoft.com/windows/win32/adschema/a-company)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
