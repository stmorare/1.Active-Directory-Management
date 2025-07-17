# Step-by-Step Guide: Active Directory Management Project (Windows Server 2025)

## 1. Set Up a Virtual Lab Environment

- **Install VMware Workstation Player** on your host PC.
- **Create Virtual Machines:**
  - **Domain Controller:**  
    - OS: Windows Server 2025 Datacenter Edition  
    - 4 GB RAM, 100 GB disk  
  - **Clients (2x):**  
    - OS: Windows 11 Pro  
    - 4 GB RAM, 100 GB disk each  
- **Install the OS:**
  - Mount the Windows Server 2025 ISO to the DC VM and complete installation.
  - Mount Windows 11 ISOs to client VMs and install.
- **Networking:** Ensure all VMs are on the same internal or bridged network in VMware.

## 2. Promote Windows Server 2025 to Domain Controller

- **Launch Server Manager** on your Windows Server 2025 VM.
- Go to **Manage > Add Roles and Features**.
- Select **Active Directory Domain Services (AD DS)** and follow the prompts to install.
- After installation, in Server Manager, click the exclamation mark (!) and select **Promote this server to a domain controller**.
- Choose **Add a new forest** and set domain name to `mydomain.local`.
- Set a Directory Services Restore Mode (DSRM) password when prompted.
- Complete the wizard, approve any prompts, and let the server reboot to complete promotion.

## 3. Join Windows 11 Pro Clients to the Domain

- Ensure the clients' **DNS** is set to the domain controller's IP address.
- On Windows 11, open **Settings > Accounts > Access work or school > Connect > Join this device to a local Active Directory domain**.
- Enter `mydomain.local` as the domain name and provide domain credentials when prompted.
- Restart the client to finalize domain joining.

## 4. Plan and Build Active Directory Structure

### Create the Organizational Unit (OU)

- On the DC, open **Active Directory Users and Computers (ADUC)**.
- Right-click the domain (`mydomain.local`), select **New > Organizational Unit**.
- Name the OU `Sales` and click OK.

### Create Security Groups

- In ADUC, right-click the `Sales` OU, choose **New > Group**.
- Name each group:
  - `SG_Sales_Staff`
  - `SG_Sales_Manager`
- Leave group type as **Security** and scope as **Global**, then click OK.

## 5. Automate User Provisioning with PowerShell

### Prepare the User List CSV

- Create `C:\Scripts\Users.csv` with this content:
  ```
  Name,Department,Role
  John Doe,Sales,Staff
  Jane Smith,Sales,Manager
  Alice Johnson,Sales,Staff
  ```

### PowerShell Script for Bulk User Creation

- Download or prepare `AddUsers_RoleBased.ps1` to process the CSV.
- Standard PowerShell logic is:
  ```powershell
  Import-Module ActiveDirectory
  $users = Import-Csv "C:\Scripts\Users.csv"
  foreach ($u in $users) {
    $ou = "OU=Sales,DC=mydomain,DC=local"
    $group = if ($u.Role -eq "Manager") { "SG_Sales_Manager" } else { "SG_Sales_Staff" }
    $sam = ($u.Name -replace '\s', '').ToLower()
    $pwd = ConvertTo-SecureString "Pa$$w0rd!" -AsPlainText -Force
    New-ADUser -Name $u.Name -SamAccountName $sam -AccountPassword $pwd -Path $ou -Enabled $true -Department $u.Department
    Add-ADGroupMember -Identity $group -Members $sam
  }
  ```
- Run PowerShell as **Administrator** and execute your script.

## 6. Configure Group Policy Objects (GPOs)

### Set Password Policy

- Open **Group Policy Management** on the DC.
- Right-click **Default Domain Policy** and select **Edit**.
- Navigate to:  
  `Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy`
- Set **Minimum password length** to `8` characters. Adjust other password/lockout options as desired.

### Set Desktop Wallpaper via GPO

- Save your desired wallpaper to a network path, e.g., `\\dc-00\netlogon\wallpaper.bmp`.
- In Group Policy Management, right-click your domain or Sales OU, choose **Create a GPO in this domain**, named "Sales Wallpaper".
- Edit the GPO:  
  `User Configuration > Policies > Administrative Templates > Desktop > Desktop`
- Double-click **Desktop Wallpaper**, set to **Enabled**.
- Enter the wallpaper UNC path (`\\dc-00\netlogon\wallpaper.bmp`) and choose **Fill** or **Center** as style.
- Link the GPO to the Sales OU or domain as required.

## 7. Set Up Security Groups and Resource Permissions

### Share the Folder

- On DC or a file server, create `C:\SalesFolder`.
- Right-click, go to **Properties > Sharing > Advanced Sharing**.
- Check **Share this folder**.
- Click **Permissions**:
  - Add `SG_Sales_Staff` and `SG_Sales_Manager`, both with **Change (Read/Write)** privileges.

### Set NTFS Permissions

- Go to **Security** tab in folder properties.
- Remove unnecessary groups like `Everyone`.  
- Add:
  - `SG_Sales_Staff`: set to **Read & Execute**
  - `SG_Sales_Manager`: set to **Modify**
- Apply and confirm changes. NTFS (Security) permissions override Share permissions for members accessing via the network.

## 8. Test and Document

- **Log in as johndoe (SG_Sales_Staff):** Verify **Read & Execute** access to `\\dc-00\SalesFolder`.
- **Log in as janesmith (SG_Sales_Manager):** Verify **Modify** access (create, edit, delete files).
- Document steps, issues, screenshots, and outcomes for each test.

## Troubleshooting Tips

- **Domain Join Fails:** Check DNS on clients points to the DC, and network connectivity.
- **GPO Not Applying:** Run `gpupdate /force` on clients and check domain linkage.
- **User Creation Errors:** Ensure PowerShell runs as Domain Admin and the AD module is present.
- **Permission Problems:** Double-check group membership and both NTFS and share permissions.

By following these steps, you will set up a modern, automated Active Directory environment using Windows Server 2025 and Windows 11 Pro, complete with user automation, GPO deployment, and granular access control.
