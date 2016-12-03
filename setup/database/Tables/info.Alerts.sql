CREATE TABLE [Info].[Alerts](

	[AlertsID] [int] IDENTITY(1,1) NOT NULL,

	[CheckDate] [datetime] NULL,

	[InstanceID] [int] NOT NULL,

	[Name] [nvarchar](128) NOT NULL,

	[Category] [nvarchar](128) NULL,

	[DatabaseID] [int] NULL,

	[DelayBetweenResponses] [int] NOT NULL,

	[EventDescriptionKeyword] [nvarchar](100) NULL,

	[EventSource] [nvarchar](100) NULL,

	[HasNotification] [int] NOT NULL,

	[IncludeEventDescription] [nvarchar](128) NOT NULL,

	[IsEnabled] [bit] NOT NULL,

	[AgentJobDetailID] [int] NULL,

	[LastOccurrenceDate] [datetime] NOT NULL,

	[LastResponseDate] [datetime] NOT NULL,

	[MessageID] [int] NOT NULL,

	[NotificationMessage] [nvarchar](512) NULL,

	[OccurrenceCount] [int] NOT NULL,

	[PerformanceCondition] [nvarchar](512) NULL,

	[Severity] [int] NOT NULL,

	[WmiEventNamespace] [nvarchar](512) NULL,

	[WmiEventQuery] [nvarchar](512) NULL

) ON [PRIMARY]