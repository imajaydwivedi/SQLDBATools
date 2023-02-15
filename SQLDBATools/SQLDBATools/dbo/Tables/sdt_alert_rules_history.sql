CREATE TABLE [dbo].[sdt_alert_rules_history] (
    [rule_id]                     BIGINT         NOT NULL,
    [alert_key]                   VARCHAR (255)  NOT NULL,
    [server_friendly_name]        VARCHAR (255)  NULL,
    [database_name]               VARCHAR (255)  NULL,
    [client_app_name]             VARCHAR (255)  NULL,
    [login_name]                  VARCHAR (125)  NULL,
    [client_host_name]            VARCHAR (255)  NULL,
    [severity]                    VARCHAR (15)   NULL,
    [severity_low_threshold]      DECIMAL (5, 2) NULL,
    [severity_medium_threshold]   DECIMAL (5, 2) NULL,
    [severity_high_threshold]     DECIMAL (5, 2) NULL,
    [severity_critical_threshold] DECIMAL (5, 2) NULL,
    [alert_receiver]              VARCHAR (500)  NOT NULL,
    [alert_receiver_name]         VARCHAR (120)  NOT NULL,
    [delay_minutes]               SMALLINT       NULL,
    [compute_duration_minutes]    SMALLINT       NULL,
    [start_date]                  DATE           NULL,
    [start_time]                  TIME (7)       NULL,
    [end_date]                    DATE           NULL,
    [end_time]                    TIME (7)       NULL,
    [copy_dba]                    BIT            NOT NULL,
    [created_by]                  VARCHAR (125)  NOT NULL,
    [created_date_utc]            DATETIME       NOT NULL,
    [reference_request]           VARCHAR (125)  NOT NULL,
    [is_active]                   BIT            NOT NULL,
    [valid_from]                  DATETIME2 (7)  NOT NULL,
    [valid_to]                    DATETIME2 (7)  NOT NULL
);


GO
CREATE CLUSTERED INDEX [ix_sdt_alert_rules_history]
    ON [dbo].[sdt_alert_rules_history]([valid_to] ASC, [valid_from] ASC) WITH (DATA_COMPRESSION = PAGE);

