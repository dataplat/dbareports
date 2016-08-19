/*
This migration script replaces uncommitted changes made to these objects:
InstanceList
DiskSpace
ServerInfo
ServerOSInfo

Use this script to make necessary schema and data changes for these objects only. Schema changes to any other objects won't be deployed.

Schema changes and migration scripts are deployed in the order they're committed.
*/

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Dropping foreign keys from [dbo].[ClientDatabaseLookup]'
GO
ALTER TABLE [dbo].[ClientDatabaseLookup] DROP CONSTRAINT [FK_ClientDatabaseLookup_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[AgentJobDetail]'
GO
ALTER TABLE [info].[AgentJobDetail] DROP CONSTRAINT [FK_info.AgentJobDetail_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[AgentJobServer]'
GO
ALTER TABLE [info].[AgentJobServer] DROP CONSTRAINT [FK_Info.AgentJobServer_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[Databases]'
GO
ALTER TABLE [info].[Databases] DROP CONSTRAINT [FK_Databases_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[DiskSpace]'
GO
ALTER TABLE [info].[DiskSpace] DROP CONSTRAINT [FK_DiskSpace_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[ServerOSInfo]'
GO
ALTER TABLE [info].[ServerOSInfo] DROP CONSTRAINT [FK_ServerOSInfo_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[SQLInfo]'
GO
ALTER TABLE [info].[SQLInfo] DROP CONSTRAINT [FK_SQLInfo_InstanceList]
GO
PRINT N'Dropping foreign keys from [info].[SuspectPages]'
GO
ALTER TABLE [info].[SuspectPages] DROP CONSTRAINT [FK_SuspectPages_InstanceList]
GO
PRINT N'Dropping constraints from [dbo].[InstanceList]'
GO
ALTER TABLE [dbo].[InstanceList] DROP CONSTRAINT [PK_InstanceList_ID]
GO
PRINT N'Dropping constraints from [dbo].[InstanceList]'
GO
ALTER TABLE [dbo].[InstanceList] DROP CONSTRAINT [DF_InstanceList_Inactive]
GO
PRINT N'Dropping constraints from [dbo].[InstanceList]'
GO
ALTER TABLE [dbo].[InstanceList] DROP CONSTRAINT [DF_InstanceList_NotContactable]
GO
PRINT N'Dropping constraints from [info].[ServerOSInfo]'
GO
ALTER TABLE [info].[ServerOSInfo] DROP CONSTRAINT [PK__ServerOS__50A5926BC7005F29]
GO
PRINT N'Dropping [info].[ServerOSInfo]'
GO
DROP TABLE [info].[ServerOSInfo]
GO
PRINT N'Rebuilding [dbo].[InstanceList]'
GO
CREATE TABLE [dbo].[RG_Recovery_1_InstanceList]
(
[InstanceID] [int] NOT NULL IDENTITY(1, 1),
[ServerID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[ComputerName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ServerName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[InstanceName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[isClustered] [bit] NOT NULL,
[Port] [int] NOT NULL,
[Inactive] [bit] NULL CONSTRAINT [DF_InstanceList_Inactive] DEFAULT ((0)),
[Environment] [nvarchar] (25) COLLATE Latin1_General_CI_AS NULL,
[Location] [nvarchar] (30) COLLATE Latin1_General_CI_AS NULL,
[NotContactable] [bit] NULL CONSTRAINT [DF_InstanceList_NotContactable] DEFAULT ((0))
) ON [PRIMARY]
GO
SET IDENTITY_INSERT [dbo].[RG_Recovery_1_InstanceList] ON
GO
INSERT INTO [dbo].[RG_Recovery_1_InstanceList]([InstanceID], [ComputerName], [ServerName], [InstanceName], [isClustered], [Port], [Inactive], [Environment], [Location], [NotContactable]) SELECT [InstanceID], [ComputerName], [ServerName], [InstanceName], [isClustered], [Port], [Inactive], [Environment], [Location], [NotContactable] FROM [dbo].[InstanceList]
GO
SET IDENTITY_INSERT [dbo].[RG_Recovery_1_InstanceList] OFF
GO
DECLARE @idVal BIGINT
SELECT @idVal = IDENT_CURRENT(N'[dbo].[InstanceList]')
IF @idVal IS NOT NULL
    DBCC CHECKIDENT(N'[dbo].[RG_Recovery_1_InstanceList]', RESEED, @idVal)
GO
DROP TABLE [dbo].[InstanceList]
GO
EXEC sp_rename N'[dbo].[RG_Recovery_1_InstanceList]', N'InstanceList', N'OBJECT'
GO
PRINT N'Creating primary key [PK_InstanceList_ID] on [dbo].[InstanceList]'
GO
ALTER TABLE [dbo].[InstanceList] ADD CONSTRAINT [PK_InstanceList_ID] PRIMARY KEY CLUSTERED  ([InstanceID]) ON [PRIMARY]
GO
PRINT N'Altering [info].[DiskSpace]'
GO
EXEC sp_rename N'[info].[DiskSpace].[InstanceID]', N'ServerID', N'COLUMN'
GO
PRINT N'Creating [info].[ServerInfo]'
GO
CREATE TABLE [info].[ServerInfo]
(
[ServerID] [int] NOT NULL IDENTITY(1, 1),
[DateChecked] [datetime] NULL,
[ServerName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[DNSHostName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Domain] [nvarchar] (30) COLLATE Latin1_General_CI_AS NULL,
[OperatingSystem] [nvarchar] (100) COLLATE Latin1_General_CI_AS NULL,
[NoProcessors] [tinyint] NULL,
[IPAddress] [nvarchar] (15) COLLATE Latin1_General_CI_AS NULL,
[RAM] [int] NULL,
[InstanceID] [int] NOT NULL
) ON [PRIMARY]
GO
PRINT N'Creating primary key [PK__ServerOS__50A5926BC7005F29] on [info].[ServerInfo]'
GO
ALTER TABLE [info].[ServerInfo] ADD CONSTRAINT [PK__ServerOS__50A5926BC7005F29] PRIMARY KEY CLUSTERED  ([ServerID]) ON [PRIMARY]
GO
PRINT N'Adding foreign keys to [dbo].[InstanceList]'
GO
ALTER TABLE [dbo].[InstanceList] ADD CONSTRAINT [FK_InstanceList_ServerInfo] FOREIGN KEY ([ServerID]) REFERENCES [info].[ServerInfo] ([ServerID])
GO
PRINT N'Adding foreign keys to [info].[DiskSpace]'
GO
ALTER TABLE [info].[DiskSpace] ADD CONSTRAINT [FK_DiskSpace_ServerInfo] FOREIGN KEY ([ServerID]) REFERENCES [info].[ServerInfo] ([ServerID])
GO
PRINT N'Adding foreign keys to [dbo].[ClientDatabaseLookup]'
GO
ALTER TABLE [dbo].[ClientDatabaseLookup] ADD CONSTRAINT [FK_ClientDatabaseLookup_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
PRINT N'Adding foreign keys to [info].[AgentJobDetail]'
GO
ALTER TABLE [info].[AgentJobDetail] ADD CONSTRAINT [FK_info.AgentJobDetail_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
PRINT N'Adding foreign keys to [info].[AgentJobServer]'
GO
ALTER TABLE [info].[AgentJobServer] ADD CONSTRAINT [FK_Info.AgentJobServer_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
PRINT N'Adding foreign keys to [info].[Databases]'
GO
ALTER TABLE [info].[Databases] ADD CONSTRAINT [FK_Databases_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
PRINT N'Adding foreign keys to [info].[SQLInfo]'
GO
ALTER TABLE [info].[SQLInfo] ADD CONSTRAINT [FK_SQLInfo_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
PRINT N'Adding foreign keys to [info].[SuspectPages]'
GO
ALTER TABLE [info].[SuspectPages] ADD CONSTRAINT [FK_SuspectPages_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO

