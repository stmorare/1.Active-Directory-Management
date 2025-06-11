# Active Directory Management Project

## Overview

This project sets up a Windows Server 2019 domain environment, automates user provisioning with PowerShell, applies GPOs, configures security groups, and troubleshoots issues. **Date**: June 11, 2025, 12:57 PM SAST.

### Objectives

- Set up a domain environment using Windows Server 2019.
- Automate user creation with PowerShell.
- Configure GPOs for desktop settings.
- Secure resources using security groups.
- Troubleshoot Active Directory issues.

### Tools Used

- Windows Server 2025
- Windows 11
- Active Directory Domain Services (AD DS)
- PowerShell
- Group Policy Management
- VMware Workstation Player

## Step-by-Step Guide

### 1. Set Up a Virtual Lab Environment:

- Install VMware Workstation Player from [VMware](https://www.vmware.com/products/workstation-player.html).
- Create VMs:
  - **Domain Controller**: Windows Server 2025, 4 GB RAM, 100 GB disk.
  - **Clients**: Two Windows 11 VMs, 4 GB RAM, 100 GB disk each.
- Promote the server to a domain controller with domain `mydomain.local`.
- Join clients to the domain.

### 2. Plan Your Active Directory Structure

- Create OU: `Sales` in Active Directory Users and Computers (ADUC).
- Create security groups: `SG_Sales_Staff` and `SG_Sales_Manager`.

### 3. Automate User Provisioning with PowerShell

- **CSV File**: Create `C:\Scripts\Users.csv`:
Name,Department,Role
John Doe,Sales,Staff
Jane Smith,Sales,Manager
Alice Johnson,Sales,Staff

- **Script**: Use `AddUsers_RoleBased.ps1` (included in this repository).

### 4. Configure Group Policy Objects (GPOs)
- Create GPOs:
- `Password Policy`: Set minimum length to 8 characters.
- `Desktop Settings`: Set wallpaper to `\\dc-00\netlogon\wallpaper.bmp`.

### 5. Set Up Security Groups and Permissions
- Create groups `SG_Sales_Staff` and `SG_Sales_Manager` in the Sales OU.
- Share `C:\SalesFolder`:
- Share permissions: Add both groups with Read/Write.
- NTFS permissions: `SG_Sales_Staff` (Read & Execute), `SG_Sales_Manager` (Modify).

### 6. Test and Document
- Test access: `johndoe` (read-only), `janesmith` (modify).

## Conclusion
This project demonstrates system administration skills, focusing on basic Active Directory tasks. 

**Prepared by**: Simphiwe T. Morare  
**Date**: June 11, 2025.

