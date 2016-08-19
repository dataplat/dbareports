CREATE TABLE [info].[SuspectPages]
(
[SuspectPageID] [int] NOT NULL IDENTITY(1, 1),
[DatabaseID] [int] NOT NULL,
[DateChecked] [datetime] NOT NULL,
[FileName] [varchar] (2000) COLLATE Latin1_General_CI_AS NOT NULL,
[Page_id] [bigint] NOT NULL,
[EventType] [nvarchar] (24) COLLATE Latin1_General_CI_AS NOT NULL,
[Error_count] [int] NOT NULL,
[last_update_date] [datetime] NOT NULL,
[InstanceID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [info].[SuspectPages] ADD CONSTRAINT [PK_SuspectPages] PRIMARY KEY CLUSTERED  ([SuspectPageID]) ON [PRIMARY]
GO
ALTER TABLE [info].[SuspectPages] ADD CONSTRAINT [FK_SuspectPages_Databases] FOREIGN KEY ([DatabaseID]) REFERENCES [info].[Databases] ([DatabaseID])
GO
ALTER TABLE [info].[SuspectPages] ADD CONSTRAINT [FK_SuspectPages_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE