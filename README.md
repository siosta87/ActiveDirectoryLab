# Active Directory Lab

A reproducible Windows Server and Windows client lab for DNS, domain joining, users, groups, and basic policy validation.

**Status:** setup automation and runbook supplied. Windows execution and screenshots have not been captured. No completed deployment is claimed.

## Files

- [Setup-Lab.ps1](Setup-Lab.ps1): staged lab setup and verification
- [EVIDENCE.md](EVIDENCE.md): results worksheet and screenshot checklist

## Lab topology

| VM | Example address | Purpose |
| --- | --- | --- |
| DC01, Windows Server | 192.168.56.10/24 | AD DS and DNS |
| CLIENT01, Windows Pro/Enterprise | 192.168.56.20/24 | Domain-joined workstation |

Use a private virtual network in VirtualBox, Hyper-V, or VMware. These are example addresses, not detected devices. Choose a subnet that does not overlap an existing network. Keep the lab separate from your employer's network. Snapshot both VMs before promotion or domain join.

Suggested VM resources: DC01 with 2 vCPUs and 4 GB RAM; CLIENT01 with 2 vCPUs and 4 GB RAM. Check the requirements of your actual Windows images. Windows Home cannot join this AD domain.

## 1. Prepare both VMs

1. Install your licensed or evaluation Windows images.
2. Set hostnames to DC01 and CLIENT01, then restart.
3. Configure static IPv4 addresses on the same private virtual network. Use your actual adapter alias from `Get-NetAdapter`.
4. DC01 should use its own address for DNS. CLIENT01 should use DC01 for DNS. Do not substitute a public DNS resolver on the domain client.
5. Confirm the two VMs can communicate and their clocks agree.
6. Copy Setup-Lab.ps1 to each VM. Run it in Windows PowerShell as administrator.

## 2. Promote DC01

Preview first:

```powershell
.\Setup-Lab.ps1 -Stage Promote -WhatIf
```

Run in DC01:

```powershell
.\Setup-Lab.ps1 -Stage Promote
```

Enter a unique DSRM recovery password at the secure prompt. The command prompts before changes. It installs AD DS and DNS for `ad.example.test` with NetBIOS name `LAB`. Restart DC01 immediately after successful promotion; it is not ready as a domain controller until restarted.

If your environment uses different names, pass `-DomainName` and `-NetbiosName` consistently in every stage. This example is for a fresh disposable lab, not an existing domain.

## 3. Create the lab directory objects

After DC01 restarts, sign in as the lab domain administrator:

```powershell
.\Setup-Lab.ps1 -Stage Directory -WhatIf
.\Setup-Lab.ps1 -Stage Directory
```

The script creates LabUsers, a Lab-Helpdesk security group, and a fictional user alex.example. Enter a unique temporary password when prompted. The user must change it at first sign-in. The group itself grants no administrator privileges.

Rerunning this stage preserves existing objects and user passwords. It adds the user to the group if needed.

## 4. Join CLIENT01

Run inside CLIENT01 as local administrator. Substitute the actual adapter alias and DC address:

```powershell
Get-NetAdapter
.\Setup-Lab.ps1 -Stage JoinClient -DcAddress 192.168.56.10 -InterfaceAlias Ethernet -WhatIf
.\Setup-Lab.ps1 -Stage JoinClient -DcAddress 192.168.56.10 -InterfaceAlias Ethernet
```

Supply lab domain administrator credentials at the prompt. Restart CLIENT01, then sign in as `alex.example@ad.example.test`. Complete the required password change at the Windows sign-in screen.

## 5. Verify

Run Verify on DC01 and CLIENT01. The AD module queries run where the module is installed:

```powershell
.\Setup-Lab.ps1 -Stage Verify
```

On CLIENT01 after domain sign-in:

```powershell
whoami
whoami /groups
Test-ComputerSecureChannel -Verbose
gpresult /r
```

Expected: PartOfDomain is True, the domain is ad.example.test, DNS SRV records point to the lab DC, and alex.example belongs to Lab-Helpdesk. These are expected checks, not recorded test results.

## 6. Optional user-policy exercise

1. On DC01, open Group Policy Management.
2. Create a GPO named Lab-Desktop-Policy and link it to LabUsers.
3. Under User Configuration > Administrative Templates > Control Panel, enable **Prohibit access to Control Panel and PC settings**.
4. On CLIENT01, sign in as alex.example and run `gpupdate /force`.
5. Test the restriction and inspect `gpresult /r` for the applied GPO.
6. Disable that setting after collecting evidence, update policy, and verify access returns.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Domain not found | Client DNS points to DC01; SRV lookup works |
| Join fails | Correct domain, credentials, VM connectivity, and clock |
| User not found | Directory stage completed on the intended domain |
| Policy does not apply | User is in LabUsers; GPO link and filtering; gpresult output |

## Validation status

The script has been reviewed as source, but no PowerShell/Windows runtime is available in this creation environment. Run all stages on snapshots and complete EVIDENCE.md before claiming a working AD deployment.

## References

- [Microsoft: Install-ADDSForest](https://learn.microsoft.com/powershell/module/addsdeployment/install-addsforest)
- [Microsoft: New-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/new-aduser)

