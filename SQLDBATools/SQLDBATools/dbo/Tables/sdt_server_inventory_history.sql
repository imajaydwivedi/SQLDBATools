CREATE TABLE [dbo].[sdt_server_inventory_history] (
    [server]                     VARCHAR (500) NOT NULL,
    [friendly_name]              VARCHAR (255) NOT NULL,
    [sql_instance]               VARCHAR (255) NOT NULL,
    [ipv4]                       VARCHAR (15)  NULL,
    [stability]                  VARCHAR (20)  NULL,
    [priority]                   TINYINT       NOT NULL,
    [product_version]            VARCHAR (30)  NULL,
    [has_hadr]                   BIT           NOT NULL,
    [hadr_strategy]              VARCHAR (30)  NULL,
    [hadr_preferred_role]        VARCHAR (50)  NULL,
    [hadr_current_role]          VARCHAR (50)  NULL,
    [hadr_partner_friendly_name] VARCHAR (255) NULL,
    [hadr_partner_sql_instance]  VARCHAR (500) NULL,
    [hadr_partner_ipv4]          VARCHAR (15)  NULL,
    [server_owner]               VARCHAR (500) NULL,
    [application]                VARCHAR (500) NULL,
    [is_active]                  BIT           NULL,
    [monitoring_enabled]         BIT           NULL,
    [other_details]              VARCHAR (500) NULL,
    [rdp_credential]             VARCHAR (125) NULL,
    [sql_credential]             VARCHAR (125) NULL,
    [valid_from]                 DATETIME2 (7) NOT NULL,
    [valid_to]                   DATETIME2 (7) NOT NULL
);


GO
CREATE CLUSTERED INDEX [ix_sdt_server_inventory_history]
    ON [dbo].[sdt_server_inventory_history]([valid_to] ASC, [valid_from] ASC) WITH (DATA_COMPRESSION = PAGE);

