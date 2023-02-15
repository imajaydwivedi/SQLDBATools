CREATE TABLE [dbo].[sdt_alert_rules] (
    [rule_id]                     BIGINT                                             IDENTITY (1, 1) NOT NULL,
    [alert_key]                   VARCHAR (255)                                      NOT NULL,
    [server_friendly_name]        VARCHAR (255)                                      NULL,
    [database_name]               VARCHAR (255)                                      NULL,
    [client_app_name]             VARCHAR (255)                                      NULL,
    [login_name]                  VARCHAR (125)                                      NULL,
    [client_host_name]            VARCHAR (255)                                      NULL,
    [severity]                    VARCHAR (15)                                       NULL,
    [severity_low_threshold]      DECIMAL (5, 2)                                     NULL,
    [severity_medium_threshold]   DECIMAL (5, 2)                                     NULL,
    [severity_high_threshold]     DECIMAL (5, 2)                                     NULL,
    [severity_critical_threshold] DECIMAL (5, 2)                                     NULL,
    [alert_receiver]              VARCHAR (500)                                      NOT NULL,
    [alert_receiver_name]         VARCHAR (120)                                      NOT NULL,
    [delay_minutes]               SMALLINT                                           NULL,
    [compute_duration_minutes]    SMALLINT                                           NULL,
    [start_date]                  DATE                                               NULL,
    [start_time]                  TIME (7)                                           NULL,
    [end_date]                    DATE                                               NULL,
    [end_time]                    TIME (7)                                           NULL,
    [copy_dba]                    BIT                                                DEFAULT ((1)) NOT NULL,
    [created_by]                  VARCHAR (125)                                      DEFAULT (suser_name()) NOT NULL,
    [created_date_utc]            DATETIME                                           DEFAULT (getutcdate()) NOT NULL,
    [reference_request]           VARCHAR (125)                                      NOT NULL,
    [is_active]                   BIT                                                DEFAULT ((1)) NOT NULL,
    [valid_from]                  DATETIME2 (7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    [valid_to]                    DATETIME2 (7) GENERATED ALWAYS AS ROW END HIDDEN   NOT NULL,
    CONSTRAINT [pk_sdt_alert_rules__rule_id] PRIMARY KEY CLUSTERED ([rule_id] ASC),
    CONSTRAINT [chk_sdt_alert_rules__severity] CHECK ([severity]='Low' OR [severity]='Medium' OR [severity]='High' OR [severity]='Critical'),
    PERIOD FOR SYSTEM_TIME ([valid_from], [valid_to])
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE=[dbo].[sdt_alert_rules_history], DATA_CONSISTENCY_CHECK=ON));


GO
CREATE UNIQUE NONCLUSTERED INDEX [nci_uq_sdt_alert_rules__alert_key__plus]
    ON [dbo].[sdt_alert_rules]([alert_key] ASC, [server_friendly_name] ASC, [database_name] ASC, [client_app_name] ASC, [login_name] ASC, [client_host_name] ASC, [severity] ASC) WHERE ([is_active]=(1));

