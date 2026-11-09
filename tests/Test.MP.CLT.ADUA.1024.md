Checks that every enabled Active Directory user has a value in each extension attribute that your organisation requires. Each attribute gets its own result row, such as `MP.CLT.ADUA.1024.extensionAttribute1` or `MP.CLT.ADUA.1024.msDS-cloudExtensionAttribute4`.

Active Directory has two sets of free-form extension attributes, and which one a forest has depends on its schema:

| Set | Comes with | Notes |
| --- | --- | --- |
| `extensionAttribute1`–`15` | The Exchange schema (Exchange calls them CustomAttribute1–15) | Synced to Microsoft Entra ID by Microsoft Entra Connect as `onPremisesExtensionAttributes`. A forest that never had Exchange doesn't have them, and `Set-ADUser` fails with *The specified directory service attribute or value does not exist*. |
| `msDS-cloudExtensionAttribute1`–`20` | The Windows Server 2012 schema and later; no Exchange needed | Synced to Microsoft Entra ID only when selected as directory extensions in Microsoft Entra Connect. |

Organisations use them for whatever they need: a cost centre, an employee type, a building code. Dynamic groups, device and app filters, and provisioning to other systems often depend on them, and a user without the value silently falls outside every rule built on it.

Because only your organisation knows which ones every user must have, this test needs you to say so:

- **With `CLT.ADUA.RequiredExtensionAttributes` set**, only the listed attributes are checked, and each fails with the users that have no value. If a listed attribute doesn't exist in this forest's schema, its row reports **Investigate** and says why, instead of failing every user.
- **Without it**, each extension attribute that at least one user has a value in is listed for review (**Investigate**), with how many users have it. Unused attributes are left out, so a directory that uses none of them gets no rows.

Give each attribute a name in `CLT.ADUA.ExtensionAttributeNames` to see it in titles and results, for example *Cost centre (msDS-cloudExtensionAttribute1)*.

#### Remediation action

1. Check which set your forest has (a result means the attribute exists):

   ```powershell
   $schema = (Get-ADRootDSE).schemaNamingContext
   Get-ADObject -SearchBase $schema -Filter "lDAPDisplayName -eq 'extensionAttribute1'"
   Get-ADObject -SearchBase $schema -Filter "lDAPDisplayName -eq 'msDS-cloudExtensionAttribute1'"
   ```

2. Decide which attributes every user must have, and what each one holds. List them in `maester-config.json`. Names can be written in full or short: `1`–`15` or `ea1` for the Exchange set, `cloud1`–`cloud20` or `cea1` for the cloud set.

   ```json
   { "GlobalSettings": {
       "CLT.ADUA.RequiredExtensionAttributes": ["msDS-cloudExtensionAttribute1", "cloud2"],
       "CLT.ADUA.ExtensionAttributeNames": { "cloud1": "Cost centre", "cloud2": "Employee type" }
   } }
   ```

3. Fill in the users listed below. In **Active Directory Users and Computers**, turn on **View** > **Advanced Features**, open the user, and use the **Attribute Editor** tab. Or use PowerShell with the ActiveDirectory module (RSAT). Quote the cloud names, because of the hyphen:

   ```powershell
   $user = 'bkowalski'   # the user's sAMAccountName
   Set-ADUser -Identity $user -Replace @{ 'msDS-cloudExtensionAttribute1' = 'CC-4100' }
   Set-ADUser -Identity $user -Replace @{ extensionAttribute1 = 'CC-4100' }   # Exchange schema only
   ```

4. If the value comes from an HR system or a provisioning tool, fix it there, or the next import overwrites your change.
5. To stop checking one attribute, turn its row off: `{ "Id": "MP.CLT.ADUA.1024.extensionAttribute5", "Enabled": false, "Reason": "Only used for some users" }` in `TestSettings`. To leave users out, use `ExcludedUsers` or `ExcludedGroups` on the family or on one row.

#### Related links

* [Custom attributes in Exchange Server](https://learn.microsoft.com/exchange/recipients/mailbox-custom-attributes)
* [Class msDS-CloudExtensions (msDS-cloudExtensionAttribute1–20)](https://learn.microsoft.com/openspecs/windows_protocols/ms-adsc/484d58a6-50af-487c-8ffb-8c1f6978fcd7)
* [onPremisesExtensionAttributes in Microsoft Graph](https://learn.microsoft.com/graph/api/resources/onpremisesextensionattributes)
* [Microsoft Entra Connect Sync: Directory extensions](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-sync-feature-directory-extensions)
* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)

<!--- Results --->
%TestResult%
