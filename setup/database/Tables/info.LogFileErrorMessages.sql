CREATE TABLE [info].[LogFileErrorMessages](
	[LogFileErrorMessagesID] [int] IDENTITY(1,1) NOT NULL,
	[Date] [date] NOT NULL,
	[FileName] [nvarchar](100) NOT NULL,
	[ErrorMsg] [nvarchar](500) NOT NULL,
	[Line] [int] NOT NULL,
	[Matches] [nvarchar](12) NULL,
 CONSTRAINT [PK_LogFileErrorMessages] PRIMARY KEY CLUSTERED 
(
	[LogFileErrorMessagesID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
