# Changelog

## Unreleased

## 0.3.2

- Added a banner (`assets/banner.png`, 1200 × 630) for the pack's page on packs.maester.cloud and the README, matching the User Attributes pack's.

## 0.3.1

- Fixed: MP.CLT.ADUA.1011 joined the accounts sharing an employee ID with `<br>`, which the Maester report shows as text, because it does not render raw HTML in results. It now lists one row per account (Employee ID, User, Account, OU), with accounts that share an ID next to each other, and adds a **Stored as** column when `IgnoreLeadingZeros` is on. `MaxRows` now counts accounts.

## 0.3.0

- MP.CLT.ADUA.1024 and 1025 now also cover **`msDS-cloudExtensionAttribute1`–`20`**, the extension attributes every forest at the Windows Server 2012 schema or later has, with or without Exchange. Their rows are `MP.CLT.ADUA.102x.msDS-cloudExtensionAttributeN`. In settings they can be written in full or as `cloud1`–`cloud20` (or `cea1`).
- The pack now reads the forest's schema to see which extension attributes exist. An attribute named in `CLT.ADUA.RequiredExtensionAttributes` or `CLT.ADUA.AllowedValues` that the schema doesn't have (such as `extensionAttribute1` without the Exchange schema) reports Investigate and says why, instead of failing every user. If the schema can't be read, every attribute is treated as present.
- MP.CLT.ADUA.1013 can check the cloud extension attributes for stray spaces.
- Approved-value tables fall back to the user's name when an account has no `sAMAccountName`.
- Fixed the schema check command in TESTING.md, which was missing `-SearchBase`.

## 0.2.0

- New: **extension attributes** (`extensionAttribute1`–`15`), as two families with one result row per attribute.
  - MP.CLT.ADUA.1024 checks that every user has the extension attributes listed in the new `CLT.ADUA.RequiredExtensionAttributes`. Until you list any, each attribute in use reports Investigate with how many users have it.
  - MP.CLT.ADUA.1025 checks extension attribute values against `extensionAttribute1`–`15` in `CLT.ADUA.AllowedValues` (or `AllowedValues` on one row). Until you set any, each attribute in use reports Investigate with the values found.
  - Attributes nobody uses get no row. New setting `CLT.ADUA.ExtensionAttributeNames` names what each attribute holds, for titles and results.
- MP.CLT.ADUA.1013 (stray spaces) can now check extension attributes too, through its `Attributes` parameter.
- Approved-value results now say "an" before a name that starts with a vowel.

## 0.1.0

- First version: the Active Directory counterpart of the User Attributes pack (`CLT.UA`), with 23 tests.
  - **Attributes are set** (MP.CLT.ADUA.1001–1010): manager, job title, department, employee ID, company, complete office address, business phone, mobile, fax and office location.
  - **Attributes are formatted correctly** (1011–1014): unique employee IDs, E.164 phone numbers, no stray or invisible spaces, one spelling per country.
  - **Attributes use approved values** (1015–1023): department, job title, company, street, city, state, postal code, business phone, and whole addresses matched to approved office locations.
- Its own read-only LDAP connector, `CLT.ADUA.Ldap`, built on `System.DirectoryServices.Protocols`, so it runs on Windows, macOS and Linux without RSAT. Negotiate, Kerberos or Basic authentication; LDAPS, StartTLS or Kerberos signing and sealing (`TlsMode` `Auto` tries them in that order); Basic without TLS is refused. Opt-in: its tests do not run until it is connected.
- The directory is read once per session in pages of 1000, and every test shares that read.
- Only normal user accounts are checked; built-in, Microsoft Entra Connect and Exchange system accounts are always left out. `CLT.ADUA.SearchBase`, `CLT.ADUA.LdapFilter` and `CLT.ADUA.ExcludedOUs` choose which users are read; `CLT.ADUA.ExcludedUsers` and `CLT.ADUA.ExcludedGroups` (nested members included) and each test's own `ExcludedUsers` and `ExcludedGroups` leave users out. An excluded group that is not found is named in the result.
- Approved values accept LDAP or Microsoft Graph attribute names, and fall back to `CLT.UA.AllowedValues` and `CLT.UA.AllowedValuesFile`, so one configuration serves both packs.
