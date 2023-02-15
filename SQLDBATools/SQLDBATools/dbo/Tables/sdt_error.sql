CREATE TABLE [dbo].[sdt_error] (
    [collection_time_utc] DATETIME2 (7)  DEFAULT (getutcdate()) NOT NULL,
    [server]              VARCHAR (500)  NULL,
    [cmdlet]              VARCHAR (125)  NOT NULL,
    [command]             VARCHAR (1000) NULL,
    [error]               VARCHAR (500)  NOT NULL,
    [remark]              VARCHAR (1000) NULL
);

