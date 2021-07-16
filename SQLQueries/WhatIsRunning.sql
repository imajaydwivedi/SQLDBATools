	SELECT s.session_id
	,DB_NAME(r.database_id) as DBName
    ,r.STATUS
	,r.percent_complete
	,CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar) + ' hour(s), '
        + CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + 'min, '
        + CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar) + ' sec'  as running_time
	,CAST((estimated_completion_time/3600000) as varchar) + ' hour(s), '
                  + CAST((estimated_completion_time %3600000)/60000  as varchar) + 'min, '
                  + CAST((estimated_completion_time %60000)/1000  as varchar) + ' sec'  as est_time_to_go
	,dateadd(second,estimated_completion_time/1000, getdate())  as est_completion_time 
    ,r.blocking_session_id 'blocked by'
    ,r.wait_type
    ,wait_resource
    ,r.wait_time / (1000.0) 'Wait Time (in Sec)'
    ,r.cpu_time
    ,r.logical_reads
    ,r.reads
    ,r.writes
    ,r.total_elapsed_time / (1000.0) 'Elapsed Time (in Sec)'
    ,Substring(st.TEXT, (r.statement_start_offset / 2) + 1, (
            (
                CASE r.statement_end_offset
                    WHEN - 1
                        THEN Datalength(st.TEXT)
                    ELSE r.statement_end_offset
                    END - r.statement_start_offset
                ) / 2
            ) + 1) AS statement_text
	,st.text as Batch_Text
	,r.sql_handle
	,r.plan_handle
	,r.query_hash
	,r.query_plan_hash
    ,s.login_name
    ,s.host_name
    ,s.program_name
    ,r.open_transaction_count
	,qp.query_plan
FROM sys.dm_exec_sessions AS s
INNER JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp
WHERE r.session_id != @@SPID
ORDER BY DBName, r.cpu_time DESC
    ,r.STATUS
    ,r.blocking_session_id
    ,s.session_id;