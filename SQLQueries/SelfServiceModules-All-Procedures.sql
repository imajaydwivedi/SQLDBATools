USE [master]
GO
IF OBJECT_ID('dbo.sp_HealthCheck') IS NULL
	EXEC ('CREATE PROCEDURE [dbo].[sp_HealthCheck] AS RETURN 0;');
GO
ALTER PROCEDURE [dbo].[sp_HealthCheck] ( 
						@p_Option		varchar(1) = 0
						,@p_Status	varchar(10) = 'ACTIVE'
						,@p_Orderby	varchar(1) = 1 
						,@p_getExecutionPlan bit = 0
					)
AS
BEGIN
/* 
	Created By:			Ajay Dwivedi
	Creatd Date:		30-Mar-2018
	Sproc Name:			dbo.sp_HealthCheck
	Current Version:	0.3
	Description: 1. Checks the Active connections
				 2. CPU and Memory Usage
				 3. Displays the capacity on the server and databases space used and availability just as sp_helpdb
				 4. Blocking Tree
				 5. Long running connection(s): Backup/Rollback, DBCC TABLE CHECK/Shrinkfile status with estimation time of completion with percentage
				 6. AlwaysOn availability Group status
				 7. Mirroring status

		Store Procedure Parameters:
				sp_HealthCheck 
						@p_Option			varchar(1)
						@p_Status			varchar(10)
						@p_Orderby		varchar(1)

		usage:  exec sp_HealthCheck -- This display the Active connections by default with order by Logical_Reads and CPU%, Diskspace, Lead Blocker, Long runngin connections
				Select parameters with values as below:
				exec sp_HealthCheck @p_Option = 0 - All, 1 - Connections, 2 - CPU %, 3 - Diskspace, 4 - Lead Blocker, 5 - Backup/Rollback status.
									, @p_Status = 'All' or 'ACTIVE' or 'SLEEPING'
									, @p_Orderby =  1 - 'Logical_Reads desc'
												  2 - 'Order by CPUTime desc'
												  3 - 'Order by SPID'
												  4 - 'Order by DBName'
		Example:									
			exec sp_HealthCheck '?' 
			exec sp_HealthCheck -- This display the Active connections by default with order by Logical_Reads and CPU%, Diskspace, Lead Blocker, Long runngin connections
			exec sp_HealthCheck @p_Option = 0  -- This display the Active connections by default with order by Logical_Reads and CPU%, Diskspace, Lead Blocker, Long running connections
			exec sp_HealthCheck @p_Option = 1	 -- Active connections

			exec sp_HealthCheck @p_Option = 1, @p_Status = 'All', @p_Orderby = 3		-- Connection with Active and Sleeping and Order by SPID
			exec sp_HealthCheck @p_Option = 1, @p_Status = 'ACTIVE', @p_Orderby = 1	-- Connection with Active and Order by Logical_Reads desc
			exec sp_HealthCheck @p_Option = 1, @p_Status = 'SLEEPING', @p_Orderby = 1	-- Connection with Sleeping and Order by Logical_Reads desc
			exec sp_HealthCheck @p_Option = 2  -- CPU usage % and Memory Usage %
												( This feature is applies to SQL Server 2008 plus higher version )
			exec sp_HealthCheck @p_Option = 3  --	Displays the capacity on the server and databases free and used
												( The Server Capacity feature is applies to SQL Server 2008 plus higher version to avoid using xp_cmdshell due to Security reasons: )
			exec sp_HealthCheck @p_Option = 4	 --	Lead Blocker list only the waittime greater than 60 seconds 
			exec sp_HealthCheck @p_Option = 5	 -- Long running connections: just ass Backup/Rollback, DBCC TABLE CHECK/Shrinkfile status with estimation time of completion with percentage'
			exec sp_HealthCheck @p_Option = 6	 -- AlwaysOn availability Group status
			exec sp_HealthCheck @p_Option = 7	 -- Mirroring status

*/
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	declare @UsageClause varchar(max)
	set @UsageClause = '
		This stored procedure gives the following reports:
			1. All sessions which are currently running some request, or sleeping but consuming memory, or blocking other sessions
			2. CPU and Memory Usage % ( This feature is applies to SQL Server 2008 plus higher version )
			3. Displays the capacity on the server and databases space used and availability
			   ( The Server Capacity feature is applies to SQL Server 2008 plus higher version )
			4. Blocking Tree
			5. Long running connection(s): Just as Backup/Rollback status with estimation time of completion with percentage
			6. AlwaysOn availability Group status
			7. Mirroring status
		** Note:
		CPU and Memory Usage and Server Capacity feature is applies to SQL Server 2008 plus higher version
		AlwaysOn availability feature is applies to SQL Server 2012 plus higher version
		Store Procedure Parameters:
			sp_HealthCheck 
					@p_Option			varchar(1)
					@p_Status			varchar(10)
					@p_Orderby		varchar(1)
		usage:
			exec sp_HealthCheck -- This display the Active connections by default with order by Logical_Reads and CPU%, Diskspace, 
								   Lead Blocker, Long running connections, AlwaysOn availability status and Mirroring status
			Select parameters with values as below:
			exec sp_HealthCheck 
					@p_Option		= 0 - Display Connections, CPU%, Diskspace, Lead Blocker, Long running connections with status, AlwaysOn availability status and Mirroring status
								  1 - Connections ( default active )
								  2 - CPU and Memory Usage % ( This feature is applies to SQL Server 2008 plus higher version )
								  3 - Displays the capacity on the server and databases space used and availability
									  ( The Server Capacity feature is applies to SQL Server 2008 plus higher version )								  
								  4 - Blocking Tree
								  5 - Long running connection(s): Just as Backup/Rollback status with estimation time of completion with percentage
								  6	- This displays the AlwaysOn availability Group status
								  7 - This displays the Mirroring status
					, @p_Status	= ''All'' ( Active & Sleeping )
								  ''ACTIVE'' ( default )
								  ''SLEEPING'' 
					, @p_Orderby	= 1 - ''Logical_Reads desc'' ( default )
								  2 - ''Order by CPUTime desc''
								  3 - ''Order by SPID''
								  4 - ''Order by DBName''
		Example:									
			exec sp_HealthCheck ''?''  -- Help
			exec sp_HealthCheck -- This display the Active connections by default with order by Logical_Reads and CPU%, Diskspace, 
								   Lead Blocker, Long running connections, AlwaysOn availability status and Mirroring status
			exec sp_HealthCheck @p_Option = 0  -- This display the Active connections by default with order by Logical_Reads and CPU%, Diskspace, 
												Lead Blocker, Long running connections, AlwaysOn availability status and Mirroring status
			exec sp_HealthCheck @p_Option = 1	 -- Active connections

			exec sp_HealthCheck @p_Option = 1, @p_Status = ''All'', @p_Orderby = 3      -- Connection with Active and Sleeping and Order by SPID
			exec sp_HealthCheck @p_Option = 1, @p_Status = ''ACTIVE'', @p_Orderby = 1   -- Connection with Active and Order by Logical_Reads desc
			exec sp_HealthCheck @p_Option = 1, @p_Status = ''SLEEPING'', @p_Orderby = 1 -- Connection with Sleeping and Order by Logical_Reads desc

			exec sp_HealthCheck @p_Option = 2  -- CPU and Memory Usage % ( This feature is applies to SQL Server 2008 plus higher version )
			exec sp_HealthCheck @p_Option = 3  --	Displays the capacity on the server and databases space used and availability 
												( The Server Capacity feature is applies to SQL Server 2008 plus higher version )
			exec sp_HealthCheck @p_Option = 4	 --	Blocking Tree only the waittime greater than 60 seconds 
			exec sp_HealthCheck @p_Option = 5	 -- Long running connections: Just as Backup/Rollback status with estimation time of completion with percentage
			exec sp_HealthCheck @p_Option = 6	 -- This displays the AlwaysOn availability Group status
			exec sp_HealthCheck @p_Option = 7	 -- This displays the Mirroring status
						
			exec sp_HealthCheck
			exec sp_HealthCheck 1
			exec sp_HealthCheck 2
			exec sp_HealthCheck 3
			exec sp_HealthCheck 4
			exec sp_HealthCheck 5
			exec sp_HealthCheck 6
			exec sp_HealthCheck 7'

	begin try
		if ( @p_Option not in ('0','1','2','3','4','5','6','7'))
		begin
			print @UsageClause
			return
		end
--		declare @current_dbname varchar(200)
--		select @current_dbname = upper(db_name())

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	1. Shows connection details
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '1' )
		begin 
			declare @p_Status_stmt nvarchar(100)
			declare @sql nvarchar(max)
			declare @sql_2ndHalf nvarchar(max)
			
			select @p_Status_stmt = case @p_Status when 'ACTIVE' then 'and upper(coalesce(r.status, s.status)) not in (''SLEEPING'', ''BACKGROUND'')' 
											   when 'SLEEPING' then 'and upper(coalesce(r.status, s.status)) in (''SLEEPING'')' 
											   when 'ALL' then ' ' end
			
			SET @sql = '
--	https://raw.githubusercontent.com/imajaydwivedi/SQLDBA-SSMS-Solution/master/BlitzQueries/WhatIsRunning.sql
SELECT	s.session_id, 
		DB_NAME(r.database_id) as DBName,
		r.percent_complete,
		[session_status] = s.status,
		[request_status] = r.status,
		[running_command] = r.command,
		[request_wait_type] = r.wait_type, 
		[request_wait_resource] = wait_resource,
		[request_start_time] = r.start_time,
		[request_running_time] = CAST(((DATEDIFF(s,r.start_time,GetDate()))/3600) as varchar) + '' hour(s), ''
			+ CAST((DATEDIFF(s,r.start_time,GetDate())%3600)/60 as varchar) + ''min, ''
			+ CAST((DATEDIFF(s,r.start_time,GetDate())%60) as varchar) + '' sec'',
		[est_time_to_go] = CAST((r.estimated_completion_time/3600000) as varchar) + '' hour(s), ''
						+ CAST((r.estimated_completion_time %3600000)/60000  as varchar) + ''min, ''
						+ CAST((r.estimated_completion_time %60000)/1000  as varchar) + '' sec'',
		[est_completion_time] = dateadd(second,r.estimated_completion_time/1000, getdate()),
		[blocked by] = r.blocking_session_id,
		[statement_text] = Substring(st.TEXT, (r.statement_start_offset / 2) + 1, (
				(
					CASE r.statement_end_offset
						WHEN - 1
							THEN Datalength(st.TEXT)
						ELSE r.statement_end_offset
						END - r.statement_start_offset
					) / 2
				) + 1),
		[Batch_Text] = st.text,
		[WaitTime(S)] = r.wait_time / (1000.0),
		[total_elapsed_time(S)] = r.total_elapsed_time / (1000.0),
		s.login_time, s.host_name, s.host_process_id, s.client_interface_name, s.login_name, 
		s.memory_usage, 
		[session_writes] = s.writes, 
		[request_writes] = r.writes, 
		[session_logical_reads] = s.logical_reads, 
		[request_logical_reads] = r.logical_reads, 
		s.is_user_process, 
		[session_row_count] = s.row_count,
		[request_row_count] = r.row_count,
		r.sql_handle, 
		r.plan_handle,
		r.open_transaction_count,
		[request_cpu_time] = r.cpu_time,
		[granted_query_memory] = CASE WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) >= 1.0
									  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) AS VARCHAR(23)) + '' GB''
									  WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) >= 1.0
									  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) AS VARCHAR(23)) + '' MB''
									  ELSE CAST((CAST(r.granted_query_memory AS numeric(20,2))*8) AS VARCHAR(23)) + '' KB''
									  END,
		r.query_hash, 
		r.query_plan_hash,'+(CASE WHEN @p_getExecutionPlan = 1 THEN '
		[BatchQueryPlan] = bqp.query_plan,
		[SqlQueryPlan] = CAST(sqp.query_plan AS xml),' ELSE '' END) + '
		[program_name] = CASE	WHEN	s.program_name like ''SQLAgent - TSQL JobStep %''
				THEN	(	select	top 1 ''SQL Job = ''+j.name 
							from msdb.dbo.sysjobs (nolock) as j
							inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
							where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(s.program_name,30,34),10) 
						)
				ELSE	s.program_name
				END,
		[IsSqlJob] = CASE WHEN s.program_name like ''SQLAgent - TSQL JobStep %''THEN 1 ELSE 2	END';
			
			SET @sql_2ndHalf = '
FROM	sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st'+(CASE WHEN @p_getExecutionPlan = 1 THEN '
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS bqp
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle,r.statement_start_offset, r.statement_end_offset) as sqp
' ELSE '' END)+'
WHERE	(case	when s.session_id != @@SPID
		AND	(	(	s.session_id > 50
				AND	(	r.session_id IS NOT NULL -- either some part of session has active request
					OR	ISNULL(open_resultset_count,0) > 0 -- some result is open
					)
				)
				OR	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
			) -- either take user sid, or system sid blocking user sid
				then 1
				when NOT (s.session_id != @@SPID
		AND	(	(	s.session_id > 50
				AND	(	r.session_id IS NOT NULL -- either some part of session has active request
					OR	ISNULL(open_resultset_count,0) > 0 -- some result is open
					)
				)
				OR	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
			))
				THEN 0
				else null
				end) = 1
