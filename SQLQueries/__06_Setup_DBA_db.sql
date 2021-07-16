SET NOCOUNT ON;

/* Create Database */
USE master;
IF NOT EXISTS (select * from sys.sysdatabases as s where s.name = 'DBA')
BEGIN
	CREATE DATABASE [DBA]
	--ON
	--( NAME = N'DBA', FILENAME = N'C:\MSSQL12.MSSQLSERVER\MSSQL\DATA\DBA.mdf' , SIZE = 512000KB , FILEGROWTH = 204800KB )
	-- LOG ON 
	--( NAME = N'DBA_log', FILENAME = N'C:\MSSQL12.MSSQLSERVER\MSSQL\DATA\DBA_log.ldf' , SIZE = 512000KB , FILEGROWTH = 200%);
END
GO

USE DBA;
/* Create table to Store Parameter Types */
IF OBJECT_ID('[dbo].[ParamsType]') IS NULL
	CREATE TABLE [dbo].[ParamsType]
	(
		[p_key] [varchar](50) NOT NULL,
		[p_valueExplanation] [varchar](200) NOT NULL,
		 CONSTRAINT [pk_ParamsType] PRIMARY KEY CLUSTERED 
		(
			[p_key] ASC
		)
	)
GO

BEGIN TRY
	INSERT [dbo].[ParamsType]
	([p_key], [p_valueExplanation])
	SELECT 'environment' AS [p_key],'Prod, Stage, QA, Dev, Test' AS [p_valueExplanation]
	union all
	SELECT 'skip backup','Yes,No'
	UNION ALL
	SELECT 'DefaultFullBackupDestination','Local backup directory like F:\Backups\'
END TRY
BEGIN CATCH
	PRINT 'Values already exists in [dbo].[ParamsType].';
END CATCH
GO
--	select * from [dbo].[ParamsType]

/* Create table to Store Parameter Values */
IF OBJECT_ID('[dbo].[Params]') IS NULL
	CREATE TABLE [dbo].[Params]
	(
		[p_key] [varchar](50) NOT NULL,
		[p_value] [varchar](2048) NOT NULL,
		PRIMARY KEY CLUSTERED ([p_key] ASC)
	)
GO

IF OBJECT_ID('FK_Params_ParamsType') IS NULL
	ALTER TABLE [dbo].[Params]  WITH CHECK ADD  CONSTRAINT [FK_Params_ParamsType] 
		FOREIGN KEY([p_key]) REFERENCES [dbo].[ParamsType] ([p_key])
GO

BEGIN TRY
	INSERT [dbo].[Params]
	([p_key], [p_value])
	SELECT 'environment' AS [p_key],'Prod' AS [p_value]
	UNION ALL
	SELECT 'DefaultFullBackupDestination','F:\Backups\'
END TRY
BEGIN CATCH
	PRINT 'Values already added into [dbo].[Params]';
END CATCH
GO
--	select * from dbo.Params

/* Create table for Storing Role Exceptions */
IF OBJECT_ID('[dbo].[ServerRoleMemberException]') IS NULL
	CREATE TABLE [dbo].[ServerRoleMemberException]
	(
		[principal_name] [sysname] NOT NULL,
		[role_permission] [sysname] NOT NULL,
		[added_by] [sysname] NOT NULL,
		[startDTS] [smalldatetime] NOT NULL,
		[endDTS] [smalldatetime] NULL,
		[reason] [varchar](255) NOT NULL,
		[createdOn] [smalldatetime] NOT NULL,
		[expiredFlag] [bit] NOT NULL,
		CONSTRAINT [PK_ServerRoleMemberException] PRIMARY KEY CLUSTERED 
		(
			[principal_name] ASC,
			[role_permission] ASC
		)
	) ON [PRIMARY]
GO

IF OBJECT_ID('[dbo].[usp_AddServerRoleMemberException]') IS NULL
	EXEC ('CREATE PROCEDURE [dbo].[usp_AddServerRoleMemberException] AS SELECT GETDATE() AS DateToday');
GO
ALTER PROCEDURE [dbo].[usp_AddServerRoleMemberException]
	(@p_principal_name VARCHAR(125), @p_role_permission VARCHAR(125), @p_startDTS DATETIME , @p_endDTS DATETIME, @p_reason VARCHAR(500))
