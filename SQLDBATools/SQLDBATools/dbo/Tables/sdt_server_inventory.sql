CREATE TABLE [dbo].[sdt_server_inventory] (
    [server]                     VARCHAR (500)                                      NOT NULL,
    [friendly_name]              VARCHAR (255)                                      NOT NULL,
    [sql_instance]               VARCHAR (255)                                      NOT NULL,
    [ipv4]                       VARCHAR (15)                                       NULL,
    [stability]                  VARCHAR (20)                                       DEFAULT ('DEV') NULL,
    [priority]                   TINYINT                                            DEFAULT ((4)) NOT NULL,
    [product_version]            VARCHAR (30)                                       NULL,
    [has_hadr]                   BIT                                                DEFAULT ((0)) NOT NULL,
    [hadr_strategy]              VARCHAR (30)                                       NULL,
    [hadr_preferred_role]        VARCHAR (50)                                       NULL,
    [hadr_current_role]          VARCHAR (50)                                       NULL,
    [hadr_partner_friendly_name] VARCHAR (255)                                      NULL,
    [hadr_partner_sql_instance]  VARCHAR (500)                                      NULL,
    [hadr_partner_ipv4]          VARCHAR (15)                                       NULL,
    [server_owner]               VARCHAR (500)                                      NULL,
    [application]                VARCHAR (500)                                      NULL,
    [is_active]                  BIT                                                DEFAULT ((1)) NULL,
    [monitoring_enabled]         BIT                                                DEFAULT ((1)) NULL,
    [other_details]              VARCHAR (500)                                      NULL,
    [rdp_credential]             VARCHAR (125)                                      NULL,
    [sql_credential]             VARCHAR (125)                                      NULL,
    [valid_from]                 DATETIME2 (7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    [valid_to]                   DATETIME2 (7) GENERATED ALWAYS AS ROW END HIDDEN   NOT NULL,
    CONSTRAINT [pk_sdt_server_inventory] PRIMARY KEY CLUSTERED ([friendly_name] ASC),
    CONSTRAINT [chk_sdt_server_inventory__stability] CHECK ([stability]='DEVDR' OR [stability]='UATDR' OR [stability]='QADR' OR [stability]='STGDR' OR [stability]='PRODDR' OR [stability]='PROD' OR [stability]='STG' OR [stability]='QA' OR [stability]='UAT' OR [stability]='DEV'),
    PERIOD FOR SYSTEM_TIME ([valid_from], [valid_to])
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE=[dbo].[sdt_server_inventory_history], DATA_CONSISTENCY_CHECK=ON));


GO
CREATE UNIQUE NONCLUSTERED INDEX [uq_sdt_server_inventory__server__sql_instance]
    ON [dbo].[sdt_server_inventory]([server] ASC, [sql_instance] ASC);


GO
CREATE UNIQUE NONCLUSTERED INDEX [uq_sdt_server_inventory__sql_instance]
    ON [dbo].[sdt_server_inventory]([sql_instance] ASC);


GO
CREATE NONCLUSTERED INDEX [ix_sdt_server_inventory__is_active__monitoring_enabled]
    ON [dbo].[sdt_server_inventory]([is_active] ASC, [monitoring_enabled] ASC);

