CREATE TABLE [info].[Alerts](
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
	[LastOccurrenceDate] [datetime] NULL,
	[LastResponseDate] [datetime] NULL,
	[MessageID] [int] NOT NULL,
	[NotificationMessage] [nvarchar](512) NULL,
	[OccurrenceCount] [int] NOT NULL,
	[PerformanceCondition] [nvarchar](512) NULL,
	[Severity] [int] NOT NULL,
	[WmiEventNamespace] [nvarchar](512) NULL,
	[WmiEventQuery] [nvarchar](512) NULL,
 CONSTRAINT [PK_Alerts] PRIMARY KEY CLUSTERED 
(
	[AlertsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO