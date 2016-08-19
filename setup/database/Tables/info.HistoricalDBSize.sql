CREATE TABLE [info].[HistoricalDBSize]
(
[DatabaseSizeHistoryID] [int] NOT NULL IDENTITY(1, 1),
[DatabaseID] [int] NOT NULL,
[InstanceID] [int] NOT NULL,
[Name] [nvarchar] (256) COLLATE Latin1_General_CI_AS NULL,
[DateChecked] [date] NULL,
[SizeMB] [float] NULL,
[SpaceAvailableKB] [float] NULL
) ON [PRIMARY]
GO
ALTER TABLE [info].[HistoricalDBSize] ADD CONSTRAINT [PK_HistoricalDBSizeNew] PRIMARY KEY CLUSTERED  ([DatabaseSizeHistoryID]) ON [PRIMARY]
GO
ALTER TABLE [info].[HistoricalDBSize] ADD CONSTRAINT [FK_HistoricalDBSize_Databases] FOREIGN KEY ([DatabaseID]) REFERENCES [info].[Databases] ([DatabaseID])
GO
