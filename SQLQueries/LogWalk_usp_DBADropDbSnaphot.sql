USE [DBA];
GO

IF OBJECT_ID('dbo.usp_DBADropDbSnaphot') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_DBADropDbSnaphot AS SELECT 1 AS DummyToBeReplace;');
GO

ALTER procedure [dbo].[usp_DBADropDbSnaphot]
	@dbname sysname = Null
as
BEGIN
	/* Modifications:	Ajay Dwivedi (June 07, 2019) - Replacing usp_DBAKillInactiveUser with [sp_kill]

	*/
-- =================================================================
-- Author:		<Authors - Clint Herring>
-- Create date: <Create Date - 6/17/2014>
-- Description:	<Description -	This proc will delete DB SnapShots
-- for all existing db snapshot or specific databases.
--
-- Parameters: @dbname - If supplied only db snapshots for this db
--                       will be deleted. The default is Null.
-- ==================================================================


	Set nocount on
	Declare @dbsslist table (dbname sysname)
	Declare @dbid int
	Declare @cmdstr varchar(1024)

	If @dbname is not null 
		Select @dbid = database_id from sys.databases where name = @dbname
	
	If @dbid is not null
		Insert into @dbsslist 
		select name from sys.databases where source_database_id = @dbid
	Else
		Insert into @dbsslist 
		select name from sys.databases where source_database_id is not null
		and name not in ('master','model', 'msdb','tempdb','ReportServer','ReportServerTempdb')
	
	If exists (select * from @dbsslist)
		Begin
			Select @dbname = MIN(dbname) from @dbsslist
			While @dbname is not null
				Begin
					Exec usp_DBAKillInactiveUser @dbname
					--EXEC master..sp_Kill @p_DbName = @dbname, @p_Force = 1;
					Set @cmdstr = 'drop database ' + @dbname
					Print @cmdstr
					Exec (@cmdstr)
					Select @dbname = MIN(dbname) from @dbsslist where dbname > @dbname
				End
		End
	Else
		Print 'No db snapshots to delete.'
END
GO


