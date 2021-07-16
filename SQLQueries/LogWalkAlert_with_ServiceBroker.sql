--	===============================================================================================================
--	Step 01:	Configure ServiceBroker (Enable, Create Message Type, Create Contract, Create Queue, Create Service)
--	Step 02:	Create Procedure for Sending Message
--	Step 03:	Create Function fn_IsJobRunning
--	Step 04:	Create Procedure for Processing Message
--	Step 05:	Create Job for timing the Processing of Message
--	Step 06:	Create WhoIsActive clensing job
--	Step 07:	Add Procedure usp_SendWhoIsActiveMessage in Log Walk jobs
--	Step 08:	Create procedure DBA..[usp_GetLogWalkJobHistoryAlert_Suppress], and dependent Objects dbo.fn_GetNextCollectionTime, dbo.usp_WhoIsActive_Blocking, [DBA]..[usp_GetMail_4_SQLAlerts]
--	Step 09:	Add a step for Job in [DBA Log Walk Alerts] job
--	===============================================================================================================

-- Enable Service Broker and switch to the database
USE master;
GO

IF NOT EXISTS (select * from sys.databases as d where d.name = 'DBA' and d.is_broker_enabled = 1)
BEGIN
	EXEC master..sp_Kill @p_DbName = 'DBA', @p_Force = 1;
	ALTER DATABASE DBA SET ENABLE_BROKER;
END
GO

USE DBA;
GO

IF NOT EXISTS (SELECT * FROM sys.service_message_types as m WHERE m.name = 'WhoIsActiveMessage')
BEGIN
	-- Create the message types
	CREATE MESSAGE TYPE
		   [WhoIsActiveMessage]
		   VALIDATION = WELL_FORMED_XML;
END
GO

IF NOT EXISTS (SELECT * FROM sys.service_contracts as m WHERE m.name = 'WhoIsActiveContract')
BEGIN
	-- Create the contract
	CREATE CONTRACT [WhoIsActiveContract]
		  ([WhoIsActiveMessage]
		   SENT BY INITIATOR);
END
GO

IF NOT EXISTS (SELECT * FROM sys.service_queues as m WHERE m.name = 'WhoIsActiveQueue')
BEGIN
	-- Create the target queue and service
	CREATE QUEUE WhoIsActiveQueue;
END
GO

IF NOT EXISTS (SELECT * FROM sys.services as m WHERE m.name = 'WhoIsActiveService')
BEGIN
	CREATE SERVICE [WhoIsActiveService] ON QUEUE WhoIsActiveQueue ([WhoIsActiveContract]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.service_queues as m WHERE m.name = 'WhoIsActiveQueue')
BEGIN
	ALTER QUEUE WhoIsActiveQueue WITH STATUS = ON
END
GO

--	Step 02:	Create Procedure for Sending Message
USE DBA;
GO

IF OBJECT_ID('DBA..usp_SendWhoIsActiveMessage') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_SendWhoIsActiveMessage AS SELECT 1 as Dummy;');
GO

ALTER PROCEDURE dbo.usp_SendWhoIsActiveMessage (@p_JobName varchar(225), @p_verbose bit = 0)
AS
BEGIN
	/*
		Created By:		Ajay Dwivedi
		Version:		0.0
		Modifications:	(26-Apr-2019) Creating Proc for 1st time
	*/

	-- Begin a conversation and send a request message
	DECLARE @conversation_handle UNIQUEIDENTIFIER;
	DECLARE @message_body XML;

	BEGIN TRANSACTION;

	BEGIN DIALOG @conversation_handle
		 FROM SERVICE [WhoIsActiveService]
		 TO SERVICE   N'WhoIsActiveService'
		 ON CONTRACT  [WhoIsActiveContract]
		 WITH ENCRYPTION = OFF;

	SELECT @message_body = N'<WhoIsActiveMessage>'+@p_JobName+'</WhoIsActiveMessage>';

	SEND ON CONVERSATION @conversation_handle
		 MESSAGE TYPE [WhoIsActiveMessage]
		 (@message_body);

	IF @p_verbose = 1
		PRINT '@message_body = '''+CAST(@message_body AS VARCHAR(255))+'''';

	COMMIT TRANSACTION;
END
GO

--	Step 03 - Create Function fn_IsJobRunning
USE DBA
GO
IF OBJECT_ID('dbo.fn_IsJobRunning') IS NULL
	EXEC ('CREATE FUNCTION dbo.fn_IsJobRunning() RETURNS BIT BEGIN RETURN 1 END');
GO
ALTER FUNCTION dbo.fn_IsJobRunning(@p_JobName VARCHAR(2000)) 
	RETURNS BIT
AS
BEGIN
	/*	Created By:			Ajay Dwivedi
		Version:			0.0
		Modifications:		(Apr 07, 2019) - Created for 1st Time
	*/
	DECLARE @returnValue BIT
	SET @returnValue = 0;

	IF EXISTS(	SELECT	1
				FROM msdb.dbo.sysjobactivity ja 
				LEFT JOIN msdb.dbo.sysjobhistory jh 
					ON ja.job_history_id = jh.instance_id
				JOIN msdb.dbo.sysjobs j 
				ON ja.job_id = j.job_id
				JOIN msdb.dbo.sysjobsteps js
					ON ja.job_id = js.job_id
					AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
				WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
				AND ja.start_execution_date is not null
				AND ja.stop_execution_date is null
				AND LTRIM(RTRIM(j.name)) = @p_JobName
	)
	BEGIN
		SET @returnValue = 1;
	END

	RETURN @returnValue
END
GO

--	Step 04:	Create Procedure for Processing Message
USE DBA
GO

IF OBJECT_ID('DBA..WhoIsActiveCallerDetails') IS NULL
BEGIN
	CREATE TABLE DBA..WhoIsActiveCallerDetails
		(JobName varchar(255) not null, collection_time smalldatetime default getdate())
END
GO

USE DBA;
GO

IF OBJECT_ID('DBA..usp_ProcessWhoIsActiveMessage') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_ProcessWhoIsActiveMessage AS SELECT 1 as Dummy;');
GO

ALTER PROCEDURE dbo.usp_ProcessWhoIsActiveMessage (@p_verbose bit = 0)
AS
BEGIN -- Procedure body
	/*
		Created By:		Ajay Dwivedi
		Version:		0.0
		Modification:	(26-Apr-2019) Creating Proc for 1st time
	*/
	SET NOCOUNT ON;
	
	-- Receive the request and send a reply
	DECLARE @conversation_handle UNIQUEIDENTIFIER;
	DECLARE @message_body XML;
	DECLARE @message_type_name sysname;
	DECLARE @isExecutedOnce bit = 0;
	DECLARE @jobName varchar(255);
	DECLARE @_ErrorMessage varchar(max);
	DECLARE @l_counter INT = 1;
	DECLARE @l_counter_max INT;

	IF EXISTS (SELECT * FROM sys.service_queues WHERE name = 'WhoIsActiveQueue' AND (is_receive_enabled = 0 OR is_enqueue_enabled = 0))
		ALTER QUEUE WhoIsActiveQueue WITH STATUS = ON;

	SELECT @l_counter_max = COUNT(*) FROM WhoIsActiveQueue;

	WHILE @l_counter <= @l_counter_max
	BEGIN -- Loop Body
		BEGIN TRANSACTION;
		--WAITFOR ( 
			RECEIVE TOP(1)
			@conversation_handle = conversation_handle,
			@message_body = message_body,
			@message_type_name = message_type_name
		  FROM WhoIsActiveQueue
		--), TIMEOUT 1000;

		IF (@message_type_name = N'WhoIsActiveMessage')
		BEGIN
			SET @jobName = CAST(@message_body AS XML).value('(/WhoIsActiveMessage)[1]', 'varchar(125)' );

			INSERT DBA..WhoIsActiveCallerDetails (JobName)
			SELECT @jobName AS JobName;

			IF @isExecutedOnce = 0 OR DBA.dbo.fn_IsJobRunning(@jobName) = 1
			BEGIN
				
				IF DBA.dbo.fn_IsJobRunning('DBA - Log_With_sp_WhoIsActive') = 0
					EXEC msdb..sp_start_job @job_name = 'DBA - Log_With_sp_WhoIsActive';
				ELSE
					PRINT 'Job ''DBA - Log_With_sp_WhoIsActive'' is already running.';
					SET @isExecutedOnce = 1;
			END

			END CONVERSATION @conversation_handle;
		END

		-- Remember to cleanup dialogs by handling EndDialog messages 
		ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
		BEGIN
			 END CONVERSATION @conversation_handle;
		END

		COMMIT TRANSACTION;

		WAITFOR DELAY '00:00:05';
		SET @l_counter = @l_counter + 1;
	END -- Loop Body
END -- Procedure body
GO

USE [msdb]
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysoperators as o where o.name = 'DBAGroup')
BEGIN
	EXEC msdb.dbo.sp_add_operator @name=N'DBAGroup', 
			@enabled=1, 
			@weekday_pager_start_time=90000, 
			@weekday_pager_end_time=180000, 
			@saturday_pager_start_time=90000, 
			@saturday_pager_end_time=180000, 
			@sunday_pager_start_time=90000, 
			@sunday_pager_end_time=180000, 
			@pager_days=0, 
			@email_address=N'IT-Ops-SQLDBA@YourOrg.com', 
			@category_name=N'[Uncategorized]'
END
GO



--	Step 05:	Create Job for timing the Processing of Message
USE [msdb]
GO

IF NOT EXISTS (select * from msdb.dbo.sysjobs as j where j.name = 'DBA - Process - WhoIsActiveQueue')
BEGIN
	BEGIN TRANSACTION
	DECLARE @ReturnCode INT
	SELECT @ReturnCode = 0
	
	IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA' AND category_class=1)
	BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	END

	DECLARE @jobId BINARY(16)
	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - Process - WhoIsActiveQueue', 
			@enabled=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'No description available.', 
			@category_name=N'DBA', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Process Message', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'TSQL', 
			@command=N'SET QUOTED_IDENTIFIER ON;

	EXEC DBA.dbo.usp_ProcessWhoIsActiveMessage', 
			@database_name=N'DBA', 
			@flags=0
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every_10_Seconds', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=2, 
			@freq_subday_interval=10, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20190425, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235959, 
			@schedule_uid=N'29e0ecba-2881-4e14-b8e4-1ee28ed2002c'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every_10_Seconds', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=2, 
			@freq_subday_interval=10, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20190426, 
			@active_end_date=99991231, 
			@active_start_time=2, 
			@active_end_time=235959, 
			@schedule_uid=N'69acdb29-1462-449b-9bb4-c657a50aa839'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every_10_Seconds', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=2, 
			@freq_subday_interval=10, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20190426, 
			@active_end_date=99991231, 
			@active_start_time=4, 
			@active_end_time=235959, 
			@schedule_uid=N'fa623cce-fad3-47a5-9cee-e3252fe9a88c'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every_10_Seconds', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=2, 
			@freq_subday_interval=10, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20190426, 
			@active_end_date=99991231, 
			@active_start_time=6, 
			@active_end_time=235959, 
			@schedule_uid=N'26eef721-bb9c-4c69-8139-de3f318264b0'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every_10_Seconds', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=2, 
			@freq_subday_interval=10, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20190426, 
			@active_end_date=99991231, 
			@active_start_time=8, 
			@active_end_time=235959, 
			@schedule_uid=N'11728ac2-0102-4db4-a19e-bbdf9bec7a3b'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	COMMIT TRANSACTION
	GOTO EndSave
	QuitWithRollback:
		IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
	EndSave:
END
GO

--	Step 06:	Create WhoIsActive clensing job
USE [msdb]
GO

IF EXISTS (select * from msdb.dbo.sysjobs as j where j.name = 'DBA - Log_With_sp_WhoIsActive - Cleanup')
BEGIN
	EXEC msdb.dbo.sp_delete_job @job_name = N'DBA - Log_With_sp_WhoIsActive - Cleanup'
END
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - Log_With_sp_WhoIsActive - Cleanup', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Cleanup job to clear data older than 60 days

SET NOCOUNT ON;
delete from dbo.WhoIsActive_ResultSets
	where collection_time <= DATEADD(DD,-60,GETDATE())', 
		@category_name=N'DBA', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge-WhoIsActive_ResultSets', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=7, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
delete from dbo.WhoIsActive_ResultSets
	where collection_time <= DATEADD(DD,-60,GETDATE())', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge-WhoIsActiveCallerDetails', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DELETE FROM DBA.dbo.WhoIsActiveCallerDetails 
WHERE collection_time <= DATEADD(DD,-60,GETDATE());', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'2 Times a week', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=35, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190408, 
		@active_end_date=99991231, 
		@active_start_time=235700, 
		@active_end_time=235959, 
		@schedule_uid=N'8f0b13cd-1933-4061-9a79-3f7175abea97'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


--	Step 07:	Add Procedure usp_SendWhoIsActiveMessage in Log Walk jobs
exec DBA.dbo.usp_SendWhoIsActiveMessage @p_JobName = 'DBA Log Walk - Restore Staging as Staging';


-- Step 08:		Create procedure DBA..[usp_GetLogWalkJobHistoryAlert_Suppress], and dependent Objects dbo.fn_GetNextCollectionTime, dbo.usp_WhoIsActive_Blocking, [DBA]..[usp_GetMail_4_SQLAlerts]
USE [DBA]
GO

IF EXISTS (SELECT * FROM   sys.objects WHERE  object_id = OBJECT_ID('dbo.fn_GetNextCollectionTime') AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
	DROP FUNCTION dbo.fn_GetNextCollectionTime
GO

CREATE FUNCTION dbo.fn_GetNextCollectionTime (@p_Collection_Time datetime = NULL)
RETURNS datetime AS 
BEGIN
	/*	Created By:			Ajay Dwivedi
		Version:			0.0
		Modification:		(May 13, 2019) - Creating for 1st time
	*/
	DECLARE @collection_time datetime;

	SELECT	@collection_time = MIN(r.collection_time)
	FROM	dbo.WhoIsActive_ResultSets as r
	WHERE	r.collection_time >= cast(@p_Collection_Time as datetime);
	
	RETURN (@collection_time);
END
GO


USE DBA
GO

IF OBJECT_ID('dbo.usp_GetMail_4_SQLAlerts') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_GetMail_4_SQLAlerts AS SELECT 1 AS DummyToBeReplace;');
GO
ALTER PROCEDURE [dbo].[usp_GetMail_4_SQLAlerts] ( 
						@p_Option VARCHAR(50) = 'JobBlockers'
						,@p_JobName VARCHAR(255) = 'DBA Log Walk - Restore Staging as Staging'
						,@p_Verbose BIT = 0
						,@p_DefaultHTMLStyle VARCHAR(100) = 'GreenBackgroundHeader'
						,@p_recipients VARCHAR(255) = NULL
					)
AS
BEGIN
	/*	Created By:		Ajay Dwivedi
		Created Date:	29-Apr-2019
		Purpose:		This procedure accepts category for mailer, and send mail for SQLAlerts
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		PRINT 'Declaring Variables';
	DECLARE @mailHTML  NVARCHAR(MAX) ;
	DECLARE @subject VARCHAR(200);
	DECLARE @tableName VARCHAR(125);
	DECLARE @columnList4TableHeader VARCHAR(MAX);
	DECLARE @columnList4TableData VARCHAR(MAX);
	DECLARE @cssStyle_GreenBackgroundHeader VARCHAR(MAX);
	DECLARE @htmlBody VARCHAR(MAX);
	DECLARE @sqlString VARCHAR(MAX);
	DECLARE @data4TableData TABLE ( TableData VARCHAR(MAX) );
	DECLARE @queryFilter VARCHAR(2000);

	IF @p_Verbose = 1
		PRINT 'Set value for @tableName';
	IF (@p_Option = 'JobBlockers')
	BEGIN
		SET @tableName = 'dbo.JobBlockers';
		--SET @queryFilter = ' AND UsedSpacePercent > 80 ';
	END

	IF @p_Verbose = 1
	BEGIN
		PRINT	CHAR(13)+CHAR(10)+'Value for @tableName = '+ISNULL(@tableName,'<<NULL>>');
		PRINT	CHAR(13)+CHAR(10)+'Value for @queryFilter = '+ISNULL(@queryFilter,'<<NULL>>');
	END

	IF @p_Verbose = 1
		PRINT 'Set value for @columnList4TableHeader';
	-- Get table headers <th> data for Table <table>
	SELECT	@columnList4TableHeader = COALESCE(@columnList4TableHeader ,'') + ('<th>'+COLUMN_NAME+'</th>'+CHAR(13)+CHAR(10))
	FROM	INFORMATION_SCHEMA.COLUMNS as c
	WHERE	TABLE_SCHEMA+'.'+c.TABLE_NAME = @tableName
		AND	c.COLUMN_NAME NOT IN ('ID');
	IF @p_Verbose = 1
		PRINT	CHAR(13)+CHAR(10)+'Value for @columnList4TableHeader = '+ISNULL(@columnList4TableHeader,'<<NULL>>');

	IF @p_Verbose = 1
		PRINT 'Set value for @columnList4TableData';
	-- Get row (tr) data for Table <table>
	SELECT	@columnList4TableData = COALESCE(@columnList4TableData+', '''','+CHAR(13)+CHAR(10) ,'') + 
			('td = '+CASE WHEN COLUMN_NAME = 'BLOCKING_TREE' THEN 'LEFT(ISNULL('+COLUMN_NAME+','' ''),150)'
						WHEN DATA_TYPE = 'xml' THEN 'ISNULL(LEFT(CAST('+COLUMN_NAME+' AS varchar(max)),150),'' '')'
						WHEN DATA_TYPE NOT LIKE '%char' AND IS_NULLABLE = 'YES' THEN 'ISNULL(CAST('+COLUMN_NAME+' AS varchar(125)),'' '')'
						WHEN DATA_TYPE NOT LIKE '%char' THEN 'CAST('+COLUMN_NAME+' AS VARCHAR(125))'
						WHEN IS_NULLABLE = 'YES' THEN 'ISNULL('+COLUMN_NAME+','' '')'
						ELSE COLUMN_NAME
						END)
	FROM	INFORMATION_SCHEMA.COLUMNS as c
	WHERE	TABLE_SCHEMA+'.'+c.TABLE_NAME = @tableName
		AND	c.COLUMN_NAME NOT IN ('ID');
	IF @p_Verbose = 1
	BEGIN
		PRINT	CHAR(13)+CHAR(10)+'Value for @columnList4TableData = '+ISNULL(@columnList4TableData,'<<NULL>>');
	END

	SET @sqlString = N'
		SELECT CAST ( ( SELECT '+@columnList4TableData+'
					  FROM '+@tableName+'
						WHERE 1 = 1 '+ISNULL(@queryFilter,'')+'
					  FOR XML PATH(''tr''), TYPE   
			) AS NVARCHAR(MAX) )';
	IF @p_Verbose = 1
	BEGIN
		PRINT CHAR(13)+CHAR(10)+'Evaluating value for @sqlString = '+CHAR(13)+CHAR(10)+ISNULL(@sqlString,'<<NULL>>'); 
		PRINT CHAR(13)+CHAR(10)+'Now populating table @data4TableData';
	END


	INSERT @data4TableData
	EXEC (@sqlString);

	SELECT @columnList4TableData = TableData FROM @data4TableData;

	IF @p_Verbose = 1
	BEGIN
		PRINT 'Table @data4TableData has been populated using @sqlString'; 
		SELECT 'SELECT * FROM @data4TableData' AS RunningQuery, * FROM @data4TableData;
		PRINT CHAR(13)+CHAR(10)+'Value for @columnList4TableData has been reset to '+CHAR(13)+CHAR(10)+ISNULL(@columnList4TableData,'<<NULL>>');
	END

	--	If no data to share on Mail, then return
	IF NOT EXISTS (SELECT * FROM @data4TableData as d WHERE d.TableData IS NOT NULL)
	BEGIN
		IF @p_Verbose = 1
			PRINT 'No Data to share on Mail. Value of @data4TableData is null.';
		RETURN
	END

	IF @p_JobName IS NOT NULL AND @p_Option = 'JobBlockers'
		SET @subject = QUOTENAME(@p_JobName) + ' - ' + @p_Option;
	ELSE IF @subject IS NULL
		SET @subject = @p_Option;

	IF @p_Verbose = 1
		PRINT 'Set value for @subject';
	SET @subject = @subject + ' - '+CAST(CAST(GETDATE() AS DATE) AS VARCHAR(20));
	IF @p_Verbose = 1
		PRINT	CHAR(13)+CHAR(10)+'Value for @subject = '+ISNULL(@subject,'<<NULL>>');

	IF @p_Verbose = 1
		PRINT 'Set value for @cssStyle_GreenBackgroundHeader';
	SET @cssStyle_GreenBackgroundHeader = N'
	<style>
	.GreenBackgroundHeader {
		font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
		border-collapse: collapse;
		width: 100%;
	}

	.GreenBackgroundHeader td, .GreenBackgroundHeader th {
		border: 1px solid #ddd;
		padding: 8px;
	}

	.GreenBackgroundHeader tr:nth-child(even){background-color: #f2f2f2;}

	.GreenBackgroundHeader tr:hover {background-color: #ddd;}

	.GreenBackgroundHeader th {
		padding-top: 12px;
		padding-bottom: 12px;
		text-align: left;
		background-color: #4CAF50;
		color: white;
	}
	</style>';
	IF @p_Verbose = 1
		PRINT	CHAR(13)+CHAR(10)+'Value for @cssStyle_GreenBackgroundHeader = '+ISNULL(@cssStyle_GreenBackgroundHeader,'<<NULL>>');
	
	IF @p_Verbose = 1
		PRINT 'Set value for @htmlBody using @subject, @p_DefaultHTMLStyle, @columnList4TableHeader and @columnList4TableData values.';
	SET @htmlBody = N'<H1>'+@subject+'</H1>' +  
		N'<table border="1" class="'+@p_DefaultHTMLStyle+'">' +  
		N'<tr>'+@columnList4TableHeader+'</tr>' +  
		+@columnList4TableData+
		N'</table>' ;  

	SET @htmlBody = @htmlBody + '
<p>
<br><br>
Thanks & Regards,<br>
SQL Alerts<br>
dba-group@YourOrg.com<br>
-- Alert Coming from SQL Agent Job [DBA Log Walk Alerts]<br>
</p>
';

	IF @p_Verbose = 1
		PRINT 'Set value for @mailHTML using @cssStyle_GreenBackgroundHeader and @htmlBody values.';
	SET @mailHTML =  @cssStyle_GreenBackgroundHeader + @htmlBody;

	IF (@p_recipients IS NULL) 
	BEGIN
		SET @p_recipients = 'ajay.dwivedi@YourOrg.com';
	END

	EXEC msdb.dbo.sp_send_dbmail 
		@recipients = @p_recipients,  
		@subject = @subject,  
		@body = @mailHTML,  
		@body_format = 'HTML' ; 
END -- Procedure
GO

IF OBJECT_ID('dbo.usp_GetLogWalkJobHistoryAlert_Suppress') IS NULL
	EXEC('CREATE PROCEDURE [dbo].[usp_GetLogWalkJobHistoryAlert_Suppress] AS SELECT 1 AS [Dummy];')
GO

ALTER PROCEDURE [dbo].[usp_GetLogWalkJobHistoryAlert_Suppress] 
		@p_JobName VARCHAR(125) = NULL,
		@p_GetSessionRequestDetails BIT = 0,
		@p_Verbose BIT = 0,
		@p_NoOfContinousFailuresThreshold TINYINT = 2,
		@p_SuppressNotification TINYINT = 0,
		@p_SendMail BIT = 0,
		@p_Mail_TO VARCHAR(1000) = NULL,
		@p_Mail_CC VARCHAR(1000) = NULL,
		@p_SlackMailID VARCHAR(1000) = 'k2b0c1w9g1k7d5e0@YourOrg.slack.com;dba-group@YourOrg.com;',
		@p_Help BIT = 0
AS
BEGIN 
	/*
		Version:		1.3
		Created By:		Ajay Kumar Dwivedi
		Purpose:		To have custom alerting system for Log Walk jobs
		Modifications:	20-Apr-2019 - Corrected Notification mail where mail was received without body
						29-Apr-2019	- Add logic to send Blocking info to Slack Email
						13-May-2019	- Modify the Blocking Mail Query with procedure DBA.dbo.usp_WhoIsActive_Blocking
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		SELECT [@p_JobName] = @p_JobName;

	IF @p_Verbose = 1
		PRINT 'Declaring local variables..';
	-- Declare Local Variables
	DECLARE @_errorMSG VARCHAR(2000);
	DECLARE @NoOfContinousFailures INT;
	DECLARE @JobHistoryRecordCounts INT;
	DECLARE @SQLString NVARCHAR(MAX);
	DECLARE @ParmDefinition NVARCHAR(500);
	DECLARE @T_JobHistory TABLE (RID INT, Server varchar(125),JobName varchar(125),Instance_Id bigint, Step_Id int, Step_Name varchar(125), Run_Status int, Run_Status_Desc varchar(20), Enabled bit, Category_Id int, RunDateTime datetime, RunDurationMinutes int);
	DECLARE @_collection_time_start datetime;
	DECLARE @_collection_time_end datetime;
	DECLARE @IsBlockingIssue BIT;
	DECLARE @_SendMailRequired BIT;
	DECLARE @_mailSubject VARCHAR(255)
			,@_mailBody VARCHAR(4000);
	IF OBJECT_ID('DBA..LogWalkThresholdInstance') IS NULL
		CREATE TABLE DBA..LogWalkThresholdInstance (JobName varchar(125), Instance_Id bigint);		
	IF OBJECT_ID('DBA..JobBlockers') IS NULL
		CREATE TABLE DBA.[dbo].[JobBlockers]
		(
			[collection_time] smalldatetime NULL,
			[BLOCKING_TREE] [nvarchar](max) NULL,
			[session_id] [smallint] NULL,
			[blocking_session_id] [smallint] NULL,
			--[sql_text] [xml] NULL,
			[host_name] varchar(128) NULL,
			[database_name] varchar(128) NULL,
			[login_name] varchar(128) NULL,
			[program_name] varchar(128) NULL,
			[wait_info] varchar(4000) NULL,
			[blocked_session_count] varchar(30) NULL,
			--[locks] [xml] NULL,
			[tran_start_time] smalldatetime NULL,
			[open_tran_count] smallint NULL,
			--[additional_info] [xml] NULL,
			[CPU] [varchar](30) NULL,
			[tempdb_allocations] [varchar](30) NULL,
			[tempdb_current] [varchar](30) NULL,
			[reads] [varchar](30) NULL,
			[writes] [varchar](30) NULL,
			[physical_io] [varchar](30) NULL,
			[physical_reads] [varchar](30) NULL
		);
	ELSE
		TRUNCATE TABLE DBA.[dbo].[JobBlockers];

	IF @p_Verbose = 1
		PRINT 'Initilizing local variables..';
	SET @IsBlockingIssue = 0;
	SET @_SendMailRequired = 0;


	IF @p_Help = 1
	BEGIN -- If @p_Help
		IF @p_Verbose = 1
			PRINT 'Inside @p_Help = 1';
		SELECT	*
		FROM (	
				SELECT	[Parameter Name] = '! ******* Version ********!', 
						[Data Type] = 'Information', 
						[Default Value] = '1.3',
						[Parameter Description] = 'Last Updated - May 13, 2019',
						[Supporting Parameters] = 'https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_Help', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'Display Help Message',
						[Supporting Parameters] = NULL
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_JobName', 
						[Data Type] = 'varchar(125)', 
						[Default Value] = NULL,
						[Parameter Description] = 'Name of SQL Server Agent job for which Email Notification is required',
						[Supporting Parameters] = '@p_SendMail, @p_NoOfContinousFailuresThreshold, @p_Mail_TO, @p_Mail_CC, @p_SuppressNotification, @p_GetSessionRequestDetails, @p_Verbose'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_GetSessionRequestDetails', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'Display details of session details involved in blocking the @p_JobName.',
						[Supporting Parameters] = '@p_JobName'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_NoOfContinousFailuresThreshold', 
						[Data Type] = 'tinyint', 
						[Default Value] = '2',
						[Parameter Description] = 'Threshold value for Continous Job failure. Default value of 2 means notification should be received when the job fails for 2 or more continous times',
						[Supporting Parameters] = '@p_JobName'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_SuppressNotification', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'To avoid notification mail, we call execute the proc with this parameter ',
						[Supporting Parameters] = '@p_JobName'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_SendMail', 
						[Data Type] = 'bit', 
						[Default Value] = '0',
						[Parameter Description] = 'To get Email Notification, this option should be set to 1',
						[Supporting Parameters] = '@p_JobName, @p_Mail_TO, @p_Mail_CC'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_Mail_TO', 
						[Data Type] = 'varchar(1000)', 
						[Default Value] = NULL,
						[Parameter Description] = 'Email Ids of main recepients separated by Semicolon (;)',
						[Supporting Parameters] = '@p_JobName, @p_SendMail'
				--
				UNION ALL
				--
				SELECT	[Parameter Name] = '@p_Mail_CC', 
						[Data Type] = 'varchar(1000)', 
						[Default Value] = NULL,
						[Parameter Description] = 'Email Ids of Copy recepients separated by Semicolon (;)',
						[Supporting Parameters] = '@p_JobName, @p_SendMail'
			 ) AS F;
	END
	ELSE
	BEGIN -- Else portion of @p_Help = 1
		-- Check @p_JobName
		IF @p_JobName IS NULL
		BEGIN
			SET @_errorMSG = 'Kindly provide value for parameter @p_JobName.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		-- Make sure either user wants mail or want to debug, or want both
		IF @p_SendMail = 0 AND @p_Verbose = 0 AND @p_GetSessionRequestDetails = 0 AND @p_SuppressNotification = 0
		BEGIN
			SET @_errorMSG = 'Kindly use at least one of the following parameters:- @p_SendMail, @p_Verbose, @p_GetSessionRequestDetails, or @p_SuppressNotification';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END


		IF @p_Verbose = 1
			PRINT 'Trying to find Job history..';
		SET @ParmDefinition = N'@_JobName VARCHAR(125)'; 
		SET @SQLString = '
			SELECT	TOP 20 
					ROW_NUMBER() OVER(ORDER BY j.name, h.instance_id desc) AS RID,
					h.server,
					[JobName] = j.name,
					h.instance_id,
					h.step_id,
					h.step_name,
					h.run_status,
					[run_status_desc] = (case when h.run_status = 0 then ''Failed'' when h.run_status =  1 then ''Succeeded'' when h.run_status =  2 then ''Retry'' when h.run_status =  3 then ''Canceled'' else ''In Progress'' END),
					j.enabled,
					j.category_id,
					[RunDateTime] = msdb.dbo.agent_datetime(run_date, run_time),
					[RunDurationMinutes] = ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)
			FROM	msdb.dbo.sysjobs j 
			INNER JOIN msdb.dbo.sysjobhistory h 
				ON	j.job_id = h.job_id 
			WHERE	j.name = @_JobName
				AND step_id = 0
			ORDER BY JobName, instance_id desc
		';
		INSERT @T_JobHistory
		EXECUTE sp_executesql @SQLString, @ParmDefinition,  
							  @_JobName = @p_JobName; 

		SET @JobHistoryRecordCounts = COALESCE((SELECT COUNT(*) FROM @T_JobHistory),0);

		-- Check if no job history found, or Job name is invalid
		IF @JobHistoryRecordCounts = 0
		BEGIN
			IF EXISTS(SELECT * FROM msdb..sysjobs as j WHERE j.name = @p_JobName)
				SET @_errorMSG = 'No job execution history found for @p_JobName = '+QUOTENAME(@p_JobName);
			ELSE
				SET @_errorMSG = 'No job named '+QUOTENAME(@p_JobName)+' is found';

			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
		ELSE
		BEGIN -- block if Job History is found
			IF @p_Verbose = 1
			BEGIN
				PRINT 'SELECT * FROM @T_JobHistory;';
				SELECT	Q.*, J.*
				FROM	(	SELECT	'SELECT * FROM @T_JobHistory;' AS RunningQuery	) AS Q
				CROSS JOIN
						@T_JobHistory AS J;

				PRINT 'SELECT * FROM DBA..LogWalkThresholdInstance;';
				SELECT	Q.*, J.*
				FROM	(	SELECT	'SELECT * FROM DBA..LogWalkThresholdInstance;' AS RunningQuery	) AS Q
				CROSS JOIN
						DBA..LogWalkThresholdInstance AS J;
			END

			-- Find No of Continous Failures
			SELECT @NoOfContinousFailures = COALESCE(MIN(RID)-1,0) FROM @T_JobHistory h WHERE h.Run_Status_Desc = 'Succeeded';
			IF @p_Verbose = 1
			BEGIN
				PRINT '@NoOfContinousFailures = '+CAST(@NoOfContinousFailures AS VARCHAR(5));
				PRINT 'Job ['+@p_JobName+'] has been failing continously for last '+cast(@NoOfContinousFailures as varchar(2))+ ' times.'
			END

			-- If unchecked job failure is there, then find Blocking details
			IF @NoOfContinousFailures <> 0
			BEGIN -- Populate #JobSessionBlockers
				IF @p_Verbose = 1
					PRINT 'Proceeding to find Blocking details..';

				SELECT	@_collection_time_start = MIN(h.RunDateTime), @_collection_time_end = GETDATE() --MAX(h.RunDateTime)
				FROM	@T_JobHistory AS h
				WHERE	h.RID <= @NoOfContinousFailures;

				IF @p_Verbose = 1
					SELECT [@_collection_time_start] = @_collection_time_start, [@_collection_time_end] = @_collection_time_end;

				-- Find Job Session along with its Blockers
				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL
					DROP TABLE #JobSessionBlockers;
				;WITH T_JobCaptures AS
				(
					SELECT [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id], [collection_time]
					FROM [DBA]..[WhoIsActive_ResultSets] as r
					WHERE r.program_name = ('SQL Job = '+@p_JobName)
						AND r.collection_time >= @_collection_time_start
						AND    r.collection_time <= @_collection_time_end
					--
					UNION ALL
					--
					SELECT r.[dd hh:mm:ss.mss], r.[dd hh:mm:ss.mss (avg)], r.[session_id], r.[sql_text], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
					FROM T_JobCaptures AS j
					INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
						ON r.collection_time = j.collection_time
						AND j.blocking_session_id = r.session_id
				)
				SELECT	*
				INTO	#JobSessionBlockers
				FROM	T_JobCaptures;

				-- If Blockers are found
				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL AND EXISTS(SELECT 1 FROM #JobSessionBlockers as jb WHERE jb.program_name = ('SQL Job = '+@p_JobName) AND jb.blocking_session_id IS NOT NULL)
				BEGIN
					SET @IsBlockingIssue = 1;
				END

				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL AND (@p_Verbose = 1 OR @p_GetSessionRequestDetails = 1)
					SELECT	Q.*, DENSE_RANK()OVER(ORDER BY J.collection_time ASC) AS CollectionBatchNO, J.*
					FROM	(	SELECT	'What Was Running' AS RunningQuery	) AS Q
					FULL OUTER JOIN
							#JobSessionBlockers AS J
						ON	1 = 1;

			END -- Populate #JobSessionBlockers

			-- Logic if Job Failure is due to Blocking Issue
			IF @IsBlockingIssue = 1
			BEGIN -- Block -> Logic if Job Failure is due to Blocking Issue
				IF @p_Verbose = 1
					PRINT 'Logic processing when Job has failed due to Blocking Issue';

				IF @p_Verbose = 1
				BEGIN
					
					IF EXISTS (SELECT * FROM @T_JobHistory h WHERE h.Run_Status = 0 AND h.RID = @p_NoOfContinousFailuresThreshold AND h.Instance_Id IN (SELECT e.Instance_Id FROM DBA..LogWalkThresholdInstance AS e WHERE e.JobName = @p_JobName))
					BEGIN
						IF @p_Verbose = 1
							PRINT 'Setting @_SendMailRequired = 0';
						SET @_SendMailRequired = 0;
						
						PRINT '
Exception is present to suppress failure notification @p_SuppressNotification.
Incase this is not required, Kindly execute below query:-
DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = '''+@p_JobName+''';

	'
					END
				END

				-- If Job has been failing for more than @p_NoOfContinousFailuresThreshold with consideration of Exception @p_SuppressNotification
				IF ((SELECT COUNT(*) FROM @T_JobHistory WHERE Run_Status = 0 AND RID <= @p_NoOfContinousFailuresThreshold AND Instance_Id NOT IN (SELECT e.Instance_Id FROM DBA..LogWalkThresholdInstance AS e WHERE e.JobName = @p_JobName)) = @p_NoOfContinousFailuresThreshold)
				BEGIN -- block if failure issue is found

					IF @p_SuppressNotification = 1
					BEGIN
						IF @p_Verbose = 1
							PRINT 'Inside @p_SuppressNotification = 1 block';
					
						DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = @p_JobName;

						INSERT DBA..LogWalkThresholdInstance
						SELECT @p_JobName, instance_id FROM	@T_JobHistory WHERE Run_Status = 0 AND RID = @p_NoOfContinousFailuresThreshold;

						IF @p_Verbose = 1
						BEGIN
							SELECT	Q.*, J.*
							FROM	(	SELECT	'SELECT * FROM DBA..LogWalkThresholdInstance' AS RunningQuery	) AS Q
							CROSS JOIN
									DBA..LogWalkThresholdInstance AS J;
						END
					END
					ELSE
					BEGIN -- Else @p_SuppressNotification
						IF @p_Verbose = 1
							PRINT 'Setting @_SendMailRequired = 1';
						SET @_SendMailRequired = 1

						IF @p_SendMail = 1
						BEGIN
							-- From -> SQL Alerts - TUL1CIPRDB1 <SQLAlerts@YourOrg.com>

							IF @p_Verbose = 1
								PRINT 'Trying to find blockers..';
							SET @ParmDefinition = N'@p_collection_time_start smalldatetime, @p_collection_time_end smalldatetime, @p_JobName VARCHAR(125)'; 
							SET @SQLString = '
;WITH T_JobCaptures AS
(
	SELECT [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id], [collection_time]
		,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE([sql_text],[sql_command]) AS VARCHAR(MAX)),char(13),''''),CHAR(10),''''),''<?query --'',''''),''--?>'','''')
		,[LEVEL] = CAST (REPLICATE (''0'', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
	FROM [DBA]..[WhoIsActive_ResultSets] as r
	WHERE r.collection_time >= @p_collection_time_start AND r.collection_time <= @p_collection_time_end
	AND	(ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
	AND EXISTS (SELECT * FROM [DBA].[dbo].WhoIsActive_ResultSets AS R2 WHERE R2.collection_Time = r.collection_Time AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id AND R2.program_name = ''SQL Job = ''+@p_JobName)
	--
	UNION ALL
	--
	SELECT r.[dd hh:mm:ss.mss], r.[dd hh:mm:ss.mss (avg)], r.[session_id], r.[sql_text], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
		,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_text],r.[sql_command]) AS VARCHAR(MAX)),char(13),''''),CHAR(10),''''),''<?query --'',''''),''--?>'','''')
		,[LEVEL] = CAST (b.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000))
	FROM T_JobCaptures AS b
	INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
		ON r.collection_time = B.collection_time
		AND	r.blocking_session_id = B.session_id
	WHERE	r.blocking_session_id <> r.session_id
)
SELECT	[collection_time], 
		[BLOCKING_TREE] = N''    '' + REPLICATE (N''|         '', LEN (LEVEL)/4 - 1) 
						+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
									THEN ''HEAD -  ''
									ELSE ''|------  '' 
							END
						+	CAST (r.session_id AS NVARCHAR (10)) + N'' '' + (CASE WHEN LEFT(r.[sql_query],1) = ''('' THEN SUBSTRING(r.[sql_query],CHARINDEX(''exec'',r.[sql_query]),LEN(r.[sql_query]))  ELSE r.[sql_query] END),
		[session_id], [blocking_session_id], 				
		--[sql_text], 
		[host_name], [database_name], [login_name], [program_name],	[wait_info], [blocked_session_count], 
		--[locks], 
		[tran_start_time], [open_tran_count] --,additional_info
		,r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.[physical_reads] --, r.[query_plan]
FROM	T_JobCaptures as r
ORDER BY r.collection_time, LEVEL ASC;
							';

							IF @p_Verbose = 1
							BEGIN
								PRINT @SQLString;
							END

							--IF @p_SlackMailID IS NOT NULL
							--BEGIN
							INSERT DBA.[dbo].[JobBlockers]
							EXECUTE sp_executesql @SQLString, @ParmDefinition,
													@p_collection_time_start = @_collection_time_start,
													@p_collection_time_end = @_collection_time_end,
													@p_JobName = @p_JobName; 

							IF @p_Verbose = 1
							BEGIN
								SELECT 'SELECT * FROM DBA.[dbo].[JobBlockers]' AS RunningQuery, * FROM DBA.[dbo].[JobBlockers];
							END
							
							IF @p_Verbose = 1
								PRINT 'Executing procedure DBA..[usp_GetMail_4_SQLAlerts];';

							EXEC DBA..[usp_GetMail_4_SQLAlerts] @p_Option = 'JobBlockers', @p_JobName = @p_JobName, @p_recipients = @p_Mail_TO, @p_Verbose=@p_Verbose;
							--END
							
							SELECT 
							@_mailBody = 'Dear DSG-Team,

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been failing for '+cast(@NoOfContinousFailures as varchar(2))+ ' times continously.

LAST JOB RUN:		'+CAST(jh.RunDateTime AS varchar(50))+'
DURATION:		'+CAST(jh.RunDurationMinutes AS varchar(10))+' Minutes
STATUS: 		Failed
MESSAGES:		Job '+QUOTENAME(@p_JobName)+' COULD NOT obtain EXCLUSIVE access of underlying database to start its activity. 
RCA:			Kindly execute below query to find out details of Blockers.

		EXEC DBA.dbo.usp_WhoIsActive_Blocking @p_Collection_time_Start = '''+CAST(@_collection_time_start AS VARCHAR(30))+''', @p_Collection_time_End = '''+CAST(@_collection_time_end AS VARCHAR(30))+''' ,@p_Program_Name = ''SQL Job = '+@p_JobName+''';

'
		
							FROM	@T_JobHistory as jh
							WHERE	jh.RID = 1;
						END -- If @p_SendMail
					END -- Else @p_SuppressNotification
				END -- block if failure issue is found
				ELSE
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Verifying if @_SendMailRequired should be set to 0';
					
					IF @p_NoOfContinousFailuresThreshold > @NoOfContinousFailures
					BEGIN
						SET @_SendMailRequired = 0;
						IF @p_Verbose = 1
							PRINT 'Setting @_SendMailRequired = 0';
					END

				END
			END -- Block -> Logic if Job Failure is due to Blocking Issue
			ELSE IF @NoOfContinousFailures <> 0 AND @IsBlockingIssue = 0
			BEGIN -- Block for Non-Blocking Issue 
				IF @p_Verbose = 1
					PRINT 'Logic processing when Job has failed due to Non-blocking Issues';

				-- If @p_SuppressNotification is used for latest job failure
				IF EXISTS (SELECT * FROM @T_JobHistory h WHERE h.RID = 1 AND h.Instance_Id IN (SELECT e.Instance_Id FROM DBA..LogWalkThresholdInstance AS e WHERE e.JobName = @p_JobName))
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Setting @_SendMailRequired = 0';
					SET @_SendMailRequired = 0;
					
					IF @p_Verbose = 1
					BEGIN
						PRINT '
Exception is present to suppress failure notification @p_SuppressNotification.
Incase this is not required, Kindly execute below query:-
DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = '''+@p_JobName+''';

'
					END
				END
				ELSE
				BEGIN -- Block when @p_SuppressNotification is NOT used for latest job failure
					
					IF @p_SendMail = 1
					BEGIN
						SELECT @_mailBody = 'Dear DBA Team,

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been failing for '+cast(@NoOfContinousFailures as varchar(2))+ ' times continously.

LAST JOB RUN:		'+CAST(jh.RunDateTime AS varchar(50))+'
DURATION:		'+CAST(jh.RunDurationMinutes AS varchar(10))+' Minutes
STATUS: 		Failed

Kindly check Job Step Error Message' 
						FROM	@T_JobHistory as jh
						WHERE	jh.RID = 1;
					END -- If @p_SendMail
				END -- Block when @p_SuppressNotification is NOT used for latest job failure
				
				IF @p_SuppressNotification = 1
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Inside @p_SuppressNotification = 1 block';
					
					DELETE FROM DBA..LogWalkThresholdInstance WHERE JobName = @p_JobName;

					INSERT DBA..LogWalkThresholdInstance
					SELECT @p_JobName, instance_id FROM	@T_JobHistory WHERE Run_Status = 0 AND RID = 1;
				END
				ELSE
				BEGIN
					IF @p_Verbose = 1
						PRINT 'Setting @_SendMailRequired = 1';
					SET @_SendMailRequired = 1
				END
				
				--ELSE -- Send Mail
				
				
			END -- Block for Non-Blocking Issue 
			ELSE
				PRINT 'Job ['+@p_JobName+'] has not crossed threshold of '+cast(@p_NoOfContinousFailuresThreshold as varchar(2))+ ' continous failures. No action required.';

			-- Send Mail
			IF @NoOfContinousFailures <> 0 AND @p_SendMail = 1 AND @_SendMailRequired = 1
			BEGIN
				SET @_mailSubject = 'SQL Agent Job '+QUOTENAME(@p_JobName)+' Failed for '+cast(@NoOfContinousFailures as varchar(2))+ ' times';
				SET @_mailBody += '


Thanks & Regards,
SQL Alerts
dba-group@YourOrg.com
-- Alert Coming from SQL Agent Job [DBA Log Walk Alerts]
		';

				IF @p_Verbose = 1
				BEGIN
					PRINT 'Mail body';
					PRINT @_mailBody;

					PRINT 'Sending mail..';

				END
				
				EXEC msdb..sp_send_dbmail
							@profile_name = @@servername,
							@recipients = @p_Mail_TO,
							@copy_recipients =  @p_Mail_CC,
							@subject = @_mailSubject,
							@body = @_mailBody;
			END
		END -- block if Job History is found
	END -- Else portion of @p_Help = 1
END -- Procedure Body
GO