AS
BEGIN
/*	Created By:		Ajay Dwivedi
*	Created Date:	30-Apr-2018
*	Purpose:		To Make Data Entry into [dbo].[ServerRoleMemberException]
*					EXEC [dbo].[usp_AddServerRoleMemberException]
DECLARE @startDTS DATETIME, 
		@endDTS DATETIME;
SELECT @startDTS = CURRENT_TIMESTAMP, @endDTS = (DATEADD(hour,24,CURRENT_TIMESTAMP)) -- 24 Hours;

EXEC [dbo].[usp_AddServerRoleMemberException]	@p_principal_name = 'Corporate\adwivedi',
												@p_role_permission = 'Sysadmin', 
												@p_startDTS = @startDTS, @p_endDTS = @endDTS,
												@p_reason = 'For Application Setup'
*/
	INSERT [dbo].[ServerRoleMemberException]
	(principal_name, role_permission, added_by, startDTS, endDTS, reason, createdOn, expiredFlag)
	SELECT	@p_principal_name AS principal_name, @p_role_permission AS role_permission, 
			CAST(SYSTEM_USER AS VARCHAR(125)) AS added_by, @p_startDTS AS startDTS, @p_endDTS AS endDTS, 
			@p_reason AS reason, CURRENT_TIMESTAMP AS createdOn, expiredFlag = 0
	
	SELECT 'Data from [ServerRoleMemberException]' as RunningQuery, principal_name, role_permission, added_by, startDTS, endDTS, reason, createdOn, expiredFlag 
	FROM [dbo].[ServerRoleMemberException];
END
GO


/* Table to Store UnauthorizedPermissionsHistory */
IF OBJECT_ID('[dbo].[UnauthorizedPermissionsHistory]') IS NULL
	CREATE TABLE [dbo].[UnauthorizedPermissionsHistory]
	(
		[id] [int] IDENTITY(1,1) NOT NULL,
		[principalName] [nvarchar](128) NOT NULL,
		[principalType] [nvarchar](60) NOT NULL,
		[rolePermission] [nvarchar](128) NOT NULL,
		[deletedOn] [smalldatetime] NOT NULL,
		CONSTRAINT [PK_UnauthorizedPermissionsHistory] PRIMARY KEY CLUSTERED ([id] ASC)
	)
GO

IF OBJECT_ID('[dbo].[Vw_UnauthorizedServerRoleMembers]') IS NULL
	EXEC ('CREATE VIEW [dbo].[Vw_UnauthorizedServerRoleMembers] AS SELECT GETDATE() AS DateToday')
GO
ALTER VIEW [dbo].[Vw_UnauthorizedServerRoleMembers]
AS
/***************************************************************************************************************************************
*	Created By:		Ajay Dwivedi
*	Created Date:	30-Apr-2018
*	Purpose:		This view returns a list of members that have been granted server-level permissions but are
*					not currently listed in the ServerRoleMemberException table.
***************************************************************************************************************************************/
SELECT	member.name collate database_default as principal_name,
		member.type_desc collate database_default as type_desc,
		[role].name collate database_default as role_permission,
		'role' as roleOrPermission  
FROM	sys.server_principals member inner join 
		sys.server_role_members rm on 
			member.principal_id = rm.member_principal_id inner join 
		sys.server_principals [role] on 
			rm.role_principal_id = [role].principal_id 
where	-- we're only checking server-level permissions
		[role].type_desc = 'SERVER_ROLE' and 
		-- ignore sa, Corporate\SQL Admins, and Corporate\ProdSQL, Any other DBA login require sysadmin
		member.name not in( 'sa', 'Corporate\SQL Admins', 'Corporate\ProdSQL' ) and
		-- bulkadmin is OK to grant to anyone
		[role].name <> 'bulkadmin' and 
		-- everything else needs an exception record
		not exists(	select *
					from dbo.[ServerRoleMemberException] ex
					where	ex.principal_name = member.name collate database_default and
							ex.role_permission = [role].name collate database_default )
union
select	pri.name as principal_name,
		pri.type_desc, 
		per.permission_name as role_permission,
		'permission' as roleOrPermission
from	sys.server_permissions per inner join
		sys.server_principals pri on
			per.grantee_principal_id = pri.principal_id and
			pri.name not like '##%' 
where	-- Grants
		per.state = 'G' and
		-- sa and DBA Logins require sysadmin - ignore them
		pri.name not in( 'sa', 'Corporate\SQL Admins', 'Corporate\ProdSQL' ) and
		-- Ignore permissions we allow without an exception requirement
		per.permission_name not in( 'connect',
									'connect sql',
									'view server state',
									'view any database',
									'administer bulk operations' ) and
		-- Ignore alter trace in dev and test
		not ( per.permission_name = 'alter trace' and (	select lower( p_value ) 
														from dbo.Params 
														where p_key = 'environment' ) in( 'dev', 'test' ) ) and 
		-- everything else needs an exception record
		not exists(	select *
					from dbo.ServerRoleMemberException ex
					where	ex.principal_name = pri.name collate database_default and
							ex.role_permission = per.permission_name collate database_default );

