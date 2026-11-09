Checks that every value set in each extension attribute of enabled Active Directory users is one of your approved values. It covers `extensionAttribute1`–`15` (Exchange schema) and `msDS-cloudExtensionAttribute1`–`20` (Windows Server 2012 schema and later). Each attribute gets its own result row, such as `MP.CLT.ADUA.1025.msDS-cloudExtensionAttribute2`. Blank values are not checked here (MP.CLT.ADUA.1024 checks those).

Extension attributes are free text, so the same meaning gets typed several ways: `Contractor`, `contractor`, `CONTR`. Dynamic groups, device and app filters and provisioning rules in Microsoft Entra ID match the exact value, so a user with a variant falls outside them.

A row is checked for every extension attribute that is in use, listed in `CLT.ADUA.RequiredExtensionAttributes`, or has approved values. The approved values come from the attribute's name (such as **msDS-cloudExtensionAttribute2**) in `CLT.ADUA.AllowedValues` under `GlobalSettings` (or `CLT.UA.AllowedValues`, which the User Attributes pack shares), or from `AllowedValues` set on one row in `TestSettings`, which replaces the shared list for that attribute. Until any are set, a row lists the values it finds and asks you to review them (**Investigate**) instead of failing. An attribute named in the config that this forest's schema doesn't have also reports **Investigate**, and says why.

#### Remediation action

1. Review the values listed below and decide which are correct.
2. Add the approved values to `maester-config.json`, by attribute:

   ```json
   { "GlobalSettings": { "CLT.ADUA.AllowedValues": {
       "msDS-cloudExtensionAttribute2": ["Employee", "Contractor", "Intern"],
       "extensionAttribute7": ["HQ", "Remote"]
   } } }
   ```

   Or for one attribute only, in `TestSettings`: `{ "Id": "MP.CLT.ADUA.1025.msDS-cloudExtensionAttribute2", "Parameters": { "AllowedValues": ["Employee", "Contractor"] } }`.
3. Change the users with a value that is not approved: in **Active Directory Users and Computers** (**View** > **Advanced Features**, then the user's **Attribute Editor** tab), or with PowerShell: `Set-ADUser -Identity <sAMAccountName> -Replace @{ 'msDS-cloudExtensionAttribute2' = 'Contractor' }`.
4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. If an attribute holds a value that is unique per user (a badge number, a cost-centre code from a long list), approved values don't fit: turn its row off, such as `{ "Id": "MP.CLT.ADUA.1025.extensionAttribute9", "Enabled": false, "Reason": "Unique per user" }`.

#### Related links

* [Custom attributes in Exchange Server](https://learn.microsoft.com/exchange/recipients/mailbox-custom-attributes)
* [Class msDS-CloudExtensions (msDS-cloudExtensionAttribute1–20)](https://learn.microsoft.com/openspecs/windows_protocols/ms-adsc/484d58a6-50af-487c-8ffb-8c1f6978fcd7)
* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)

<!--- Results --->
%TestResult%
