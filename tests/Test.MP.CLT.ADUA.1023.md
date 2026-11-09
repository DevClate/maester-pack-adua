Checks that each enabled Active Directory user's address matches one of your approved office locations. By default it compares `streetAddress`, `l` (city), `st` (state), `postalCode`, `co` (country) and `company`; use `Fields` to add `telephoneNumber` or `physicalDeliveryOfficeName`, or to leave fields out. For each user that matches no location, the result shows the closest location and the fields that differ.

Checking each field on its own (MP.CLT.ADUA.1018–1021) does not catch a valid street with the wrong city. Matching the whole address to a real office does, and it finds users still showing an office that has closed.

#### Remediation action

1. List your offices under **locations** in `CLT.ADUA.AllowedValues` in `maester-config.json`. Each location can use LDAP names (`l`, `st`, `co`, `company`, `telephoneNumber`) or the Microsoft Graph names the User Attributes pack uses (`city`, `state`, `country`, `companyName`, `businessPhones`):

   ```json
   { "GlobalSettings": { "CLT.ADUA.AllowedValues": { "locations": [
     { "name": "Seattle HQ", "streetAddress": "1 Main Street", "l": "Redmond", "st": "WA", "postalCode": "98052", "co": "United States", "company": "Contoso Ltd" }
   ] } } }
   ```

2. Fix each user listed below on the **Address** and **Organization** tabs in **Active Directory Users and Computers**, or with `Set-ADUser`.
3. If a location is missing from the list, add it rather than changing the users.

#### Related links

* [Set-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/set-aduser)
* [Attributes synchronized to Microsoft Entra ID by Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/reference-connect-sync-attributes-synchronized)

<!--- Results --->
%TestResult%
