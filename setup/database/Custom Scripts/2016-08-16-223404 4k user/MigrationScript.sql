/*
This migration script replaces uncommitted changes made to these objects:
ServerInfo

Use this script to make necessary schema and data changes for these objects only. Schema changes to any other objects won't be deployed.

Schema changes and migration scripts are deployed in the order they're committed.
*/

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Altering [info].[ServerInfo]'
GO
ALTER TABLE [info].[ServerInfo] DROP
COLUMN [InstanceID]
GO

