IF NOT EXISTS(SELECT * FROM msdb..sysoperators o where o.name = 'DBAGroup')
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
			@email_address=N'dba-group@YourCompany.com', 
			@category_name=N'[Uncategorized]'
END

