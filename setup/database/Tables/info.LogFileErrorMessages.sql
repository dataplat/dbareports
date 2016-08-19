CREATE TABLE [info].[LogFileErrorMessages]
(
[FileName] [nvarchar] (100) COLLATE Latin1_General_CI_AS NOT NULL,
[ErrorMsg] [nvarchar] (500) COLLATE Latin1_General_CI_AS NOT NULL,
[Line] [int] NOT NULL,
[Matches] [nvarchar] (12) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
