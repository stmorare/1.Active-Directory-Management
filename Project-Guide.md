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

- Prepare `AddUsers_RoleBased.ps1` to process the CSV.
- Script:
  ```powershell
  # Load the Active Directory tools
  Import-Module ActiveDirectory

  # Set file locations
  $csvPath = "C:\Scripts\Users.csv"
  $logPath = "C:\Scripts\User_Log.txt"

  # Function to write logs
  function Write-Log {
    param($Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $Message" | Out-File -FilePath $logPath -Append
  }

  # Check if CSV file exists
  if (-not (Test-Path $csvPath)) {
    Write-Log "Error: CSV file not found at $csvPath!"
    Write-Host "Error: CSV file not found at $csvPath. Please create the file and try again."
    exit
  }

  # Check if role-based groups exist
  $staffGroup = "SG_Sales_Staff"
  $managerGroup = "SG_Sales_Manager"

  if (-not (Get-ADGroup -Identity $staffGroup -ErrorAction SilentlyContinue)) {
    Write-Log "Error: Security group $staffGroup does not exist in mydomain.local!"
    Write-Host "Error: Security group $staffGroup does not exist. Please create it in Active Directory."
    exit
  }

  if (-not (Get-ADGroup -Identity $managerGroup -ErrorAction SilentlyContinue)) {
    Write-Log "Error: Security group $managerGroup does not exist in mydomain.local!"
    Write-Host "Error: Security group $managerGroup does not exist. Please create it in Active Directory."
    exit
  }

  # Read the CSV and create users
  $users = Import-Csv -Path $csvPath
  foreach ($user in $users) {
    try {
        # Get user details from CSV
        $name = $user.Name
        $department = $user.Department
        $role = $user.Role
        $username = ($name -replace " ", "").ToLower()
        $password = ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force
        $ouPath = "OU=$department,DC=mydomain,DC=local"

        Write-Log "Processing user: $username, Name: $name, Department: $department, Role: $role, OU: $ouPath"
        Write-Host "Processing user: $username, Name: $name, Department: $department, Role: $role, OU: $ouPath"

        # Check if the OU exists
        if (-not (Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction SilentlyContinue)) {
            Write-Log "Error: OU $ouPath does not exist for user $username!"
            Write-Host "Error: OU $ouPath does not exist. Skipping user $username."
            continue
        }

        # Check if user already exists
        $existingUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
        if ($existingUser) {
            Write-Log "Warning: User $username already exists. Using existing user."
            Write-Host "Warning: User $username already exists. Using existing user."
        } else {
            # Create the user
            Write-Log "Attempting to create user $username..."
            Write-Host "Attempting to create user $username..."
            
            New-ADUser -Name $name `
                       -SamAccountName $username `
                       -UserPrincipalName "$username@mydomain.local" `
                       -Path $ouPath `
                       -AccountPassword $password `
                       -Enabled $true `
                       -ChangePasswordAtLogon $true `
                       -ErrorAction Stop

            Write-Log "Successfully created user $username in $department OU."
            Write-Host "Successfully created user $username in $department OU."

            # Wait a moment for AD replication and then retrieve the user
            Start-Sleep -Seconds 2
            
            # Retrieve the newly created user using Filter instead of Identity
            Write-Log "Retrieving user $username after creation..."
            Write-Host "Retrieving user $username after creation..."
            
            $existingUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
            if (-not $existingUser) {
                # Try one more time with a longer wait
                Start-Sleep -Seconds 3
                $existingUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
                if (-not $existingUser) {
                    throw "Failed to retrieve user $username after creation and waiting."
                }
            }
        }

        # Add user to the appropriate group based on role
        Write-Log "Adding user $username to group based on role: $role..."
        Write-Host "Adding user $username to group based on role: $role..."
        
        if ($role -eq "Staff") {
            # Use the SamAccountName instead of the user object
            Add-ADGroupMember -Identity $staffGroup -Members $username -ErrorAction Stop
            Write-Log "Added $username to $staffGroup."
            Write-Host "Added $username to $staffGroup."
        }
        elseif ($role -eq "Manager") {
            # Use the SamAccountName instead of the user object
            Add-ADGroupMember -Identity $managerGroup -Members $username -ErrorAction Stop
            Write-Log "Added $username to $managerGroup."
            Write-Host "Added $username to $managerGroup."
        }
        else {
            Write-Log "Warning: Role $role for $username is not recognized. Skipping group assignment."
            Write-Host "Warning: Role $role for $username is not recognized. Skipping group assignment."
        }
    }
    catch {
        Write-Log "Error with $username : $($_.Exception.Message)"
        Write-Host "Error with $username : $($_.Exception.Message)"
    }
  }

  Write-Log "User provisioning completed!"
  Write-Host "User provisioning completed! Check $logPath for details."
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
