# DBA Reports
This repo contains the PowerShell module SSRS and PowerBi samples for you to gather, store and report on information about your SQL Server estate. You can find more details on the website https://dbareports.io 

## Installer
We’ve tried to make the installation experience as simple as possible. Executing Install-DBAreports does the following:

![Alt text](https://dbareports.io/wp-content/uploads/2016/07/installer.png "Installer")

* Uses SQL Server’s default backup directory if no InstallPath is specified
* Uses a logging directory within your InstallPath if no log path is specified
* If no proxy account is specified, you will be prompted to create one or choose to use the SQL Agent’s service account
* Customizes the PowerShell scripts for your specific install and associates them with the SQL Agent Jobs
* Creates the database if it doesn’t already exist
* Creates the required schemas, extended proeprties, tables, stored procedures and user-defined table types
* Automatically creates the required SQL Agent PowerShell and T-SQL jobs
* Automatically schedules each job
* Writes a client config file to your local PowerShell directory so that you don’t have to specify your dbareports server and database each time you run a command

![Alt Text](https://dbareports.io/wp-content/uploads/2016/07/agents-1.png "Agents")
##Experience
Adding and modifying SQL Servers is performed through PowerShell commands, while PowerBI and SSRS are used to visualize the data that the Agent Jobs collect.
##Goals
The ultimate goal of dbareports is to enable SQL Server DBAs to provide up to date, accurate information about the SQL Server Estate (It can easily be expanded for other technologies) to other parties.
The other parties could be
* technical teams: DBA Team, DataCenter, Systems Teams, Developers, IT Security
* technical process teams: Change Managers, Project Managers, Compliance
* senior management
* business teams: Client Account Managers, System Owners
* external: Auditors, Third Party Suppliers

This is **NOT real-time monitoring** – of course you could develop it to be so. But at present dbareports is designed to provide information about estates it does not alert about issues.
The types of information available about the estate includes
* Overall Information: Number of Servers, Instances, Databases, Environments, Clients, Locations
* Operating System: HostName, Operating System version, IP Addresses, RAM, CPU
* Instance: SQL version, edition, collation, service accounts, memory settings, default locations, configuration
* Database: Collation, Compatibility, last backup, owner, space used, space available
* SQL Agent server level: Roll up of number of jobs and status
* SQL Agent detail: Name, Category, Status, Last Run Time, Outcome
* Suspect Pages: Number of suspect pages in msdb
* Database last used: Uses the sys.dm_db_index_usage_stats
