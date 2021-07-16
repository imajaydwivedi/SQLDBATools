USE [msdb]
GO

/****** Object:  Job [DBA - IndexOptimize - All Dbs - Minus - Staging/IDS]    Script Date: 10/18/2019 3:50:14 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/18/2019 3:50:14 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - IndexOptimize - All Dbs - Minus - Staging/IDS', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Update Stats for All Databases using Ola Hallengren

select * from DBA.dbo.CommandLog as l
	where l.CommandType in (''UPDATE_STATISTICS'',''ALTER_INDEX'')', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IndexOptimize]    Script Date: 10/18/2019 3:50:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
select @_dbNames = COALESCE(@_dbNames+'',''+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
                 --,mf.physical_name
from sys.master_files as mf
where mf.file_id = 1
         AND DB_NAME(mf.database_id) NOT IN (''tempdb'',''ArchiveDB'',''Staging'',''IDS'')
         AND mf.physical_name not like ''C:\AppSyncMounts\%''
         AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL)
ORDER BY name;


EXECUTE dbo.IndexOptimize
@Databases = @_dbNames,
@TimeLimit = 10800, -- 3 hours
@FragmentationLow = NULL,
@FragmentationMedium = ''INDEX_REBUILD_ONLINE,INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE'',
@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
@FragmentationLevel1 = 30,
@FragmentationLevel2 = 50,
@MinNumberOfPages = 1000,
@LOBCompaction = ''Y'', 
@UpdateStatistics = ''ALL'',
@OnlyModifiedStatistics = ''Y'',
@Indexes = ''ALL_INDEXES'',
@DatabasesInParallel = ''Y'',
@LogToTable = ''Y''
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily-Once', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=8, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190201, 
		@active_end_date=99991231, 
		@active_start_time=163000, 
		@active_end_time=235959, 
		@schedule_uid=N'd29c8cc3-e31a-4229-ad83-cb2c4871e8e2'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [DBA - IndexOptimize - All Dbs - Minus - Staging/IDS - 02]    Script Date: 10/18/2019 3:50:14 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/18/2019 3:50:14 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - IndexOptimize - All Dbs - Minus - Staging/IDS - 02', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Update Stats for All Databases using Ola Hallengren

select * from DBA.dbo.CommandLog as l
	where l.CommandType in (''UPDATE_STATISTICS'',''ALTER_INDEX'')', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IndexOptimize]    Script Date: 10/18/2019 3:50:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
select @_dbNames = COALESCE(@_dbNames+'',''+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
                 --,mf.physical_name
from sys.master_files as mf
where mf.file_id = 1
         AND DB_NAME(mf.database_id) NOT IN (''tempdb'',''ArchiveDB'',''Staging'',''IDS'')
         AND mf.physical_name not like ''C:\AppSyncMounts\%''
         AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL)
ORDER BY name;


EXECUTE dbo.IndexOptimize
@Databases = @_dbNames,
@TimeLimit = 10800, -- 3 hours
@FragmentationLow = NULL,
@FragmentationMedium = ''INDEX_REBUILD_ONLINE,INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE'',
@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
@FragmentationLevel1 = 30,
@FragmentationLevel2 = 50,
@MinNumberOfPages = 1000,
@LOBCompaction = ''Y'', 
@UpdateStatistics = ''ALL'',
@OnlyModifiedStatistics = ''Y'',
@Indexes = ''ALL_INDEXES'',
@DatabasesInParallel = ''Y'',
@LogToTable = ''Y''
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily-Once', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=8, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190201, 
		@active_end_date=99991231, 
		@active_start_time=163000, 
		@active_end_time=235959, 
		@schedule_uid=N'd29c8cc3-e31a-4229-ad83-cb2c4871e8e2'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [DBA - IndexOptimize - All Dbs - Minus - Staging/IDS - 03]    Script Date: 10/18/2019 3:50:14 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/18/2019 3:50:14 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - IndexOptimize - All Dbs - Minus - Staging/IDS - 03', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Update Stats for All Databases using Ola Hallengren

select * from DBA.dbo.CommandLog as l
	where l.CommandType in (''UPDATE_STATISTICS'',''ALTER_INDEX'')', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IndexOptimize]    Script Date: 10/18/2019 3:50:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
select @_dbNames = COALESCE(@_dbNames+'',''+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
                 --,mf.physical_name
from sys.master_files as mf
where mf.file_id = 1
         AND DB_NAME(mf.database_id) NOT IN (''tempdb'',''ArchiveDB'',''Staging'',''IDS'')
         AND mf.physical_name not like ''C:\AppSyncMounts\%''
         AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL)
ORDER BY name;


EXECUTE dbo.IndexOptimize
@Databases = @_dbNames,
@TimeLimit = 10800, -- 3 hours
@FragmentationLow = NULL,
@FragmentationMedium = ''INDEX_REBUILD_ONLINE,INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE'',
@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
@FragmentationLevel1 = 30,
@FragmentationLevel2 = 50,
@MinNumberOfPages = 1000,
@LOBCompaction = ''Y'', 
@UpdateStatistics = ''ALL'',
@OnlyModifiedStatistics = ''Y'',
@Indexes = ''ALL_INDEXES'',
@DatabasesInParallel = ''Y'',
@LogToTable = ''Y''
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily-Once', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=8, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190201, 
		@active_end_date=99991231, 
		@active_start_time=163000, 
		@active_end_time=235959, 
		@schedule_uid=N'd29c8cc3-e31a-4229-ad83-cb2c4871e8e2'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO