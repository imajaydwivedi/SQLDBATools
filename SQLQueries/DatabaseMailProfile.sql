--Created By:		Ajay Dwivedi
--Created Date:	09-Feb-2018
--Updated Date:	09-Feb-2018
--Version:		0.0
--Purpose:		Create/Update Mail Profile in YourOrg SQL Server Environments

SET NOCOUNT ON;

--	Declare variables and other objects
DECLARE @verbose BIT = 1;

DECLARE @DisplayName SYSNAME;
DECLARE @ProfilesAccounts TABLE 
(	profile_id INT, 
	profile_name SYSNAME, 
	account_id INT, 
	account_name SYSNAME, 
	sequence_number INT
);
DECLARE @profile_name SYSNAME, @account_name SYSNAME, @sequence_number INT;

-- Set Display name with Instance/Server Name
SELECT @DisplayName = CASE WHEN CHARINDEX('\',@@SERVERNAME) = 0 THEN 'SQL Alerts - '+@@SERVERNAME ELSE 'SQL Alerts - '+REPLACE(@@SERVERNAME,'\','(')+')' END;
--SET @DisplayName = 'SQL Alerts - '+@@SERVERNAME;
IF @verbose = 1
	SELECT [@DisplayName] = @DisplayName;


-- Find out all Mail Profiles with Account Details
IF @verbose = 1
	PRINT 'Find out all Mail Profiles with Account Details';
INSERT @ProfilesAccounts
EXECUTE msdb.dbo.sysmail_help_profileaccount_sp --@profile_name = @@SERVERNAME ;  

-- Create Mail Account and Attach it with Profile if NOT EXISTS
	-- Also, change the Sequence Number for other accounts
-- Find out all Mail Profiles with Account Details
IF @verbose = 1
BEGIN
	PRINT 'Create Mail Account and Attach it with Profile if NOT EXISTS';
	PRINT '		Also, change the Sequence Number for other accounts';
END
IF NOT EXISTS (SELECT * FROM @ProfilesAccounts as a WHERE a.profile_name = @@SERVERNAME AND a.account_name = 'SQLAlerts')
	OR EXISTS (SELECT * FROM @ProfilesAccounts as a WHERE a.profile_name = @@SERVERNAME AND sequence_number = 1 AND a.account_name <> 'SQLAlerts')
	OR NOT EXISTS(SELECT * FROM msdb..sysmail_account a WHERE a.name = 'SQLAlerts' AND a.email_address = 'SQLAlerts@YourOrg.com' AND a.display_name = @DisplayName)
BEGIN
	-- Create Database Mail account for SQLAlerts if NOT EXISTS
	IF NOT EXISTS (SELECT * FROM [msdb]..[sysmail_account] as a WHERE a.name = 'SQLAlerts')
	BEGIN
		IF @verbose = 1
			PRINT 'EXECUTE msdb.dbo.sysmail_add_account_sp  ';
		EXECUTE msdb.dbo.sysmail_add_account_sp  
			@account_name = 'SQLAlerts',  
			@description = 'Mail account for alerts',  
			@email_address = 'SQLAlerts@YourOrg.com',--'SQLAlerts@YourCompany.com',  
			@replyto_address = 'dba-group@YourOrg.com',  
			@display_name = @DisplayName,  
			@mailserver_name = 'relay.corporate.local';
	END
	ELSE
	BEGIN
		IF @verbose = 1
			PRINT 'EXECUTE msdb.dbo.sysmail_update_account_sp'
		IF NOT EXISTS(SELECT * FROM msdb..sysmail_account a WHERE a.name = 'SQLAlerts' AND a.email_address = 'SQLAlerts@YourOrg.com' AND a.display_name = @DisplayName)
		BEGIN		
			EXECUTE msdb.dbo.sysmail_update_account_sp  
					 @account_name = 'SQLAlerts',  
					@description = 'Mail account for alerts',  
					@email_address = 'SQLAlerts@YourOrg.com',--'SQLAlerts@YourCompany.com',  
					@replyto_address = 'dba-group@YourOrg.com',  
					@display_name = @DisplayName,  
					@mailserver_name = 'relay.corporate.local'; 
		END
	END
	
	
	-- Create a Database Mail profile if NOT EXISTS 
	IF NOT EXISTS ( SELECT * FROM msdb..sysmail_profile as p WHERE p.name = @@SERVERNAME )
	BEGIN
		IF @verbose = 1
			PRINT 'EXECUTE msdb.dbo.sysmail_add_profile_sp ';
		EXECUTE msdb.dbo.sysmail_add_profile_sp  
			@profile_name = @@SERVERNAME,  
			@description = 'Local default mail profile' ;
	END

	-- Add the account to the profile
	IF NOT EXISTS (SELECT * FROM @ProfilesAccounts as a WHERE a.profile_name = @@SERVERNAME AND a.account_name = 'SQLAlerts')
	EXECUTE msdb.dbo.sysmail_add_profileaccount_sp  
		@profile_name = @@SERVERNAME,  
		@account_name = 'SQLAlerts',  
		@sequence_number = 1 ;  

	-- Update Existing Account Sequence Number greater than 1
	IF EXISTS (SELECT * FROM @ProfilesAccounts as a WHERE a.profile_name = @@SERVERNAME AND a.account_name <> 'SQLAlerts' AND sequence_number = 1)
	BEGIN
		DECLARE C CURSOR LOCAL FAST_FORWARD FOR
			SELECT a.profile_name, a.account_name, a.sequence_number 
			FROM @ProfilesAccounts as a 
			WHERE a.profile_name = @@SERVERNAME AND a.account_name <> 'SQLAlerts';

		OPEN C; 
		FETCH C INTO @profile_name, @account_name, @sequence_number ;

		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			SET @sequence_number = @sequence_number + 1;
			-- Modify Sequence Number
			EXECUTE msdb..sysmail_update_profileaccount_sp
					@profile_name = @profile_name
					,@account_name = @account_name
					,@sequence_number = @sequence_number;

			FETCH C INTO @profile_name, @account_name, @sequence_number;
		END
	END
END;

-- Grant access to the profile to all users in the msdb database if NOT EXISTS
IF EXISTS (SELECT * FROM msdb..sysmail_profile as p 
						inner join msdb..sysmail_principalprofile AS pp
					ON pp.profile_id = p.profile_id AND p.name = @@SERVERNAME
					WHERE is_default <> 1
)
BEGIN
	BEGIN TRY
		EXECUTE msdb.dbo.sysmail_add_principalprofile_sp  
			@profile_name = @@SERVERNAME,  
			@principal_name = 'public',
			@is_default = 1 ;
	END TRY
	BEGIN CATCH
		PRINT 'Some error occurred during EXECUTE msdb.dbo.sysmail_add_principalprofile_sp  '
	END CATCH
END


-- Test Mail Profile by Sending Dummy Mail
	EXEC msdb.dbo.sp_send_dbmail  
		@profile_name = @@SERVERNAME,  
		@recipients = 'ajay.dwivedi@YourOrg.com',  
		--@copy_recipients = 'dba-group@YourOrg.com',
		@body = 'This is Test Mail. Kindly verify the EMail Account and Display Name.',  
		@subject = 'Test Mail for New SQLAlerts Account' ;

