<#
/* 

Various queries for getting information out of the DBA Database
Connect to Server hosting DBA Database


Use 

where IL.Inactive = 0 

to only get active instances

*/


-- Generic infomration about Servers and locations and environments

Select IL.ServerName,
		IL.InstanceName,
		IL.Environment,
		IL.location
FROM dbo.InstanceList IL
-- where IL.Environment = 'Prod'
-- Where IL.Location = 'Bolton'

-- Generic infromation about servers and clients

Select
		DISTINCT C.ClientName,
		IL.ServerName
FROM dbo.InstanceList IL
JOIN
dbo.ClientDatabaseLookup CDL
ON
CDL.InstanceID = IL.InstanceID
JOIN dbo.Clients C
ON c.ClientID = cdl.ClientID
WHERE C.ClientName <> 'DBA-Team' ---- AND C.ClientName = '' -- AND IL.ServerName = '' 
group by C.ClientName ,ServerName


-- Generic SQL Instance Information Specifics can be picked from the SQLInfo table as required - The date checked value will show how up to date the data is

Select IL.ServerName,
		IL.InstanceName,
		IL.Environment,
		IL.location,
		SI.*
FROM dbo.InstanceList IL
JOIN info.SQLInfo SI
ON SI.instanceid = IL.InstanceID
--- Use the relevant where clause you require here

order by SI.ServerName


-- Generic Windows Information Specifics can be picked from the ServerOSInfo table as required - The date checked value will show how up to date the data is
Select 
		SOI.*
FROM info.serverosinfo SOI

-- Pick your required where clause here

-- Generic Database Information Specifics can be picked from the Databases table as required - The date checked value will show how up to date the data is

Select IL.ServerName,
		IL.InstanceName,
		IL.Environment,
		IL.location,
		D.*
FROM dbo.InstanceList IL
JOIN info.Databases D
ON D.InstanceID = IL.InstanceID
where D.Name = 'Name of Database 175'

-- pick your required where clause here


---- Job Detail INformation is in the AgentJobDetail table this holds infomration about every job that ran
Select IL.ServerName,
		IL.InstanceName,
		IL.Environment,
		IL.location,
		AJD.*
FROM dbo.InstanceList IL
JOIN info.AgentJobDetail AJD
ON AJD.InstanceID = IL.InstanceID

-- pick your required where clause here - Think about LastRuntime or outcome or server or job name
WHERE AJD.InstanceID 
IN 

(Select IL.InstanceID
FROM dbo.InstanceList IL
WHERE IL.Environment = 'Prod'          ---- This clause is looking for Prod Environment Servers with Jobs that have Newport in the name
and AJD.JobName LIKE '%Index%')

and AJD.LastRunTime > DATEADD(day,-1,GETDATE())    --- That finished since yesterday
ORDER by AJD.LastRunTime desc


---- Job Server INformation is in the AgentJobServer table this holds a roll up of each days job records

Select IL.ServerName,
		IL.InstanceName,
		IL.Environment,
		IL.location,
		AJS.*
FROM dbo.InstanceList IL
JOIN info.AgentJobServer AJS
ON AJS.InstanceID = IL.InstanceID

-- pick your required where clause here - Think about LastRuntime or outcome or server or job name
WHERE AJS.InstanceID 
IN  

(Select IL.InstanceID
FROM dbo.InstanceList IL
WHERE IL.Environment = 'Prod'          ---- This clause is looking for Prod Environment Servers in Bolton
and IL.Location = 'Bolton')

and AJS.Date > DATEADD(day,-1,GETDATE())    --- That were collected since yesterday
ORDER by IL.ServerName


-- Find the server a database is on

SELECT il.ServerName,
	il.InstanceName,
	il.Port,
	d.Name,
    il.Environment,
	c.ClientName,
	cdl.Notes
	FROM info.Databases d
	join dbo.InstanceList il
	on il.InstanceID = d.InstanceID
	join dbo.ClientDatabaseLookup cdl
	on d.DatabaseID = cdl.DatabaseID
	join dbo.clients c
	on cdl.ClientID = c.ClientID
	where d.name LIKE'%172%'
    AND IL.InActive = 0
	
	#>