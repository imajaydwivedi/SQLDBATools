IF NOT EXISTS (SELECT * FROM msdb..sysjobs j where j.name = 'DBA DatabaseBackup - USER_DATABASES - LOG')
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
	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA DatabaseBackup - USER_DATABASES - LOG', 
			@enabled=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: https://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	/****** Object:  Step [DatabaseBackup - USER_DATABASES - LOG]    Script Date: 10/23/2019 4:22:32 AM ******/
	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - USER_DATABASES - LOG', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'TSQL', 
			@command=N'DECLARE @_dbNames VARCHAR(MAX);

	/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
	select @_dbNames = COALESCE(@_dbNames+'',''+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
					 --,mf.physical_name
	from sys.master_files as mf
	where mf.file_id = 1
			 AND mf.database_id <> DB_ID(''tempdb'')
			 AND mf.physical_name not like ''C:\AppSyncMounts\%''
			 AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL);

	--select @_dbNames;

	EXECUTE [DBA].[dbo].[DatabaseBackup] 
			@Databases = @_dbNames
			,@Directory = N''SqlInstanceDefaultBackupDirectory''
			,@FileName = N''{DatabaseName}_{BackupType}_{Partial}_{CopyOnly}_{Year}{Month}{Day}_{Hour}{Minute}{Second}_{FileNumber}.{FileExtension}''
			,@BackupType = ''LOG'',@Verify = ''N'',@Compress = ''Y'',@DirectoryStructure = NULL,
			@CleanupTime = 24,@CheckSum = ''N'',@LogToTable = ''Y''
			--,@Execute = ''N''
                                            
	', 
			@database_name=N'DBA', 
			@flags=0
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RUN', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=4, 
			@freq_subday_interval=30, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20180830, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235959, 
			@schedule_uid=N'29d98d80-2d50-4917-b6e2-c9e1cc5c44c5'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	COMMIT TRANSACTION
	GOTO EndSave
	QuitWithRollback:
		IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
	EndSave:
END