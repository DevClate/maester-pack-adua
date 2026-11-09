Checks that name, job and location attributes of enabled Active Directory users have no leading or trailing spaces, repeated spaces, tabs, line breaks or invisible characters (such as a non-breaking or zero-width space). Use the `Attributes` parameter to choose which attributes are checked.

These characters usually arrive by copying from email, spreadsheets or HR exports. `Finance ` and `Finance` look identical but are different values, so dynamic groups, approved-value checks and address-book sorting treat the user as different from everyone else. In the results, each space is shown as ␣.

#### Remediation action

1. Retype each value listed below, or trim it with PowerShell: `Set-ADUser -Identity <sAMAccountName> -Department ((Get-ADUser <sAMAccountName> -Properties department).department.Trim())`.
2. For invisible characters, delete and retype the whole value rather than editing it, because the character cannot be seen.
3. If the values come from an HR export or a provisioning tool, trim them there too, or the next import brings them back.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Get-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/get-aduser)

<!--- Results --->
%TestResult%
