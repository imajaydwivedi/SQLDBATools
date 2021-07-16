USE master
go

IF OBJECT_ID('dbo.sp_WhoIsActive') IS NOT NULL
	DROP PROCEDURE [sp_WhoIsActive]; 
GO
IF OBJECT_ID('dbo.sp_kill') IS NOT NULL
	DROP PROCEDURE [sp_kill]
GO
IF OBJECT_ID('dbo.sp_HealthCheck') IS NOT NULL
	DROP PROCEDURE [sp_HealthCheck]
GO
IF EXISTS(select * from sys.database_principals as p where p.name = 'CodeSigningLogin')
	DROP USER [CodeSigningLogin]; 
GO 
IF EXISTS(select * from sys.server_principals as p where p.name = 'CodeSigningLogin')
	DROP LOGIN [CodeSigningLogin]; 
GO 
IF EXISTS (select * from sys.certificates as c where c.name = 'CodeSigningCertificate')
	DROP CERTIFICATE [CodeSigningCertificate]; 
GO


USE master
GO

IF EXISTS (select * from sys.configurations as c where c.name = 'xp_cmdshell' and c.value_in_use = 0)
BEGIN
	-- To allow advanced options to be changed.  
	EXEC sp_configure 'show advanced options', 1;    
	-- To update the currently configured value for advanced options.  
	RECONFIGURE;  
	-- To enable the feature.  
	EXEC sp_configure 'xp_cmdshell', 1;  
	-- To update the currently configured value for this feature.  
	RECONFIGURE;  
END
GO

USE master
GO
DECLARE @cmd NVARCHAR(MAX) = 'xp_cmdshell ''del "C:\temp\CodeSigningCertificate.cer"'', no_output'; EXEC (@cmd);
SET @cmd = 'xp_cmdshell ''del "C:\temp\CodeSigningCertificate_WithKey.pvk"'', no_output'; EXEC (@cmd);
GO

USE DBA;
GO

IF OBJECT_ID('dbo.usp_WhoIsActive_Blocking') IS NOT NULL
	DROP PROCEDURE dbo.usp_WhoIsActive_Blocking
GO

IF EXISTS(select * from sys.database_principals as p where p.name = 'CodeSigningLogin')
	DROP USER [CodeSigningLogin]; 
GO 

IF EXISTS (select * from sys.certificates as c where c.name = 'CodeSigningCertificate')
	DROP CERTIFICATE [CodeSigningCertificate]; 
GO


