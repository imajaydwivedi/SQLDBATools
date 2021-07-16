--	http://ajaydwivedi.com/2016/12/log-all-activities-using-sp_whoisactive/

--	Verify Server Name
--SELECT @@SERVERNAME as SrvName;

--	Step 01: Create Your @destination_table
USE DBA
GO

IF OBJECT_ID('DBA.dbo.WhoIsActive_ResultSets') IS NULL
BEGIN
	DECLARE @destination_table VARCHAR(4000) ;
	SET @destination_table = 'DBA.dbo.WhoIsActive_ResultSets';

	DECLARE @schema VARCHAR(4000) ;
	--	Specify all your proc parameters here
	EXEC master..sp_WhoIsActive @get_plans=2, @get_full_inner_text=0, @get_transaction_info=1, @get_task_info=2, @get_locks=1, 
						@get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1
						,@return_schema = 1
						,@schema = @schema OUTPUT ;

	SET @schema = REPLACE(@schema, '<table_name>', @destination_table) ;

	PRINT @schema
	EXEC(@schema) ;
END
GO

--	Step 02: Add Computed Column to get TimeInMinutes
USE DBA
GO
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS as c WHERE c.TABLE_NAME = 'WhoIsActive_ResultSets' AND c.COLUMN_NAME = 'TimeInMinutes')
BEGIN
	ALTER TABLE dbo.[WhoIsActive_ResultSets]
		ADD [TimeInMinutes]  AS (((CONVERT([bigint],left([dd hh:mm:ss.mss],charindex(' ',[dd hh:mm:ss.mss])-(1)),0)*(24))*(60)+CONVERT([int],substring([dd hh:mm:ss.mss],charindex(' ',[dd hh:mm:ss.mss])+(1),(2)),0)*(60))+CONVERT([int],substring([dd hh:mm:ss.mss],charindex(':',[dd hh:mm:ss.mss])+(1),(2)),0));
END
GO

--	Step 03: Add a clustered Index
IF NOT EXISTS (select * from sys.indexes i where i.type_desc = 'CLUSTERED' and i.object_id = OBJECT_ID('DBA..WhoIsActive_ResultSets'))
BEGIN
	CREATE CLUSTERED INDEX [CI_WhoIsActive_ResultSets] ON [dbo].[WhoIsActive_ResultSets] ( [collection_time] ASC, session_id )
END
GO

--	Step 04: Add a Non-clustered Index
IF NOT EXISTS (select * from sys.indexes i where i.type_desc = 'NONCLUSTERED' and i.object_id = OBJECT_ID('DBA..WhoIsActive_ResultSets') and i.name = 'NCI_WhoIsActive_ResultSets_Blockings')
BEGIN
	CREATE NONCLUSTERED INDEX [NCI_WhoIsActive_ResultSets_Blockings] ON [dbo].[WhoIsActive_ResultSets]
	(	blocking_session_id, blocked_session_count, [collection_time] ASC, session_id)
	INCLUDE (login_name, [host_name], [database_name], [program_name])
END
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
			@email_address=N'dba-group@YourOrg.com', 
			@category_name=N'[Uncategorized]'
END
GO

-- Step 06: Create SQL Agent Job
USE [msdb]
GO

IF NOT EXISTS (select * from dbo.sysjobs as j where j.name = 'DBA - Log_With_sp_WhoIsActive')
BEGIN

	BEGIN TRANSACTION
	DECLARE @ReturnCode INT
	SELECT @ReturnCode = 0

	IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
	BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	END

	DECLARE @jobId BINARY(16)
	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - Log_With_sp_WhoIsActive', 
			@enabled=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'This job will log activities using Adam Mechanic''s [sp_whoIsActive] stored procedure.

		Results are saved into DBA..WhoIsActive_ResultSets table.

		Job will run every 2 Minutes once started.', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Log activities with [sp_WhoIsActive]', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'TSQL', 
			@command=N'DECLARE	@destination_table VARCHAR(4000);
		SET @destination_table = ''DBA.dbo.WhoIsActive_ResultSets'';

		EXEC DBA..sp_WhoIsActive @get_full_inner_text=0, @get_transaction_info=1, @get_task_info=2, @get_locks=1, @get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1	
							,@get_plans=2,
					@destination_table = @destination_table ;
			
		update w
		set query_plan = qp.query_plan
		--select w.collection_time, w.session_id, w.sql_command, w.additional_info
		--		,qp.query_plan
		from [DBA].[dbo].WhoIsActive_ResultSets AS w
		join sys.dm_exec_requests as r
		on w.session_id = r.session_id and w.request_id = r.request_id
		outer apply sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) as qp
		where w.collection_time = (select max(ri.collection_time) from [DBA].[dbo].WhoIsActive_ResultSets AS ri)
		and w.query_plan IS NULL and qp.query_plan is not null;
					', 
			@database_name=N'DBA', 
			@flags=0
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Log_Using_whoIsActive_Every_2_Minutes', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=4, 
			@freq_subday_interval=15, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20161227, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235900, 
			@schedule_uid=N'f583e6cd-9431-4afc-94a3-e3ef9bfa0d27'
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

USE [msdb]
GO

IF NOT EXISTS (select * from dbo.sysjobs as j where j.name = 'DBA - Log_With_sp_WhoIsActive - Cleanup')
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
			@notify_email_operator_name=N'DBAGroup', 
			@job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge-Data-Older-Than-60-Days', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
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
END
GO


