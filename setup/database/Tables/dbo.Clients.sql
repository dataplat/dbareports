CREATE TABLE [dbo].[Clients]
(
[ClientID] [int] NOT NULL IDENTITY(1, 1),
[ClientName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[External] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Clients] ADD CONSTRAINT [PK_dbo.Clients] PRIMARY KEY CLUSTERED  ([ClientID]) ON [PRIMARY]
GO
