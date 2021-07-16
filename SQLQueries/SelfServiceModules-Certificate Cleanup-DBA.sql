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


