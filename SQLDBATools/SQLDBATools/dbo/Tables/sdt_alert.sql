CREATE TABLE [dbo].[sdt_alert] (
    [id]                      BIGINT         IDENTITY (1, 1) NOT NULL,
    [created_date_utc]        DATETIME2 (7)  DEFAULT (sysutcdatetime()) NOT NULL,
    [alert_key]               VARCHAR (255)  NOT NULL,
    [email_to]                VARCHAR (500)  NOT NULL,
    [state]                   VARCHAR (15)   DEFAULT ('Active') NOT NULL,
    [severity]                VARCHAR (15)   DEFAULT ('High') NOT NULL,
    [last_occurred_date_utc]  DATETIME       DEFAULT (getutcdate()) NOT NULL,
    [last_notified_date_utc]  DATETIME       DEFAULT (getutcdate()) NOT NULL,
    [notification_counts]     INT            DEFAULT ((1)) NOT NULL,
    [suppress_start_date_utc] DATETIME       NULL,
    [suppress_end_date_utc]   DATETIME       NULL,
    [servers_affected]        VARCHAR (1000) NULL,
    CONSTRAINT [pk_sdt_alert] PRIMARY KEY CLUSTERED ([id] ASC),
    CONSTRAINT [chk_sdt_alert__severity] CHECK ([severity]='Low' OR [severity]='Medium' OR [severity]='High' OR [severity]='Critical'),
    CONSTRAINT [chk_sdt_alert__state] CHECK ([state]='Cleared' OR [state]='Suppressed' OR [state]='Active'),
    CONSTRAINT [chk_sdt_alert__suppress_state] CHECK (case when [state]<>'Suppressed' then (1) when [state]='Suppressed' AND ([suppress_start_date_utc] IS NULL OR [suppress_end_date_utc] IS NULL) then (0) when [state]='Suppressed' AND datediff(day,[suppress_start_date_utc],[suppress_end_date_utc])>=(7) then (0) else (1) end=(1))
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [uq_sdt_alert__alert_key__severity__active]
    ON [dbo].[sdt_alert]([alert_key] ASC, [severity] ASC, [email_to] ASC) WHERE ([state] IN ('Active', 'Suppressed'));


GO
CREATE NONCLUSTERED INDEX [ix_sdt_alert__created_date_utc__alert_key]
    ON [dbo].[sdt_alert]([created_date_utc] ASC, [alert_key] ASC);


GO
CREATE NONCLUSTERED INDEX [ix_sdt_alert__state__active]
    ON [dbo].[sdt_alert]([state] ASC) WHERE ([state] IN ('Active', 'Suppressed'));


GO
CREATE NONCLUSTERED INDEX [ix_sdt_alert__servers_affected]
    ON [dbo].[sdt_alert]([servers_affected] ASC);

