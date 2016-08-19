SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:          Rob Sewell
-- Create date: 31/12/2015
-- Description:     Get the 5 fastest growing disks
-- =============================================
CREATE PROCEDURE [dbo].[Get_FastestGrowingDisks]
AS
BEGIN
       -- SET NOCOUNT ON added to prevent extra result sets from
       -- interfering with SELECT statements.
       SET NOCOUNT ON;

    -- Insert statements for procedure here
       WITH Percentage_cte AS (
    SELECT
        ROW_NUMBER() OVER(PARTITION BY ServerId,DiskName ORDER BY ServerId,[DiskName],Date) rn
             ,Date
       ,ServerID
      ,[DiskName]
      ,[Percentage]
      ,[Label]
      ,[Capacity]
      ,[FreeSpace]
    FROM  [Info].[DiskSpace]
       wHERE Date > DATEADD(Day, -2, GETDATE()) 
)

select top 5
c1.date
,(SELECT ServerName FROM info.ServerInfo WHERE ServerID = c1.ServerID) as Server
,c1.DiskName
,c1.[Label]
,c1.[Capacity]
,c1.[FreeSpace]
,c1.[Percentage]
,c2.FreeSpace - c1.FreeSpace as Growth
from Percentage_cte c1
join Percentage_cte c2
ON
c1.rn = c2.rn + 1 
AND c1.ServerId= c2.ServerId
AND c1.diskname = c2.diskname
ORDER BY Growth desc,c1.Percentage asc
END


GO
