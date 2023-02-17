"WordPress installation for Windows Server 2019"

<#
======================== Internet Information Services =========================
#>

#IIS installation
"Installing Internet Information Services..."
"  -Installing Features"
Install-WindowsFeature `
		Web-Server,`
            Web-Common-Http,`
                Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,`
            Web-Health,`
                Web-Http-Logging,`
            Web-Performance,`
                Web-Stat-Compression,`
            Web-Security,`
                Web-Filtering,`
            Web-Mgmt-Tools,`
            Web-App-Dev,`
                Web-CGI,`
		WAS,`
            WAS-Process-Model, WAS-NET-Environment, WAS-Config-APIs,`
        Net-Framework-Core -IncludeManagementTools | Out-Null
"Done."

<#
===================== TEMP directory ======================
#>
"Creating TEMP directory..."
$TEMP_PATH='SystemDrive\tmp\'
New-Item -Path $TEMP_PATH -ItemType Directory | Out-Null
"Done."

<#
===================== Visual C++ Redistributable Package ======================
#>

# Download and install the Visual C++ 2013 - 2015 Redistributable (required for PHP 7.x and MySQL 5.x)
"Visual C++ 2015 Redistributable ..."
"  - Downloading..."
Invoke-WebRequest "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile "$TEMP_PATH\vc_redist_2015_x64.exe"
"  - Installing"
.$TEMP_PATH\vc_redist_2015_x64.exe /Q
"Done."

<#
============================== MySQL Server 5.7 ================================
#>

# Set temporary variables to be used during MySQL installation
$MYSQL_ZIP = "mysql-5.7.39-winx64"
$MYSQL_URL = "https://downloads.mysql.com/archives/get/p/23/file/$MYSQL_ZIP.zip"
$MYSQL_NAME = "MySQL"
$MYSQL_PROD = "$MYSQL_NAME Server 5.7"
$MYSQL_PATH = "$env:SystemDrive\Program Files\$MYSQL_NAME"
$MYSQL_BASE = "$MYSQL_PATH\$MYSQL_PROD"
$MYSQL_PDTA = "$env:SystemDrive\Program Data\$MYSQL_NAME\$MYSQL_PROD"
$MYSQL_DATA = "$MYSQL_PDTA\data"
$MYSQL_INIT = "$MYSQL_PDTA\mysql-init.sql"

$MYSQL_USER = "wordpress"
$MYSQL_DB_NAME = "wordpress"
$MYSQL_DB_HOST = "localhost"

"Installing MySQL Server..."
"  - Downloading..."
#Downloading MySQL
Invoke-WebRequest "$MYSQL_URL"-OutFile "$TEMP_PATH\$MYSQL_ZIP.zip"
"Done."
"  - Expanding archive..."
Expand-Archive -Path $TEMP_PATH\$MYSQL_ZIP.zip -DestinationPath $MYSQL_PATH
"Done."
"  - Renaming destination directory"
Rename-Item -NewName $MYSQL_PROD -Path $MYSQL_PATH\$MYSQL_ZIP

# Add the MySQL “bin” directory to the search Path variable
"  - Setting PATH variable"
$env:Path += ";$MYSQL_BASE\bin"
setx Path $env:Path /m

# Create a MySQL Option File
"  - Creating MY.INI"
Set-Content "$MYSQL_BASE\my.ini" "[mysqld]`r`nbasedir=""$MYSQL_BASE""`r`ndatadir=""$MYSQL_DATA""`r`nexplicit_defaults_for_timestamp=1"
"Done."

# Create the MySQL database directory
"  - Creating database directory"
New-Item $MYSQL_DATA -ItemType "Directory" | Out-Null

# Initialise the MySQL database files
"  - Initialising database directory"
mysqld --initialize-insecure

# Install MySQL as a Windows service
"  - Installing MySQL as Windows Service"
mysqld --install

# Start the MySQL service
"  - Starting MySQL Windows Service"
Start-Service MySQL
"Done."

# Generate random passwords for 'root' and 'wordpress' accounts
"  -Generating passwords"
Add-Type -AssemblyName System.Web
$MYSQL_ROOT_PWD = [System.Web.Security.Membership]::GeneratePassword(18,3)
$MYSQL_WORD_PWD = [System.Web.Security.Membership]::GeneratePassword(18,3)
"Done."

# Create a MySQL initialisation script
"  - Generating initialisation script"
Set-Content $MYSQL_INIT "ALTER USER 'root'@'$MYSQL_DB_HOST' IDENTIFIED BY '$MYSQL_ROOT_PWD';"
Add-Content $MYSQL_INIT "CREATE DATABASE $MYSQL_DB_NAME;"
Add-Content $MYSQL_INIT "CREATE USER '$MYSQL_USER'@'$MYSQL_DB_HOST' IDENTIFIED BY '$MYSQL_WORD_PWD';"
Add-Content $MYSQL_INIT "GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '$MYSQL_USER'@'$MYSQL_DB_HOST';"

# Execute the MySQL initialisation script
"  - Executing initialisation script"
mysql --user=root --execute="source $MYSQL_INIT"

# Delete the MySQL initialisation script
"  - Deleting initialisation script"
Remove-Item $MYSQL_INIT

<#
============================== PHP 7.4 ================================
#>

# Set temporary variables to be used during PHP installation
$PHP_ZIP = "php-7.4.33-nts-Win32-vc15-x64"
$PHP_URL = "https://windows.php.net/downloads/releases/$PHP_ZIP.zip"
$PHP_NAME = "PHP"
$PHP_PATH = "$env:SystemDrive\Program Files\$PHP_NAME"
$PHP_DATA = "$env:SystemDrive\Program Data\$PHP_NAME"

# Download and install PHP
"Downloading PHP ..."
Invoke-WebRequest "$PHP_URL" -OutFile "$TEMP_PATH\$PHP_ZIP.zip"
"Done."

"  - Expanding archive..."
Expand-Archive -Path "$TEMP_PATH\$PHP_ZIP.zip" -DestinationPath "$PHP_PATH"
"Done."

"  - Creating PHP.INI"
Copy-Item -Path "$PHP_PATH\php.ini-production" -Destination "$PHP_PATH\php.ini"
(Get-Content -Path $PHP_PATH\php.ini) -replace';open_basedir =',';open_basedir = C:\inetpub\wwwroot' | Set-Content -Path $PHP_PATH\php.ini
(Get-Content -Path $PHP_PATH\php.ini) -replace ';cgi.force_redirect = 1',';cgi.force_redirect = 0' | Set-Content -Path $PHP_PATH\php.ini
(Get-Content -Path $PHP_PATH\php.ini) -replace'short_open_tag = Off','short_open_tag = On' | Set-Content -Path $PHP_PATH\php.ini
"Done."


# Download and install PHP Manager for IIS
"PHP Manager for IIS 2.11.0 ..."
"  - Downloading"
Invoke-WebRequest "https://github.com/phpmanager/phpmanager/releases/download/v2.11/PHPManagerForIIS_x64.msi" -OutFile "$TEMP_PATH\PHPManagerForIIS-2.11.0-x64.msi"
"  - Installing"
Start-Process -FilePath $TEMP_PATH\PHPManagerForIIS-2.11.0-x64.msi /qn -Wait
"  - Waiting"
Start-Sleep -s 5
"Done."

"Configure PHP with IIS ..."
# Add the PHP Manager PowerShell Snap-In
Add-PsSnapin -Name PHPManagerSnapin

# Register PHP with Internet Information Services (IIS)
New-PHPVersion "$PHP_PATH\php-cgi.exe"
"Done."

<#
================================== WordPress ===================================
#>

# Set temporary variables to be used during the WordPress installation
$IIS_PATH = "$env:SystemDrive\inetpub"
$WORDPRESS_PATH = "$IIS_PATH\wordpress"
$WORDPRESS_URL = "https://wordpress.org/latest.zip"
$WORDPRESS_ZIP = "wordpress.zip"

# Download and install WordPress
"WordPress ..."
"  - Downloading"
Invoke-WebRequest "$WORDPRESS_URL" -OutFile "$TEMP_PATH\$WORDPRESS_ZIP"
"  - Expanding"
Expand-Archive "$TEMP_PATH\$WORDPRESS_ZIP" "$IIS_PATH"
"Done."

# Grant the IIS_IUSRS and IUSR accounts Modify rights to the WordPress directory
"NuGet installation"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
"Done." 
"Installing NTFSSecurity"
Install-Module -Name NTFSSecurity -Force
"Done."
"Import NTFSSecurity"
Import-Module NTFSSecurity
"  - Appying NTFS Permissions (IIS_IUSRS)"
Add-NTFSAccess "$WORDPRESS_PATH" IIS_IUSRS Modify
"  - Appying NTFS Permissions (IUSR)"
Add-NTFSAccess "$WORDPRESS_PATH" IUSR Modify

# Create a new Internet Information Services application pool for WordPress
"  - Creating Application Pool"
$WebAppPool = New-WebAppPool "WordPress"
$WebAppPool.managedPipelineMode = "Classic"
$WebAppPool.managedRuntimeVersion = ""
$WebAppPool | Set-Item
"Done."

# Create a new Internet Information Services website for WordPress
"  - Creating WebSite"
New-Website "WordPress" -ApplicationPool "WordPress" -PhysicalPath "$WORDPRESS_PATH"  | Out-Null
" - Waiting"
Start-Sleep -s 5
"Done."

# Remove the “Default Web Site” and start the new “WordPress” website
"  - Activating WebSite"
Remove-Website "Default Web Site"
Start-Website "WordPress"
"Done."

<#
===================== Remove TEMP directory ======================
#>
"  -Removing temporary data..."
Remove-Item -Path $TEMP_PATH -Force -Recurse
"Done."

#Create WordPress Config File
"Configuring wp-config.php..."
"  -Setting Database Credentials"
Copy-Item -Path "$WORDPRESS_PATH\wp-config-sample.php" -Destination "$WORDPRESS_PATH\wp-config.php"
(Get-Content -Path $WORDPRESS_PATH\wp-config.php).Replace("define( 'DB_NAME', 'database_name_here' )","define( 'DB_NAME', '$MYSQL_DB_NAME' )")| Set-Content -Path $WORDPRESS_PATH\wp-config.php | Out-Null
(Get-Content -Path $WORDPRESS_PATH\wp-config.php).Replace("define( 'DB_USER', 'username_here' )","define( 'DB_USER', '$MYSQL_USER' )")| Set-Content -Path $WORDPRESS_PATH\wp-config.php | Out-Null
(Get-Content -Path $WORDPRESS_PATH\wp-config.php).Replace("define( 'DB_PASSWORD', 'password_here' )","define( 'DB_PASSWORD', '$MYSQL_WORD_PWD' )")| Set-Content -Path $WORDPRESS_PATH\wp-config.php | Out-Null
"Done."

<#
===========================================================
#>
"Installation finished."
#"MySQL Accounts"
#"       root = $MYSQL_ROOT_PWD"
#"  wordpress = $MYSQL_WORD_PWD"
$IPADDRESS = (Get-NetIPAddress | ? {($_.AddressFamily -eq "IPv4") -and ($_.IPAddress -ne "127.0.0.1")}).IPAddress
"Connect your web browser to http://$IPADDRESS/ to complete this WordPress installation."
