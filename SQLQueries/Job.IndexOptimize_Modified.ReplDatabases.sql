USE [msdb]
GO


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - IndexOptimize_Modified - ReplicationDatabaseName', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Use Ola Code

Job is taking care of Index Rebuild/ReOrg and UpdateStats.

Job is configured to run for 2 hours only. Will process indexes for all databases in Rotational Manner.

USE DBA;
SELECT * FROM dbo.CommandLog as cl
SELECT * FROM dbo.IndexProcessing_IndexOptimize;', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Start Notification', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Body varchar(2000);
DECLARE @Subject varchar(500);
set @Body = ''[DBA - IndexOptimize_Modified - All Databases] has started @''+cast(getdate() as varchar(50));
set @subject = ''[DBA - IndexOptimize_Modified - All Databases] has started @''+cast(getdate() as varchar(50));
EXEC msdb.dbo.sp_send_dbmail  
    @profile_name = @@SERVERNAME,  
    @recipients = ''it-ops-sqldba@YourOrg.com'',  
    @body = @Body,
    @subject = @Subject;', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Index Optimize', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* IndexOptimize [ReplicationDatabaseName] with @TimeLimit = 3.5 Hour */
SET NOCOUNT ON;

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
select @_dbNames = COALESCE(@_dbNames+'',''+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
                 --,mf.physical_name
from sys.master_files as mf
where mf.file_id = 1
         AND DB_NAME(mf.database_id) IN (''ReplicationDatabaseName'')
         AND mf.physical_name not like ''C:\AppSyncMounts\%''
         AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL)
ORDER BY name;


EXECUTE DBA.dbo.IndexOptimize_Modified
@Databases = @_dbNames,
@TimeLimit = 72000, -- 20 hours
@FragmentationLow = NULL,
@FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
@FragmentationLevel1 = 30,
@FragmentationLevel2 = 50,
@MinNumberOfPages = 1000,
@SortInTempdb = ''Y'', /* Enable it when [Cosmo] production Server since [tempdb] & [Cosmo] database are on separate disks */
@MaxDOP = 1, /* Default = 3 on Cosmo server */
--@FillFactor = 70, /* Recommendations says to start with 100, and keep decreasing based on Page Splits/Sec value of server. On Cosmo server, Page Splits/sec are very high. Avg 171 page splits/sec for Avg 354 Batch Requests/sec */
@LOBCompaction = ''Y'', 
@UpdateStatistics = ''ALL'',
@OnlyModifiedStatistics = ''Y'',
@Indexes = ''ALL_INDEXES'', /* Default is not specified. Db1.Schema1.Tbl1.Idx1, Db2.Schema2.Tbl2.Idx2 */
--@Delay = 120, /* Introduce 300 seconds of Delay b/w Indexes of Replicated Databases */
@LogToTable = ''Y''
--,@Execute = ''N''
,@forceReInitiate = 0', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'End Notification', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Body varchar(2000);
DECLARE @Subject varchar(500);
set @Body = ''[DBA - IndexOptimize_Modified - All Databases] has finished @''+cast(getdate() as varchar(50));
set @subject = ''[DBA - IndexOptimize_Modified - All Databases] has finished @''+cast(getdate() as varchar(50));
EXEC msdb.dbo.sp_send_dbmail  
    @profile_name = @@SERVERNAME,  
    @recipients = ''it-ops-sqldba@YourOrg.com'',   
    @body = @Body,
    @subject = @Subject;', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'One-Hour-Morning', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190519, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, 
		@schedule_uid=N'2d651c36-6d12-499d-9ca3-83986181792b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'On-Friday-10PM', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=32, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190519, 
		@active_end_date=99991231, 
		@active_start_time=220000, 
		@active_end_time=235959, 
		@schedule_uid=N'968c1e23-57f5-4449-9c07-b31094510ccb'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


