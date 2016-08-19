CREATE TABLE [info].[AgentJobDetail]
(
[AgentJobDetailID] [int] NOT NULL IDENTITY(1, 1),
[DateCreated] [datetime] NOT NULL,
[InstanceID] [int] NOT NULL,
[Category] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[JobName] [nvarchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[Description] [nvarchar] (750) COLLATE Latin1_General_CI_AS NOT NULL,
[IsEnabled] [bit] NOT NULL,
[Status] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[LastRunTime] [datetime] NULL,
[Outcome] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Date] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [info].[AgentJobDetail] ADD CONSTRAINT [PK_info.AgentJobDetail] PRIMARY KEY CLUSTERED  ([AgentJobDetailID]) ON [PRIMARY]
GO
ALTER TABLE [info].[AgentJobDetail] ADD CONSTRAINT [FK_info.AgentJobDetail_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
