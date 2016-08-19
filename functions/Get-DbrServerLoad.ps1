<#/*
Adding a new server to the DBA Database


Enter the corect values against the variables

The errors will tell you what you have done wrong

AUTHOR - ROb Sewell
DATE - 04/05/2015 - Initial
	- 10/08/2015 - Added some failsafes !!
	- 18/08/2015 - Added non contactabel and inactive to the query
	-- 25/092015 jw - fixed typo NotContactable instead of NonContactable

*/




Use [DBADatabase]
GO


DECLARE @Server nvarchar(50) = ''					--- ENTER SERVER HERE
DECLARE @InstanceName nvarchar(50) = 'MSSQLSERVER'			--- ENTER INSTANCE NAME HERE EVEN IF DEFAULT
DECLARE @Port int = 1433									--- ENTER Port Here EVEN IF DEFAULT
DECLARE @AG bit = 0											--- Is this an Availability group enabled instance? 1 - Yes 0 - No
DECLARE @Environment nvarchar(25) = 'PROD'						--- Environment -  Prod, Test, Int,PreProd,Dev etc
DECLARE @Location nvarchar(30) = ''							--- Location - Data Centre 1 Data Centre 2  etc


---------------------------------------------------------------------------------------------------------------------
/*

			YOU SHOULD NOT NEED TO CHANGE ANYTHING BELOW HERE

*/
---------------------------------------------------------------------------------------------------------------------




DECLARE @Message nvarchar(150)

declare @InstanceId int

-- Ensure Instance does not already exist
IF EXISTS
(
SELECT  [InstanceID]
  FROM [DBADatabase].[dbo].[InstanceList]
  Where [ServerName] = @Server
AND [InstanceName] = @InstanceName
													)
BEGIN
DECLARE @P nvarchar(10) = CAST(@Port as nvarchar(10))
SET @Message = @Server  + '\' + @InstanceName + ',' + @P + ' already exists in the DBA Database';
THROW 50000, @Message, 1
END

INSERT INTO [dbo].[InstanceList]
           ([ServerName]
           ,[InstanceName]
           ,[Port]
		   ,[AG]
		   ,Inactive
		   ,Environment
		   ,Location
		   ,NotContactable)
     VALUES
           (@Server   
           ,@InstanceName         
           ,@Port            
		   ,@AG   
		   ,0           
		   ,@Environment           
		   ,@Location    
		   ,0 ---------------------Unless this servers in on a network that cannot be contacted in which case this is a 1            
		   ) 

set @InstanceId = SCOPE_IDENTITY()

insert into dbo.InstanceScriptLookup (
	InstanceID,
	ScriptID,
	NeedsUpdate
) 
	select 
		@InstanceId,
		s.ScriptID,
		0							-- This will update all scripts if set to 1 - DO NOT DO THIS
	from dbo.ScriptList as s

GO
#>
