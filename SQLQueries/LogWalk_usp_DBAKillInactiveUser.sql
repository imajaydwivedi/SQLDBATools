USE [DBA]
GO

IF OBJECT_ID('dbo.usp_DBAKillInactiveUser') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_DBAKillInactiveUser AS SELECT 1 AS DummyToBeReplace;');
GO

ALTER  procedure [dbo].[usp_DBAKillInactiveUser]
        @DbName varchar(60) = null,
        @activedate datetime = '01/01/3000'	
AS
BEGIN

-- Parameters  :@Dbname - Database where users are connected.  
--                        This is a required parameter	
--		          @activedate - Last active transaction date.	
--		
-- Description :Kills all users connected to a specified database 
--              (@Dbname) except sa. If @activedate is specified, 
--              it kills all connections that are have a last_batch 
--              date (last active transaction) older than @activedate			
--
--	Created on June 18, 2001 Shrikant Kumar

   set nocount on
   If (select object_id('tempdb.dbo.#spids')) > 0 
      drop table dbo.#spids
   Create table dbo.#spids(spid int null, last_batch datetime null, loginame sysname null)

   declare @cmd varchar(255)
   declare @spid int
   declare @loginame sysname
   DECLARE @_errorMSG VARCHAR(2000);
	DECLARE @_errorNumber INT;

   if @DbName is null or @DbName = ''
      begin
         print ' Process failed due to a missing parameter.'
         print ' Usage: usp_killuser <DbName>, <activedate>'
         return
      end
   else
      begin
         insert into #spids
         select spid, last_batch, loginame
           from master.dbo.sysprocesses
          where dbid = (select dbid from master.dbo.sysdatabases
   		                where name = @DbName) 
            and last_batch < @activedate 
            and sid not in (select sid from master.dbo.syslogins where name in ('sa','tvguide\mssqlexec'))
   
         select @spid = min(spid) from #spids 
         while @spid is not null
            begin
               if @spid <> @@spid
                  begin
                     select @loginame = loginame from #spids where spid = @spid
                     select @cmd = 'use master; kill ' + ltrim(rtrim(str(@spid))) 
                     print 'Killing spid ' + ltrim(rtrim(str(@spid)))  + ' - ' + @loginame
					 begin try
						execute (@cmd)
					 end try
					 begin catch
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
					 end catch
                  end
               select @spid = min(spid) from #spids where  spid > @spid
               waitfor delay '00:00:02'
            end
      end
end


GO


