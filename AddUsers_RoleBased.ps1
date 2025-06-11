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