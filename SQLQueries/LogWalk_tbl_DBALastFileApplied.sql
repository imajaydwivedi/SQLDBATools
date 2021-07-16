USE [DBA]
GO

CREATE TABLE [dbo].[DBALastFileApplied](
	[dbname] [varchar](50) NULL,
	[LastFileApplied] [varchar](100) NULL,
	[lastUpdateDate] [datetime] NULL,
	[PointerResetFile] [varchar](100) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DBALastFileApplied] ADD  DEFAULT (getdate()) FOR [lastUpdateDate]
GO