# DBA-Database-Creation-and-Population
This repo contains the scripts to create and populate the DBA Database to automatically gather information about your estate

- Install the DBA Database on your server
- Follow the [Add Server to Auto Scripts Doc](/Setup/Add%20Server%20to%20Auto%20Scripts.docx) to add servers 
- Copy the [PowerShell scripts](/Setup/SSMS%20Solution%20and%20Scripts/PowerShell) to a location that can be accessed by the server. You will need to alter each of them to add the Servername and log file location
- Create a credential and a proxy using [Create Credential and proxy for Agent jobs.sql](Setup/SSMS%20Solution%20and%20Scripts/TSQL/Create%20Credential%20and%20proxy%20for%20Agent%20jobs.sql) for an account with permissions on all of the servers that you need to monitor
- Create the agent jobs using the scripts provided - you will need to alter the Script location to the location you placed the powershell scripts
- The auto-install script requires you to download and add those scripts where the license requires this (Brent Ozar, Adam Mechanic, Ola Hallengren, Jared Zagelbaum)
- The script location needs to be updated in the [DBADatabase].[dbo].[ScriptList] table
- You can add extra scripts for your own environment using [- LOAD - Script Data Load.sql](/Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20LOAD%20-%20Script%20Data%20Load.sql) and adding a new code block to the [Auto Update PS job steps.ps1](Setup/SSMS%20Solution%20and%20Scripts/PowerShell/Auto%20Update%20PS%20job%20steps.ps1)
- You can set which servers get which scripts using the [- LOAD - Update the Needs Update Flag for a server.sql](Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20LOAD%20-%20Update%20the%20Needs%20Update%20Flag%20for%20a%20server.sql) or [- LOAD - Update the Needs Update for a script.sql](/Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20LOAD%20-%20Update%20the%20Needs%20Update%20for%20a%20script.sql) scripts although more granular targetting is recommended. The auto script job will then install them.
- All agent jobs should show success when run but you MUST check (or scrape automatically) the errors in the log files I do this via an agent job running some Powershell and a SSRS report (I Will add this soon)
- There are a number of scripts for displaying information 
    - [- INFO - All info for a Server.sql](/Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20INFO%20-%20All%20info%20for%20a%20Server.sql) shows all of the information in the DBA Database for a single server
    - [- INFO - Query For Needs update =1.sql ](/Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20INFO%20-%20Query%20For%20Needs%20update%20%3D1.sql) Shows the servers adn scripts you have set to be updated next time the Auto Script install job runs
    - [- INFO - Various scripts to get information.sql](/Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20INFO%20-%20Various%20scripts%20to%20get%20information.sql) has other generic queries
    - [- INFO - Estate Detailed Information.sql ](/Setup/SSMS%20Solution%20and%20Scripts/TSQL/-%20INFO%20-%20Estate%20Detailed%20Information.sql) Gives more detailed information about an estate, number of servers, databases, sizes, versions, editions, locations, no full backups etc
- The [PowerBi Reports](Setup/SSMS%20Solution%20and%20Scripts/PowerBi) will need Power Bi Desktop a free download from (https://powerbi.microsoft.com/en-us/desktop/) You will need to alter each of the queries to use the server you have the DBA Database on

## Blog Posts, Slides and Videos

- [Using Power Bi with my DBA Database](https://sqldbawithabeard.com/2015/08/16/using-power-bi-with-my-dba-database/)
- [Populating My DBA Database for Power Bi with PowerShell – Server
Info](https://sqldbawithabeard.com/2015/08/31/populating-my-dba-database-for-power-bi-with-powershell-server-info/)
- [Populating My DBA Database for Power Bi with PowerShell – SQL
Info](https://sqldbawithabeard.com/2015/09/07/populating-my-dba-database-for-power-bi-with-powershell-sql-info/)
- [Populating My DBA Database for Power Bi with PowerShell – Databases](https://sqldbawithabeard.com/2015/09/22/populating-my-dba-database-for-power-bi-with-powershell-databases/)
- [Power Bi, PowerShell and SQL Agent Jobs](https://sqldbawithabeard.com/2015/09/28/power-bi-powershell-and-sql-agent-jobs/)

- PSConfEU - (https://www.youtube.com/watch?v=9BKlrOjMWXk&index=5&list=PLIg9rQe6gY0pHCeB9WpCkyI8_27sC94ZT)
- PSConfEU - (https://www.youtube.com/watch?v=KIsPXCeIlJw)
- SQL Relay - (https://www.youtube.com/watch?v=9BKlrOjMWXk&index=5&list=PLIg9rQe6gY0pHCeB9WpCkyI8_27sC94ZT) 

- SQL Relay - (https://onedrive.live.com/view.aspx?cid=c802df42025d5e1f&page=view&resid=C802DF42025D5E1F!128659&parId=C802DF42025D5E1F!128658&app=PowerPoint)
- PSConfEU - (https://onedrive.live.com/view.aspx?cid=c802df42025d5e1f&page=view&resid=C802DF42025D5E1F!184185&parId=C802DF42025D5E1F!181837&app=PowerPoint)



