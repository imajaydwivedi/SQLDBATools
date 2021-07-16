--	Minimum permissions required to run sp_Blitz
	-- https://dba.stackexchange.com/a/188193/98923
--	Certificate Signing Stored Procedures in Multiple Databases
	-- https://www.sqlskills.com/blogs/jonathan/certificate-signing-stored-procedures-in-multiple-databases/

USE master
GO

CREATE CERTIFICATE [CodeSigningCertificate]	ENCRYPTION BY PASSWORD = 'Work@Y0urBest' WITH EXPIRY_DATE = '2099-01-01' ,SUBJECT = 'DBA Code Signing Cert'
GO

BACKUP CERTIFICATE [CodeSigningCertificate] TO FILE = 'C:\temp\CodeSigningCertificate.cer'
	WITH PRIVATE KEY (FILE = 'C:\temp\CodeSigningCertificate_WithKey.pvk', ENCRYPTION BY PASSWORD = 'Work@Y0urBest', DECRYPTION BY PASSWORD = 'Work@Y0urBest' );
GO

CREATE LOGIN [CodeSigningLogin] FROM CERTIFICATE [CodeSigningCertificate];
GO

GRANT AUTHENTICATE SERVER TO [CodeSigningLogin]
GO

EXEC master..sp_addsrvrolemember @loginame = N'CodeSigningLogin', @rolename = N'sysadmin'
GO

USE DBA
GO

CREATE CERTIFICATE [CodeSigningCertificate] FROM FILE = 'C:\temp\CodeSigningCertificate.cer'
	WITH PRIVATE KEY (FILE = 'C:\temp\CodeSigningCertificate_WithKey.pvk',
					  ENCRYPTION BY PASSWORD = 'Work@Y0urBest',
					  DECRYPTION BY PASSWORD = 'Work@Y0urBest'
					  );
GO

CREATE USER [CodeSigningLogin] FROM CERTIFICATE [CodeSigningCertificate];
GO

EXEC sp_addrolemember N'db_owner', N'CodeSigningLogin'
GO

USE master
go

ADD SIGNATURE TO [dbo].[sp_Kill] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = 'Work@Y0urBest' -- 'Work@Y0urBest'
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_Kill] TO [public]
GO

ADD SIGNATURE TO [dbo].[sp_WhoIsActive] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = 'Work@Y0urBest' -- 'Work@Y0urBest'
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_WhoIsActive] TO [public]
GO

ADD SIGNATURE TO [dbo].[sp_HealthCheck] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = 'Work@Y0urBest' -- 'Work@Y0urBest'
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_HealthCheck] TO [public]
GO

USE DBA
GO

GRANT CONNECT TO [guest]
GO

ADD SIGNATURE TO [dbo].[usp_WhoIsActive_Blocking] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = 'Work@Y0urBest' -- 'Work@Y0urBest'
GO

GRANT EXECUTE ON OBJECT::[dbo].[usp_WhoIsActive_Blocking] TO [public]
GO