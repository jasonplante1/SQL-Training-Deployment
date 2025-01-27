# If you modified the ARM template in any way, please adjust the appropriate commands below
# latest sqlserver cmdlets
install-module sqlserver -AllowClobber -Force


#get adventureworks2017 
mkdir c:\adventureworks
Invoke-WebRequest -Uri https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2017.bak -OutFile c:\adventureworks\AdventureWorks2017.bak


# Firewall Rules
New-NetFirewallRule -DisplayName "SQLEndpoint" -Direction Inbound -protocol TCP -LocalPort 1433  -Action Allow -Enabled True
New-NetFirewallRule -DisplayName "SQLHADREndpoint" -Direction Inbound  -protocol TCP -LocalPort 5022  -Action Allow -Enabled True
New-NetFirewallRule -DisplayName "Healthprobe" -Direction Inbound -protocol TCP -LocalPort 59999 -Action Allow -Enabled True
Enable-NetFirewallRule -DisplayName "Windows Management Instrumentation (WMI-In)"
Enable-NetFirewallRule -DisplayName "Windows Management Instrumentation (DCOM-In)"


#after domain join, needs to be done under local adminuser acct -  run powershell as adminuser to do this or login as adminuser.
Invoke-Sqlcmd -Database "master" -Query "CREATE LOGIN [SQLTRAIN\adminuser] FROM WINDOWS WITH DEFAULT_DATABASE=[master]" -ServerInstance "." 
Invoke-Sqlcmd -Database "master" -Query "ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLTRAIN\adminuser]" -ServerInstance "." 
Invoke-Sqlcmd -Database "master" -Query "CREATE LOGIN [SQLTRAIN\SQL2VM$] FROM WINDOWS WITH DEFAULT_DATABASE=[master]" -ServerInstance "."
Invoke-Sqlcmd -Database "master" -Query "CREATE LOGIN [SQLTRAIN\SQL1vm$] FROM WINDOWS WITH DEFAULT_DATABASE=[master]" -ServerInstance "."
Invoke-Sqlcmd -Database "master" -Query "CREATE LOGIN [SQLTRAIN\SQL3vm$] FROM WINDOWS WITH DEFAULT_DATABASE=[master]" -ServerInstance "."
Invoke-Sqlcmd -Database "master" -Query "ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLTRAIN\SQL2VM$]" -ServerInstance "."
Invoke-Sqlcmd -Database "master" -Query "ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLTRAIN\SQL1vm$]" -ServerInstance "."
Invoke-Sqlcmd -Database "master" -Query "ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLTRAIN\SQL3vm$]" -ServerInstance "."


#make directory for snapshots -- replication stuff
mkdir c:\snapshot


#grab chrome to bypass IE security
$LocalTempDir = $env:TEMP; $ChromeInstaller = "ChromeInstaller.exe"; (new-object    System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor = "ChromeInstaller"; Do { $ProcessesFound = Get-Process | ? { $Process2Monitor -contains $_.Name } | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 } else { rm "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)


# Get access to SqlWmiManagement DLL on the machine with SQL
# we are on, which is where SQL Server was installed.
# Note: this is installed in the GAC by SQL Server Setup.

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')

# Instantiate a ManagedComputer object which exposes primitives to control the
# installation of SQL Server on this machine.

$wmi = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' localhost

# Enable the TCP protocol on the default instance. If the instance is named, 
# replace MSSQLSERVER with the instance name in the following line.

$tcp = $wmi.ServerInstances['MSSQLSERVER'].ServerProtocols['Tcp']
$tcp.IsEnabled = $true  
$tcp.Alter()  

# You need to restart SQL Server for the change to persist
# -Force takes care of any dependent services, like SQL Agent.
# Note: if the instance is named, replace MSSQLSERVER with MSSQL$ followed by
# the name of the instance (e.g. MSSQL$MYINSTANCE)

Restart-Service -Name MSSQLSERVER -Force
Install-WindowsFeature -Name Failover-Clustering –IncludeManagementTools

# just in case local admin is still logged in
Restart-Computer -force 

