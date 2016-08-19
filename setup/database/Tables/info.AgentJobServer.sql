CREATE TABLE [info].[AgentJobServer]
(
[AgentJobServerID] [int] NOT NULL IDENTITY(1, 1),
[Date] [datetime] NOT NULL,
[InstanceID] [int] NOT NULL,
[NumberOfJobs] [int] NOT NULL,
[SuccessfulJobs] [int] NOT NULL,
[FailedJobs] [int] NOT NULL,
[DisabledJobs] [int] NOT NULL,
[UnknownJobs] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [info].[AgentJobServer] ADD CONSTRAINT [PK_Info.AgentJobServer] PRIMARY KEY CLUSTERED  ([AgentJobServerID]) ON [PRIMARY]
GO
ALTER TABLE [info].[AgentJobServer] ADD CONSTRAINT [FK_Info.AgentJobServer_InstanceList] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[InstanceList] ([InstanceID]) ON DELETE CASCADE
GO
