USE DBA
GO

IF OBJECT_ID('dbo.usp_Get_LogShip_Database_Restore_Status') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_Get_LogShip_Database_Restore_Status AS SELECT 1 as Dummy;')
GO
	
ALTER PROCEDURE dbo.usp_Get_LogShip_Database_Restore_Status @recipients VARCHAR(2000) = 'ajay.dwivedi@YourOrg.com; renuka.chopra@YourOrg.com', @threshold_hours int = 24
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @tableHTML  NVARCHAR(MAX) ;  
	DECLARE @mailSubject VARCHAR(500);

	if OBJECT_ID('tempdb..#log_shipping_status') is not null
		drop table #log_shipping_status;
	;with t_log_ship_dbs as
	(
		select d.name as database_name from	sys.databases as d where d.is_in_standby = 1 or	d.is_read_only = 1
	)
	,t_restore_history as
	(
		SELECT rs.[destination_database_name]
				,bs.database_name as source_database_name
				,bs.server_name as source_server_name
				,bs.recovery_model
				,rs.[restore_date]
				,bs.backup_start_date
				,bmf.physical_device_name
				,rs.[user_name]
				,rs.[backup_set_id]
				,CASE rs.[restore_type]
				WHEN 'D' THEN 'Database'
				WHEN 'I' THEN 'Differential'
				WHEN 'L' THEN 'Log'
				WHEN 'F' THEN 'File'
				WHEN 'G' THEN 'Filegroup'
				WHEN 'V' THEN 'Verifyonlyl'
				END AS RestoreType
				,rs.[replace]
				,rs.[recovery]
				,ROW_NUMBER()over(partition by rs.[destination_database_name] order by rs.[restore_date] desc) as RowID
		 FROM [msdb].[dbo].[restorehistory] rs
		 inner join [msdb].[dbo].[backupset] bs
		 on rs.backup_set_id = bs.backup_set_id
		 INNER JOIN msdb.dbo.backupmediafamily bmf 
		 ON bs.media_set_id = bmf.media_set_id
		 where rs.restore_date >= DATEADD(DAY,-7,getdate())
	)
	 select @@serverName as srvName, d.database_name as [destination_database_name] , case when datediff(hour,[restore_date],getdate()) > @threshold_hours then 'YES' else 'no' end as [Need_Attention], [source_database_name] ,[recovery_model] ,[restore_date] ,DATEDIFF(HOUR,[restore_date],GETDATE()) as [Last_Restore_Hours] , [RestoreType]
	 into #log_shipping_status
	 from t_log_ship_dbs as d
	 left join t_restore_history as h
	 on h.destination_database_name = d.database_name
	 where h.RowID = 1
	 and h.restore_date <= DATEADD(hour,-@threshold_hours,getdate())
 
	if OBJECT_ID('tempdb..#log_shipping_status') is not null and exists (select * from #log_shipping_status where recovery_model <> 'SIMPLE')
	begin
		SET @mailSubject = 'Restore History Report - '+@@SERVERNAME+' - '+CAST(GETDATE() AS VARCHAR(30));
		SET @tableHTML =  
		N'<style>
		.attention_yes {
			background-color: yellow;
			color: #A52A2A;
		}
		.attention_no {
			color: #228B22;
		}
		</style>'+
			N'<H1>Restore History Report</H1>' +  
			N'<table border="1">' +  
			N'<tr><th>srvName</th><th>destination_database_name</th><th>Need_Attention</th><th>source_database_name</th><th>recovery_model</th><th>restore_date</th><th>Last_Restore_Hours</th><th>RestoreType</th></tr>' +  
			CAST ( ( SELECT td = srvName,       '',  
							td = destination_database_name, '',  
							--td = (case when Need_Attention = 'YES' then '<span class=attention_yes>'+Need_Attention+'</span>' else '<span class=attention_no>'+Need_Attention+'</span>' end), '',  
							td = Need_Attention, '',  
							td = source_database_name, '',  
							td = recovery_model, '',  
							td = restore_date, '',  
							td = cast(Last_Restore_Hours as varchar(20)), '',  
							td = RestoreType
					  FROM #log_shipping_status as l 
					  WHERE recovery_model <> 'SIMPLE'
					  ORDER BY restore_date ASC
					  FOR XML PATH('tr'), TYPE   
			) AS NVARCHAR(MAX) ) +  
			N'</table>' ;  

		SET @tableHTML = @tableHTML + '
<p><br>
Thanks & Regards,<br>
SQL Alerts<br>
dba-group@YourOrg.com<br>
-- Alert Coming from SQL Agent Job [DBA Log Walk Alerts]<br>
</p>
'
  
		EXEC msdb.dbo.sp_send_dbmail @recipients=@recipients,
			@subject = @mailSubject,  
			@body = @tableHTML,  
			@body_format = 'HTML' ;  
	end
END
GO


