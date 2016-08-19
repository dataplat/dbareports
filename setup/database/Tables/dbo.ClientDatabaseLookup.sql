CREATE TABLE [dbo].[ClientDatabaseLookup]
(
[ClientInstanceLookup] [int] NOT NULL IDENTITY(1, 1),
[ClientID] [int] NOT NULL,
[DatabaseID] [int] NOT NULL,
[InstanceID] [int] NULL,
[Notes] [nvarchar] (250) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ClientDatabaseLookup] ADD CONSTRAINT [PK_ClientInstanceLookup] PRIMARY KEY CLUSTERED  ([ClientInstanceLookup]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ClientDatabaseLookup] ADD CONSTRAINT [FK_ClientDatabaseLookup_Clients] FOREIGN KEY ([ClientID]) REFERENCES [dbo].[Clients] ([ClientID])
GO
ALTER TABLE [dbo].[ClientDatabaseLookup] ADD CONSTRAINT [FK_ClientDatabaseLookup_Databases] FOREIGN KEY ([DatabaseID]) REFERENCES [info].[Databases] ([DatabaseID])
GO
ALTER TABLE [dbo].[ClientDatabaseLookup] ADD CONSTRAINT [FK_ClientDatabaseLookup_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