GO

--select * from [dbo].[Vw_UnauthorizedServerRoleMembers]
IF OBJECT_ID('dbo.usp_SecurityCheck') IS NULL
	EXECUTE ('CREATE PROCEDURE [dbo].[usp_SecurityCheck] AS SELECT 1 as DummyCol');
GO
ALTER PROCEDURE [dbo].[usp_SecurityCheck] (@getMailOnly char(1) = 'y')
AS
BEGIN
/*******************************************************************************************************
*	Created By:		Ajay Dwivedi
*	Created Date:	30-Apr-2018
*	Purpose:		This procedure has two major tasks related to unauthorized permissions and exceptions
*					1) purges exceptions that have expired
*					2) removes unauthorized permissions.
*
*******************************************************************************************************/
	set nocount on;

	If (lower( @getMailOnly ) = 'y' )
	Begin
	   select * from [dbo].[Vw_UnauthorizedServerRoleMembers]
	   Return 0
	End;

	declare @errorFlag		tinyint;
	declare @curExpired		cursor;
	declare @curUnauth		cursor;
	declare @account		sysname;
	declare @rolePermission	sysname;
	declare @roleOrPrmsn	varchar(10 );
	declare @acctType		nvarchar( 60 );
	declare @addedBy		sysname;
	declare @startDate		char( 16 );
	declare @endDate		char( 16 );
	declare @sql			nvarchar( 512 );
	declare @logMsg			nvarchar( 255 );

	set @errorFlag = 0

	----------------------------------------------------------------------------------------------------
	-- Set expiredFlag for expired records, then delete them
	-- This will ensure we can identify records in the history table that were expired by this process.
	----------------------------------------------------------------------------------------------------
	update dbo.ServerRoleMemberException
	set expiredFlag = 1
	where endDTS <= getdate();

	delete dbo.ServerRoleMemberException
	where expiredFlag = 1;

	----------------------------------------------------------------------------------------------------
	-- Drop unauthorized server-level permissions and log to the UnauthorizedPermissionsHistory table
	----------------------------------------------------------------------------------------------------
	set @curUnauth= cursor fast_forward for
		select principal_name, type_desc, role_permission, roleOrPermission
		from DBA.dbo.Vw_UnauthorizedServerRoleMembers
		-- Omit sa and Corporate\ProdSQL so we never remove permissions from these two accounts
		-- This is redundant because the Vw_UnauthorizedServerRoleMembers view also omits these two accounts, but
		--  we want redundant ensurances we do not remove these permissions.
		where principal_name not in( 'sa', 'Corporate\ProdSQL', 'Corporate\SQL Admins' );

	open @curUnauth;
	fetch next from @curUnauth into @account, @acctType, @rolePermission, @roleOrPrmsn;
	while @@fetch_status = 0 begin
		insert into dbo.UnauthorizedPermissionsHistory
		( principalName,principalType, rolePermission )
		values( @account, @acctType, @rolePermission );
	
		-- Log failure of insert into history table to the sql server log
		if @@rowCount != 1 begin
			raiserror( 'Error adding unauthorized permission to UnauthorizedPermissionsHistory table for account ''%s'', role ''%s''.', 16, 1, @account, @rolePermission ) with log;
			set @errorFlag = 1;
		end;
	
		-- Even if the insert into our history table fails, we still need to remove these premissions
		if @roleOrPrmsn = 'role' begin
			set @sql = 'EXEC master..sp_dropsrvrolemember @loginame = N''' + @account + ''', @rolename = N''' + @rolePermission + '''';
		end
		else begin
			set @sql = 'use master; revoke ' + @rolePermission + ' to [' + @account + ']';
			-- REVOKE CONTROL SERVER TO [Corporate\Ajay] 
		end;
		--print @sql;
		exec( @sql );
		if @@error != 0 begin
			raiserror( 'Error attempting to drop unauthorized permissions for account ''%s'', role ''%s''.', 16, 1, @account, @rolePermission ) with log;
			set @errorFlag = 1;
		end;
	
		fetch next from @curUnauth into @account, @acctType, @rolePermission, @roleOrPrmsn;
	end;

	if @errorFlag = 1 begin
		raiserror( 'One or more errors occurred in the Security Check procedure.  Review the SQL Server Log for details.', 16, 1 ) with log;
		return 1;
	end;

	return 0;
END -- procedure
GO