' + @p_Status_stmt + 
			' order by ' +
			( case @p_Orderby when 1 then 'request_logical_reads desc' 
							when 2 then 'CPUTime desc' 
							when 3 then 'SPID' 
							when 4 then 'Order by DBName'
			  else 'request_logical_reads desc' end )

			--print @sql;
			--PRINT @sql_2ndHalf;
			exec (@sql+@sql_2ndHalf);
		end

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	2. CPU and Memory Usage % ( This feature is applies to SQL Server 2008 through current version )
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '2' )
		begin 
			if object_id (N'master.sys.dm_os_sys_memory') is null or object_id (N'master.sys.dm_os_ring_buffers') is null
			begin
				select [CPU & Memory Usage] = '*** This feature is applies to SQL Server 2008 plus higher version ***'
			end
			else
			begin
				declare @cpuUsage float
	    
				select top 1 @cpuUsage = 100 - r.SystemIdle
				from (  select rx.record.value('(./Record/@id)[1]', 'int') AS record_id
						, rx.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle
						from (  select convert(xml, record) as record
								from sys.dm_os_ring_buffers ( nolock )
								where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
								  and record like '%<SystemHealth>%') as rx
						) as r
				order by r.record_id desc

				select [CPU Usage %] = @cpuUsage
					, [Memory Usage %]  = convert(decimal(12,2),((total_physical_memory_kb - available_physical_memory_kb) / convert(float,total_physical_memory_kb )) * 100.0 )
					, PhysicalMemoryGB  = convert(decimal(12,2),convert(float,total_physical_memory_kb) / ( 1024 * 1024 ))
					, AvailableMemoryGB = convert(decimal(12,2),convert(float,available_physical_memory_kb) / ( 1024 * 1024 ))
				from master.sys.dm_os_sys_memory 
			end
		end

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	3. Displays the capacity on the server space used and availablity
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '3' )
		begin 
			if object_id (N'master.sys.dm_os_volume_stats') is null or object_id (N'sys.dm_db_file_space_usage') is null
			begin
				select [Server Capacity] = '*** This feature is applies to SQL Server 2008 plus higher version ***'
			end
			else
			begin
				declare @tLabel varchar(100) 
					, @tVolume  varchar(100) 
				select @tLabel = upper(logical_volume_name)
					, @tVolume = upper(volume_mount_point)
				from master.sys.dm_os_volume_stats(2, 1) 

				select distinct 
					Label = upper(vs.logical_volume_name)
					, [Volume] = upper(vs.volume_mount_point)
					, [Total (GB)] = convert(decimal(20,2), vs.total_bytes / 1024. /1024. / 1024. )
					, [Used (GB)] = convert(decimal(20,2), (vs.total_bytes - vs.available_bytes) / 1024. /1024. / 1024. )
					, [Free (GB)] = convert(decimal(20,2), vs.available_bytes / 1024. /1024. / 1024. )
					, [Used (%)] = convert(decimal(20,2), convert(decimal(20,2), (vs.total_bytes - vs.available_bytes) / 1024. /1024. / 1024. ) /
									convert(decimal(20,2), vs.total_bytes / 1024. /1024. / 1024. ) * 100.0)
					, [Free (%)] =  convert(decimal(20,2), convert(decimal(20,2), vs.available_bytes / 1024. /1024. / 1024. ) / 
									convert(decimal(20,2), vs.total_bytes / 1024. /1024. / 1024. ) * 100.0 )
				from sys.master_files mf 
				cross apply master.sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
				where upper(vs.logical_volume_name) != @tLabel
				union all 
				select Label = @tLabel
					, [Volume] = @tVolume
					, [Total (GB)] = a.totalFileSizeGB
					, [Used (GB)] = cast( ( a.totalFileSizeGB - a.freeSpaceGB ) as decimal( 20, 2 ) )
					, [Free (GB)] = a.freeSpaceGB
					, [Used (%)] = cast( ( a.totalFileSizeGB - freeSpaceGB ) / totalFileSizeGB * 100 as decimal( 20, 2 ) )
					, [Free (%)] = cast(  freeSpaceGB / totalFileSizeGB * 100 as decimal( 20, 2 ) )
				from  ( select	totalFileSizeGB = cast( sum(	unallocated_extent_page_count +
										version_store_reserved_page_count +
										user_object_reserved_page_count +
										internal_object_reserved_page_count +
										mixed_extent_page_count ) * 8. / 1024. / 1024.  as decimal( 20, 2 ) ) 
							, freeSpaceGB = cast( sum( unallocated_extent_page_count ) * 8. / 1024. / 1024. as decimal( 20, 2 ) ) 
						from tempdb.sys.dm_db_file_space_usage ) a
				order by [Volume]
			end

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	3.1. Displays the capacity on the databases space used and availablity just as sp_helpdb details 
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

			declare @FileSpaceDetails TABLE (
				DatabaseId			integer
				, DatabaseName		sysname
				, LogicalFileName	varchar(100)
				, FileName			varchar(250)
				, FileSizeKB		decimal(20,2)
				, SpaceUsedKB		decimal(20,2)
				, FreeSpaceKB		decimal(20,2)
				, FileSize AS (CASE WHEN FileSizeKB/1024/1024/1024 >= 1.0 THEN CAST( CAST(FileSizeKB/1024/1024/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' TB'
									WHEN FileSizeKB/1024/1024 >= 1.0 THEN CAST( CAST(FileSizeKB/1024/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' GB'
									WHEN FileSizeKB/1024 >= 1.0 THEN CAST( CAST(FileSizeKB/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' MB'
									ELSE CAST(CAST(FileSizeKB AS DECIMAL(20,2)) AS VARCHAR(23))+ ' KB' END)
				, SpaceUsed AS (CASE WHEN SpaceUsedKB/1024/1024/1024 >= 1.0 THEN CAST( CAST(SpaceUsedKB/1024/1024/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' TB'
									WHEN SpaceUsedKB/1024/1024 >= 1.0 THEN CAST( CAST(SpaceUsedKB/1024/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' GB'
									WHEN SpaceUsedKB/1024 >= 1.0 THEN CAST( CAST(SpaceUsedKB/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' MB'
									ELSE CAST(CAST(SpaceUsedKB AS DECIMAL(20,2)) AS VARCHAR(23))+ ' KB' END)
				, FreeSpace AS (CASE WHEN FreeSpaceKB/1024/1024/1024 >= 1.0 THEN CAST( CAST(FreeSpaceKB/1024/1024/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' TB'
									WHEN FreeSpaceKB/1024/1024 >= 1.0 THEN CAST( CAST(FreeSpaceKB/1024/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' GB'
									WHEN FreeSpaceKB/1024 >= 1.0 THEN CAST( CAST(FreeSpaceKB/1024 AS DECIMAL(20,2)) AS VARCHAR(23))+' MB'
									ELSE CAST(CAST(FreeSpaceKB AS DECIMAL(20,2)) AS VARCHAR(23))+ ' KB' END)
				, [SpaceUsed(%)] AS cast( (SpaceUsedKB*100.0)/FileSizeKB as DECIMAL(20,1))
				 )

			if object_id (N'master.sys.sp_msforeachdb') is not null
			begin
				insert into @FileSpaceDetails
				exec sp_msforeachdb 'use [?]; 
				select DatabaseId = db_id(''?'')
					, DatabaseName = ''?''
					, LogicalFileName = a.name
					, a.Filename
					, FileSizeKB = (a.size * 8.0)
					, SpaceUsedKB = (fileproperty(a.name,''SpaceUsed'') * 8.0)
					, FreeSpaceKB = (a.size - fileproperty(a.name,''SpaceUsed''))*8.0
				from sys.sysfiles a ( nolock )'
			end

			if object_id (N'master.sys.sp_msforeachdb') is null 
			begin
				declare @dbnm varchar(200) 
				declare @dbtmp table ( dbname varchar(200))
				insert into @dbtmp
				select name from sys.databases 
				select @dbnm = ''
				select top 1 @dbnm = dbname from @dbtmp
				while @dbnm != ''
				begin
					select @sql = ''
					select @sql = ' use [' + @dbnm + '] ; 
						select DatabaseId = db_id(''' + @dbnm + ''')
							, DatabaseName = ''' + @dbnm + ''' 
							, LogicalFileName = a.name
							, a.Filename
							, round(convert(float,a.size/128.000),2) as FileSizeMB     
							, round(convert(float,fileproperty(a.name,''SpaceUsed'')/128.000),2) as SpaceUsedMB     
							, round(convert(float,(a.size-fileproperty(a.name,''SpaceUsed''))/128.000),2) as FreeSpaceMB 
						from sys.sysfiles a ( nolock )'
				
					insert into @FileSpaceDetails				
					execute sp_executesql @sql
				
					delete from @dbtmp where dbname = @dbnm
					select @dbnm = ''
					select top 1 @dbnm = dbname from @dbtmp
				end
			end
			select DatabaseId, DatabaseName, LogicalFileName, FileName, FileSize, SpaceUsed, FreeSpace, [SpaceUsed(%)]
					--,FileSizeKB, SpaceUsedKB, FreeSpaceKB
			from @FileSpaceDetails
			where DatabaseId > 4
			order by DatabaseName, FileSizeKB desc 
		end

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	4. Blocking Tree
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '4' )
		begin 
			--	https://blog.sqlauthority.com/2008/08/18/sql-server-detailed-explanation-of-transaction-lock-lock-type-avoid-locks/
			IF OBJECT_ID('tempdb..#T') IS NOT NULL
				DROP TABLE #T;
			SELECT SPID
				,BLOCKED
				,REPLACE(REPLACE(T.TEXT, CHAR(10), ' '), CHAR(13), ' ') AS BATCH
			INTO #T
			FROM sys.sysprocesses R
			CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T;

			WITH BLOCKERS (	SPID	,BLOCKED	,LEVEL	,BATCH	)
			AS (
				SELECT SPID
					,BLOCKED
					,CAST(REPLICATE('0', 4 - LEN(CAST(SPID AS VARCHAR))) + CAST(SPID AS VARCHAR) AS VARCHAR(1000)) AS LEVEL
					,BATCH
				FROM #T R
				WHERE (	BLOCKED = 0 OR BLOCKED = SPID )
					AND EXISTS ( SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID )
				--
				UNION ALL
				--
				SELECT R.SPID
					,R.BLOCKED
					,CAST(BLOCKERS.LEVEL + RIGHT(CAST((1000 + R.SPID) AS VARCHAR(100)), 4) AS VARCHAR(1000)) AS LEVEL
					,R.BATCH
				FROM #T AS R
				INNER JOIN BLOCKERS 
					ON R.BLOCKED = BLOCKERS.SPID
				WHERE R.BLOCKED > 0	AND R.BLOCKED <> R.SPID
				)
			SELECT N'    ' + REPLICATE(N'|         ', LEN(LEVEL) / 4 - 1) + CASE 
					WHEN (LEN(LEVEL) / 4 - 1) = 0
						THEN 'HEAD -  '
					ELSE '|------  '
					END + CAST(SPID AS NVARCHAR(10)) + N' ' + BATCH AS BLOCKING_TREE
			FROM BLOCKERS
			ORDER BY LEVEL ASC;
		end

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	5. Long running connections: Backup/Rollback, DBCC TABLE CHECK/Shrinkfile status with 
		--		estimation time of completion with percentage
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '5' )
		begin 
			if not exists ( select 1 from master.sys.dm_exec_requests r 
						where r.percent_complete <> 0
						union
						select 1 from master.sys.dm_exec_requests r 
						where upper(r.command) like '%ROLLBACK%' )
			begin
				 select BackupOrRollbackStatus = '*** No results for Long running queries, just as Backup/Rollback  ***' 
			end
			else
			begin 
				select LongRunningSPID = r.session_id
					, dbname = db_name(r.database_id) 
					, r.start_time
					, r.percent_complete
					, estimated_completion_time = dateadd(millisecond, r.estimated_completion_time, getdate())
					, total_process_time_minutes = datediff(minute, r.start_time, dateadd(millisecond, r.estimated_completion_time, getdate())) 
					, currentQuery = substring(	t.text, r.statement_start_offset / 2 + 1,
								( case when r.statement_end_offset = -1 then len( convert( nvarchar( max ), t.text ) ) * 2 
								  else r.statement_end_offset 
								  end - r.statement_start_offset ) / 2 )
					, Complete_Statement = t.text
					, r.command		
				from master.sys.dm_exec_requests r 
				outer apply master.sys.dm_exec_sql_text(r.sql_handle) t
				where r.percent_complete <> 0
				union
				select r.session_id
					, dbname = db_name(r.database_id) 
					, r.start_time
					, r.percent_complete
					, estimated_completion_time = dateadd(millisecond, r.estimated_completion_time, getdate())
					, total_process_time_minutes = datediff(minute, r.start_time, dateadd(millisecond, r.estimated_completion_time, getdate())) 
					, currentQuery = substring(	t.text, r.statement_start_offset / 2 + 1,
								( case when r.statement_end_offset = -1 then len( convert( nvarchar( max ), t.text ) ) * 2 
								  else r.statement_end_offset 
								  end - r.statement_start_offset ) / 2 )
					, Complete_Statement = t.text
					, r.command		
				from master.sys.dm_exec_requests r 
				outer apply master.sys.dm_exec_sql_text(r.sql_handle) t
				where upper(r.command) like '%ROLLBACK%'				 
			end
		end

		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	6. AlwaysOn availability Group status
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '6' )
		begin 
			if object_id (N'master.sys.availability_groups') is not null 
			   and exists ( select port from sys.tcp_endpoints where type_desc = 'DATABASE_MIRRORING' ) 
			begin
				if exists ( select group_id from sys.availability_groups )
				begin
					select 
 						AlwaysOn_dsn_name = agl.dns_name
						, ar.replica_server_name
						, ars.role_desc
						, dr.database_name
						, ar.create_date	
						, ars.operational_state_desc
						, ars.connected_state_desc
						, ars.recovery_health_desc
						, ars.synchronization_health_desc
						, ar.availability_mode_desc
						, ars.last_connect_error_number
						, ars.last_connect_error_description
						, ars.last_connect_error_timestamp
					from sys.availability_groups ag (nolock)
					join sys.dm_hadr_availability_group_states ags (nolock) on
						 ags.group_id = ag.group_id
					join sys.availability_replicas ar (nolock) on
						 ar.group_id = ag.group_id
					join sys.dm_hadr_availability_replica_states ars (nolock) on
						 ars.replica_id = ar.replica_id
					 and ars.group_id = ag.group_id
					join sys.dm_hadr_database_replica_cluster_states dr (nolock) on
						 dr.replica_id = ar.replica_id
					join sys.availability_group_listeners agl (nolock) on
						 agl.group_id = ag.group_id
					order by role_desc
				end
			end
		end
		-- - - - - - - - - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - - - - - - - - - - - 
		--	7. Mirroring status
		--- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		if ( @p_Option = '0' or @p_Option = '7' )
		begin 
			if object_id (N'master.sys.tcp_endpoints') is not null 
			begin
				if exists ( select port from master.sys.tcp_endpoints where type_desc = 'DATABASE_MIRRORING' ) 
					and exists ( select mirroring_role_desc from sys.database_mirroring where mirroring_role_desc is not null )
				begin
					select Mirroring_DatabaseName = d.name
						, m.mirroring_role_desc
						, m.mirroring_partner_instance
						, m.mirroring_state_desc
						, mirroring_safety_level_desc = case m.mirroring_safety_level 
														when 0 then 'Unknown state'
														when 1 then 'Off [asynchronous]'
														when 2 then 'Full [synchronous]' 
														else 'Not mirrored' end
						, m.mirroring_witness_state_desc
					from sys.database_mirroring m 
					join sys.databases d on
						 m.database_id = d.database_id
					where m.mirroring_role_desc is not null 
					order by m.mirroring_role_desc desc, d.name
				end
			end
		end
	end try

	begin catch
		declare @errorNumber int
			, @errorSeverity int
			, @errorState int
			, @errorLine int
			, @errorMessage varchar(4000)

		select @errorNumber	 = Error_Number()
			, @errorSeverity = Error_Severity()
			, @errorState	 = Error_State()
			, @errorLine	 = Error_Line()
			, @errorMessage	 = Error_Message()
		
		set @errorMessage = 'Error Number: ' + convert(varchar, @errorNumber) + '; ' + 
							'Line: ' + convert(varchar, @errorLine) + '; ' + 
							'Message: "' + @errorMessage + '"';
		raiserror (@errorMessage, @errorSeverity, @errorState);
	end catch
end
GO

use master;

SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ANSI_WARNINGS ON;
SET NUMERIC_ROUNDABORT OFF;
SET ARITHABORT ON;
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_WhoIsActive')
	EXEC ('CREATE PROC dbo.sp_WhoIsActive AS SELECT ''stub version, to be replaced''')
GO

/* ********************************************************************************************
Who Is Active? v11.32 (2018-07-03)
(C) 2007-2018, Adam Machanic

Feedback: mailto:adam@dataeducation.com
Updates: http://whoisactive.com
Blog: http://dataeducation.com

License: 
	Who is Active? is free to download and use for personal, educational, and internal 
	corporate purposes, provided that this header is preserved. Redistribution or sale 
	of Who is Active?, in whole or in part, is prohibited without the author's express 
	written consent.
******************************************************************************************** */
ALTER PROC dbo.sp_WhoIsActive
(
--~
	--Filters--Both inclusive and exclusive
	--Set either filter to '' to disable
	--Valid filter types are: session, program, database, login, and host
	--Session is a session ID, and either 0 or '' can be used to indicate "all" sessions
	--All other filter types support % or _ as wildcards
	@filter sysname = '',
	@filter_type VARCHAR(10) = 'session',
	@not_filter sysname = '',
	@not_filter_type VARCHAR(10) = 'session',

	--Retrieve data about the calling session?
	@show_own_spid BIT = 0,

	--Retrieve data about system sessions?
	@show_system_spids BIT = 0,

	--Controls how sleeping SPIDs are handled, based on the idea of levels of interest
	--0 does not pull any sleeping SPIDs
	--1 pulls only those sleeping SPIDs that also have an open transaction
	--2 pulls all sleeping SPIDs
	@show_sleeping_spids TINYINT = 1,

	--If 1, gets the full stored procedure or running batch, when available
	--If 0, gets only the actual statement that is currently running in the batch or procedure
	@get_full_inner_text BIT = 0,

	--Get associated query plans for running tasks, if available
	--If @get_plans = 1, gets the plan based on the request's statement offset
	--If @get_plans = 2, gets the entire plan based on the request's plan_handle
	@get_plans TINYINT = 0,

	--Get the associated outer ad hoc query or stored procedure call, if available
	@get_outer_command BIT = 0,

	--Enables pulling transaction log write info and transaction duration
	@get_transaction_info BIT = 0,

	--Get information on active tasks, based on three interest levels
	--Level 0 does not pull any task-related information
	--Level 1 is a lightweight mode that pulls the top non-CXPACKET wait, giving preference to blockers
	--Level 2 pulls all available task-based metrics, including: 
	--number of active tasks, current wait stats, physical I/O, context switches, and blocker information
	@get_task_info TINYINT = 1,

	--Gets associated locks for each request, aggregated in an XML format
	@get_locks BIT = 0,

	--Get average time for past runs of an active query
	--(based on the combination of plan handle, sql handle, and offset)
	@get_avg_time BIT = 0,

	--Get additional non-performance-related information about the session or request
	--text_size, language, date_format, date_first, quoted_identifier, arithabort, ansi_null_dflt_on, 
	--ansi_defaults, ansi_warnings, ansi_padding, ansi_nulls, concat_null_yields_null, 
	--transaction_isolation_level, lock_timeout, deadlock_priority, row_count, command_type
	--
	--If a SQL Agent job is running, an subnode called agent_info will be populated with some or all of
	--the following: job_id, job_name, step_id, step_name, msdb_query_error (in the event of an error)
	--
	--If @get_task_info is set to 2 and a lock wait is detected, a subnode called block_info will be
	--populated with some or all of the following: lock_type, database_name, object_id, file_id, hobt_id, 
	--applock_hash, metadata_resource, metadata_class_id, object_name, schema_name
	@get_additional_info BIT = 0,

	--Walk the blocking chain and count the number of 
	--total SPIDs blocked all the way down by a given session
	--Also enables task_info Level 1, if @get_task_info is set to 0
	@find_block_leaders BIT = 0,

	--Pull deltas on various metrics
	--Interval in seconds to wait before doing the second data pull
	@delta_interval TINYINT = 0,

	--List of desired output columns, in desired order
	--Note that the final output will be the intersection of all enabled features and all 
	--columns in the list. Therefore, only columns associated with enabled features will 
	--actually appear in the output. Likewise, removing columns from this list may effectively
	--disable features, even if they are turned on
	--
	--Each element in this list must be one of the valid output column names. Names must be
	--delimited by square brackets. White space, formatting, and additional characters are
	--allowed, as long as the list contains exact matches of delimited valid column names.
	@output_column_list VARCHAR(8000) = '[dd%][session_id][sql_text][sql_command][login_name][wait_info][tasks][tran_log%][cpu%][temp%][block%][reads%][writes%][context%][physical%][query_plan][locks][%]',

	--Column(s) by which to sort output, optionally with sort directions. 
		--Valid column choices:
		--session_id, physical_io, reads, physical_reads, writes, tempdb_allocations, 
		--tempdb_current, CPU, context_switches, used_memory, physical_io_delta, reads_delta, 
		--physical_reads_delta, writes_delta, tempdb_allocations_delta, tempdb_current_delta, 
		--CPU_delta, context_switches_delta, used_memory_delta, tasks, tran_start_time, 
		--open_tran_count, blocking_session_id, blocked_session_count, percent_complete, 
		--host_name, login_name, database_name, start_time, login_time, program_name
		--
		--Note that column names in the list must be bracket-delimited. Commas and/or white
		--space are not required. 
	@sort_order VARCHAR(500) = '[start_time] ASC',

	--Formats some of the output columns in a more "human readable" form
	--0 disables outfput format
	--1 formats the output for variable-width fonts
	--2 formats the output for fixed-width fonts
	@format_output TINYINT = 1,

	--If set to a non-blank value, the script will attempt to insert into the specified 
	--destination table. Please note that the script will not verify that the table exists, 
	--or that it has the correct schema, before doing the insert.
	--Table can be specified in one, two, or three-part format
	@destination_table VARCHAR(4000) = '',

	--If set to 1, no data collection will happen and no result set will be returned; instead,
	--a CREATE TABLE statement will be returned via the @schema parameter, which will match 
	--the schema of the result set that would be returned by using the same collection of the
	--rest of the parameters. The CREATE TABLE statement will have a placeholder token of 
	--<table_name> in place of an actual table name.
	@return_schema BIT = 0,
	@schema VARCHAR(MAX) = NULL OUTPUT,

	--Help! What do I do?
	@help BIT = 0
--~
)
/*
OUTPUT COLUMNS
--------------
Formatted/Non:	[session_id] [smallint] NOT NULL
	Session ID (a.k.a. SPID)

Formatted:		[dd hh:mm:ss.mss] [varchar](15) NULL
Non-Formatted:	<not returned>
	For an active request, time the query has been running
	For a sleeping session, time since the last batch completed

Formatted:		[dd hh:mm:ss.mss (avg)] [varchar](15) NULL
Non-Formatted:	[avg_elapsed_time] [int] NULL
	(Requires @get_avg_time option)
	How much time has the active portion of the query taken in the past, on average?

Formatted:		[physical_io] [varchar](30) NULL
Non-Formatted:	[physical_io] [bigint] NULL
	Shows the number of physical I/Os, for active requests

Formatted:		[reads] [varchar](30) NULL
Non-Formatted:	[reads] [bigint] NULL
	For an active request, number of reads done for the current query
	For a sleeping session, total number of reads done over the lifetime of the session

Formatted:		[physical_reads] [varchar](30) NULL
Non-Formatted:	[physical_reads] [bigint] NULL
	For an active request, number of physical reads done for the current query
	For a sleeping session, total number of physical reads done over the lifetime of the session

Formatted:		[writes] [varchar](30) NULL
Non-Formatted:	[writes] [bigint] NULL
	For an active request, number of writes done for the current query
	For a sleeping session, total number of writes done over the lifetime of the session

Formatted:		[tempdb_allocations] [varchar](30) NULL
Non-Formatted:	[tempdb_allocations] [bigint] NULL
	For an active request, number of TempDB writes done for the current query
	For a sleeping session, total number of TempDB writes done over the lifetime of the session

Formatted:		[tempdb_current] [varchar](30) NULL
Non-Formatted:	[tempdb_current] [bigint] NULL
	For an active request, number of TempDB pages currently allocated for the query
	For a sleeping session, number of TempDB pages currently allocated for the session

Formatted:		[CPU] [varchar](30) NULL
Non-Formatted:	[CPU] [int] NULL
	For an active request, total CPU time consumed by the current query
	For a sleeping session, total CPU time consumed over the lifetime of the session

Formatted:		[context_switches] [varchar](30) NULL
Non-Formatted:	[context_switches] [bigint] NULL
	Shows the number of context switches, for active requests

Formatted:		[used_memory] [varchar](30) NOT NULL
Non-Formatted:	[used_memory] [bigint] NOT NULL
	For an active request, total memory consumption for the current query
	For a sleeping session, total current memory consumption

Formatted:		[physical_io_delta] [varchar](30) NULL
Non-Formatted:	[physical_io_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of physical I/Os reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[reads_delta] [varchar](30) NULL
Non-Formatted:	[reads_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of reads reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[physical_reads_delta] [varchar](30) NULL
Non-Formatted:	[physical_reads_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of physical reads reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[writes_delta] [varchar](30) NULL
Non-Formatted:	[writes_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of writes reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[tempdb_allocations_delta] [varchar](30) NULL
Non-Formatted:	[tempdb_allocations_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of TempDB writes reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[tempdb_current_delta] [varchar](30) NULL
Non-Formatted:	[tempdb_current_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of allocated TempDB pages reported on the first and second 
	collections. If the request started after the first collection, the value will be NULL

Formatted:		[CPU_delta] [varchar](30) NULL
Non-Formatted:	[CPU_delta] [int] NULL
	(Requires @delta_interval option)
	Difference between the CPU time reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[context_switches_delta] [varchar](30) NULL
Non-Formatted:	[context_switches_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the context switches count reported on the first and second collections
	If the request started after the first collection, the value will be NULL

Formatted:		[used_memory_delta] [varchar](30) NULL
Non-Formatted:	[used_memory_delta] [bigint] NULL
	Difference between the memory usage reported on the first and second collections
	If the request started after the first collection, the value will be NULL

Formatted:		[tasks] [varchar](30) NULL
Non-Formatted:	[tasks] [smallint] NULL
	Number of worker tasks currently allocated, for active requests

Formatted/Non:	[status] [varchar](30) NOT NULL
	Activity status for the session (running, sleeping, etc)

Formatted/Non:	[wait_info] [nvarchar](4000) NULL
	Aggregates wait information, in the following format:
		(Ax: Bms/Cms/Dms)E
	A is the number of waiting tasks currently waiting on resource type E. B/C/D are wait
	times, in milliseconds. If only one thread is waiting, its wait time will be shown as B.
	If two tasks are waiting, each of their wait times will be shown (B/C). If three or more 
	tasks are waiting, the minimum, average, and maximum wait times will be shown (B/C/D).
	If wait type E is a page latch wait and the page is of a "special" type (e.g. PFS, GAM, SGAM), 
	the page type will be identified.
	If wait type E is CXPACKET, the nodeId from the query plan will be identified

Formatted/Non:	[locks] [xml] NULL
	(Requires @get_locks option)
	Aggregates lock information, in XML format.
	The lock XML includes the lock mode, locked object, and aggregates the number of requests. 
	Attempts are made to identify locked objects by name

Formatted/Non:	[tran_start_time] [datetime] NULL
	(Requires @get_transaction_info option)
	Date and time that the first transaction opened by a session caused a transaction log 
	write to occur.

Formatted/Non:	[tran_log_writes] [nvarchar](4000) NULL
	(Requires @get_transaction_info option)
	Aggregates transaction log write information, in the following format:
	A:wB (C kB)
	A is a database that has been touched by an active transaction
	B is the number of log writes that have been made in the database as a result of the transaction
	C is the number of log kilobytes consumed by the log records

Formatted:		[open_tran_count] [varchar](30) NULL
Non-Formatted:	[open_tran_count] [smallint] NULL
	Shows the number of open transactions the session has open

Formatted:		[sql_command] [xml] NULL
Non-Formatted:	[sql_command] [nvarchar](max) NULL
	(Requires @get_outer_command option)
	Shows the "outer" SQL command, i.e. the text of the batch or RPC sent to the server, 
	if available

Formatted:		[sql_text] [xml] NULL
Non-Formatted:	[sql_text] [nvarchar](max) NULL
	Shows the SQL text for active requests or the last statement executed
	for sleeping sessions, if available in either case.
	If @get_full_inner_text option is set, shows the full text of the batch.
	Otherwise, shows only the active statement within the batch.
	If the query text is locked, a special timeout message will be sent, in the following format:
		<timeout_exceeded />
	If an error occurs, an error message will be sent, in the following format:
		<error message="message" />

Formatted/Non:	[query_plan] [xml] NULL
	(Requires @get_plans option)
	Shows the query plan for the request, if available.
	If the plan is locked, a special timeout message will be sent, in the following format:
		<timeout_exceeded />
	If an error occurs, an error message will be sent, in the following format:
		<error message="message" />

Formatted/Non:	[blocking_session_id] [smallint] NULL
	When applicable, shows the blocking SPID

Formatted:		[blocked_session_count] [varchar](30) NULL
Non-Formatted:	[blocked_session_count] [smallint] NULL
	(Requires @find_block_leaders option)
	The total number of SPIDs blocked by this session,
	all the way down the blocking chain.

Formatted:		[percent_complete] [varchar](30) NULL
Non-Formatted:	[percent_complete] [real] NULL
	When applicable, shows the percent complete (e.g. for backups, restores, and some rollbacks)

Formatted/Non:	[host_name] [sysname] NOT NULL
	Shows the host name for the connection

Formatted/Non:	[login_name] [sysname] NOT NULL
	Shows the login name for the connection

Formatted/Non:	[database_name] [sysname] NULL
	Shows the connected database

Formatted/Non:	[program_name] [sysname] NULL
	Shows the reported program/application name

Formatted/Non:	[additional_info] [xml] NULL
	(Requires @get_additional_info option)
	Returns additional non-performance-related session/request information
	If the script finds a SQL Agent job running, the name of the job and job step will be reported
	If @get_task_info = 2 and the script finds a lock wait, the locked object will be reported

Formatted/Non:	[start_time] [datetime] NOT NULL
	For active requests, shows the time the request started
	For sleeping sessions, shows the time the last batch completed

Formatted/Non:	[login_time] [datetime] NOT NULL
	Shows the time that the session connected

Formatted/Non:	[request_id] [int] NULL
	For active requests, shows the request_id
	Should be 0 unless MARS is being used

Formatted/Non:	[collection_time] [datetime] NOT NULL
	Time that this script's final SELECT ran
*/
AS
BEGIN;
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET QUOTED_IDENTIFIER ON;
	SET ANSI_PADDING ON;
	SET CONCAT_NULL_YIELDS_NULL ON;
	SET ANSI_WARNINGS ON;
	SET NUMERIC_ROUNDABORT OFF;
	SET ARITHABORT ON;

	IF
		@filter IS NULL
		OR @filter_type IS NULL
		OR @not_filter IS NULL
		OR @not_filter_type IS NULL
		OR @show_own_spid IS NULL
		OR @show_system_spids IS NULL
		OR @show_sleeping_spids IS NULL
		OR @get_full_inner_text IS NULL
		OR @get_plans IS NULL
		OR @get_outer_command IS NULL
		OR @get_transaction_info IS NULL
		OR @get_task_info IS NULL
		OR @get_locks IS NULL
		OR @get_avg_time IS NULL
		OR @get_additional_info IS NULL
		OR @find_block_leaders IS NULL
		OR @delta_interval IS NULL
		OR @format_output IS NULL
		OR @output_column_list IS NULL
		OR @sort_order IS NULL
		OR @return_schema IS NULL
		OR @destination_table IS NULL
		OR @help IS NULL
	BEGIN;
		RAISERROR('Input parameters cannot be NULL', 16, 1);
		RETURN;
	END;
	
	IF @filter_type NOT IN ('session', 'program', 'database', 'login', 'host')
	BEGIN;
		RAISERROR('Valid filter types are: session, program, database, login, host', 16, 1);
		RETURN;
	END;
	
	IF @filter_type = 'session' AND @filter LIKE '%[^0123456789]%'
	BEGIN;
		RAISERROR('Session filters must be valid integers', 16, 1);
		RETURN;
	END;
	
	IF @not_filter_type NOT IN ('session', 'program', 'database', 'login', 'host')
	BEGIN;
		RAISERROR('Valid filter types are: session, program, database, login, host', 16, 1);
		RETURN;
	END;
	
	IF @not_filter_type = 'session' AND @not_filter LIKE '%[^0123456789]%'
	BEGIN;
		RAISERROR('Session filters must be valid integers', 16, 1);
		RETURN;
	END;
	
	IF @show_sleeping_spids NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @show_sleeping_spids are: 0, 1, or 2', 16, 1);
		RETURN;
	END;
	
	IF @get_plans NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @get_plans are: 0, 1, or 2', 16, 1);
		RETURN;
	END;

	IF @get_task_info NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @get_task_info are: 0, 1, or 2', 16, 1);
		RETURN;
	END;

	IF @format_output NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @format_output are: 0, 1, or 2', 16, 1);
		RETURN;
	END;
	
	IF @help = 1
	BEGIN;
		DECLARE 
			@header VARCHAR(MAX),
			@params VARCHAR(MAX),
			@outputs VARCHAR(MAX);

		SELECT 
			@header =
				REPLACE
				(
					REPLACE
					(
						CONVERT
						(
							VARCHAR(MAX),
							SUBSTRING
							(
								t.text, 
								CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94,
								CHARINDEX(REPLICATE('*', 93) + '/', t.text) - (CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94)
							)
						),
						CHAR(13)+CHAR(10),
						CHAR(13)
					),
					'	',
					''
				),
			@params =
				CHAR(13) +
					REPLACE
					(
						REPLACE
						(
							CONVERT
							(
								VARCHAR(MAX),
								SUBSTRING
								(
									t.text, 
									CHARINDEX('--~', t.text) + 5, 
									CHARINDEX('--~', t.text, CHARINDEX('--~', t.text) + 5) - (CHARINDEX('--~', t.text) + 5)
								)
							),
							CHAR(13)+CHAR(10),
							CHAR(13)
						),
						'	',
						''
					),
				@outputs = 
					CHAR(13) +
						REPLACE
						(
							REPLACE
							(
								REPLACE
								(
									CONVERT
									(
										VARCHAR(MAX),
										SUBSTRING
										(
											t.text, 
											CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32,
											CHARINDEX('*/', t.text, CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32) - (CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32)
										)
									),
									CHAR(9),
									CHAR(255)
								),
								CHAR(13)+CHAR(10),
								CHAR(13)
							),
							'	',
							''
						) +
						CHAR(13)
		FROM sys.dm_exec_requests AS r
		CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
		WHERE
			r.session_id = @@SPID;

		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@header) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		)
		SELECT
			RTRIM(LTRIM(
				SUBSTRING
				(
					@header,
					number + 1,
					CHARINDEX(CHAR(13), @header, number + 1) - number - 1
				)
			)) AS [------header---------------------------------------------------------------------------------------------------------------]
		FROM numbers
		WHERE
			SUBSTRING(@header, number, 1) = CHAR(13);

		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@params) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		),
		tokens AS
		(
			SELECT 
				RTRIM(LTRIM(
					SUBSTRING
					(
						@params,
						number + 1,
						CHARINDEX(CHAR(13), @params, number + 1) - number - 1
					)
				)) AS token,
				number,
				CASE
					WHEN SUBSTRING(@params, number + 1, 1) = CHAR(13) THEN number
					ELSE COALESCE(NULLIF(CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number), 0), LEN(@params)) 
				END AS param_group,
				ROW_NUMBER() OVER
				(
					PARTITION BY
						CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number),
						SUBSTRING(@params, number+1, 1)
					ORDER BY 
						number
				) AS group_order
			FROM numbers
			WHERE
				SUBSTRING(@params, number, 1) = CHAR(13)
		),
		parsed_tokens AS
		(
			SELECT
				MIN
				(
					CASE
						WHEN token LIKE '@%' THEN token
						ELSE NULL
					END
				) AS parameter,
				MIN
				(
					CASE
						WHEN token LIKE '--%' THEN RIGHT(token, LEN(token) - 2)
						ELSE NULL
					END
				) AS description,
				param_group,
				group_order
			FROM tokens
			WHERE
				NOT 
				(
					token = '' 
					AND group_order > 1
				)
			GROUP BY
				param_group,
				group_order
		)
		SELECT
			CASE
				WHEN description IS NULL AND parameter IS NULL THEN '-------------------------------------------------------------------------'
				WHEN param_group = MAX(param_group) OVER() THEN parameter
				ELSE COALESCE(LEFT(parameter, LEN(parameter) - 1), '')
			END AS [------parameter----------------------------------------------------------],
			CASE
				WHEN description IS NULL AND parameter IS NULL THEN '----------------------------------------------------------------------------------------------------------------------'
				ELSE COALESCE(description, '')
			END AS [------description-----------------------------------------------------------------------------------------------------]
		FROM parsed_tokens
		ORDER BY
			param_group, 
			group_order;
		
		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@outputs) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		),
		tokens AS
		(
			SELECT 
				RTRIM(LTRIM(
					SUBSTRING
					(
						@outputs,
						number + 1,
						CASE
							WHEN 
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) < 
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2, @outputs, number + 1), 0), LEN(@outputs))
								THEN COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) - number - 1
							ELSE
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2, @outputs, number + 1), 0), LEN(@outputs)) - number - 1
						END
					)
				)) AS token,
				number,
				COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) AS output_group,
				ROW_NUMBER() OVER
				(
					PARTITION BY 
						COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs))
					ORDER BY
						number
				) AS output_group_order
			FROM numbers
			WHERE
				SUBSTRING(@outputs, number, 10) = CHAR(13) + 'Formatted'
				OR SUBSTRING(@outputs, number, 2) = CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2
		),
		output_tokens AS
		(
			SELECT 
				*,
				CASE output_group_order
					WHEN 2 THEN MAX(CASE output_group_order WHEN 1 THEN token ELSE NULL END) OVER (PARTITION BY output_group)
					ELSE ''
				END COLLATE Latin1_General_Bin2 AS column_info
			FROM tokens
		)
		SELECT
			CASE output_group_order
				WHEN 1 THEN '-----------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN
							SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+1, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info))
						ELSE
							SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)-1)
					END
				ELSE ''
			END AS formatted_column_name,
			CASE output_group_order
				WHEN 1 THEN '-----------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN
							SUBSTRING(column_info, CHARINDEX(']', column_info)+2, LEN(column_info))
						ELSE
							SUBSTRING(column_info, CHARINDEX(']', column_info)+2, CHARINDEX('Non-Formatted:', column_info, CHARINDEX(']', column_info)+2) - CHARINDEX(']', column_info)-3)
					END
				ELSE ''
			END AS formatted_column_type,
			CASE output_group_order
				WHEN 1 THEN '---------------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN ''
						ELSE
							CASE
								WHEN SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, 1) = '<' THEN
									SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, CHARINDEX('>', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info)))
								ELSE
									SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info)))
							END
					END
				ELSE ''
			END AS unformatted_column_name,
			CASE output_group_order
				WHEN 1 THEN '---------------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN ''
						ELSE
							CASE
								WHEN SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, 1) = '<' THEN ''
								ELSE
									SUBSTRING(column_info, CHARINDEX(']', column_info, CHARINDEX('Non-Formatted:', column_info))+2, CHARINDEX('Non-Formatted:', column_info, CHARINDEX(']', column_info)+2) - CHARINDEX(']', column_info)-3)
							END
					END
				ELSE ''
			END AS unformatted_column_type,
			CASE output_group_order
				WHEN 1 THEN '----------------------------------------------------------------------------------------------------------------------'
				ELSE REPLACE(token, CHAR(255) COLLATE Latin1_General_Bin2, '')
			END AS [------description-----------------------------------------------------------------------------------------------------]
		FROM output_tokens
		WHERE
			NOT 
			(
				output_group_order = 1 
				AND output_group = LEN(@outputs)
			)
		ORDER BY
			output_group,
			CASE output_group_order
				WHEN 1 THEN 99
				ELSE output_group_order
			END;

		RETURN;
	END;

	WITH
	a0 AS
	(SELECT 1 AS n UNION ALL SELECT 1),
	a1 AS
	(SELECT 1 AS n FROM a0 AS a, a0 AS b),
	a2 AS
	(SELECT 1 AS n FROM a1 AS a, a1 AS b),
	a3 AS
	(SELECT 1 AS n FROM a2 AS a, a2 AS b),
	a4 AS
	(SELECT 1 AS n FROM a3 AS a, a3 AS b),
	numbers AS
	(
		SELECT TOP(LEN(@output_column_list))
			ROW_NUMBER() OVER
			(
				ORDER BY (SELECT NULL)
			) AS number
		FROM a4
		ORDER BY
			number
	),
	tokens AS
	(
		SELECT 
			'|[' +
				SUBSTRING
				(
					@output_column_list,
					number + 1,
					CHARINDEX(']', @output_column_list, number) - number - 1
				) + '|]' AS token,
			number
		FROM numbers
		WHERE
			SUBSTRING(@output_column_list, number, 1) = '['
	),
	ordered_columns AS
	(
		SELECT
			x.column_name,
			ROW_NUMBER() OVER
			(
				PARTITION BY
					x.column_name
				ORDER BY
					tokens.number,
					x.default_order
			) AS r,
			ROW_NUMBER() OVER
			(
				ORDER BY
					tokens.number,
					x.default_order
			) AS s
		FROM tokens
		JOIN
		(
			SELECT '[session_id]' AS column_name, 1 AS default_order
			UNION ALL
			SELECT '[dd hh:mm:ss.mss]', 2
			WHERE
				@format_output IN (1, 2)
			UNION ALL
			SELECT '[dd hh:mm:ss.mss (avg)]', 3
			WHERE
				@format_output IN (1, 2)
				AND @get_avg_time = 1
			UNION ALL
			SELECT '[avg_elapsed_time]', 4
			WHERE
				@format_output = 0
				AND @get_avg_time = 1
			UNION ALL
			SELECT '[physical_io]', 5
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[reads]', 6
			UNION ALL
			SELECT '[physical_reads]', 7
			UNION ALL
			SELECT '[writes]', 8
			UNION ALL
			SELECT '[tempdb_allocations]', 9
			UNION ALL
			SELECT '[tempdb_current]', 10
			UNION ALL
			SELECT '[CPU]', 11
			UNION ALL
			SELECT '[context_switches]', 12
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[used_memory]', 13
			UNION ALL
			SELECT '[physical_io_delta]', 14
			WHERE
				@delta_interval > 0	
				AND @get_task_info = 2
			UNION ALL
			SELECT '[reads_delta]', 15
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[physical_reads_delta]', 16
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[writes_delta]', 17
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tempdb_allocations_delta]', 18
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tempdb_current_delta]', 19
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[CPU_delta]', 20
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[context_switches_delta]', 21
			WHERE
				@delta_interval > 0
				AND @get_task_info = 2
			UNION ALL
			SELECT '[used_memory_delta]', 22
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tasks]', 23
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[status]', 24
			UNION ALL
			SELECT '[wait_info]', 25
			WHERE
				@get_task_info > 0
				OR @find_block_leaders = 1
			UNION ALL
			SELECT '[locks]', 26
			WHERE
				@get_locks = 1
			UNION ALL
			SELECT '[tran_start_time]', 27
			WHERE
				@get_transaction_info = 1
			UNION ALL
			SELECT '[tran_log_writes]', 28
			WHERE
				@get_transaction_info = 1
			UNION ALL
			SELECT '[open_tran_count]', 29
			UNION ALL
			SELECT '[sql_command]', 30
			WHERE
				@get_outer_command = 1
			UNION ALL
			SELECT '[sql_text]', 31
			UNION ALL
			SELECT '[query_plan]', 32
			WHERE
				@get_plans >= 1
			UNION ALL
			SELECT '[blocking_session_id]', 33
			WHERE
				@get_task_info > 0
				OR @find_block_leaders = 1
			UNION ALL
			SELECT '[blocked_session_count]', 34
			WHERE
				@find_block_leaders = 1
			UNION ALL
			SELECT '[percent_complete]', 35
			UNION ALL
			SELECT '[host_name]', 36
			UNION ALL
			SELECT '[login_name]', 37
			UNION ALL
			SELECT '[database_name]', 38
			UNION ALL
			SELECT '[program_name]', 39
			UNION ALL
			SELECT '[additional_info]', 40
			WHERE
				@get_additional_info = 1
			UNION ALL
			SELECT '[start_time]', 41
			UNION ALL
			SELECT '[login_time]', 42
			UNION ALL
			SELECT '[request_id]', 43
			UNION ALL
			SELECT '[collection_time]', 44
		) AS x ON 
			x.column_name LIKE token ESCAPE '|'
	)
	SELECT
		@output_column_list =
			STUFF
			(
				(
					SELECT
						',' + column_name as [text()]
					FROM ordered_columns
					WHERE
						r = 1
					ORDER BY
						s
					FOR XML
						PATH('')
				),
				1,
				1,
				''
			);
	
	IF COALESCE(RTRIM(@output_column_list), '') = ''
	BEGIN;
		RAISERROR('No valid column matches found in @output_column_list or no columns remain due to selected options.', 16, 1);
		RETURN;
	END;
	
	IF @destination_table <> ''
	BEGIN;
		SET @destination_table = 
			--database
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 3)) + '.', '') +
			--schema
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 2)) + '.', '') +
			--table
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 1)), '');
			
		IF COALESCE(RTRIM(@destination_table), '') = ''
		BEGIN;
			RAISERROR('Destination table not properly formatted.', 16, 1);
			RETURN;
		END;
	END;

	WITH
	a0 AS
	(SELECT 1 AS n UNION ALL SELECT 1),
	a1 AS
	(SELECT 1 AS n FROM a0 AS a, a0 AS b),
	a2 AS
	(SELECT 1 AS n FROM a1 AS a, a1 AS b),
	a3 AS
	(SELECT 1 AS n FROM a2 AS a, a2 AS b),
	a4 AS
	(SELECT 1 AS n FROM a3 AS a, a3 AS b),
	numbers AS
	(
		SELECT TOP(LEN(@sort_order))
			ROW_NUMBER() OVER
			(
				ORDER BY (SELECT NULL)
			) AS number
		FROM a4
		ORDER BY
			number
	),
	tokens AS
	(
		SELECT 
			'|[' +
				SUBSTRING
				(
					@sort_order,
					number + 1,
					CHARINDEX(']', @sort_order, number) - number - 1
				) + '|]' AS token,
			SUBSTRING
			(
				@sort_order,
				CHARINDEX(']', @sort_order, number) + 1,
				COALESCE(NULLIF(CHARINDEX('[', @sort_order, CHARINDEX(']', @sort_order, number)), 0), LEN(@sort_order)) - CHARINDEX(']', @sort_order, number)
			) AS next_chunk,
			number
		FROM numbers
		WHERE
			SUBSTRING(@sort_order, number, 1) = '['
	),
	ordered_columns AS
	(
		SELECT
			x.column_name +
				CASE
					WHEN tokens.next_chunk LIKE '%asc%' THEN ' ASC'
					WHEN tokens.next_chunk LIKE '%desc%' THEN ' DESC'
					ELSE ''
				END AS column_name,
			ROW_NUMBER() OVER
			(
				PARTITION BY
					x.column_name
				ORDER BY
					tokens.number
			) AS r,
			tokens.number
		FROM tokens
		JOIN
		(
			SELECT '[session_id]' AS column_name
			UNION ALL
			SELECT '[physical_io]'
			UNION ALL
			SELECT '[reads]'
			UNION ALL
			SELECT '[physical_reads]'
			UNION ALL
			SELECT '[writes]'
			UNION ALL
			SELECT '[tempdb_allocations]'
			UNION ALL
			SELECT '[tempdb_current]'
			UNION ALL
			SELECT '[CPU]'
			UNION ALL
			SELECT '[context_switches]'
			UNION ALL
			SELECT '[used_memory]'
			UNION ALL
			SELECT '[physical_io_delta]'
			UNION ALL
			SELECT '[reads_delta]'
			UNION ALL
			SELECT '[physical_reads_delta]'
			UNION ALL
			SELECT '[writes_delta]'
			UNION ALL
			SELECT '[tempdb_allocations_delta]'
			UNION ALL
			SELECT '[tempdb_current_delta]'
			UNION ALL
			SELECT '[CPU_delta]'
			UNION ALL
			SELECT '[context_switches_delta]'
			UNION ALL
			SELECT '[used_memory_delta]'
			UNION ALL
			SELECT '[tasks]'
			UNION ALL
			SELECT '[tran_start_time]'
			UNION ALL
			SELECT '[open_tran_count]'
			UNION ALL
			SELECT '[blocking_session_id]'
			UNION ALL
			SELECT '[blocked_session_count]'
			UNION ALL
			SELECT '[percent_complete]'
			UNION ALL
			SELECT '[host_name]'
			UNION ALL
			SELECT '[login_name]'
			UNION ALL
			SELECT '[database_name]'
			UNION ALL
			SELECT '[start_time]'
			UNION ALL
			SELECT '[login_time]'
			UNION ALL
			SELECT '[program_name]'
		) AS x ON 
			x.column_name LIKE token ESCAPE '|'
	)
	SELECT
		@sort_order = COALESCE(z.sort_order, '')
	FROM
	(
		SELECT
			STUFF
			(
				(
					SELECT
						',' + column_name as [text()]
					FROM ordered_columns
					WHERE
						r = 1
					ORDER BY
						number
					FOR XML
						PATH('')
				),
				1,
				1,
				''
			) AS sort_order
	) AS z;

	CREATE TABLE #sessions
	(
		recursion SMALLINT NOT NULL,
		session_id SMALLINT NOT NULL,
		request_id INT NOT NULL,
		session_number INT NOT NULL,
		elapsed_time INT NOT NULL,
		avg_elapsed_time INT NULL,
		physical_io BIGINT NULL,
		reads BIGINT NULL,
		physical_reads BIGINT NULL,
		writes BIGINT NULL,
		tempdb_allocations BIGINT NULL,
		tempdb_current BIGINT NULL,
		CPU INT NULL,
		thread_CPU_snapshot BIGINT NULL,
		context_switches BIGINT NULL,
		used_memory BIGINT NOT NULL, 
		tasks SMALLINT NULL,
		status VARCHAR(30) NOT NULL,
		wait_info NVARCHAR(4000) NULL,
		locks XML NULL,
		transaction_id BIGINT NULL,
		tran_start_time DATETIME NULL,
		tran_log_writes NVARCHAR(4000) NULL,
		open_tran_count SMALLINT NULL,
		sql_command XML NULL,
		sql_handle VARBINARY(64) NULL,
		statement_start_offset INT NULL,
		statement_end_offset INT NULL,
		sql_text XML NULL,
		plan_handle VARBINARY(64) NULL,
		query_plan XML NULL,
		blocking_session_id SMALLINT NULL,
		blocked_session_count SMALLINT NULL,
		percent_complete REAL NULL,
		host_name sysname NULL,
		login_name sysname NOT NULL,
		database_name sysname NULL,
		program_name sysname NULL,
		additional_info XML NULL,
		start_time DATETIME NOT NULL,
		login_time DATETIME NULL,
		last_request_start_time DATETIME NULL,
		PRIMARY KEY CLUSTERED (session_id, request_id, recursion) WITH (IGNORE_DUP_KEY = ON),
		UNIQUE NONCLUSTERED (transaction_id, session_id, request_id, recursion) WITH (IGNORE_DUP_KEY = ON)
	);

	IF @return_schema = 0
	BEGIN;
		--Disable unnecessary autostats on the table
		CREATE STATISTICS s_session_id ON #sessions (session_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_request_id ON #sessions (request_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_transaction_id ON #sessions (transaction_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_session_number ON #sessions (session_number)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_status ON #sessions (status)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_start_time ON #sessions (start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_last_request_start_time ON #sessions (last_request_start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_recursion ON #sessions (recursion)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;

		DECLARE @recursion SMALLINT;
		SET @recursion = 
			CASE @delta_interval
				WHEN 0 THEN 1
				ELSE -1
			END;

		DECLARE @first_collection_ms_ticks BIGINT;
		DECLARE @last_collection_start DATETIME;
		DECLARE @sys_info BIT;
		SET @sys_info = ISNULL(CONVERT(BIT, SIGN(OBJECT_ID('sys.dm_os_sys_info'))), 0);

		--Used for the delta pull
		REDO:;
		
		IF 
			@get_locks = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[locks|]%' ESCAPE '|'
		BEGIN;
			SELECT
				y.resource_type,
				y.database_name,
				y.object_id,
				y.file_id,
				y.page_type,
				y.hobt_id,
				y.allocation_unit_id,
				y.index_id,
				y.schema_id,
				y.principal_id,
				y.request_mode,
				y.request_status,
				y.session_id,
				y.resource_description,
				y.request_count,
				s.request_id,
				s.start_time,
				CONVERT(sysname, NULL) AS object_name,
				CONVERT(sysname, NULL) AS index_name,
				CONVERT(sysname, NULL) AS schema_name,
				CONVERT(sysname, NULL) AS principal_name,
				CONVERT(NVARCHAR(2048), NULL) AS query_error
			INTO #locks
			FROM
			(
				SELECT
					sp.spid AS session_id,
					CASE sp.status
						WHEN 'sleeping' THEN CONVERT(INT, 0)
						ELSE sp.request_id
					END AS request_id,
					CASE sp.status
						WHEN 'sleeping' THEN sp.last_batch
						ELSE COALESCE(req.start_time, sp.last_batch)
					END AS start_time,
					sp.dbid
				FROM sys.sysprocesses AS sp
				OUTER APPLY
				(
					SELECT TOP(1)
						CASE
							WHEN 
							(
								sp.hostprocess > ''
								OR r.total_elapsed_time < 0
							) THEN
								r.start_time
							ELSE
								DATEADD
								(
									ms, 
									1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())), 
									DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
								)
						END AS start_time
					FROM sys.dm_exec_requests AS r
					WHERE
						r.session_id = sp.spid
						AND r.request_id = sp.request_id
				) AS req
				WHERE
					--Process inclusive filter
					1 =
						CASE
							WHEN @filter <> '' THEN
								CASE @filter_type
									WHEN 'session' THEN
										CASE
											WHEN
												CONVERT(SMALLINT, @filter) = 0
												OR sp.spid = CONVERT(SMALLINT, @filter)
													THEN 1
											ELSE 0
										END
									WHEN 'program' THEN
										CASE
											WHEN sp.program_name LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'login' THEN
										CASE
											WHEN sp.loginame LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'host' THEN
										CASE
											WHEN sp.hostname LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'database' THEN
										CASE
											WHEN DB_NAME(sp.dbid) LIKE @filter THEN 1
											ELSE 0
										END
									ELSE 0
								END
							ELSE 1
						END
					--Process exclusive filter
					AND 0 =
						CASE
							WHEN @not_filter <> '' THEN
								CASE @not_filter_type
									WHEN 'session' THEN
										CASE
											WHEN sp.spid = CONVERT(SMALLINT, @not_filter) THEN 1
											ELSE 0
										END
									WHEN 'program' THEN
										CASE
											WHEN sp.program_name LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'login' THEN
										CASE
											WHEN sp.loginame LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'host' THEN
										CASE
											WHEN sp.hostname LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'database' THEN
										CASE
											WHEN DB_NAME(sp.dbid) LIKE @not_filter THEN 1
											ELSE 0
										END
									ELSE 0
								END
							ELSE 0
						END
					AND 
					(
						@show_own_spid = 1
						OR sp.spid <> @@SPID
					)
					AND 
					(
						@show_system_spids = 1
						OR sp.hostprocess > ''
					)
					AND sp.ecid = 0
			) AS s
			INNER HASH JOIN
			(
				SELECT
					x.resource_type,
					x.database_name,
					x.object_id,
					x.file_id,
					CASE
						WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
						WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
						WHEN x.page_no = 3 OR (x.page_no - 1) % 511232 = 0 THEN 'SGAM'
						WHEN x.page_no = 6 OR (x.page_no - 6) % 511232 = 0 THEN 'DCM'
						WHEN x.page_no = 7 OR (x.page_no - 7) % 511232 = 0 THEN 'BCM'
						WHEN x.page_no IS NOT NULL THEN '*'
						ELSE NULL
					END AS page_type,
					x.hobt_id,
					x.allocation_unit_id,
					x.index_id,
					x.schema_id,
					x.principal_id,
					x.request_mode,
					x.request_status,
					x.session_id,
					x.request_id,
					CASE
						WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
						ELSE NULL
					END AS resource_description,
					COUNT(*) AS request_count
				FROM
				(
					SELECT
						tl.resource_type +
							CASE
								WHEN tl.resource_subtype = '' THEN ''
								ELSE '.' + tl.resource_subtype
							END AS resource_type,
						COALESCE(DB_NAME(tl.resource_database_id), N'(null)') AS database_name,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_type = 'OBJECT' THEN tl.resource_associated_entity_id
								WHEN tl.resource_description LIKE '%object_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('object_id = ', tl.resource_description) + 12), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('object_id = ', tl.resource_description) + 12),
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('object_id = ', tl.resource_description) + 12)
										)
									)
								ELSE NULL
							END
						) AS object_id,
						CONVERT
						(
							INT,
							CASE 
								WHEN tl.resource_type = 'FILE' THEN CONVERT(INT, tl.resource_description)
								WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN LEFT(tl.resource_description, CHARINDEX(':', tl.resource_description)-1)
								ELSE NULL
							END
						) AS file_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN 
									SUBSTRING
									(
										tl.resource_description, 
										CHARINDEX(':', tl.resource_description) + 1, 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(':', tl.resource_description, CHARINDEX(':', tl.resource_description) + 1), 
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX(':', tl.resource_description) + 1)
									)
								ELSE NULL
							END
						) AS page_no,
						CASE
							WHEN tl.resource_type IN ('PAGE', 'KEY', 'RID', 'HOBT') THEN tl.resource_associated_entity_id
							ELSE NULL
						END AS hobt_id,
						CASE
							WHEN tl.resource_type = 'ALLOCATION_UNIT' THEN tl.resource_associated_entity_id
							ELSE NULL
						END AS allocation_unit_id,
						CONVERT
						(
							INT,
							CASE
								WHEN
									/* TODO: Deal with server principals */ 
									tl.resource_subtype <> 'SERVER_PRINCIPAL' 
									AND tl.resource_description LIKE '%index_id or stats_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23)
										)
									)
								ELSE NULL
							END 
						) AS index_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_description LIKE '%schema_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('schema_id = ', tl.resource_description) + 12), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('schema_id = ', tl.resource_description) + 12), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('schema_id = ', tl.resource_description) + 12)
										)
									)
								ELSE NULL
							END 
						) AS schema_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_description LIKE '%principal_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('principal_id = ', tl.resource_description) + 15), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('principal_id = ', tl.resource_description) + 15), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('principal_id = ', tl.resource_description) + 15)
										)
									)
								ELSE NULL
							END
						) AS principal_id,
						tl.request_mode,
						tl.request_status,
						tl.request_session_id AS session_id,
						tl.request_request_id AS request_id,

						/* TODO: Applocks, other resource_descriptions */
						RTRIM(tl.resource_description) AS resource_description,
						tl.resource_associated_entity_id
						/* ******************************************* */
					FROM 
					(
						SELECT 
							request_session_id,
							CONVERT(VARCHAR(120), resource_type) COLLATE Latin1_General_Bin2 AS resource_type,
							CONVERT(VARCHAR(120), resource_subtype) COLLATE Latin1_General_Bin2 AS resource_subtype,
							resource_database_id,
							CONVERT(VARCHAR(512), resource_description) COLLATE Latin1_General_Bin2 AS resource_description,
							resource_associated_entity_id,
							CONVERT(VARCHAR(120), request_mode) COLLATE Latin1_General_Bin2 AS request_mode,
							CONVERT(VARCHAR(120), request_status) COLLATE Latin1_General_Bin2 AS request_status,
							request_request_id
						FROM sys.dm_tran_locks
					) AS tl
				) AS x
				GROUP BY
					x.resource_type,
					x.database_name,
					x.object_id,
					x.file_id,
					CASE
						WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
						WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
						WHEN x.page_no = 3 OR (x.page_no - 1) % 511232 = 0 THEN 'SGAM'
						WHEN x.page_no = 6 OR (x.page_no - 6) % 511232 = 0 THEN 'DCM'
						WHEN x.page_no = 7 OR (x.page_no - 7) % 511232 = 0 THEN 'BCM'
						WHEN x.page_no IS NOT NULL THEN '*'
						ELSE NULL
					END,
					x.hobt_id,
					x.allocation_unit_id,
					x.index_id,
					x.schema_id,
					x.principal_id,
					x.request_mode,
					x.request_status,
					x.session_id,
					x.request_id,
					CASE
						WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
						ELSE NULL
					END
			) AS y ON
				y.session_id = s.session_id
				AND y.request_id = s.request_id
			OPTION (HASH GROUP);

			--Disable unnecessary autostats on the table
			CREATE STATISTICS s_database_name ON #locks (database_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_id ON #locks (object_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_hobt_id ON #locks (hobt_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_allocation_unit_id ON #locks (allocation_unit_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_index_id ON #locks (index_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_id ON #locks (schema_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_principal_id ON #locks (principal_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_id ON #locks (request_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_start_time ON #locks (start_time)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_resource_type ON #locks (resource_type)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_name ON #locks (object_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_name ON #locks (schema_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_page_type ON #locks (page_type)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_mode ON #locks (request_mode)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_status ON #locks (request_status)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_resource_description ON #locks (resource_description)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_index_name ON #locks (index_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_principal_name ON #locks (principal_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
		END;
		
		DECLARE 
			@sql VARCHAR(MAX), 
			@sql_n NVARCHAR(MAX);

		SET @sql = 
			CONVERT(VARCHAR(MAX), '') +
			'DECLARE @blocker BIT;
			SET @blocker = 0;
			DECLARE @i INT;
			SET @i = 2147483647;

			DECLARE @sessions TABLE
			(
				session_id SMALLINT NOT NULL,
				request_id INT NOT NULL,
				login_time DATETIME,
				last_request_end_time DATETIME,
				status VARCHAR(30),
				statement_start_offset INT,
				statement_end_offset INT,
				sql_handle BINARY(20),
				host_name NVARCHAR(128),
				login_name NVARCHAR(128),
				program_name NVARCHAR(128),
				database_id SMALLINT,
				memory_usage INT,
				open_tran_count SMALLINT, 
				' +
				CASE
					WHEN 
					(
						@get_task_info <> 0 
						OR @find_block_leaders = 1 
					) THEN
						'wait_type NVARCHAR(32),
						wait_resource NVARCHAR(256),
						wait_time BIGINT, 
						'
					ELSE 
						''
				END +
				'blocked SMALLINT,
				is_user_process BIT,
				cmd VARCHAR(32),
				PRIMARY KEY CLUSTERED (session_id, request_id) WITH (IGNORE_DUP_KEY = ON)
			);

			DECLARE @blockers TABLE
			(
				session_id INT NOT NULL PRIMARY KEY WITH (IGNORE_DUP_KEY = ON)
			);

			BLOCKERS:;

			INSERT @sessions
			(
				session_id,
				request_id,
				login_time,
				last_request_end_time,
				status,
				statement_start_offset,
				statement_end_offset,
				sql_handle,
				host_name,
				login_name,
				program_name,
				database_id,
				memory_usage,
				open_tran_count, 
				' +
				CASE
					WHEN 
					(
						@get_task_info <> 0
						OR @find_block_leaders = 1 
					) THEN
						'wait_type,
						wait_resource,
						wait_time, 
						'
					ELSE
						''
				END +
				'blocked,
				is_user_process,
				cmd 
			)
			SELECT TOP(@i)
				spy.session_id,
				spy.request_id,
				spy.login_time,
				spy.last_request_end_time,
				spy.status,
				spy.statement_start_offset,
				spy.statement_end_offset,
				spy.sql_handle,
				spy.host_name,
				spy.login_name,
				--spy.program_name,
				CASE LEFT(spy.program_name,15)
            WHEN ''SQLAgent - TSQL'' THEN 
            (     select top 1 ''SQL Job = ''+j.name from msdb.dbo.sysjobs (nolock) j
                  inner join msdb.dbo.sysjobsteps (nolock) s on j.job_id=s.job_id
                  where right(cast(s.job_id as nvarchar(50)),10) = RIGHT(substring(spy.program_name,30,34),10) )
            WHEN ''SQL Server Prof'' THEN ''SQL Server Profiler''
            ELSE spy.program_name
            END as Program_name,
				spy.database_id,
				spy.memory_usage,
				spy.open_tran_count,
				' +
				CASE
					WHEN 
					(
						@get_task_info <> 0  
						OR @find_block_leaders = 1 
					) THEN
						'spy.wait_type,
						CASE
							WHEN
								spy.wait_type LIKE N''PAGE%LATCH_%''
								OR spy.wait_type = N''CXPACKET''
								OR spy.wait_type LIKE N''LATCH[_]%''
								OR spy.wait_type = N''OLEDB'' THEN
									spy.wait_resource
							ELSE
								NULL
						END AS wait_resource,
						spy.wait_time, 
						'
					ELSE
						''
				END +
				'spy.blocked,
				spy.is_user_process,
				spy.cmd
			FROM
			(
				SELECT TOP(@i)
					spx.*, 
					' +
					CASE
						WHEN 
						(
							@get_task_info <> 0 
							OR @find_block_leaders = 1 
						) THEN
							'ROW_NUMBER() OVER
							(
								PARTITION BY
									spx.session_id,
									spx.request_id
								ORDER BY
									CASE
										WHEN spx.wait_type LIKE N''LCK[_]%'' THEN 
											1
										ELSE
											99
									END,
									spx.wait_time DESC,
									spx.blocked DESC
							) AS r 
							'
						ELSE 
							'1 AS r 
							'
					END +
				'FROM
				(
					SELECT TOP(@i)
						sp0.session_id,
						sp0.request_id,
						sp0.login_time,
						sp0.last_request_end_time,
						LOWER(sp0.status) AS status,
						CASE
							WHEN sp0.cmd = ''CREATE INDEX'' THEN
								0
							ELSE
								sp0.stmt_start
						END AS statement_start_offset,
						CASE
							WHEN sp0.cmd = N''CREATE INDEX'' THEN
								-1
							ELSE
								COALESCE(NULLIF(sp0.stmt_end, 0), -1)
						END AS statement_end_offset,
						sp0.sql_handle,
						sp0.host_name,
						sp0.login_name,
						sp0.program_name,
						sp0.database_id,
						sp0.memory_usage,
						sp0.open_tran_count, 
						' +
						CASE
							WHEN 
							(
								@get_task_info <> 0 
								OR @find_block_leaders = 1 
							) THEN
								'CASE
									WHEN sp0.wait_time > 0 AND sp0.wait_type <> N''CXPACKET'' THEN
										sp0.wait_type
									ELSE
										NULL
								END AS wait_type,
								CASE
									WHEN sp0.wait_time > 0 AND sp0.wait_type <> N''CXPACKET'' THEN 
										sp0.wait_resource
									ELSE
										NULL
								END AS wait_resource,
								CASE
									WHEN sp0.wait_type <> N''CXPACKET'' THEN
										sp0.wait_time
									ELSE
										0
								END AS wait_time, 
								'
							ELSE
								''
						END +
						'sp0.blocked,
						sp0.is_user_process,
						sp0.cmd
					FROM
					(
						SELECT TOP(@i)
							sp1.session_id,
							sp1.request_id,
							sp1.login_time,
							sp1.last_request_end_time,
							sp1.status,
							sp1.cmd,
							sp1.stmt_start,
							sp1.stmt_end,
							MAX(NULLIF(sp1.sql_handle, 0x00)) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS sql_handle,
							sp1.host_name,
							MAX(sp1.login_name) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS login_name,
							sp1.program_name,
							sp1.database_id,
							MAX(sp1.memory_usage)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS memory_usage,
							MAX(sp1.open_tran_count)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS open_tran_count,
							sp1.wait_type,
							sp1.wait_resource,
							sp1.wait_time,
							sp1.blocked,
							sp1.hostprocess,
							sp1.is_user_process
						FROM
						(
							SELECT TOP(@i)
								sp2.spid AS session_id,
								CASE sp2.status
									WHEN ''sleeping'' THEN
										CONVERT(INT, 0)
									ELSE
										sp2.request_id
								END AS request_id,
								MAX(sp2.login_time) AS login_time,
								MAX(sp2.last_batch) AS last_request_end_time,
								MAX(CONVERT(VARCHAR(30), RTRIM(sp2.status)) COLLATE Latin1_General_Bin2) AS status,
								MAX(CONVERT(VARCHAR(32), RTRIM(sp2.cmd)) COLLATE Latin1_General_Bin2) AS cmd,
								MAX(sp2.stmt_start) AS stmt_start,
								MAX(sp2.stmt_end) AS stmt_end,
								MAX(sp2.sql_handle) AS sql_handle,
								MAX(CONVERT(sysname, RTRIM(sp2.hostname)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS host_name,
								MAX(CONVERT(sysname, RTRIM(sp2.loginame)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS login_name,
								MAX
								(
									CASE
										WHEN blk.queue_id IS NOT NULL THEN
											N''Service Broker
												database_id: '' + CONVERT(NVARCHAR, blk.database_id) +
												N'' queue_id: '' + CONVERT(NVARCHAR, blk.queue_id)
										ELSE
											CONVERT
											(
												sysname,
												RTRIM(sp2.program_name)
											)
									END COLLATE SQL_Latin1_General_CP1_CI_AS
								) AS program_name,
								MAX(sp2.dbid) AS database_id,
								MAX(sp2.memusage) AS memory_usage,
								MAX(sp2.open_tran) AS open_tran_count,
								RTRIM(sp2.lastwaittype) AS wait_type,
								RTRIM(sp2.waitresource) AS wait_resource,
								MAX(sp2.waittime) AS wait_time,
								COALESCE(NULLIF(sp2.blocked, sp2.spid), 0) AS blocked,
								MAX
								(
									CASE
										WHEN blk.session_id = sp2.spid THEN
											''blocker''
										ELSE
											RTRIM(sp2.hostprocess)
									END
								) AS hostprocess,
								CONVERT
								(
									BIT,
									MAX
									(
										CASE
											WHEN sp2.hostprocess > '''' THEN
												1
											ELSE
												0
										END
									)
								) AS is_user_process
							FROM
							(
								SELECT TOP(@i)
									session_id,
									CONVERT(INT, NULL) AS queue_id,
									CONVERT(INT, NULL) AS database_id
								FROM @blockers

								UNION ALL

								SELECT TOP(@i)
									CONVERT(SMALLINT, 0),
									CONVERT(INT, NULL) AS queue_id,
									CONVERT(INT, NULL) AS database_id
								WHERE
									@blocker = 0

								UNION ALL

								SELECT TOP(@i)
									CONVERT(SMALLINT, spid),
									queue_id,
									database_id
								FROM sys.dm_broker_activated_tasks
								WHERE
									@blocker = 0
							) AS blk
							INNER JOIN sys.sysprocesses AS sp2 ON
								sp2.spid = blk.session_id
								OR
								(
									blk.session_id = 0
									AND @blocker = 0
								)
							' +
							CASE 
								WHEN 
								(
									@get_task_info = 0 
									AND @find_block_leaders = 0
								) THEN
									'WHERE
										sp2.ecid = 0 
									' 
								ELSE
									''
							END +
							'GROUP BY
								sp2.spid,
								CASE sp2.status
									WHEN ''sleeping'' THEN
										CONVERT(INT, 0)
									ELSE
										sp2.request_id
								END,
								RTRIM(sp2.lastwaittype),
								RTRIM(sp2.waitresource),
								COALESCE(NULLIF(sp2.blocked, sp2.spid), 0)
						) AS sp1
					) AS sp0
					WHERE
						@blocker = 1
						OR
						(1=1 
						' +
							--inclusive filter
							CASE
								WHEN @filter <> '' THEN
									CASE @filter_type
										WHEN 'session' THEN
											CASE
												WHEN CONVERT(SMALLINT, @filter) <> 0 THEN
													'AND sp0.session_id = CONVERT(SMALLINT, @filter) 
													'
												ELSE
													''
											END
										WHEN 'program' THEN
											'AND sp0.program_name LIKE @filter 
											'
										WHEN 'login' THEN
											'AND sp0.login_name LIKE @filter 
											'
										WHEN 'host' THEN
											'AND sp0.host_name LIKE @filter 
											'
										WHEN 'database' THEN
											'AND DB_NAME(sp0.database_id) LIKE @filter 
											'
										ELSE
											''
									END
								ELSE
									''
							END +
							--exclusive filter
							CASE
								WHEN @not_filter <> '' THEN
									CASE @not_filter_type
										WHEN 'session' THEN
											CASE
												WHEN CONVERT(SMALLINT, @not_filter) <> 0 THEN
													'AND sp0.session_id <> CONVERT(SMALLINT, @not_filter) 
													'
												ELSE
													''
											END
										WHEN 'program' THEN
											'AND sp0.program_name NOT LIKE @not_filter 
											'
										WHEN 'login' THEN
											'AND sp0.login_name NOT LIKE @not_filter 
											'
										WHEN 'host' THEN
											'AND sp0.host_name NOT LIKE @not_filter 
											'
										WHEN 'database' THEN
											'AND DB_NAME(sp0.database_id) NOT LIKE @not_filter 
											'
										ELSE
											''
									END
								ELSE
									''
							END +
							CASE @show_own_spid
								WHEN 1 THEN
									''
								ELSE
									'AND sp0.session_id <> @@spid 
									'
							END +
							CASE 
								WHEN @show_system_spids = 0 THEN
									'AND sp0.hostprocess > '''' 
									' 
								ELSE
									''
							END +
							CASE @show_sleeping_spids
								WHEN 0 THEN
									'AND sp0.status <> ''sleeping'' 
									'
								WHEN 1 THEN
									'AND
									(
										sp0.status <> ''sleeping''
										OR sp0.open_tran_count > 0
									)
									'
								ELSE
									''
							END +
						')
				) AS spx
			) AS spy
			WHERE
				spy.r = 1; 
			' + 
			CASE @recursion
				WHEN 1 THEN 
					'IF @@ROWCOUNT > 0
					BEGIN;
						INSERT @blockers
						(
							session_id
						)
						SELECT TOP(@i)
							blocked
						FROM @sessions
						WHERE
							NULLIF(blocked, 0) IS NOT NULL

						EXCEPT

						SELECT TOP(@i)
							session_id
						FROM @sessions; 
						' +

						CASE
							WHEN
							(
								@get_task_info > 0
								OR @find_block_leaders = 1
							) THEN
								'IF @@ROWCOUNT > 0
								BEGIN;
									SET @blocker = 1;
									GOTO BLOCKERS;
								END; 
								'
							ELSE 
								''
						END +
					'END; 
					'
				ELSE 
					''
			END +
			'SELECT TOP(@i)
				@recursion AS recursion,
				x.session_id,
				x.request_id,
				DENSE_RANK() OVER
				(
					ORDER BY
						x.session_id
				) AS session_number,
				' +
				CASE
					WHEN @output_column_list LIKE '%|[dd hh:mm:ss.mss|]%' ESCAPE '|' THEN 
						'x.elapsed_time '
					ELSE 
						'0 '
				END + 
					'AS elapsed_time, 
					' +
				CASE
					WHEN
						(
							@output_column_list LIKE '%|[dd hh:mm:ss.mss (avg)|]%' ESCAPE '|' OR 
							@output_column_list LIKE '%|[avg_elapsed_time|]%' ESCAPE '|'
						)
						AND @recursion = 1
							THEN 
								'x.avg_elapsed_time / 1000 '
					ELSE 
						'NULL '
				END + 
					'AS avg_elapsed_time, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[physical_io|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[physical_io_delta|]%' ESCAPE '|'
							THEN 
								'x.physical_io '
					ELSE 
						'NULL '
				END + 
					'AS physical_io, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[reads|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[reads_delta|]%' ESCAPE '|'
							THEN 
								'x.reads '
					ELSE 
						'0 '
				END + 
					'AS reads, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[physical_reads|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[physical_reads_delta|]%' ESCAPE '|'
							THEN 
								'x.physical_reads '
					ELSE 
						'0 '
				END + 
					'AS physical_reads, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[writes|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[writes_delta|]%' ESCAPE '|'
							THEN 
								'x.writes '
					ELSE 
						'0 '
				END + 
					'AS writes, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tempdb_allocations|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[tempdb_allocations_delta|]%' ESCAPE '|'
							THEN 
								'x.tempdb_allocations '
					ELSE 
						'0 '
				END + 
					'AS tempdb_allocations, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tempdb_current|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[tempdb_current_delta|]%' ESCAPE '|'
							THEN 
								'x.tempdb_current '
					ELSE 
						'0 '
				END + 
					'AS tempdb_current, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[CPU|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
							THEN
								'x.CPU '
					ELSE
						'0 '
				END + 
					'AS CPU, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
						AND @get_task_info = 2
						AND @sys_info = 1
							THEN 
								'x.thread_CPU_snapshot '
					ELSE 
						'0 '
				END + 
					'AS thread_CPU_snapshot, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[context_switches|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[context_switches_delta|]%' ESCAPE '|'
							THEN 
								'x.context_switches '
					ELSE 
						'NULL '
				END + 
					'AS context_switches, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[used_memory|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[used_memory_delta|]%' ESCAPE '|'
							THEN 
								'x.used_memory '
					ELSE 
						'0 '
				END + 
					'AS used_memory, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tasks|]%' ESCAPE '|'
						AND @recursion = 1
							THEN 
								'x.tasks '
					ELSE 
						'NULL '
				END + 
					'AS tasks, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[status|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[sql_command|]%' ESCAPE '|'
						)
						AND @recursion = 1
							THEN 
								'x.status '
					ELSE 
						''''' '
				END + 
					'AS status, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[wait_info|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								CASE @get_task_info
									WHEN 2 THEN
										'COALESCE(x.task_wait_info, x.sys_wait_info) '
									ELSE
										'x.sys_wait_info '
								END
					ELSE 
						'NULL '
				END + 
					'AS wait_info, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[tran_start_time|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[tran_log_writes|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
								'x.transaction_id '
					ELSE 
						'NULL '
				END + 
					'AS transaction_id, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[open_tran_count|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.open_tran_count '
					ELSE 
						'NULL '
				END + 
					'AS open_tran_count, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.sql_handle '
					ELSE 
						'NULL '
				END + 
					'AS sql_handle, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
								'x.statement_start_offset '
					ELSE 
						'NULL '
				END + 
					'AS statement_start_offset, 
					' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
								'x.statement_end_offset '
					ELSE 
						'NULL '
				END + 
					'AS statement_end_offset, 
					' +
				'NULL AS sql_text, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.plan_handle '
					ELSE 
						'NULL '
				END + 
					'AS plan_handle, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[blocking_session_id|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'NULLIF(x.blocking_session_id, 0) '
					ELSE 
						'NULL '
				END + 
					'AS blocking_session_id, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[percent_complete|]%' ESCAPE '|'
						AND @recursion = 1
							THEN 
								'x.percent_complete '
					ELSE 
						'NULL '
				END + 
					'AS percent_complete, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[host_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.host_name '
					ELSE 
						''''' '
				END + 
					'AS host_name, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[login_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.login_name '
					ELSE 
						''''' '
				END + 
					'AS login_name, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[database_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'DB_NAME(x.database_id) '
					ELSE 
						'NULL '
				END + 
					'AS database_name, 
					' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[program_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								'x.program_name '
					ELSE 
						''''' '
				END + 
					'AS program_name, 
					' +
				CASE
					WHEN
						@output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
						AND @recursion = 1
							THEN
								'(
									SELECT TOP(@i)
										x.text_size,
										x.language,
										x.date_format,
										x.date_first,
										CASE x.quoted_identifier
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS quoted_identifier,
										CASE x.arithabort
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS arithabort,
										CASE x.ansi_null_dflt_on
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_null_dflt_on,
										CASE x.ansi_defaults
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_defaults,
										CASE x.ansi_warnings
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_warnings,
										CASE x.ansi_padding
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_padding,
										CASE ansi_nulls
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS ansi_nulls,
										CASE x.concat_null_yields_null
											WHEN 0 THEN ''OFF''
											WHEN 1 THEN ''ON''
										END AS concat_null_yields_null,
										CASE x.transaction_isolation_level
											WHEN 0 THEN ''Unspecified''
											WHEN 1 THEN ''ReadUncomitted''
											WHEN 2 THEN ''ReadCommitted''
											WHEN 3 THEN ''Repeatable''
											WHEN 4 THEN ''Serializable''
											WHEN 5 THEN ''Snapshot''
										END AS transaction_isolation_level,
										x.lock_timeout,
										x.deadlock_priority,
										x.row_count,
										x.command_type, 
										' +
										CASE
											WHEN OBJECT_ID('master.dbo.fn_varbintohexstr') IS NOT NULL THEN
												'master.dbo.fn_varbintohexstr(x.sql_handle) AS sql_handle,
												master.dbo.fn_varbintohexstr(x.plan_handle) AS plan_handle,'
											ELSE
												'CONVERT(VARCHAR(256), x.sql_handle, 1) AS sql_handle,
												CONVERT(VARCHAR(256), x.plan_handle, 1) AS plan_handle,'
										END +
										'
										x.statement_start_offset,
										x.statement_end_offset,
										' +
										CASE
											WHEN @output_column_list LIKE '%|[program_name|]%' ESCAPE '|' THEN
												'(
													SELECT TOP(1)
														CONVERT(uniqueidentifier, CONVERT(XML, '''').value(''xs:hexBinary( substring(sql:column("agent_info.job_id_string"), 0) )'', ''binary(16)'')) AS job_id,
														agent_info.step_id,
														(
															SELECT TOP(1)
																NULL
															FOR XML
																PATH(''job_name''),
																TYPE
														),
														(
															SELECT TOP(1)
																NULL
															FOR XML
																PATH(''step_name''),
																TYPE
														)
													FROM
													(
														SELECT TOP(1)
															SUBSTRING(x.program_name, CHARINDEX(''0x'', x.program_name) + 2, 32) AS job_id_string,
															SUBSTRING(x.program_name, CHARINDEX('': Step '', x.program_name) + 7, CHARINDEX('')'', x.program_name, CHARINDEX('': Step '', x.program_name)) - (CHARINDEX('': Step '', x.program_name) + 7)) AS step_id
														WHERE
															x.program_name LIKE N''SQLAgent - TSQL JobStep (Job 0x%''
													) AS agent_info
													FOR XML
														PATH(''agent_job_info''),
														TYPE
												),
												'
											ELSE ''
										END +
										CASE
											WHEN @get_task_info = 2 THEN
												'CONVERT(XML, x.block_info) AS block_info, 
												'
											ELSE
												''
										END + '
										x.host_process_id,
										x.group_id
									FOR XML
										PATH(''additional_info''),
										TYPE
								) '
					ELSE
						'NULL '
				END + 
					'AS additional_info, 
				x.start_time, 
					' +
				CASE
					WHEN
						@output_column_list LIKE '%|[login_time|]%' ESCAPE '|'
						AND @recursion = 1
							THEN
								'x.login_time '
					ELSE 
						'NULL '
				END + 
					'AS login_time, 
				x.last_request_start_time
			FROM
			(
				SELECT TOP(@i)
					y.*,
					CASE
						WHEN DATEDIFF(hour, y.start_time, GETDATE()) > 576 THEN
							DATEDIFF(second, GETDATE(), y.start_time)
						ELSE DATEDIFF(ms, y.start_time, GETDATE())
					END AS elapsed_time,
					COALESCE(tempdb_info.tempdb_allocations, 0) AS tempdb_allocations,
					COALESCE
					(
						CASE
							WHEN tempdb_info.tempdb_current < 0 THEN 0
							ELSE tempdb_info.tempdb_current
						END,
						0
					) AS tempdb_current, 
					' +
					CASE
						WHEN 
							(
								@get_task_info <> 0
								OR @find_block_leaders = 1
							) THEN
								'N''('' + CONVERT(NVARCHAR, y.wait_duration_ms) + N''ms)'' +
									y.wait_type +
										CASE
											WHEN y.wait_type LIKE N''PAGE%LATCH_%'' THEN
												N'':'' +
												COALESCE(DB_NAME(CONVERT(INT, LEFT(y.resource_description, CHARINDEX(N'':'', y.resource_description) - 1))), N''(null)'') +
												N'':'' +
												SUBSTRING(y.resource_description, CHARINDEX(N'':'', y.resource_description) + 1, LEN(y.resource_description) - CHARINDEX(N'':'', REVERSE(y.resource_description)) - CHARINDEX(N'':'', y.resource_description)) +
												N''('' +
													CASE
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 1 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 8088 = 0
																THEN 
																	N''PFS''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 2 OR
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511232 = 0
																THEN 
																	N''GAM''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 3 OR
															(CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) - 1) % 511232 = 0
																THEN
																	N''SGAM''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 6 OR
															(CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) - 6) % 511232 = 0 
																THEN 
																	N''DCM''
														WHEN
															CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 7 OR
															(CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) - 7) % 511232 = 0 
																THEN 
																	N''BCM''
														ELSE 
															N''*''
													END +
												N'')''
											WHEN y.wait_type = N''CXPACKET'' THEN
												N'':'' + SUBSTRING(y.resource_description, CHARINDEX(N''nodeId'', y.resource_description) + 7, 4)
											WHEN y.wait_type LIKE N''LATCH[_]%'' THEN
												N'' ['' + LEFT(y.resource_description, COALESCE(NULLIF(CHARINDEX(N'' '', y.resource_description), 0), LEN(y.resource_description) + 1) - 1) + N'']''
											WHEN
												y.wait_type = N''OLEDB''
												AND y.resource_description LIKE N''%(SPID=%)'' THEN
													N''['' + LEFT(y.resource_description, CHARINDEX(N''(SPID='', y.resource_description) - 2) +
														N'':'' + SUBSTRING(y.resource_description, CHARINDEX(N''(SPID='', y.resource_description) + 6, CHARINDEX(N'')'', y.resource_description, (CHARINDEX(N''(SPID='', y.resource_description) + 6)) - (CHARINDEX(N''(SPID='', y.resource_description) + 6)) + '']''
											ELSE
												N''''
										END COLLATE Latin1_General_Bin2 AS sys_wait_info, 
										'
							ELSE
								''
						END +
						CASE
							WHEN @get_task_info = 2 THEN
								'tasks.physical_io,
								tasks.context_switches,
								tasks.tasks,
								tasks.block_info,
								tasks.wait_info AS task_wait_info,
								tasks.thread_CPU_snapshot,
								'
							ELSE
								'' 
					END +
					CASE 
						WHEN NOT (@get_avg_time = 1 AND @recursion = 1) THEN
							'CONVERT(INT, NULL) '
						ELSE 
							'qs.total_elapsed_time / qs.execution_count '
					END + 
						'AS avg_elapsed_time 
				FROM
				(
					SELECT TOP(@i)
						sp.session_id,
						sp.request_id,
						COALESCE(r.logical_reads, s.logical_reads) AS reads,
						COALESCE(r.reads, s.reads) AS physical_reads,
						COALESCE(r.writes, s.writes) AS writes,
						COALESCE(r.CPU_time, s.CPU_time) AS CPU,
						sp.memory_usage + COALESCE(r.granted_query_memory, 0) AS used_memory,
						LOWER(sp.status) AS status,
						COALESCE(r.sql_handle, sp.sql_handle) AS sql_handle,
						COALESCE(r.statement_start_offset, sp.statement_start_offset) AS statement_start_offset,
						COALESCE(r.statement_end_offset, sp.statement_end_offset) AS statement_end_offset,
						' +
						CASE
							WHEN 
							(
								@get_task_info <> 0
								OR @find_block_leaders = 1 
							) THEN
								'sp.wait_type COLLATE Latin1_General_Bin2 AS wait_type,
								sp.wait_resource COLLATE Latin1_General_Bin2 AS resource_description,
								sp.wait_time AS wait_duration_ms, 
								'
							ELSE
								''
						END +
						'NULLIF(sp.blocked, 0) AS blocking_session_id,
						r.plan_handle,
						NULLIF(r.percent_complete, 0) AS percent_complete,
						sp.host_name,
						sp.login_name,
						sp.program_name,
						s.host_process_id,
						COALESCE(r.text_size, s.text_size) AS text_size,
						COALESCE(r.language, s.language) AS language,
						COALESCE(r.date_format, s.date_format) AS date_format,
						COALESCE(r.date_first, s.date_first) AS date_first,
						COALESCE(r.quoted_identifier, s.quoted_identifier) AS quoted_identifier,
						COALESCE(r.arithabort, s.arithabort) AS arithabort,
						COALESCE(r.ansi_null_dflt_on, s.ansi_null_dflt_on) AS ansi_null_dflt_on,
						COALESCE(r.ansi_defaults, s.ansi_defaults) AS ansi_defaults,
						COALESCE(r.ansi_warnings, s.ansi_warnings) AS ansi_warnings,
						COALESCE(r.ansi_padding, s.ansi_padding) AS ansi_padding,
						COALESCE(r.ansi_nulls, s.ansi_nulls) AS ansi_nulls,
						COALESCE(r.concat_null_yields_null, s.concat_null_yields_null) AS concat_null_yields_null,
						COALESCE(r.transaction_isolation_level, s.transaction_isolation_level) AS transaction_isolation_level,
						COALESCE(r.lock_timeout, s.lock_timeout) AS lock_timeout,
						COALESCE(r.deadlock_priority, s.deadlock_priority) AS deadlock_priority,
						COALESCE(r.row_count, s.row_count) AS row_count,
						COALESCE(r.command, sp.cmd) AS command_type,
						COALESCE
						(
							CASE
								WHEN
								(
									s.is_user_process = 0
									AND r.total_elapsed_time >= 0
								) THEN
									DATEADD
									(
										ms,
										1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())),
										DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
									)
							END,
							NULLIF(COALESCE(r.start_time, sp.last_request_end_time), CONVERT(DATETIME, ''19000101'', 112)),
							sp.login_time
						) AS start_time,
						sp.login_time,
						CASE
							WHEN s.is_user_process = 1 THEN
								s.last_request_start_time
							ELSE
								COALESCE
								(
									DATEADD
									(
										ms,
										1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())),
										DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
									),
									s.last_request_start_time
								)
						END AS last_request_start_time,
						r.transaction_id,
						sp.database_id,
						sp.open_tran_count,
						' +
							CASE
								WHEN EXISTS
								(
									SELECT
										*
									FROM sys.all_columns AS ac
									WHERE
										ac.object_id = OBJECT_ID('sys.dm_exec_sessions')
										AND ac.name = 'group_id'
								)
									THEN 's.group_id'
								ELSE 'CONVERT(INT, NULL) AS group_id'
							END + '
					FROM @sessions AS sp
					LEFT OUTER LOOP JOIN sys.dm_exec_sessions AS s ON
						s.session_id = sp.session_id
						AND s.login_time = sp.login_time
					LEFT OUTER LOOP JOIN sys.dm_exec_requests AS r ON
						sp.status <> ''sleeping''
						AND r.session_id = sp.session_id
						AND r.request_id = sp.request_id
						AND
						(
							(
								s.is_user_process = 0
								AND sp.is_user_process = 0
							)
							OR
							(
								r.start_time = s.last_request_start_time
								AND s.last_request_end_time <= sp.last_request_end_time
							)
						)
				) AS y
				' + 
				CASE 
					WHEN @get_task_info = 2 THEN
						CONVERT(VARCHAR(MAX), '') +
						'LEFT OUTER HASH JOIN
						(
							SELECT TOP(@i)
								task_nodes.task_node.value(''(session_id/text())[1]'', ''SMALLINT'') AS session_id,
								task_nodes.task_node.value(''(request_id/text())[1]'', ''INT'') AS request_id,
								task_nodes.task_node.value(''(physical_io/text())[1]'', ''BIGINT'') AS physical_io,
								task_nodes.task_node.value(''(context_switches/text())[1]'', ''BIGINT'') AS context_switches,
								task_nodes.task_node.value(''(tasks/text())[1]'', ''INT'') AS tasks,
								task_nodes.task_node.value(''(block_info/text())[1]'', ''NVARCHAR(4000)'') AS block_info,
								task_nodes.task_node.value(''(waits/text())[1]'', ''NVARCHAR(4000)'') AS wait_info,
								task_nodes.task_node.value(''(thread_CPU_snapshot/text())[1]'', ''BIGINT'') AS thread_CPU_snapshot
							FROM
							(
								SELECT TOP(@i)
									CONVERT
									(
										XML,
										REPLACE
										(
											CONVERT(NVARCHAR(MAX), tasks_raw.task_xml_raw) COLLATE Latin1_General_Bin2,
											N''</waits></tasks><tasks><waits>'',
											N'', ''
										)
									) AS task_xml
								FROM
								(
									SELECT TOP(@i)
										CASE waits.r
											WHEN 1 THEN
												waits.session_id
											ELSE
												NULL
										END AS [session_id],
										CASE waits.r
											WHEN 1 THEN
												waits.request_id
											ELSE
												NULL
										END AS [request_id],											
										CASE waits.r
											WHEN 1 THEN
												waits.physical_io
											ELSE
												NULL
										END AS [physical_io],
										CASE waits.r
											WHEN 1 THEN
												waits.context_switches
											ELSE
												NULL
										END AS [context_switches],
										CASE waits.r
											WHEN 1 THEN
												waits.thread_CPU_snapshot
											ELSE
												NULL
										END AS [thread_CPU_snapshot],
										CASE waits.r
											WHEN 1 THEN
												waits.tasks
											ELSE
												NULL
										END AS [tasks],
										CASE waits.r
											WHEN 1 THEN
												waits.block_info
											ELSE
												NULL
										END AS [block_info],
										REPLACE
										(
											REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
											REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
											REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												CONVERT
												(
													NVARCHAR(MAX),
													N''('' +
														CONVERT(NVARCHAR, num_waits) + N''x: '' +
														CASE num_waits
															WHEN 1 THEN
																CONVERT(NVARCHAR, min_wait_time) + N''ms''
															WHEN 2 THEN
																CASE
																	WHEN min_wait_time <> max_wait_time THEN
																		CONVERT(NVARCHAR, min_wait_time) + N''/'' + CONVERT(NVARCHAR, max_wait_time) + N''ms''
																	ELSE
																		CONVERT(NVARCHAR, max_wait_time) + N''ms''
																END
															ELSE
																CASE
																	WHEN min_wait_time <> max_wait_time THEN
																		CONVERT(NVARCHAR, min_wait_time) + N''/'' + CONVERT(NVARCHAR, avg_wait_time) + N''/'' + CONVERT(NVARCHAR, max_wait_time) + N''ms''
																	ELSE 
																		CONVERT(NVARCHAR, max_wait_time) + N''ms''
																END
														END +
													N'')'' + wait_type COLLATE Latin1_General_Bin2
												),
												NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''),
												NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''),
												NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''),
											NCHAR(0),
											N''''
										) AS [waits]
									FROM
									(
										SELECT TOP(@i)
											w1.*,
											ROW_NUMBER() OVER
											(
												PARTITION BY
													w1.session_id,
													w1.request_id
												ORDER BY
													w1.block_info DESC,
													w1.num_waits DESC,
													w1.wait_type
											) AS r
										FROM
										(
											SELECT TOP(@i)
												task_info.session_id,
												task_info.request_id,
												task_info.physical_io,
												task_info.context_switches,
												task_info.thread_CPU_snapshot,
												task_info.num_tasks AS tasks,
												CASE
													WHEN task_info.runnable_time IS NOT NULL THEN
														''RUNNABLE''
													ELSE
														wt2.wait_type
												END AS wait_type,
												NULLIF(COUNT(COALESCE(task_info.runnable_time, wt2.waiting_task_address)), 0) AS num_waits,
												MIN(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS min_wait_time,
												AVG(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS avg_wait_time,
												MAX(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS max_wait_time,
												MAX(wt2.block_info) AS block_info
											FROM
											(
												SELECT TOP(@i)
													t.session_id,
													t.request_id,
													SUM(CONVERT(BIGINT, t.pending_io_count)) OVER (PARTITION BY t.session_id, t.request_id) AS physical_io,
													SUM(CONVERT(BIGINT, t.context_switches_count)) OVER (PARTITION BY t.session_id, t.request_id) AS context_switches, 
													' +
													CASE
														WHEN 
															@output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
															AND @sys_info = 1
															THEN
																'SUM(tr.usermode_time + tr.kernel_time) OVER (PARTITION BY t.session_id, t.request_id) '
														ELSE
															'CONVERT(BIGINT, NULL) '
													END + 
														' AS thread_CPU_snapshot, 
													COUNT(*) OVER (PARTITION BY t.session_id, t.request_id) AS num_tasks,
													t.task_address,
													t.task_state,
													CASE
														WHEN
															t.task_state = ''RUNNABLE''
															AND w.runnable_time > 0 THEN
																w.runnable_time
														ELSE
															NULL
													END AS runnable_time
												FROM sys.dm_os_tasks AS t
												CROSS APPLY
												(
													SELECT TOP(1)
														sp2.session_id
													FROM @sessions AS sp2
													WHERE
														sp2.session_id = t.session_id
														AND sp2.request_id = t.request_id
														AND sp2.status <> ''sleeping''
												) AS sp20
												LEFT OUTER HASH JOIN
												( 
												' +
													CASE
														WHEN @sys_info = 1 THEN
															'SELECT TOP(@i)
																(
																	SELECT TOP(@i)
																		ms_ticks
																	FROM sys.dm_os_sys_info
																) -
																	w0.wait_resumed_ms_ticks AS runnable_time,
																w0.worker_address,
																w0.thread_address,
																w0.task_bound_ms_ticks
															FROM sys.dm_os_workers AS w0
															WHERE
																w0.state = ''RUNNABLE''
																OR @first_collection_ms_ticks >= w0.task_bound_ms_ticks'
														ELSE
															'SELECT
																CONVERT(BIGINT, NULL) AS runnable_time,
																CONVERT(VARBINARY(8), NULL) AS worker_address,
																CONVERT(VARBINARY(8), NULL) AS thread_address,
																CONVERT(BIGINT, NULL) AS task_bound_ms_ticks
															WHERE
																1 = 0'
														END +
												'
												) AS w ON
													w.worker_address = t.worker_address 
												' +
												CASE
													WHEN
														@output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
														AND @sys_info = 1
														THEN
															'LEFT OUTER HASH JOIN sys.dm_os_threads AS tr ON
																tr.thread_address = w.thread_address
																AND @first_collection_ms_ticks >= w.task_bound_ms_ticks
															'
													ELSE
														''
												END +
											') AS task_info
											LEFT OUTER HASH JOIN
											(
												SELECT TOP(@i)
													wt1.wait_type,
													wt1.waiting_task_address,
													MAX(wt1.wait_duration_ms) AS wait_duration_ms,
													MAX(wt1.block_info) AS block_info
												FROM
												(
													SELECT DISTINCT TOP(@i)
														wt.wait_type +
															CASE
																WHEN wt.wait_type LIKE N''PAGE%LATCH_%'' THEN
																	'':'' +
																	COALESCE(DB_NAME(CONVERT(INT, LEFT(wt.resource_description, CHARINDEX(N'':'', wt.resource_description) - 1))), N''(null)'') +
																	N'':'' +
																	SUBSTRING(wt.resource_description, CHARINDEX(N'':'', wt.resource_description) + 1, LEN(wt.resource_description) - CHARINDEX(N'':'', REVERSE(wt.resource_description)) - CHARINDEX(N'':'', wt.resource_description)) +
																	N''('' +
																		CASE
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 1 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 8088 = 0
																					THEN 
																						N''PFS''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 2 OR
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511232 = 0 
																					THEN 
																						N''GAM''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 3 OR
																				(CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) - 1) % 511232 = 0 
																					THEN 
																						N''SGAM''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 6 OR
																				(CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) - 6) % 511232 = 0 
																					THEN 
																						N''DCM''
																			WHEN
																				CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 7 OR
																				(CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) - 7) % 511232 = 0
																					THEN 
																						N''BCM''
																			ELSE
																				N''*''
																		END +
																	N'')''
																WHEN wt.wait_type = N''CXPACKET'' THEN
																	N'':'' + SUBSTRING(wt.resource_description, CHARINDEX(N''nodeId'', wt.resource_description) + 7, 4)
																WHEN wt.wait_type LIKE N''LATCH[_]%'' THEN
																	N'' ['' + LEFT(wt.resource_description, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 1) + N'']''
																ELSE 
																	N''''
															END COLLATE Latin1_General_Bin2 AS wait_type,
														CASE
															WHEN
															(
																wt.blocking_session_id IS NOT NULL
																AND wt.wait_type LIKE N''LCK[_]%''
															) THEN
																(
																	SELECT TOP(@i)
																		x.lock_type,
																		REPLACE
																		(
																			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																				DB_NAME
																				(
																					CONVERT
																					(
																						INT,
																						SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''dbid='', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''dbid='', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''dbid='', wt.resource_description) - 5)
																					)
																				),
																				NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''),
																				NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''),
																				NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''),
																			NCHAR(0),
																			N''''
																		) AS database_name,
																		CASE x.lock_type
																			WHEN N''objectlock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''objid='', wt.resource_description), 0) + 6, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''objid='', wt.resource_description) + 6), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''objid='', wt.resource_description) - 6)
																			ELSE
																				NULL
																		END AS object_id,
																		CASE x.lock_type
																			WHEN N''filelock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''fileid='', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''fileid='', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''fileid='', wt.resource_description) - 7)
																			ELSE
																				NULL
																		END AS file_id,
																		CASE
																			WHEN x.lock_type in (N''pagelock'', N''extentlock'', N''ridlock'') THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''associatedObjectId='', wt.resource_description), 0) + 19, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''associatedObjectId='', wt.resource_description) + 19), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''associatedObjectId='', wt.resource_description) - 19)
																			WHEN x.lock_type in (N''keylock'', N''hobtlock'', N''allocunitlock'') THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''hobtid='', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''hobtid='', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''hobtid='', wt.resource_description) - 7)
																			ELSE
																				NULL
																		END AS hobt_id,
																		CASE x.lock_type
																			WHEN N''applicationlock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''hash='', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''hash='', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''hash='', wt.resource_description) - 5)
																			ELSE
																				NULL
																		END AS applock_hash,
																		CASE x.lock_type
																			WHEN N''metadatalock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''subresource='', wt.resource_description), 0) + 12, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''subresource='', wt.resource_description) + 12), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''subresource='', wt.resource_description) - 12)
																			ELSE
																				NULL
																		END AS metadata_resource,
																		CASE x.lock_type
																			WHEN N''metadatalock'' THEN
																				SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''classid='', wt.resource_description), 0) + 8, COALESCE(NULLIF(CHARINDEX(N'' dbid='', wt.resource_description) - CHARINDEX(N''classid='', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 8)
																			ELSE
																				NULL
																		END AS metadata_class_id
																	FROM
																	(
																		SELECT TOP(1)
																			LEFT(wt.resource_description, CHARINDEX(N'' '', wt.resource_description) - 1) COLLATE Latin1_General_Bin2 AS lock_type
																	) AS x
																	FOR XML
																		PATH('''')
																)
															ELSE NULL
														END AS block_info,
														wt.wait_duration_ms,
														wt.waiting_task_address
													FROM
													(
														SELECT TOP(@i)
															wt0.wait_type COLLATE Latin1_General_Bin2 AS wait_type,
															wt0.resource_description COLLATE Latin1_General_Bin2 AS resource_description,
															wt0.wait_duration_ms,
															wt0.waiting_task_address,
															CASE
																WHEN wt0.blocking_session_id = p.blocked THEN
																	wt0.blocking_session_id
																ELSE
																	NULL
															END AS blocking_session_id
														FROM sys.dm_os_waiting_tasks AS wt0
														CROSS APPLY
														(
															SELECT TOP(1)
																s0.blocked
															FROM @sessions AS s0
															WHERE
																s0.session_id = wt0.session_id
																AND COALESCE(s0.wait_type, N'''') <> N''OLEDB''
																AND wt0.wait_type <> N''OLEDB''
														) AS p
													) AS wt
												) AS wt1
												GROUP BY
													wt1.wait_type,
													wt1.waiting_task_address
											) AS wt2 ON
												wt2.waiting_task_address = task_info.task_address
												AND wt2.wait_duration_ms > 0
												AND task_info.runnable_time IS NULL
											GROUP BY
												task_info.session_id,
												task_info.request_id,
												task_info.physical_io,
												task_info.context_switches,
												task_info.thread_CPU_snapshot,
												task_info.num_tasks,
												CASE
													WHEN task_info.runnable_time IS NOT NULL THEN
														''RUNNABLE''
													ELSE
														wt2.wait_type
												END
										) AS w1
									) AS waits
									ORDER BY
										waits.session_id,
										waits.request_id,
										waits.r
									FOR XML
										PATH(N''tasks''),
										TYPE
								) AS tasks_raw (task_xml_raw)
							) AS tasks_final
							CROSS APPLY tasks_final.task_xml.nodes(N''/tasks'') AS task_nodes (task_node)
							WHERE
								task_nodes.task_node.exist(N''session_id'') = 1
						) AS tasks ON
							tasks.session_id = y.session_id
							AND tasks.request_id = y.request_id 
						'
					ELSE
						''
				END +
				'LEFT OUTER HASH JOIN
				(
					SELECT TOP(@i)
						t_info.session_id,
						COALESCE(t_info.request_id, -1) AS request_id,
						SUM(t_info.tempdb_allocations) AS tempdb_allocations,
						SUM(t_info.tempdb_current) AS tempdb_current
					FROM
					(
						SELECT TOP(@i)
							tsu.session_id,
							tsu.request_id,
							tsu.user_objects_alloc_page_count +
								tsu.internal_objects_alloc_page_count AS tempdb_allocations,
							tsu.user_objects_alloc_page_count +
								tsu.internal_objects_alloc_page_count -
								tsu.user_objects_dealloc_page_count -
								tsu.internal_objects_dealloc_page_count AS tempdb_current
						FROM sys.dm_db_task_space_usage AS tsu
						CROSS APPLY
						(
							SELECT TOP(1)
								s0.session_id
							FROM @sessions AS s0
							WHERE
								s0.session_id = tsu.session_id
						) AS p

						UNION ALL

						SELECT TOP(@i)
							ssu.session_id,
							NULL AS request_id,
							ssu.user_objects_alloc_page_count +
								ssu.internal_objects_alloc_page_count AS tempdb_allocations,
							ssu.user_objects_alloc_page_count +
								ssu.internal_objects_alloc_page_count -
								ssu.user_objects_dealloc_page_count -
								ssu.internal_objects_dealloc_page_count AS tempdb_current
						FROM sys.dm_db_session_space_usage AS ssu
						CROSS APPLY
						(
							SELECT TOP(1)
								s0.session_id
							FROM @sessions AS s0
							WHERE
								s0.session_id = ssu.session_id
						) AS p
					) AS t_info
					GROUP BY
						t_info.session_id,
						COALESCE(t_info.request_id, -1)
				) AS tempdb_info ON
					tempdb_info.session_id = y.session_id
					AND tempdb_info.request_id =
						CASE
							WHEN y.status = N''sleeping'' THEN
								-1
							ELSE
								y.request_id
						END
				' +
				CASE 
					WHEN 
						NOT 
						(
							@get_avg_time = 1 
							AND @recursion = 1
						) THEN 
							''
					ELSE
						'LEFT OUTER HASH JOIN
						(
							SELECT TOP(@i)
								*
							FROM sys.dm_exec_query_stats
						) AS qs ON
							qs.sql_handle = y.sql_handle
							AND qs.plan_handle = y.plan_handle
							AND qs.statement_start_offset = y.statement_start_offset
							AND qs.statement_end_offset = y.statement_end_offset
						'
				END + 
			') AS x
			OPTION (KEEPFIXED PLAN, OPTIMIZE FOR (@i = 1)); ';

		SET @sql_n = CONVERT(NVARCHAR(MAX), @sql);

		SET @last_collection_start = GETDATE();

		IF 
			@recursion = -1
			AND @sys_info = 1
		BEGIN;
			SELECT
				@first_collection_ms_ticks = ms_ticks
			FROM sys.dm_os_sys_info;
		END;

		INSERT #sessions
		(
			recursion,
			session_id,
			request_id,
			session_number,
			elapsed_time,
			avg_elapsed_time,
			physical_io,
			reads,
			physical_reads,
			writes,
			tempdb_allocations,
			tempdb_current,
			CPU,
			thread_CPU_snapshot,
			context_switches,
			used_memory,
			tasks,
			status,
			wait_info,
			transaction_id,
			open_tran_count,
			sql_handle,
			statement_start_offset,
			statement_end_offset,		
			sql_text,
			plan_handle,
			blocking_session_id,
			percent_complete,
			host_name,
			login_name,
			database_name,
			program_name,
			additional_info,
			start_time,
			login_time,
			last_request_start_time
		)
		EXEC sp_executesql 
			@sql_n,
			N'@recursion SMALLINT, @filter sysname, @not_filter sysname, @first_collection_ms_ticks BIGINT',
			@recursion, @filter, @not_filter, @first_collection_ms_ticks;

		--Collect transaction information?
		IF
			@recursion = 1
			AND
			(
				@output_column_list LIKE '%|[tran_start_time|]%' ESCAPE '|'
				OR @output_column_list LIKE '%|[tran_log_writes|]%' ESCAPE '|' 
			)
		BEGIN;	
			DECLARE @i INT;
			SET @i = 2147483647;

			UPDATE s
			SET
				tran_start_time =
					CONVERT
					(
						DATETIME,
						LEFT
						(
							x.trans_info,
							NULLIF(CHARINDEX(NCHAR(254) COLLATE Latin1_General_Bin2, x.trans_info) - 1, -1)
						),
						121
					),
				tran_log_writes =
					RIGHT
					(
						x.trans_info,
						LEN(x.trans_info) - CHARINDEX(NCHAR(254) COLLATE Latin1_General_Bin2, x.trans_info)
					)
			FROM
			(
				SELECT TOP(@i)
					trans_nodes.trans_node.value('(session_id/text())[1]', 'SMALLINT') AS session_id,
					COALESCE(trans_nodes.trans_node.value('(request_id/text())[1]', 'INT'), 0) AS request_id,
					trans_nodes.trans_node.value('(trans_info/text())[1]', 'NVARCHAR(4000)') AS trans_info				
				FROM
				(
					SELECT TOP(@i)
						CONVERT
						(
							XML,
							REPLACE
							(
								CONVERT(NVARCHAR(MAX), trans_raw.trans_xml_raw) COLLATE Latin1_General_Bin2, 
								N'</trans_info></trans><trans><trans_info>', N''
							)
						)
					FROM
					(
						SELECT TOP(@i)
							CASE u_trans.r
								WHEN 1 THEN u_trans.session_id
								ELSE NULL
							END AS [session_id],
							CASE u_trans.r
								WHEN 1 THEN u_trans.request_id
								ELSE NULL
							END AS [request_id],
							CONVERT
							(
								NVARCHAR(MAX),
								CASE
									WHEN u_trans.database_id IS NOT NULL THEN
										CASE u_trans.r
											WHEN 1 THEN COALESCE(CONVERT(NVARCHAR, u_trans.transaction_start_time, 121) + NCHAR(254), N'')
											ELSE N''
										END + 
											REPLACE
											(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
													CONVERT(VARCHAR(128), COALESCE(DB_NAME(u_trans.database_id), N'(null)')),
													NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
													NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
													NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
												NCHAR(0),
												N'?'
											) +
											N': ' +
										CONVERT(NVARCHAR, u_trans.log_record_count) + N' (' + CONVERT(NVARCHAR, u_trans.log_kb_used) + N' kB)' +
										N','
									ELSE
										N'N/A,'
								END COLLATE Latin1_General_Bin2
							) AS [trans_info]
						FROM
						(
							SELECT TOP(@i)
								trans.*,
								ROW_NUMBER() OVER
								(
									PARTITION BY
										trans.session_id,
										trans.request_id
									ORDER BY
										trans.transaction_start_time DESC
								) AS r
							FROM
							(
								SELECT TOP(@i)
									session_tran_map.session_id,
									session_tran_map.request_id,
									s_tran.database_id,
									COALESCE(SUM(s_tran.database_transaction_log_record_count), 0) AS log_record_count,
									COALESCE(SUM(s_tran.database_transaction_log_bytes_used), 0) / 1024 AS log_kb_used,
									MIN(s_tran.database_transaction_begin_time) AS transaction_start_time
								FROM
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_active_transactions
									WHERE
										transaction_begin_time <= @last_collection_start
								) AS a_tran
								INNER HASH JOIN
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_database_transactions
									WHERE
										database_id < 32767
								) AS s_tran ON
									s_tran.transaction_id = a_tran.transaction_id
								LEFT OUTER HASH JOIN
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_session_transactions
								) AS tst ON
									s_tran.transaction_id = tst.transaction_id
								CROSS APPLY
								(
									SELECT TOP(1)
										s3.session_id,
										s3.request_id
									FROM
									(
										SELECT TOP(1)
											s1.session_id,
											s1.request_id
										FROM #sessions AS s1
										WHERE
											s1.transaction_id = s_tran.transaction_id
											AND s1.recursion = 1
											
										UNION ALL
									
										SELECT TOP(1)
											s2.session_id,
											s2.request_id
										FROM #sessions AS s2
										WHERE
											s2.session_id = tst.session_id
											AND s2.recursion = 1
									) AS s3
									ORDER BY
										s3.request_id
								) AS session_tran_map
								GROUP BY
									session_tran_map.session_id,
									session_tran_map.request_id,
									s_tran.database_id
							) AS trans
						) AS u_trans
						FOR XML
							PATH('trans'),
							TYPE
					) AS trans_raw (trans_xml_raw)
				) AS trans_final (trans_xml)
				CROSS APPLY trans_final.trans_xml.nodes('/trans') AS trans_nodes (trans_node)
			) AS x
			INNER HASH JOIN #sessions AS s ON
				s.session_id = x.session_id
				AND s.request_id = x.request_id
			OPTION (OPTIMIZE FOR (@i = 1));
		END;

		--Variables for text and plan collection
		DECLARE	
			@session_id SMALLINT,
			@request_id INT,
			@sql_handle VARBINARY(64),
			@plan_handle VARBINARY(64),
			@statement_start_offset INT,
			@statement_end_offset INT,
			@start_time DATETIME,
			@database_name sysname;

		IF 
			@recursion = 1
			AND @output_column_list LIKE '%|[sql_text|]%' ESCAPE '|'
		BEGIN;
			DECLARE sql_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT 
					session_id,
					request_id,
					sql_handle,
					statement_start_offset,
					statement_end_offset
				FROM #sessions
				WHERE
					recursion = 1
					AND sql_handle IS NOT NULL
			OPTION (KEEPFIXED PLAN);

			OPEN sql_cursor;

			FETCH NEXT FROM sql_cursor
			INTO 
				@session_id,
				@request_id,
				@sql_handle,
				@statement_start_offset,
				@statement_end_offset;

			--Wait up to 5 ms for the SQL text, then give up
			SET LOCK_TIMEOUT 5;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					UPDATE s
					SET
						s.sql_text =
						(
							SELECT
								REPLACE
								(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
										N'--' + NCHAR(13) + NCHAR(10) +
										CASE 
											WHEN @get_full_inner_text = 1 THEN est.text
											WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN est.text
											WHEN SUBSTRING(est.text, (@statement_start_offset/2), 2) LIKE N'[a-zA-Z0-9][a-zA-Z0-9]' THEN est.text
											ELSE
												CASE
													WHEN @statement_start_offset > 0 THEN
														SUBSTRING
														(
															est.text,
															((@statement_start_offset/2) + 1),
															(
																CASE
																	WHEN @statement_end_offset = -1 THEN 2147483647
																	ELSE ((@statement_end_offset - @statement_start_offset)/2) + 1
																END
															)
														)
													ELSE RTRIM(LTRIM(est.text))
												END
										END +
										NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2,
										NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
										NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
										NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
									NCHAR(0),
									N''
								) AS [processing-instruction(query)]
							FOR XML
								PATH(''),
								TYPE
						),
						s.statement_start_offset = 
							CASE 
								WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN 0
								WHEN SUBSTRING(CONVERT(VARCHAR(MAX), est.text), (@statement_start_offset/2), 2) LIKE '[a-zA-Z0-9][a-zA-Z0-9]' THEN 0
								ELSE @statement_start_offset
							END,
						s.statement_end_offset = 
							CASE 
								WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN -1
								WHEN SUBSTRING(CONVERT(VARCHAR(MAX), est.text), (@statement_start_offset/2), 2) LIKE '[a-zA-Z0-9][a-zA-Z0-9]' THEN -1
								ELSE @statement_end_offset
							END
					FROM 
						#sessions AS s,
						(
							SELECT TOP(1)
								text
							FROM
							(
								SELECT 
									text, 
									0 AS row_num
								FROM sys.dm_exec_sql_text(@sql_handle)
								
								UNION ALL
								
								SELECT 
									NULL,
									1 AS row_num
							) AS est0
							ORDER BY
								row_num
						) AS est
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END TRY
				BEGIN CATCH;
					UPDATE s
					SET
						s.sql_text = 
							CASE ERROR_NUMBER() 
								WHEN 1222 THEN '<timeout_exceeded />'
								ELSE '<error message="' + ERROR_MESSAGE() + '" />'
							END
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM sql_cursor
				INTO
					@session_id,
					@request_id,
					@sql_handle,
					@statement_start_offset,
					@statement_end_offset;
			END;

			--Return this to the default
			SET LOCK_TIMEOUT -1;

			CLOSE sql_cursor;
			DEALLOCATE sql_cursor;
		END;

		IF 
			@get_outer_command = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[sql_command|]%' ESCAPE '|'
		BEGIN;
			DECLARE @buffer_results TABLE
			(
				EventType VARCHAR(30),
				Parameters INT,
				EventInfo NVARCHAR(4000),
				start_time DATETIME,
				session_number INT IDENTITY(1,1) NOT NULL PRIMARY KEY
			);

			DECLARE buffer_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT 
					session_id,
					MAX(start_time) AS start_time
				FROM #sessions
				WHERE
					recursion = 1
				GROUP BY
					session_id
				ORDER BY
					session_id
				OPTION (KEEPFIXED PLAN);

			OPEN buffer_cursor;

			FETCH NEXT FROM buffer_cursor
			INTO 
				@session_id,
				@start_time;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					--In SQL Server 2008, DBCC INPUTBUFFER will throw 
					--an exception if the session no longer exists
					INSERT @buffer_results
					(
						EventType,
						Parameters,
						EventInfo
					)
					EXEC sp_executesql
						N'DBCC INPUTBUFFER(@session_id) WITH NO_INFOMSGS;',
						N'@session_id SMALLINT',
						@session_id;

					UPDATE br
					SET
						br.start_time = @start_time
					FROM @buffer_results AS br
					WHERE
						br.session_number = 
						(
							SELECT MAX(br2.session_number)
							FROM @buffer_results br2
						);
				END TRY
				BEGIN CATCH
				END CATCH;

				FETCH NEXT FROM buffer_cursor
				INTO 
					@session_id,
					@start_time;
			END;

			UPDATE s
			SET
				sql_command = 
				(
					SELECT 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX),
									N'--' + NCHAR(13) + NCHAR(10) + br.EventInfo + NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						) AS [processing-instruction(query)]
					FROM @buffer_results AS br
					WHERE 
						br.session_number = s.session_number
						AND br.start_time = s.start_time
						AND 
						(
							(
								s.start_time = s.last_request_start_time
								AND EXISTS
								(
									SELECT *
									FROM sys.dm_exec_requests r2
									WHERE
										r2.session_id = s.session_id
										AND r2.request_id = s.request_id
										AND r2.start_time = s.start_time
								)
							)
							OR 
							(
								s.request_id = 0
								AND EXISTS
								(
									SELECT *
									FROM sys.dm_exec_sessions s2
									WHERE
										s2.session_id = s.session_id
										AND s2.last_request_start_time = s.last_request_start_time
								)
							)
						)
					FOR XML
						PATH(''),
						TYPE
				)
			FROM #sessions AS s
			WHERE
				recursion = 1
			OPTION (KEEPFIXED PLAN);

			CLOSE buffer_cursor;
			DEALLOCATE buffer_cursor;
		END;

		IF 
			@get_plans >= 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|'
		BEGIN;
			DECLARE @live_plan BIT;
			SET @live_plan = ISNULL(CONVERT(BIT, SIGN(OBJECT_ID('sys.dm_exec_query_statistics_xml'))), 0)

			DECLARE plan_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT
					session_id,
					request_id,
					plan_handle,
					statement_start_offset,
					statement_end_offset
				FROM #sessions
				WHERE
					recursion = 1
					AND plan_handle IS NOT NULL
			OPTION (KEEPFIXED PLAN);

			OPEN plan_cursor;

			FETCH NEXT FROM plan_cursor
			INTO 
				@session_id,
				@request_id,
				@plan_handle,
				@statement_start_offset,
				@statement_end_offset;

			--Wait up to 5 ms for a query plan, then give up
			SET LOCK_TIMEOUT 5;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				DECLARE @query_plan XML;
				SET @query_plan = NULL;

				IF @live_plan = 1
				BEGIN;
					BEGIN TRY;
						SELECT
							@query_plan = x.query_plan
						FROM sys.dm_exec_query_statistics_xml(@session_id) AS x;

						IF 
							@query_plan IS NOT NULL
							AND EXISTS
							(
								SELECT
									*
								FROM sys.dm_exec_requests AS r
								WHERE
									r.session_id = @session_id
									AND r.request_id = @request_id
									AND r.plan_handle = @plan_handle
									AND r.statement_start_offset = @statement_start_offset
									AND r.statement_end_offset = @statement_end_offset
							)
						BEGIN;
							UPDATE s
							SET
								s.query_plan = @query_plan
							FROM #sessions AS s
							WHERE 
								s.session_id = @session_id
								AND s.request_id = @request_id
								AND s.recursion = 1
							OPTION (KEEPFIXED PLAN);
						END;
					END TRY
					BEGIN CATCH;
						SET @query_plan = NULL;
					END CATCH;
				END;

				IF @query_plan IS NULL
				BEGIN;
					BEGIN TRY;
						UPDATE s
						SET
							s.query_plan =
							(
								SELECT
									CONVERT(xml, query_plan)
								FROM sys.dm_exec_text_query_plan
								(
									@plan_handle, 
									CASE @get_plans
										WHEN 1 THEN
											@statement_start_offset
										ELSE
											0
									END, 
									CASE @get_plans
										WHEN 1 THEN
											@statement_end_offset
										ELSE
											-1
									END
								)
							)
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.request_id = @request_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
					END TRY
					BEGIN CATCH;
						IF ERROR_NUMBER() = 6335
						BEGIN;
							UPDATE s
							SET
								s.query_plan =
								(
									SELECT
										N'--' + NCHAR(13) + NCHAR(10) + 
										N'-- Could not render showplan due to XML data type limitations. ' + NCHAR(13) + NCHAR(10) + 
										N'-- To see the graphical plan save the XML below as a .SQLPLAN file and re-open in SSMS.' + NCHAR(13) + NCHAR(10) +
										N'--' + NCHAR(13) + NCHAR(10) +
											REPLACE(qp.query_plan, N'<RelOp', NCHAR(13)+NCHAR(10)+N'<RelOp') + 
											NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2 AS [processing-instruction(query_plan)]
									FROM sys.dm_exec_text_query_plan
									(
										@plan_handle, 
										CASE @get_plans
											WHEN 1 THEN
												@statement_start_offset
											ELSE
												0
										END, 
										CASE @get_plans
											WHEN 1 THEN
												@statement_end_offset
											ELSE
												-1
										END
									) AS qp
									FOR XML
										PATH(''),
										TYPE
								)
							FROM #sessions AS s
							WHERE 
								s.session_id = @session_id
								AND s.request_id = @request_id
								AND s.recursion = 1
							OPTION (KEEPFIXED PLAN);
						END;
						ELSE
						BEGIN;
							UPDATE s
							SET
								s.query_plan = 
									CASE ERROR_NUMBER() 
										WHEN 1222 THEN '<timeout_exceeded />'
										ELSE '<error message="' + ERROR_MESSAGE() + '" />'
									END
							FROM #sessions AS s
							WHERE 
								s.session_id = @session_id
								AND s.request_id = @request_id
								AND s.recursion = 1
							OPTION (KEEPFIXED PLAN);
						END;
					END CATCH;
				END;

				FETCH NEXT FROM plan_cursor
				INTO
					@session_id,
					@request_id,
					@plan_handle,
					@statement_start_offset,
					@statement_end_offset;
			END;

			--Return this to the default
			SET LOCK_TIMEOUT -1;

			CLOSE plan_cursor;
			DEALLOCATE plan_cursor;
		END;

		IF 
			@get_locks = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[locks|]%' ESCAPE '|'
		BEGIN;
			DECLARE locks_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT DISTINCT
					database_name
				FROM #locks
				WHERE
					EXISTS
					(
						SELECT *
						FROM #sessions AS s
						WHERE
							s.session_id = #locks.session_id
							AND recursion = 1
					)
					AND database_name <> '(null)'
				OPTION (KEEPFIXED PLAN);

			OPEN locks_cursor;

			FETCH NEXT FROM locks_cursor
			INTO 
				@database_name;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					SET @sql_n = CONVERT(NVARCHAR(MAX), '') +
						'UPDATE l ' +
						'SET ' +
							'object_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'o.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'index_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'i.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'schema_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										's.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'principal_name = ' + 
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'dp.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								') ' +
						'FROM #locks AS l ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.allocation_units AS au ON ' +
							'au.allocation_unit_id = l.allocation_unit_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
							'p.hobt_id = ' +
								'COALESCE ' +
								'( ' +
									'l.hobt_id, ' +
									'CASE ' +
										'WHEN au.type IN (1, 3) THEN au.container_id ' +
										'ELSE NULL ' +
									'END ' +
								') ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p1 ON ' +
							'l.hobt_id IS NULL ' +
							'AND au.type = 2 ' +
							'AND p1.partition_id = au.container_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
							'o.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.indexes AS i ON ' +
							'i.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
							'AND i.index_id = COALESCE(l.index_id, p.index_id, p1.index_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
							's.schema_id = COALESCE(l.schema_id, o.schema_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.database_principals AS dp ON ' +
							'dp.principal_id = l.principal_id ' +
						'WHERE ' +
							'l.database_name = @database_name ' +
						'OPTION (KEEPFIXED PLAN); ';
					
					EXEC sp_executesql
						@sql_n,
						N'@database_name sysname',
						@database_name;
				END TRY
				BEGIN CATCH;
					UPDATE #locks
					SET
						query_error = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX), 
										ERROR_MESSAGE() COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							)
					WHERE 
						database_name = @database_name
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM locks_cursor
				INTO
					@database_name;
			END;

			CLOSE locks_cursor;
			DEALLOCATE locks_cursor;

			CREATE CLUSTERED INDEX IX_SRD ON #locks (session_id, request_id, database_name);

			UPDATE s
			SET 
				s.locks =
				(
					SELECT 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX), 
									l1.database_name COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						) AS [Database/@name],
						MIN(l1.query_error) AS [Database/@query_error],
						(
							SELECT 
								l2.request_mode AS [Lock/@request_mode],
								l2.request_status AS [Lock/@request_status],
								COUNT(*) AS [Lock/@request_count]
							FROM #locks AS l2
							WHERE 
								l1.session_id = l2.session_id
								AND l1.request_id = l2.request_id
								AND l2.database_name = l1.database_name
								AND l2.resource_type = 'DATABASE'
							GROUP BY
								l2.request_mode,
								l2.request_status
							FOR XML
								PATH(''),
								TYPE
						) AS [Database/Locks],
						(
							SELECT
								COALESCE(l3.object_name, '(null)') AS [Object/@name],
								l3.schema_name AS [Object/@schema_name],
								(
									SELECT
										l4.resource_type AS [Lock/@resource_type],
										l4.page_type AS [Lock/@page_type],
										l4.index_name AS [Lock/@index_name],
										CASE 
											WHEN l4.object_name IS NULL THEN l4.schema_name
											ELSE NULL
										END AS [Lock/@schema_name],
										l4.principal_name AS [Lock/@principal_name],
										l4.resource_description AS [Lock/@resource_description],
										l4.request_mode AS [Lock/@request_mode],
										l4.request_status AS [Lock/@request_status],
										SUM(l4.request_count) AS [Lock/@request_count]
									FROM #locks AS l4
									WHERE 
										l4.session_id = l3.session_id
										AND l4.request_id = l3.request_id
										AND l3.database_name = l4.database_name
										AND COALESCE(l3.object_name, '(null)') = COALESCE(l4.object_name, '(null)')
										AND COALESCE(l3.schema_name, '') = COALESCE(l4.schema_name, '')
										AND l4.resource_type <> 'DATABASE'
									GROUP BY
										l4.resource_type,
										l4.page_type,
										l4.index_name,
										CASE 
											WHEN l4.object_name IS NULL THEN l4.schema_name
											ELSE NULL
										END,
										l4.principal_name,
										l4.resource_description,
										l4.request_mode,
										l4.request_status
									FOR XML
										PATH(''),
										TYPE
								) AS [Object/Locks]
							FROM #locks AS l3
							WHERE 
								l3.session_id = l1.session_id
								AND l3.request_id = l1.request_id
								AND l3.database_name = l1.database_name
								AND l3.resource_type <> 'DATABASE'
							GROUP BY 
								l3.session_id,
								l3.request_id,
								l3.database_name,
								COALESCE(l3.object_name, '(null)'),
								l3.schema_name
							FOR XML
								PATH(''),
								TYPE
						) AS [Database/Objects]
					FROM #locks AS l1
					WHERE
						l1.session_id = s.session_id
						AND l1.request_id = s.request_id
						AND l1.start_time IN (s.start_time, s.last_request_start_time)
						AND s.recursion = 1
					GROUP BY 
						l1.session_id,
						l1.request_id,
						l1.database_name
					FOR XML
						PATH(''),
						TYPE
				)
			FROM #sessions s
			OPTION (KEEPFIXED PLAN);
		END;

		IF 
			@find_block_leaders = 1
			AND @recursion = 1
			AND @output_column_list LIKE '%|[blocked_session_count|]%' ESCAPE '|'
		BEGIN;
			WITH
			blockers AS
			(
				SELECT
					session_id,
					session_id AS top_level_session_id,
					CONVERT(VARCHAR(8000), '.' + CONVERT(VARCHAR(8000), session_id) + '.') AS the_path
				FROM #sessions
				WHERE
					recursion = 1

				UNION ALL

				SELECT
					s.session_id,
					b.top_level_session_id,
					CONVERT(VARCHAR(8000), b.the_path + CONVERT(VARCHAR(8000), s.session_id) + '.') AS the_path
				FROM blockers AS b
				JOIN #sessions AS s ON
					s.blocking_session_id = b.session_id
					AND s.recursion = 1
					AND b.the_path NOT LIKE '%.' + CONVERT(VARCHAR(8000), s.session_id) + '.%' COLLATE Latin1_General_Bin2
			)
			UPDATE s
			SET
				s.blocked_session_count = x.blocked_session_count
			FROM #sessions AS s
			JOIN
			(
				SELECT
					b.top_level_session_id AS session_id,
					COUNT(*) - 1 AS blocked_session_count
				FROM blockers AS b
				GROUP BY
					b.top_level_session_id
			) x ON
				s.session_id = x.session_id
			WHERE
				s.recursion = 1;
		END;

		IF
			@get_task_info = 2
			AND @output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
			AND @recursion = 1
		BEGIN;
			CREATE TABLE #blocked_requests
			(
				session_id SMALLINT NOT NULL,
				request_id INT NOT NULL,
				database_name sysname NOT NULL,
				object_id INT,
				hobt_id BIGINT,
				schema_id INT,
				schema_name sysname NULL,
				object_name sysname NULL,
				query_error NVARCHAR(2048),
				PRIMARY KEY (database_name, session_id, request_id)
			);

			CREATE STATISTICS s_database_name ON #blocked_requests (database_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_name ON #blocked_requests (schema_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_name ON #blocked_requests (object_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_query_error ON #blocked_requests (query_error)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
		
			INSERT #blocked_requests
			(
				session_id,
				request_id,
				database_name,
				object_id,
				hobt_id,
				schema_id
			)
			SELECT
				session_id,
				request_id,
				database_name,
				object_id,
				hobt_id,
				CONVERT(INT, SUBSTRING(schema_node, CHARINDEX(' = ', schema_node) + 3, LEN(schema_node))) AS schema_id
			FROM
			(
				SELECT
					session_id,
					request_id,
					agent_nodes.agent_node.value('(database_name/text())[1]', 'sysname') AS database_name,
					agent_nodes.agent_node.value('(object_id/text())[1]', 'int') AS object_id,
					agent_nodes.agent_node.value('(hobt_id/text())[1]', 'bigint') AS hobt_id,
					agent_nodes.agent_node.value('(metadata_resource/text()[.="SCHEMA"]/../../metadata_class_id/text())[1]', 'varchar(100)') AS schema_node
				FROM #sessions AS s
				CROSS APPLY s.additional_info.nodes('//block_info') AS agent_nodes (agent_node)
				WHERE
					s.recursion = 1
			) AS t
			WHERE
				t.database_name IS NOT NULL
				AND
				(
					t.object_id IS NOT NULL
					OR t.hobt_id IS NOT NULL
					OR t.schema_node IS NOT NULL
				);
			
			DECLARE blocks_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR
				SELECT DISTINCT
					database_name
				FROM #blocked_requests;
				
			OPEN blocks_cursor;
			
			FETCH NEXT FROM blocks_cursor
			INTO 
				@database_name;
			
			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					SET @sql_n = 
						CONVERT(NVARCHAR(MAX), '') +
						'UPDATE b ' +
						'SET ' +
							'b.schema_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										's.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'b.object_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'o.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								') ' +
						'FROM #blocked_requests AS b ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
							'p.hobt_id = b.hobt_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
							'o.object_id = COALESCE(p.object_id, b.object_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
							's.schema_id = COALESCE(o.schema_id, b.schema_id) ' +
						'WHERE ' +
							'b.database_name = @database_name; ';
					
					EXEC sp_executesql
						@sql_n,
						N'@database_name sysname',
						@database_name;
				END TRY
				BEGIN CATCH;
					UPDATE #blocked_requests
					SET
						query_error = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX), 
										ERROR_MESSAGE() COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							)
					WHERE
						database_name = @database_name;
				END CATCH;

				FETCH NEXT FROM blocks_cursor
				INTO
					@database_name;
			END;
			
			CLOSE blocks_cursor;
			DEALLOCATE blocks_cursor;
			
			UPDATE s
			SET
				additional_info.modify
				('
					insert <schema_name>{sql:column("b.schema_name")}</schema_name>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.schema_name IS NOT NULL;

			UPDATE s
			SET
				additional_info.modify
				('
					insert <object_name>{sql:column("b.object_name")}</object_name>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.object_name IS NOT NULL;

			UPDATE s
			SET
				additional_info.modify
				('
					insert <query_error>{sql:column("b.query_error")}</query_error>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.query_error IS NOT NULL;
		END;

		IF
			@output_column_list LIKE '%|[program_name|]%' ESCAPE '|'
			AND @output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
			AND @recursion = 1
			AND DB_ID('msdb') IS NOT NULL
		BEGIN;
			SET @sql_n =
				N'BEGIN TRY;
					DECLARE @job_name sysname;
					SET @job_name = NULL;
					DECLARE @step_name sysname;
					SET @step_name = NULL;

					SELECT
						@job_name = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									j.name,
									NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''),
									NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''),
									NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''),
								NCHAR(0),
								N''?''
							),
						@step_name = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									s.step_name,
									NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''),
									NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''),
									NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''),
								NCHAR(0),
								N''?''
							)
					FROM msdb.dbo.sysjobs AS j
					INNER JOIN msdb.dbo.sysjobsteps AS s ON
						j.job_id = s.job_id
					WHERE
						j.job_id = @job_id
						AND s.step_id = @step_id;

					IF @job_name IS NOT NULL
					BEGIN;
						UPDATE s
						SET
							additional_info.modify
							(''
								insert text{sql:variable("@job_name")}
								into (/additional_info/agent_job_info/job_name)[1]
							'')
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
						
						UPDATE s
						SET
							additional_info.modify
							(''
								insert text{sql:variable("@step_name")}
								into (/additional_info/agent_job_info/step_name)[1]
							'')
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
					END;
				END TRY
				BEGIN CATCH;
					DECLARE @msdb_error_message NVARCHAR(256);
					SET @msdb_error_message = ERROR_MESSAGE();
				
					UPDATE s
					SET
						additional_info.modify
						(''
							insert <msdb_query_error>{sql:variable("@msdb_error_message")}</msdb_query_error>
							as last
							into (/additional_info/agent_job_info)[1]
						'')
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END CATCH;'

			DECLARE @job_id UNIQUEIDENTIFIER;
			DECLARE @step_id INT;

			DECLARE agent_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT
					s.session_id,
					agent_nodes.agent_node.value('(job_id/text())[1]', 'uniqueidentifier') AS job_id,
					agent_nodes.agent_node.value('(step_id/text())[1]', 'int') AS step_id
				FROM #sessions AS s
				CROSS APPLY s.additional_info.nodes('//agent_job_info') AS agent_nodes (agent_node)
				WHERE
					s.recursion = 1
			OPTION (KEEPFIXED PLAN);
			
			OPEN agent_cursor;

			FETCH NEXT FROM agent_cursor
			INTO 
				@session_id,
				@job_id,
				@step_id;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				EXEC sp_executesql
					@sql_n,
					N'@job_id UNIQUEIDENTIFIER, @step_id INT, @session_id SMALLINT',
					@job_id, @step_id, @session_id

				FETCH NEXT FROM agent_cursor
				INTO 
					@session_id,
					@job_id,
					@step_id;
			END;

			CLOSE agent_cursor;
			DEALLOCATE agent_cursor;
		END; 
		
		IF 
			@delta_interval > 0 
			AND @recursion <> 1
		BEGIN;
			SET @recursion = 1;

			DECLARE @delay_time CHAR(12);
			SET @delay_time = CONVERT(VARCHAR, DATEADD(second, @delta_interval, 0), 114);
			WAITFOR DELAY @delay_time;

			GOTO REDO;
		END;
	END;

	SET @sql = 
		--Outer column list
		CONVERT
		(
			VARCHAR(MAX),
			CASE
				WHEN 
					@destination_table <> '' 
					AND @return_schema = 0 
						THEN 'INSERT ' + @destination_table + ' '
				ELSE ''
			END +
			'SELECT ' +
				@output_column_list + ' ' +
			CASE @return_schema
				WHEN 1 THEN 'INTO #session_schema '
				ELSE ''
			END
		--End outer column list
		) + 
		--Inner column list
		CONVERT
		(
			VARCHAR(MAX),
			'FROM ' +
			'( ' +
				'SELECT ' +
					'session_id, ' +
					--[dd hh:mm:ss.mss]
					CASE
						WHEN @format_output IN (1, 2) THEN
							'CASE ' +
								'WHEN elapsed_time < 0 THEN ' +
									'RIGHT ' +
									'( ' +
										'REPLICATE(''0'', max_elapsed_length) + CONVERT(VARCHAR, (-1 * elapsed_time) / 86400), ' +
										'max_elapsed_length ' +
									') + ' +
										'RIGHT ' +
										'( ' +
											'CONVERT(VARCHAR, DATEADD(second, (-1 * elapsed_time), 0), 120), ' +
											'9 ' +
										') + ' +
										'''.000'' ' +
								'ELSE ' +
									'RIGHT ' +
									'( ' +
										'REPLICATE(''0'', max_elapsed_length) + CONVERT(VARCHAR, elapsed_time / 86400000), ' +
										'max_elapsed_length ' +
									') + ' +
										'RIGHT ' +
										'( ' +
											'CONVERT(VARCHAR, DATEADD(second, elapsed_time / 1000, 0), 120), ' +
											'9 ' +
										') + ' +
										'''.'' + ' + 
										'RIGHT(''000'' + CONVERT(VARCHAR, elapsed_time % 1000), 3) ' +
							'END AS [dd hh:mm:ss.mss], '
						ELSE
							''
					END +
					--[dd hh:mm:ss.mss (avg)] / avg_elapsed_time
					CASE 
						WHEN  @format_output IN (1, 2) THEN 
							'RIGHT ' +
							'( ' +
								'''00'' + CONVERT(VARCHAR, avg_elapsed_time / 86400000), ' +
								'2 ' +
							') + ' +
								'RIGHT ' +
								'( ' +
									'CONVERT(VARCHAR, DATEADD(second, avg_elapsed_time / 1000, 0), 120), ' +
									'9 ' +
								') + ' +
								'''.'' + ' +
								'RIGHT(''000'' + CONVERT(VARCHAR, avg_elapsed_time % 1000), 3) AS [dd hh:mm:ss.mss (avg)], '
						ELSE
							'avg_elapsed_time, '
					END +
					--physical_io
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_io))) OVER() - LEN(CONVERT(VARCHAR, physical_io))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io), 1), 19)) AS '
						ELSE ''
					END + 'physical_io, ' +
					--reads
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, reads))) OVER() - LEN(CONVERT(VARCHAR, reads))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads), 1), 19)) AS '
						ELSE ''
					END + 'reads, ' +
					--physical_reads
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_reads))) OVER() - LEN(CONVERT(VARCHAR, physical_reads))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads), 1), 19)) AS '
						ELSE ''
					END + 'physical_reads, ' +
					--writes
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, writes))) OVER() - LEN(CONVERT(VARCHAR, writes))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes), 1), 19)) AS '
						ELSE ''
					END + 'writes, ' +
					--tempdb_allocations
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_allocations))) OVER() - LEN(CONVERT(VARCHAR, tempdb_allocations))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations), 1), 19)) AS '
						ELSE ''
					END + 'tempdb_allocations, ' +
					--tempdb_current
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_current))) OVER() - LEN(CONVERT(VARCHAR, tempdb_current))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current), 1), 19)) AS '
						ELSE ''
					END + 'tempdb_current, ' +
					--CPU
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, CPU))) OVER() - LEN(CONVERT(VARCHAR, CPU))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU), 1), 19)) AS '
						ELSE ''
					END + 'CPU, ' +
					--context_switches
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, context_switches))) OVER() - LEN(CONVERT(VARCHAR, context_switches))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches), 1), 19)) AS '
						ELSE ''
					END + 'context_switches, ' +
					--used_memory
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, used_memory))) OVER() - LEN(CONVERT(VARCHAR, used_memory))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory), 1), 19)) AS '
						ELSE ''
					END + 'used_memory, ' +
					CASE
						WHEN @output_column_list LIKE '%|_delta|]%' ESCAPE '|' THEN
							--physical_io_delta			
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND physical_io_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_io_delta))) OVER() - LEN(CONVERT(VARCHAR, physical_io_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io_delta), 1), 19)) ' 
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io_delta), 1), 19)) '
											ELSE 'physical_io_delta '
										END +
								'ELSE NULL ' +
							'END AS physical_io_delta, ' +
							--reads_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND reads_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, reads_delta))) OVER() - LEN(CONVERT(VARCHAR, reads_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads_delta), 1), 19)) '
											ELSE 'reads_delta '
										END +
								'ELSE NULL ' +
							'END AS reads_delta, ' +
							--physical_reads_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND physical_reads_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_reads_delta))) OVER() - LEN(CONVERT(VARCHAR, physical_reads_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads_delta), 1), 19)) '
											ELSE 'physical_reads_delta '
										END + 
								'ELSE NULL ' +
							'END AS physical_reads_delta, ' +
							--writes_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND writes_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, writes_delta))) OVER() - LEN(CONVERT(VARCHAR, writes_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes_delta), 1), 19)) '
											ELSE 'writes_delta '
										END + 
								'ELSE NULL ' +
							'END AS writes_delta, ' +
							--tempdb_allocations_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND tempdb_allocations_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_allocations_delta))) OVER() - LEN(CONVERT(VARCHAR, tempdb_allocations_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations_delta), 1), 19)) '
											ELSE 'tempdb_allocations_delta '
										END + 
								'ELSE NULL ' +
							'END AS tempdb_allocations_delta, ' +
							--tempdb_current_delta
							--this is the only one that can (legitimately) go negative 
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_current_delta))) OVER() - LEN(CONVERT(VARCHAR, tempdb_current_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current_delta), 1), 19)) '
											ELSE 'tempdb_current_delta '
										END + 
								'ELSE NULL ' +
							'END AS tempdb_current_delta, ' +
							--CPU_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
										'THEN ' +
											'CASE ' +
												'WHEN ' +
													'thread_CPU_delta > CPU_delta ' +
													'AND thread_CPU_delta > 0 ' +
														'THEN ' +
															CASE @format_output
																WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, thread_CPU_delta + CPU_delta))) OVER() - LEN(CONVERT(VARCHAR, thread_CPU_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, thread_CPU_delta), 1), 19)) '
																WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, thread_CPU_delta), 1), 19)) '
																ELSE 'thread_CPU_delta '
															END + 
												'WHEN CPU_delta >= 0 THEN ' +
													CASE @format_output
														WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, thread_CPU_delta + CPU_delta))) OVER() - LEN(CONVERT(VARCHAR, CPU_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU_delta), 1), 19)) '
														WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU_delta), 1), 19)) '
														ELSE 'CPU_delta '
													END + 
												'ELSE NULL ' +
											'END ' +
								'ELSE ' +
									'NULL ' +
							'END AS CPU_delta, ' +
							--context_switches_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND context_switches_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, context_switches_delta))) OVER() - LEN(CONVERT(VARCHAR, context_switches_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches_delta), 1), 19)) '
											ELSE 'context_switches_delta '
										END + 
								'ELSE NULL ' +
							'END AS context_switches_delta, ' +
							--used_memory_delta
							'CASE ' +
								'WHEN ' +
									'first_request_start_time = last_request_start_time ' + 
									'AND num_events = 2 ' +
									'AND used_memory_delta >= 0 ' +
										'THEN ' +
										CASE @format_output
											WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, used_memory_delta))) OVER() - LEN(CONVERT(VARCHAR, used_memory_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory_delta), 1), 19)) '
											WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory_delta), 1), 19)) '
											ELSE 'used_memory_delta '
										END + 
								'ELSE NULL ' +
							'END AS used_memory_delta, '
						ELSE ''
					END +
					--tasks
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tasks))) OVER() - LEN(CONVERT(VARCHAR, tasks))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tasks), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tasks), 1), 19)) '
						ELSE ''
					END + 'tasks, ' +
					'status, ' +
					'wait_info, ' +
					'locks, ' +
					'tran_start_time, ' +
					'LEFT(tran_log_writes, LEN(tran_log_writes) - 1) AS tran_log_writes, ' +
					--open_tran_count
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, open_tran_count))) OVER() - LEN(CONVERT(VARCHAR, open_tran_count))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, open_tran_count), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, open_tran_count), 1), 19)) AS '
						ELSE ''
					END + 'open_tran_count, ' +
					--sql_command
					CASE @format_output 
						WHEN 0 THEN 'REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), sql_command), ''<?query --''+CHAR(13)+CHAR(10), ''''), CHAR(13)+CHAR(10)+''--?>'', '''') AS '
						ELSE ''
					END + 'sql_command, ' +
					--sql_text
					CASE @format_output 
						WHEN 0 THEN 'REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), sql_text), ''<?query --''+CHAR(13)+CHAR(10), ''''), CHAR(13)+CHAR(10)+''--?>'', '''') AS '
						ELSE ''
					END + 'sql_text, ' +
					'query_plan, ' +
					'blocking_session_id, ' +
					--blocked_session_count
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, blocked_session_count))) OVER() - LEN(CONVERT(VARCHAR, blocked_session_count))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1), 19)) AS '
						ELSE ''
					END + 'blocked_session_count, ' +
					--percent_complete
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, CONVERT(MONEY, percent_complete), 2))) OVER() - LEN(CONVERT(VARCHAR, CONVERT(MONEY, percent_complete), 2))) + CONVERT(CHAR(22), CONVERT(MONEY, percent_complete), 2)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1)) AS '
						ELSE ''
					END + 'percent_complete, ' +
					'host_name, ' +
					'login_name, ' +
					'database_name, ' +
					'program_name, ' +
					'additional_info, ' +
					'start_time, ' +
					'login_time, ' +
					'CASE ' +
						'WHEN status = N''sleeping'' THEN NULL ' +
						'ELSE request_id ' +
					'END AS request_id, ' +
					'GETDATE() AS collection_time '
		--End inner column list
		) +
		--Derived table and INSERT specification
		CONVERT
		(
			VARCHAR(MAX),
				'FROM ' +
				'( ' +
					'SELECT TOP(2147483647) ' +
						'*, ' +
						'CASE ' +
							'MAX ' +
							'( ' +
								'LEN ' +
								'( ' +
									'CONVERT ' +
									'( ' +
										'VARCHAR, ' +
										'CASE ' +
											'WHEN elapsed_time < 0 THEN ' +
												'(-1 * elapsed_time) / 86400 ' +
											'ELSE ' +
												'elapsed_time / 86400000 ' +
										'END ' +
									') ' +
								') ' +
							') OVER () ' +
								'WHEN 1 THEN 2 ' +
								'ELSE ' +
									'MAX ' +
									'( ' +
										'LEN ' +
										'( ' +
											'CONVERT ' +
											'( ' +
												'VARCHAR, ' +
												'CASE ' +
													'WHEN elapsed_time < 0 THEN ' +
														'(-1 * elapsed_time) / 86400 ' +
													'ELSE ' +
														'elapsed_time / 86400000 ' +
												'END ' +
											') ' +
										') ' +
									') OVER () ' +
						'END AS max_elapsed_length, ' +
						CASE
							WHEN @output_column_list LIKE '%|_delta|]%' ESCAPE '|' THEN
								'MAX(physical_io * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(physical_io * recursion) OVER (PARTITION BY session_id, request_id) AS physical_io_delta, ' +
								'MAX(reads * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(reads * recursion) OVER (PARTITION BY session_id, request_id) AS reads_delta, ' +
								'MAX(physical_reads * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(physical_reads * recursion) OVER (PARTITION BY session_id, request_id) AS physical_reads_delta, ' +
								'MAX(writes * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(writes * recursion) OVER (PARTITION BY session_id, request_id) AS writes_delta, ' +
								'MAX(tempdb_allocations * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(tempdb_allocations * recursion) OVER (PARTITION BY session_id, request_id) AS tempdb_allocations_delta, ' +
								'MAX(tempdb_current * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(tempdb_current * recursion) OVER (PARTITION BY session_id, request_id) AS tempdb_current_delta, ' +
								'MAX(CPU * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(CPU * recursion) OVER (PARTITION BY session_id, request_id) AS CPU_delta, ' +
								'MAX(thread_CPU_snapshot * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(thread_CPU_snapshot * recursion) OVER (PARTITION BY session_id, request_id) AS thread_CPU_delta, ' +
								'MAX(context_switches * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(context_switches * recursion) OVER (PARTITION BY session_id, request_id) AS context_switches_delta, ' +
								'MAX(used_memory * recursion) OVER (PARTITION BY session_id, request_id) + ' +
									'MIN(used_memory * recursion) OVER (PARTITION BY session_id, request_id) AS used_memory_delta, ' +
								'MIN(last_request_start_time) OVER (PARTITION BY session_id, request_id) AS first_request_start_time, '
							ELSE ''
						END +
						'COUNT(*) OVER (PARTITION BY session_id, request_id) AS num_events ' +
					'FROM #sessions AS s1 ' +
					CASE 
						WHEN @sort_order = '' THEN ''
						ELSE
							'ORDER BY ' +
								@sort_order
					END +
				') AS s ' +
				'WHERE ' +
					's.recursion = 1 ' +
			') x ' +
			'OPTION (KEEPFIXED PLAN); ' +
			'' +
			CASE @return_schema
				WHEN 1 THEN
					'SET @schema = ' +
						'''CREATE TABLE <table_name> ( '' + ' +
							'STUFF ' +
							'( ' +
								'( ' +
									'SELECT ' +
										''','' + ' +
										'QUOTENAME(COLUMN_NAME) + '' '' + ' +
										'DATA_TYPE + ' + 
										'CASE ' +
											'WHEN DATA_TYPE LIKE ''%char'' THEN ''('' + COALESCE(NULLIF(CONVERT(VARCHAR, CHARACTER_MAXIMUM_LENGTH), ''-1''), ''max'') + '') '' ' +
											'ELSE '' '' ' +
										'END + ' +
										'CASE IS_NULLABLE ' +
											'WHEN ''NO'' THEN ''NOT '' ' +
											'ELSE '''' ' +
										'END + ''NULL'' AS [text()] ' +
									'FROM tempdb.INFORMATION_SCHEMA.COLUMNS ' +
									'WHERE ' +
										'TABLE_NAME = (SELECT name FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(''tempdb..#session_schema'')) ' +
										'ORDER BY ' +
											'ORDINAL_POSITION ' +
									'FOR XML ' +
										'PATH('''') ' +
								'), + ' +
								'1, ' +
								'1, ' +
								''''' ' +
							') + ' +
						''')''; ' 
				ELSE ''
			END
		--End derived table and INSERT specification
		);

	SET @sql_n = CONVERT(NVARCHAR(MAX), @sql);

	EXEC sp_executesql
		@sql_n,
		N'@schema VARCHAR(MAX) OUTPUT',
		@schema OUTPUT;
END;
GO


USE master
GO

IF OBJECT_ID('dbo.sp_Kill') IS NULL
	EXEC('CREATE PROCEDURE dbo.sp_Kill AS SELECT 1 as Dummy;');
	--DROP PROCEDURE dbo.sp_Kill
GO

ALTER PROCEDURE dbo.sp_Kill @p_SpId SMALLINT = NULL, 
							@p_DbName VARCHAR(155) = NULL, @p_LoginName VARCHAR(255) = NULL, 
							@p_RollbackStatus BIT = NULL, @p_Force BIT = NULL, 
							@p_AddAuthorizedSessionKiller BIT = 0,
							@p_Help BIT = NULL, @p_Verbose BIT = 0
--WITH EXECUTE AS OWNER
AS
BEGIN -- Proc Body
	/*	Created By:		Ajay Dwivedi
		Version:		0.0
		Permission:		https://dba.stackexchange.com/a/188193
						https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/blob/master/sp_HealthCheck/Certificate%20Based%20Authentication.sql
		Modifications:	May 14, 2019 - Creating procedure for 1st time
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		PRINT 'Declaring Variables..';

	DECLARE @_errorMSG VARCHAR(MAX);
	DECLARE @_errorNumber INT;
	DECLARE @_isValidParameterSet bit = 0;
	DECLARE @_callerSPID smallint = @@SPID;
	DECLARE @_callerLoginName varchar(125);
	DECLARE @_runningAsLoginName varchar(125);
	DECLARE @_isKillerSameAsKilled BIT = 0;
	DECLARE @_isAuthorizedSessionKiller BIT = 0;
	DECLARE @_sessionDbName varchar(125);
	DECLARE @_isKillerDbOwner BIT = 0;
	DECLARE @_isKillerSysAdmin BIT = 0;
	DECLARE @_CallerUserName_OUT varchar(125); -- Used for Check 04 - SysAdmin
	DECLARE @_SQLString nvarchar(MAX);  
	DECLARE @_ParmDefinition nvarchar(500);
	DECLARE @_PermissionOutput TABLE (hasAlterAnyConnection INT);

	CREATE TABLE #DatabaseLoginConnections (ID INT IDENTITY(1,1), session_id INT NOT NULL, dbName varchar(225) NULL, login_name varchar(125) NULL);

	IF OBJECT_ID('DBA..AuthorizedSessionKiller') IS NULL
	BEGIN
		CREATE TABLE DBA.dbo.AuthorizedSessionKiller(ID INT IDENTITY(1,1), IsDbLevelPermission BIT NOT NULL DEFAULT 1, DbName varchar(125) NULL, LoginName varchar(125) NOT NULL, AddedBy varchar(125) NOT NULL, AddedOn datetime NOT NULL DEFAULT GETDATE());
	END

	IF @p_Verbose = 1
		PRINT 'Removing null values from parameters..';
	SELECT @_callerLoginName = s.original_login_name from sys.dm_exec_sessions as s where s.session_id = @_callerSPID;
	SET @_runningAsLoginName = SUSER_NAME();
	SET @p_RollbackStatus = ISNULL(@p_RollbackStatus,0);
	SET @p_Force = ISNULL(@p_Force,0);
	SET @p_Help = ISNULL(@p_Help,0);
	SET @p_Verbose = ISNULL(@p_Verbose,0);
	SET @p_AddAuthorizedSessionKiller = ISNULL(@p_AddAuthorizedSessionKiller,0);

	IF @p_Verbose = 1
	BEGIN
		PRINT 'Values of Parameters:- ';
		PRINT CHAR(9)+'@p_SpId = '+(CASE WHEN @p_SpId IS NULL THEN 'NULL' ELSE CAST(@p_SpId AS VARCHAR(5)) END);
		PRINT CHAR(9)+'@p_DbName = '+CAST(ISNULL(@p_DbName,'NULL') AS VARCHAR(255));
		PRINT CHAR(9)+'@p_LoginName = '+CAST(ISNULL(@p_LoginName,'NULL') AS VARCHAR(255));
		PRINT CHAR(9)+'@p_RollbackStatus = '+CAST(@p_RollbackStatus AS VARCHAR(5));		
		PRINT CHAR(9)+'@p_Force = '+CAST(@p_Force AS VARCHAR(5));
		PRINT CHAR(9)+'@p_AddAuthorizedSessionKiller = '+CAST(@p_AddAuthorizedSessionKiller AS VARCHAR(5));		
		PRINT CHAR(9)+'@p_Help = '+CAST(@p_Help AS VARCHAR(5));
		PRINT CHAR(9)+'@p_Verbose = '+CAST(@p_Verbose AS VARCHAR(5));
			
		PRINT CHAR(9)+'@_callerSPID = '+CAST(@_callerSPID AS VARCHAR(5));
		PRINT CHAR(9)+'@_callerLoginName = '+ISNULL(@_callerLoginName, 'NULL');
		PRINT CHAR(9)+'@_runningAsLoginName = '+ISNULL(@_runningAsLoginName,'NULL');
		PRINT CHAR(9)+'@_isAuthorizedSessionKiller = '+CAST(@_isAuthorizedSessionKiller AS VARCHAR(5));	
	END

	/*
	IF @p_Verbose = 1
	BEGIN
		SET @_SQLString = 'USE [master]; EXECUTE AS LOGIN = '''+@_callerLoginName+'''; IF EXISTS (SELECT 1 FROM fn_my_permissions(NULL, ''SERVER'') as p WHERE p.permission_name = ''ALTER ANY CONNECTION'') SELECT 1; ELSE SELECT 0;';
		PRINT @_SQLString
		
		INSERT @_PermissionOutput(hasAlterAnyConnection)
		EXEC(@_SQLString);

		SELECT Q.RunningQuery, P.hasAlterAnyConnection
		FROM @_PermissionOutput AS p
		FULL OUTER JOIN
		(SELECT 'SELECT * FROM @_PermissionOutput' AS RunningQuery ) AS Q
		ON 1 = 1
	END
	*/

	IF @p_Verbose = 1
		PRINT 'Start - verification of provided parameter values..';

	-- Validate that At least one valid parameter value if provided
	IF @p_SpId IS NULL AND (@p_Help IS NULL OR @p_Help = 0) AND @p_DbName IS NULL AND @p_LoginName IS NULL AND (@p_AddAuthorizedSessionKiller IS NULL OR @p_AddAuthorizedSessionKiller <> 1)
	BEGIN
		SET @_errorMSG = 'Kindly provide value for at least one of the following parameters:-'+char(10)+char(13)+'@p_SpId, @p_Help, @p_DbName, @p_LoginName, or @p_AddAuthorizedSessionKiller';
		IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
			EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
		ELSE
			EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
	END

	-- Validate if valid parameter set is provided with @p_SpId
	IF @p_SpId IS NOT NULL
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_DbName IS NOT NULL OR @p_LoginName IS NOT NULL OR 
												 (@p_Force IS NOT NULL AND @p_Force = 1) OR 
												 (@p_AddAuthorizedSessionKiller IS NOT NULL AND @p_AddAuthorizedSessionKiller = 1) OR
												 (@p_Help IS NOT NULL AND @p_Help = 1)		
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameters @p_SpId is not compatible with @p_Help, @p_DbName, @p_LoginName & @p_AddAuthorizedSessionKiller. Kindly keep values for these to default(NULL/0).';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_RollbackStatus
	IF @p_RollbackStatus IS NOT NULL AND @p_RollbackStatus = 1
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_SpId IS NULL OR @p_SpId < 50 THEN 0 ELSE 1 END;

		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Provided value for parameter @p_SpId is not valid with @p_RollbackStatus parameter.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_DbName
	IF @p_DbName IS NOT NULL
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_SpId IS NOT NULL OR (@p_Help IS NOT NULL AND @p_Help = 1) OR (@p_RollbackStatus IS NOT NULL AND @p_RollbackStatus = 1)	
											THEN 0
											WHEN (@p_AddAuthorizedSessionKiller IS NULL OR @p_AddAuthorizedSessionKiller <> 1) AND (@p_Force IS NULL OR @p_Force <> 1)	
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameter @p_DbName require values for either @p_Force(=1) & @p_AddAuthorizedSessionKiller(=1).';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_LoginName
	IF @p_LoginName IS NOT NULL
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_SpId IS NOT NULL OR (@p_Help IS NOT NULL AND @p_Help = 1) OR (@p_RollbackStatus IS NOT NULL AND @p_RollbackStatus = 1)	
											THEN 0
											WHEN (@p_AddAuthorizedSessionKiller IS NULL OR @p_AddAuthorizedSessionKiller <> 1) AND (@p_Force IS NULL OR @p_Force <> 1)	
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameter @p_LoginName require values for either @p_Force(=1) & @p_AddAuthorizedSessionKiller(=1).';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_RollbackStatus
	IF @p_RollbackStatus IS NOT NULL AND @p_RollbackStatus = 1
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_SpId IS NULL OR @p_SpId < 50
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameter @p_RollbackStatus require value for parameter @p_SpId (>= 50).';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_Force
	IF @p_Force IS NOT NULL AND @p_Force = 1
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_DbName IS NULL AND @p_LoginName IS NULL
											THEN 0
											WHEN @p_AddAuthorizedSessionKiller IS NOT NULL AND @p_AddAuthorizedSessionKiller = 1
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameter @p_Force require values for parameters @p_DbName & @p_LoginName. Also, @p_AddAuthorizedSessionKiller should be either NULL or 0';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_AddAuthorizedSessionKiller
	IF @p_AddAuthorizedSessionKiller IS NOT NULL AND @p_AddAuthorizedSessionKiller = 1
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_LoginName IS NULL
											THEN 0
											WHEN @p_SpId IS NOT NULL OR (@p_RollbackStatus IS NOT NULL AND @p_RollbackStatus = 1) OR (@p_Force IS NOT NULL AND @p_Force = 1) OR (@p_Help IS NOT NULL AND @p_Help = 1)
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameter @p_AddAuthorizedSessionKiller require value for parameter @p_LoginName (and @p_DbName if available). Also, @p_AddAuthorizedSessionKiller is not compatible with parameters @p_SpId, @p_RollbackStatus, @p_Force & @p_Help.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END

	-- Validate if valid parameter set is provided with @p_Help
	IF @p_Help IS NOT NULL AND @p_Help = 1
	BEGIN
		SET @_isValidParameterSet = 1;
		SELECT @_isValidParameterSet = CASE WHEN @p_SpId IS NOT NULL OR @p_DbName IS NOT NULL OR @p_LoginName IS NOT NULL OR (@p_RollbackStatus IS NOT NULL AND @p_RollbackStatus = 1) OR (@p_Force IS NOT NULL AND @p_Force = 1) OR (@p_AddAuthorizedSessionKiller IS NOT NULL AND @p_AddAuthorizedSessionKiller = 1)
											THEN 0
											ELSE 1
											END;
		IF @_isValidParameterSet = 0
		BEGIN
			SET @_errorMSG = 'Parameter @p_Help is not compatible with parameters @p_SpId, @p_DbName, @p_LoginName, @p_RollbackStatus, @p_Force & @p_AddAuthorizedSessionKiller.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
	END
	
	IF @p_Verbose = 1
		PRINT 'End - verification of provided parameter values..';

	/* ********************************************************************************************************* */

	IF (@p_SpId IS NOT NULL OR @p_LoginName IS NOT NULL OR @p_DbName IS NOT NULL)
	BEGIN -- Validate Killer Credentials
		IF @p_Verbose = 1
			PRINT 'Begin - Validate Killer Credentials ...';

		IF @p_SpId IS NOT NULL
		BEGIN
			IF @p_Verbose = 1
				PRINT CHAR(9)+'Finding @p_SpId context database..';

			-- Trying to find dbName from running request
			SELECT @_sessionDbName = DB_NAME(r.database_id) 
			FROM sys.dm_exec_sessions as s inner join sys.dm_exec_requests as r 
			ON r.session_id = s.session_id WHERE s.session_id = @p_SpId;

			-- Tyring to find dbName from open transactions
			IF @_sessionDbName IS NULL
			BEGIN
				SELECT	@_sessionDbName = db_name(dt.database_id)
						--,st.session_id, dt.transaction_id
				FROM	sys.dm_tran_session_transactions as st
				INNER JOIN sys.dm_tran_database_transactions as dt
					ON	dt.transaction_id = st.transaction_id
				WHERE	st.session_id = @p_SpId;
			END

			IF @p_Verbose = 1
				PRINT CHAR(9)+CHAR(9)+'@_sessionDbName = '+ISNULL(@_sessionDbName,'NULL');
		END
		
		IF @p_Verbose = 1
		BEGIN
			PRINT CHAR(9)+'Check 01 - Is killer part of AuthorizedSessionKiller exception entry';
			PRINT CHAR(9)+CHAR(9)+'Before Check, @_isAuthorizedSessionKiller = '+CAST(@_isAuthorizedSessionKiller AS VARCHAR(5));	
		END
		IF EXISTS (SELECT * FROM DBA.dbo.AuthorizedSessionKiller as k WHERE k.LoginName = @_callerLoginName AND (k.DbName IS NULL OR k.DbName = COALESCE(@p_DbName,@_sessionDbName)) )
			SET @_isAuthorizedSessionKiller = 1;
		IF @p_Verbose = 1
			PRINT CHAR(9)+CHAR(9)+'After Check, @_isAuthorizedSessionKiller = '+CAST(@_isAuthorizedSessionKiller AS VARCHAR(5));	


		-- If 1st Check did not pass
		IF @_isAuthorizedSessionKiller <> 1
		BEGIN
			IF @p_SpId IS NOT NULL OR @p_LoginName IS NOT NULL
			BEGIN
				IF @p_Verbose = 1
				BEGIN
					PRINT CHAR(9)+'Check 02 - Verify if Killer is same as session owner';
					PRINT CHAR(9)+CHAR(9)+'Before Check, @_isKillerSameAsKilled = '+CAST(@_isKillerSameAsKilled AS VARCHAR(5));	
				END
				SELECT @_isKillerSameAsKilled = 1 FROM sys.dm_exec_sessions as s WHERE s.session_id = @p_SpId AND s.login_name = @_callerLoginName;

				IF @_isKillerSameAsKilled <> 1 AND (@p_LoginName IS NOT NULL AND @p_LoginName = @_callerLoginName)
					SET @_isKillerSameAsKilled = 1;		

				IF @p_Verbose = 1
					PRINT CHAR(9)+CHAR(9)+'Before Check, @_isKillerSameAsKilled = '+CAST(@_isKillerSameAsKilled AS VARCHAR(5));
			END
		END

		-- If 1st & 2nd Check did not pass
		IF @_isKillerSameAsKilled <> 1 AND @_isAuthorizedSessionKiller <> 1
		BEGIN
			IF @p_DbName IS NOT NULL OR (@p_SpId IS NOT NULL AND @_sessionDbName IS NOT NULL)
			BEGIN
				IF @p_Verbose = 1
				BEGIN
					PRINT CHAR(9)+'Check 03 - Verify if Killer is [db_owner]';
					PRINT CHAR(9)+CHAR(9)+'Before Check, @_isKillerDbOwner = '+CAST(@_isKillerDbOwner AS VARCHAR(5));	
				END

				SET @_SQLString = N'USE ['+COALESCE(@p_DbName,@_sessionDbName)+']; SELECT @p_isKillerDbOwner_OUT = ISNULL(is_rolemember(''db_owner'', @p_callerLoginName),0)';  
				SET @_ParmDefinition = N'@p_callerLoginName varchar(125), @p_isKillerDbOwner_OUT bit OUTPUT';  

				IF @p_Verbose = 1
					PRINT CHAR(9)+CHAR(9)+'@_SQLString = '+CHAR(10)+@_SQLString;

				EXECUTE sp_executesql @_SQLString, @_ParmDefinition, @p_callerLoginName = @_callerLoginName, @p_isKillerDbOwner_OUT = @_isKillerDbOwner OUTPUT;  

				IF @p_Verbose = 1
					PRINT CHAR(9)+CHAR(9)+'After Check, @_isKillerDbOwner = '+CAST(@_isKillerDbOwner AS VARCHAR(5));	
			END
		END

		IF @_isKillerSameAsKilled <> 1 AND @_isAuthorizedSessionKiller <> 1 AND @_isKillerDbOwner <> 1
		BEGIN
			IF @p_Verbose = 1
			BEGIN
				PRINT CHAR(9)+'Check 04 - Verify if Killer is [sysadmin]';
				PRINT CHAR(9)+CHAR(9)+'Before Check, @p_callerLoginName = '+@_callerLoginName;
				--PRINT CHAR(9)+CHAR(9)+'Before Check, @_CallerUserName_OUT = '+CAST(ISNULL(@_CallerUserName_OUT,'NULL') AS VARCHAR(125));
				PRINT CHAR(9)+CHAR(9)+'Before Check, @_isKillerSysAdmin = '+CAST(@_isKillerSysAdmin AS VARCHAR(5));	
			END

			/*
			SET @_SQLString = N'USE [master]; EXECUTE AS LOGIN = '''+@_callerLoginName+''';
SET @_CallerUserName_OUT = SUSER_NAME();
IF (SELECT COUNT(*) FROM fn_my_permissions(NULL, ''SERVER'') as p WHERE p.permission_name IN (''CONNECT SQL'',''SHUTDOWN'',''VIEW SERVER STATE'',''ALTER SERVER STATE'',''CONTROL SERVER'',''ALTER ANY CONNECTION'')) = 6
	SET @p_isKillerSysAdmin_OUT = 1
ELSE
	SET @p_isKillerSysAdmin_OUT = 0';
			SET @_ParmDefinition = N'@p_isKillerSysAdmin_OUT bit OUTPUT, @_CallerUserName_OUT VARCHAR(125) OUTPUT';

			IF @p_Verbose = 1
				PRINT CHAR(9)+CHAR(9)+'@_SQLString = '+CHAR(10)+@_SQLString;

			EXECUTE sp_executesql @_SQLString, @_ParmDefinition, @p_isKillerSysAdmin_OUT = @_isKillerSysAdmin OUTPUT, @_CallerUserName_OUT = @_CallerUserName_OUT OUTPUT;  
			*/

			SET @_SQLString = 'USE [master]; EXECUTE AS LOGIN = '''+@_callerLoginName+'''; IF EXISTS (SELECT 1 FROM fn_my_permissions(NULL, ''SERVER'') as p WHERE p.permission_name = ''ALTER ANY CONNECTION'') SELECT 1; ELSE SELECT 0;';
		
			INSERT @_PermissionOutput(hasAlterAnyConnection)
			EXEC(@_SQLString);

			IF @p_Verbose = 1
				PRINT CHAR(9)+CHAR(9)+'@_SQLString = '+CHAR(10)+@_SQLString;

			IF EXISTS (SELECT * FROM @_PermissionOutput WHERE hasAlterAnyConnection = 1)
				SET @_isKillerSysAdmin = 1;
			ELSE
				SET @_isKillerSysAdmin = 0;

			IF @p_Verbose = 1
			BEGIN
				SELECT Q.RunningQuery, P.hasAlterAnyConnection
				FROM @_PermissionOutput AS p
				FULL OUTER JOIN
				(SELECT 'SELECT * FROM @_PermissionOutput' AS RunningQuery ) AS Q
				ON 1 = 1;

				PRINT CHAR(9)+CHAR(9)+'After Check, @p_callerLoginName = '+@_callerLoginName;
				PRINT CHAR(9)+CHAR(9)+'After Check, @_isKillerSysAdmin = '+CAST(ISNULL(@_isKillerSysAdmin,'NULL') AS VARCHAR(2));
				--PRINT CHAR(9)+CHAR(9)+'After Check, @_CallerUserName_OUT = '+CAST(ISNULL(@_CallerUserName_OUT,'NULL') AS VARCHAR(125));
			END
		END

		IF @p_Verbose = 1
			PRINT 'End - Validate Killer Credentials ...';
	END -- Validate Killer Credentials

	/* ********************************************************************************************************* */


	IF @p_AddAuthorizedSessionKiller = 1
	BEGIN
		IF @p_Verbose = 1
			PRINT 'Begin - [@p_AddAuthorizedSessionKiller = 1]';

		IF @_isKillerSysAdmin = 1
		BEGIN
			PRINT CHAR(9)+'Adding exception for login '+QUOTENAME(@p_LoginName)+' ..';
			-- Validate the same login name + database is not already present
			IF NOT EXISTS (SELECT * FROM DBA.dbo.AuthorizedSessionKiller as k WHERE k.LoginName = @p_LoginName AND ( CASE WHEN @p_DbName IS NOT NULL AND DbName = @p_DbName THEN 1 WHEN @p_DbName IS NULL THEN 1 ELSE 0 END) = 1)
			BEGIN
				INSERT DBA.dbo.AuthorizedSessionKiller
				(IsDbLevelPermission, DbName, LoginName , AddedBy)
				SELECT	[IsDbLevelPermission] = CASE WHEN @p_DbName IS NOT NULL THEN 1 ELSE 0 END
						,@p_DbName	,@p_LoginName ,@_callerLoginName;
			END

			PRINT 'Login '+QUOTENAME(@p_LoginName)+' is added successfully';
		END
		ELSE
		BEGIN
			SET @_errorMSG = 'Login '+QUOTENAME(@_callerLoginName)+' is not SysAdmin on server. So not authorized to add Exception.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF @p_Verbose = 1
			PRINT 'End - [@p_AddAuthorizedSessionKiller = 1]';
	END

	IF @p_Help = 1
	BEGIN
		IF @p_Verbose=1 
			PRINT	'
/*	******************** Begin:	@p_Help = 1 **************************** */';

		-- VALUES constructor method does not work in SQL 2005. So using UNION ALL
		SELECT	[Parameter Name], [Data Type], [Default Value], [Parameter Description], [Supporting Parameters]
		FROM	(SELECT	'!~~~ Version ~~~~!' as [Parameter Name],'Information' as [Data Type],'0.0' as [Default Value],'Last Updated - 15/May/2019' as [Parameter Description], 'https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Help' as [Parameter Name],'BIT' as [Data Type],'0' as [Default Value],'Displays this help message.' as [Parameter Description], '' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_SpId','INT',NULL,'Session ID to be killed, or for which rollback status check is required.', '[@p_RollbackStatus] [,@p_Verbose]' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_AddAuthorizedSessionKiller','BIT','0','Mention @p_LoginName (& @p_DbName is available but not required) along with this parameter to Add Exception as Authorized Killers of session requests.', '@p_LoginName [,@p_DbName] [,@p_Verbose] ' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_DbName','VARCHAR(125)',NULL,'Database name for which either the session are to be killed, or Exception has to be added.', '{@p_Force | @p_AddAuthorizedSessionKiller}' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_LoginName','VARCHAR(125)',NULL,'Login name for which either the session are to be killed, or Exception has to be added.', '{@p_Force | @p_AddAuthorizedSessionKiller} [,@p_DbName] [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_RollbackStatus','BIT','0','Is used to check rollback status of previous killed session id.', '@p_SpId [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_Force','BIT','0','Is used to kill all connections for @p_DbName and/or @p_LoginName.', '{@p_LoginName [,@p_DbName] | @p_DbName [,@p_LoginNam]} [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_Verbose','BIT','0','This present all background information that can be used to debug procedure working.', 'All parameters supported' as [Supporting Parameters]
				) AS Params; --([Parameter Name], [Data Type], [Default Value], [Parameter Description], [Supporting Parameters]);


		IF @p_Verbose = 1 
			PRINT	'/*	******************** End:	@p_Help = 1 **************************** */
';
	END

	IF @p_SpId IS NOT NULL
	BEGIN -- Begin [@p_SpId IS NOT NULL]
		IF @p_Verbose = 1
			PRINT 'Begin - [@p_SpId IS NOT NULL]';

		IF NOT EXISTS(SELECT * FROM sys.dm_exec_sessions s where s.session_id = @p_SpId)
		BEGIN
			SET @_errorMSG = 'Session id (@p_SpId) '+cast(@p_SpId as varchar(10))+' no longer exists. No action required.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF @_isAuthorizedSessionKiller = 1 OR @_isKillerSameAsKilled = 1 OR @_isKillerDbOwner = 1 OR @_isKillerSysAdmin = 1
		BEGIN
			IF @p_Verbose = 1
				PRINT CHAR(9)+'Caller is allowed to kill sessions';

			IF @p_RollbackStatus = 1
				SET @_SQLString = N'KILL '+CAST(@p_SpId AS VARCHAR(10))+' WITH STATUSONLY;';  
			ELSE
				SET @_SQLString = N'KILL '+CAST(@p_SpId AS VARCHAR(10));  

			BEGIN TRY
				EXEC (@_SQLString);
				PRINT 'Session Id '+CAST(@p_SpId AS VARCHAR(10))+' has been killed. To check rollback status, kindly execute below code:-'+CHAR(10)+'EXEC sp_kill @p_SpId = '+CAST(@p_SpId AS VARCHAR(10))+', @p_RollbackStatus = 1;';
			END TRY
			BEGIN CATCH
				SELECT @_errorMSG = ERROR_MESSAGE(), @_errorNumber = ERROR_NUMBER();

				IF @_errorNumber = 6106
					PRINT @_errorMSG;
				ELSE
				BEGIN
					IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
						EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
					ELSE
						EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
				END
			END CATCH
		END
		ELSE
		BEGIN
			IF @p_Verbose = 1
				PRINT CHAR(9)+'Caller is not allowed to kill sessions';
			SET @_errorMSG = 'You '+QUOTENAME(@_callerLoginName)+' are not authorized to kill session as you do not fall in any of the following categories:-'+CHAR(10)
							+CHAR(10)+CHAR(9)+'Check 01 - Is killer part of AuthorizedSessionKiller exception entry'
							+CHAR(10)+CHAR(9)+'Check 02 - Verify if Killer is same as session owner'
							+CHAR(10)+CHAR(9)+'Check 03 - Verify if Killer is [db_owner]'
							+CHAR(10)+CHAR(9)+'Check 04 - Verify if Killer is [sysadmin]';

			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(MAX)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(MAX)', @_errorMSG;
		END

		IF @p_Verbose = 1
			PRINT 'End - [@p_SpId IS NOT NULL]';
	END -- End [@p_SpId IS NOT NULL]

	-- Kill All connections of Database/Login
	IF @p_SpId IS NULL AND (@p_AddAuthorizedSessionKiller IS NULL OR @p_AddAuthorizedSessionKiller <> 1) AND (@p_DbName IS NOT NULL OR @p_LoginName IS NOT NULL)
	BEGIN -- Begin [Kill All connections of Database/Login]
		IF @p_Verbose = 1
			PRINT 'Begin - [Kill All connections of Database/Login]';

		IF @p_Verbose = 1
			PRINT CHAR(9)+'Validating if Killer is [Sysadmin] on server..';
		IF @_isKillerSysAdmin = 1
		BEGIN
			IF @p_Verbose = 1
				PRINT CHAR(9)+CHAR(9)+'Validation if Killer is [Sysadmin] on server has Passed.';
				
			IF @p_LoginName IS NOT NULL
			BEGIN
				IF @p_Verbose = 1
					PRINT CHAR(9)+'Find/Populate #DatabaseLoginConnections if connections are there for Login '+QUOTENAME(@p_LoginName)+'..';
									
				INSERT #DatabaseLoginConnections (session_id, login_name)
				SELECT	s.session_id, COALESCE(s.login_name, s.original_login_name)
				FROM	sys.dm_exec_sessions as s
				WHERE	COALESCE(s.login_name, s.original_login_name) = @p_LoginName;
			END

			IF @p_DbName IS NOT NULL
			BEGIN
				IF @p_Verbose = 1
					PRINT CHAR(9)+'Find/Populate #DatabaseLoginConnections  if connections are there for database '+QUOTENAME(@p_DbName)+'..';
									
				INSERT #DatabaseLoginConnections (session_id, login_name, dbName)
				SELECT s.session_id, s.login_name, DB_NAME(r.database_id) as dbName
				FROM sys.dm_exec_sessions as s
				INNER JOIN sys.dm_exec_requests as r on r.session_id = s.session_id
				WHERE r.database_id = db_id(@p_DbName)
				--
				UNION
				--
				SELECT l.request_session_id, login_name = COALESCE(s.login_name, s.original_login_name), db_name(l.resource_database_id) as dbName 
				FROM sys.dm_tran_locks as l left join sys.dm_exec_sessions as s on s.session_id = l.request_session_id
				WHERE l.resource_type = 'DATABASE' AND l.resource_database_id = db_id(@p_DbName);
			END

			IF @p_Verbose = 1
			BEGIN
				PRINT CHAR(9)+'SELECT * FROM #DatabaseLoginConnections;';
				SELECT Q.RunningQuery, c.* FROM #DatabaseLoginConnections as c
				FULL OUTER JOIN
				( SELECT 'SELECT * FROM #DatabaseLoginConnections' as RunningQuery ) AS Q
				ON 1 = 1
			END

			IF EXISTS (SELECT * FROM #DatabaseLoginConnections)
			BEGIN
				IF @p_Verbose = 1
					PRINT CHAR(9)+'Proceeding to kill connections for database/login..';

				SET @_SQLString = '';
				SELECT	@_SQLString = @_SQLString + 'BEGIN TRY'+CHAR(10)+CHAR(9)+'Kill ' + Convert(varchar(5), session_id) + ';'+CHAR(10)+'END TRY'+CHAR(10)+'BEGIN CATCH '+CHAR(10)+CHAR(9)+'PRINT ''Session ID '+Convert(varchar(5), session_id)+' does not exist anymore. ''; '+CHAR(10)+'END CATCH'+CHAR(10)+''
				FROM (	SELECT	DISTINCT session_id FROM #DatabaseLoginConnections s 
						WHERE	(@p_LoginName IS NULL OR s.login_name = @p_LoginName)
							AND (@p_DbName IS NULL OR s.dbName = @p_DbName)
					 ) AS s;

				IF @p_Verbose = 1
					PRINT CHAR(9)+'@_SQLString = '+CHAR(10)+@_SQLString;

				EXEC (@_SQLString);

				PRINT 'All connections are killed successfully.';
			END
		END
		ELSE
		BEGIN
			IF @p_Verbose = 1
				PRINT CHAR(9)+'Caller is not allowed to kill sessions at Database/Login level as it requires Sysadmin permission';
			SET @_errorMSG = 'You '+QUOTENAME(@_callerLoginName)+' not allowed to kill sessions at Database/Login level as it requires Sysadmin permission';

			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(MAX)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(MAX)', @_errorMSG;
		END

		IF @p_Verbose = 1
			PRINT 'End - [Kill All connections of Database/Login]';
	END -- End [Kill All connections of Database/Login]
	
END	 -- Proc Body
GO

USE DBA
GO

IF OBJECT_ID('dbo.usp_WhoIsActive_Blocking') IS NULL
	EXEC('CREATE PROCEDURE dbo.usp_WhoIsActive_Blocking AS SELECT 1 AS Dummy')
GO

ALTER PROCEDURE dbo.usp_WhoIsActive_Blocking
	@p_Collection_time_Start datetime = NULL, @p_Collection_time_End datetime = NULL, @p_Program_Name nvarchar(256) = NULL, @p_WaitTime_Seconds BIGINT = NULL,
	@p_Help bit = 0, @p_Verbose bit = 0
WITH EXECUTE AS OWNER
AS 
BEGIN
	/*	Created By:			Ajay Dwivedi (ajay.dwivedi2007@gmail.com)
		Version:			0.1
		Permission:			https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/blob/master/sp_HealthCheck/Certificate%20Based%20Authentication.sql
		Updates:			May 12, 2019 - Get Blocking Details
							May 23, 2019 - Add one more parameter to filter on BlockTime(Seconds)
	*/
	SET NOCOUNT ON;

	DECLARE @_errorMSG VARCHAR(MAX);
	DECLARE @_errorNumber INT;

	IF @p_Help = 1
	BEGIN
		IF @p_Verbose=1 
			PRINT	'
/*	******************** Begin:	@p_Help = 1 **************************** */';

		-- VALUES constructor method does not work in SQL 2005. So using UNION ALL
		SELECT	[Parameter Name], [Data Type], [Default Value], [Parameter Description], [Supporting Parameters]
		FROM	(SELECT	'!~~~ Version ~~~~!' as [Parameter Name],'Information' as [Data Type],'0.1' as [Default Value],'Last Updated - 23/May/2019' as [Parameter Description], 'https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Help' as [Parameter Name],'BIT' as [Data Type],'0' as [Default Value],'Displays this help message.' as [Parameter Description], '' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Collection_time_Start','datetime',NULL,'Start time in format ''May 17 2019 01:45AM''.', '[@p_Collection_time_End] [,@p_Program_Name] [,@p_Verbose]' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Collection_time_End','datetime',NULL,'End time in format ''May 17 2019 01:45AM''.', '[@p_Collection_time_Start] [,@p_Program_Name] [,@p_Verbose]' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_WaitTime_Seconds','bigint',NULL,'Lock Time Threshold in seconds to filter the blocking resultset.', '[@p_Collection_time_Start] [,@p_Collection_time_End] [,@p_Program_Name] [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_Program_Name','VARCHAR(125)',NULL,'value that would match [program_name] column of DBA..whoIsActive_ResultSets table.', '[@p_Collection_time_Start] [,@p_Collection_time_End] [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_Verbose','BIT','0','This present all background information that can be used to debug procedure working.', 'All parameters supported' as [Supporting Parameters]
				) AS Params; --([Parameter Name], [Data Type], [Default Value], [Parameter Description], [Supporting Parameters]);


		IF @p_Verbose = 1 
			PRINT	'/*	******************** End:	@p_Help = 1 **************************** */
';
	END
	ELSE
	BEGIN
		IF @p_Verbose = 1
			PRINT 'Evaluating values of @p_Collection_time_Start and @p_Collection_time_End';

		IF @p_Collection_time_Start IS NULL AND @p_Collection_time_End IS NULL
			SELECT	@p_Collection_time_Start = DATEADD(minute,-120,getdate()), @p_Collection_time_End = GETDATE();
		ELSE IF @p_Collection_time_Start IS NULL
			SELECT @p_Collection_time_Start = DATEADD(minute,-120,@p_Collection_time_End);
	
		IF @p_Collection_time_End IS NULL AND @p_Collection_time_Start IS NOT NULL
			SELECT	@p_Collection_time_End = DBA.dbo.fn_GetNextCollectionTime(@p_Collection_time_Start);

		IF @p_WaitTime_Seconds IS NOT NULL AND @p_WaitTime_Seconds <= 0
		BEGIN
			SET @_errorMSG = 'Kindly provide value for following parameters:-'+char(10)+char(13)+'@p_Collection_time_Start, @p_Collection_time_End';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF @p_Verbose = 1
		BEGIN
			PRINT '@p_Collection_time_Start = '''+CAST(@p_Collection_time_Start AS VARCHAR(35))+'''';
			PRINT '@p_Collection_time_End = '''+CAST(@p_Collection_time_End AS VARCHAR(35))+'''';
		END
			
		IF OBJECT_ID('tempdb..#BlockingTree') IS NOT NULL
			DROP TABLE #BlockingTree;

		;WITH T_BLOCKERS AS
		(
			-- Find block Leaders
			SELECT	[collection_time], [TimeInMinutes], [session_id], 
					[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST([sql_text] AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
					[login_name], [wait_info], [blocking_session_id], [blocking_head] = cast(NULL as int),
					[status], [open_tran_count], [host_name], [database_name], [program_name],
					r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_reads],
					[LEVEL] = CAST (REPLICATE ('0', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
			FROM	[dbo].WhoIsActive_ResultSets AS r
			WHERE	(r.collection_time >= @p_Collection_time_Start AND r.collection_time <= @p_Collection_time_End)
				AND	(r.blocking_session_id IS NULL OR r.blocking_session_id = r.session_id)
				AND EXISTS (SELECT R2.session_id FROM [dbo].WhoIsActive_ResultSets AS R2 
							WHERE R2.collection_Time = r.collection_Time AND R2.blocking_session_id IS NOT NULL 
								AND R2.blocking_session_id = r.session_id AND R2.blocking_session_id <> R2.session_id
								AND (@p_Program_Name IS NULL OR R2.program_name = @p_Program_Name)
							)
			--	
			UNION ALL
			--
			SELECT	r.[collection_time], r.[TimeInMinutes], r.[session_id], 
					[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(r.[sql_text] AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
					r.[login_name], r.[wait_info], r.[blocking_session_id], [blocking_head] = cast(COALESCE(B.[blocking_head],B.session_id) as int),
					r.[status], r.[open_tran_count], r.[host_name], r.[database_name], r.[program_name],
					r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_reads],
					CAST (B.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL
			FROM	[dbo].WhoIsActive_ResultSets AS r
			INNER JOIN 
					T_BLOCKERS AS B
				ON	r.collection_time = B.collection_time
				AND	r.blocking_session_id = B.session_id
			WHERE	r.blocking_session_id <> r.session_id
		)
		SELECT	[collection_time], 
				[BLOCKING_TREE] = N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) 
								+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
											THEN 'HEAD -  '
											ELSE '|------  ' 
									END
								+	CAST (r.session_id AS NVARCHAR (10)) + N' ' + (CASE WHEN LEFT(r.[sql_text],1) = '(' THEN SUBSTRING(r.[sql_text],CHARINDEX('exec',r.[sql_text]),LEN(r.[sql_text]))  ELSE r.[sql_text] END),
				[session_id], [blocking_session_id], [blocking_head],
				[WaitTime(Seconds)] = COALESCE([lock_time(UnExpected)], [lock_time(1)],[lock_time(2)],[lock_time(x)])/1000,
				w.lock_text,
				[sql_commad] = CONVERT(XML, '<?query -- '+char(13)
								+ (CASE WHEN LEFT([sql_text],1) = '(' THEN SUBSTRING([sql_text],CHARINDEX('exec',[sql_text]),LEN([sql_text]))  ELSE [sql_text] END)
								+ char(13)+'--?>'), 
				[host_name], [database_name], [login_name], [program_name],	[wait_info], [open_tran_count]
				,r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_reads] --, r.[query_plan]
				--,[Blocking_Order] = DENSE_RANK()OVER(ORDER BY collection_time, LEVEL ASC)
				,LEVEL
		INTO	#BlockingTree
		FROM	T_BLOCKERS AS r
		OUTER APPLY
			(	
				select	lock_text,								
						[lock_time(UnExpected)] = CASE WHEN lock_text IS NULL THEN NULL -- When Lock_Test is NULL or Not Valid
												WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) = 0
												THEN CAST(SUBSTRING(lock_text,2,CHARINDEX('ms)',lock_text)-2) AS bigint)
												ELSE NULL		
												END
						,[lock_time(1)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
												THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) = 1
															THEN CAST(SUBSTRING(lock_text,6,CHARINDEX('ms)',lock_text)-6) AS bigint)
															ELSE NULL
															END
												ELSE NULL		
												END
						,[lock_time(2)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
												THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) = 2
															THEN CAST(SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1) AS bigint)
															ELSE NULL
															END
												ELSE NULL		
												END
						,[lock_time(x)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
												THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) > 2
															THEN CAST(SUBSTRING(lock_text, CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)+1, CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)-1) AS bigint)
															ELSE NULL
															END
												ELSE NULL		
												END
								
				from (
					SELECT	[lock_text] = CASE	WHEN r.[wait_info] IS NULL OR CHARINDEX('LCK',r.[wait_info]) = 0
												THEN NULL
												WHEN CHARINDEX(',',r.[wait_info]) = 0
												THEN r.[wait_info]
												WHEN CHARINDEX(',',LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1   )) <> 0
												THEN REVERSE(LEFT(	REVERSE(LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1)),
																CHARINDEX(',',REVERSE(LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1)))-1
															))
												ELSE LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1   )
												END
				) as wi
			) AS w;	

		SELECT	[collection_time], [BLOCKING_TREE],	[session_id], [WaitTime(Seconds)], lock_text, [sql_commad], 
				[host_name], [database_name], [login_name], [program_name],	[wait_info], [open_tran_count]
				,[CPU], [tempdb_allocations], [tempdb_current], [reads], [writes], [physical_reads]
		FROM #BlockingTree AS b
		WHERE	@p_WaitTime_Seconds IS NULL
		OR	(	CASE WHEN	blocking_session_id IS NULL AND NOT EXISTS (SELECT i.* FROM #BlockingTree as i WHERE i.collection_time = b.collection_time AND i.blocking_head = b.session_id AND i.[WaitTime(Seconds)] >= @p_WaitTime_Seconds)
					 THEN	0
					 WHEN	[WaitTime(Seconds)] < @p_WaitTime_Seconds AND NOT EXISTS (SELECT i.* FROM #BlockingTree as i WHERE i.collection_time = b.collection_time AND i.blocking_session_id = b.session_id AND i.[WaitTime(Seconds)] >= @p_WaitTime_Seconds)
					 THEN	0
					 ELSE	1
					 END
			) = 1
		ORDER BY collection_time, LEVEL ASC;
	END
END
GO
