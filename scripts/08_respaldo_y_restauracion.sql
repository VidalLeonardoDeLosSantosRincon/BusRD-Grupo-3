--BACKUPS
USE BusRD;
GO

--1) Colocamos la base de datos en Recuperación Completa
ALTER DATABASE BusRD SET RECOVERY FULL;

--2) Creamos carpetas necesarias para los backups
--Nota: es necesario habilitar las opciones avanzadas y luego habilitar la ejecucion de comandos de consola.
--Importante: Por motivos de seguridad de igual forma estos se deben apagar luego de creadas las carpetas 
--para evitar que se puedan ejecutar algun otro tipo de comandos que puedan comprometer el sistema.
BEGIN
	DECLARE @Result1 INT;
	DECLARE @Result2 INT;
	DECLARE @Result3 INT;

	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\Backups\BusRD';
	DECLARE @SQLDataPath VARCHAR(50) = 'C:\Backups\BusRD\SQLData';
	DECLARE @SQLLogsPath VARCHAR(50) = 'C:\Backups\BusRD\SQLLogs';
	DECLARE @Command NVARCHAR(100);

	-- Verificar si la carpeta existe
	EXEC xp_fileexist @SqlBackupPath, @Result1 OUTPUT;
	EXEC xp_fileexist @SQLDataPath, @Result2 OUTPUT;
	EXEC xp_fileexist @SQLLogsPath, @Result3 OUTPUT;

	EXEC sp_configure 'show advanced options', 1;
	RECONFIGURE;

	EXEC sp_configure 'xp_cmdshell', 1;
	RECONFIGURE;

	-- Si no existe, crearla
	IF @Result1 = 0
		SET @Command = 'mkdir "' + @SqlBackupPath + '"';
		EXEC xp_cmdshell @Command;
	IF @Result2 = 0
		SET @Command = 'mkdir "' + @SQLDataPath + '"';
		EXEC xp_cmdshell @Command;
	IF @Result3 = 0
		SET @Command = 'mkdir "' + @SQLLogsPath + '"';
		EXEC xp_cmdshell @Command;

	EXEC sp_configure 'xp_cmdshell', 0;
	RECONFIGURE;

	EXEC sp_configure 'show advanced options', 0;
	RECONFIGURE;
END;

--3) Realizamos un respaldo completo.
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\Backups\BusRD';
	DECLARE @path NVARCHAR(200) = CONCAT(@SqlBackupPath, '\');
	DECLARE @dbName NVARCHAR(50) = 'BusRD';
	DECLARE @fileExtension NVARCHAR(10) = '.bak';
	DECLARE @fileName NVARCHAR(200) = CONCAT(@dbName, '_Full', @fileExtension);
	DECLARE @fullFilePath NVARCHAR(200) = CONCAT(@path, @fileName);
	DECLARE @completedMessage NVARCHAR(200) = CONCAT(
		'Respaldo completo en el archivo "' 
		,@fileName
		,'" En la ruta "'
		, @fullFilePath,
		'"');
	
	BACKUP DATABASE @dbName
	TO DISK = @fullFilePath
	WITH FORMAT, --INIT,
	COMPRESSION,   -- Comprime el respaldo para ahorrar espacio
    CHECKSUM,      -- Valida la integridad física de las páginas de datos
	NAME = @completedMessage,
	STATS = 10;
END;

------confirmamos nuestros archivos de backup .mdf y .ldf
--RESTORE FILELISTONLY
--FROM DISK = 'C:\Backups\BusRD\BusRD_Full.bak');

--Consultas de asientos disponibles y boletos vendidados de un viaje
/*
SELECT * FROM dbo.Asientos a
WHERE a.AutobusID = '8'
AND NOT EXISTS (
		SELECT 1 FROM dbo.Boletos b
		WHERE b.ViajeID = 3000
		AND b.NumeroAsiento = a.NumeroAsiento
);

SELECT * FROM dbo.Boletos WHERE ViajeID = 3000
ORDER BY FechaVenta DESC;
*/

--4) Vender 5 boletos
--Canal: Taquilla, Web
--Metodo: Efectivo, Tarjeta, Transferencia
DECLARE @NombreTransaccion VARCHAR(50) = 'Comprar5Boletos';
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN @NombreTransaccion;

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 1,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Efectivo';

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 2,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Efectivo';

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 4,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Efectivo';

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 5,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Efectivo';

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 6,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Efectivo';

    COMMIT TRAN @NombreTransaccion;
    
    PRINT 'Transacción completada con éxito.';
END TRY
BEGIN CATCH
    -- Si hay un error, revertimos la transacción
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN @NombreTransaccion;

    PRINT 'Ocurrió un error, se revirtieron los cambios.';
    THROW;
END CATCH;

--5) Backup diferencial
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\Backups\BusRD';
	DECLARE @path NVARCHAR(200) = CONCAT(@SqlBackupPath, '\');
	DECLARE @dbName NVARCHAR(50) = 'BusRD';
	DECLARE @fileExtension NVARCHAR(10) = '.bak';
	DECLARE @fileName NVARCHAR(200) = CONCAT(@dbName, '_Diff', @fileExtension);
	DECLARE @fullFilePath NVARCHAR(200) = CONCAT(@path, @fileName);
	DECLARE @completedMessage NVARCHAR(200) = CONCAT(
		'Respaldo diferencial en el archivo "' 
		,@fileName
		,'" En la ruta "'
		, @fullFilePath,
		'"');
	
	BACKUP DATABASE @dbName
	TO DISK = @fullFilePath
	WITH DIFFERENTIAL,
	NAME = @completedMessage,
	STATS = 10;
END;

--Consultas de asientos disponibles y boletos vendidados de un viaje
/*
SELECT * FROM dbo.Asientos a
WHERE a.AutobusID = '8'
AND NOT EXISTS (
		SELECT 1 FROM dbo.Boletos b
		WHERE b.ViajeID = 3000
		AND b.NumeroAsiento = a.NumeroAsiento
);

SELECT * FROM dbo.Boletos WHERE ViajeID = 3000
ORDER BY FechaVenta DESC;
*/

--6) Vender 3 boletos
--Canal: Taquilla, Web
--Metodo: Efectivo, Tarjeta, Transferencia

DECLARE @NombreTransaccion VARCHAR(50) = 'Comprar3Boletos';
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRAN @NombreTransaccion;

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 11,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Tarjeta';

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 8,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Tarjeta';

	EXEC dbo.sp_VenderBoleto_v0
		@ViajeID = 3000,
		@NumeroAsiento = 9,
		@ClienteID = 3000,
		@Canal = 'Taquilla',
		@Metodo = 'Tarjeta';

    COMMIT TRAN @NombreTransaccion;
    
    PRINT 'Transacción completada con éxito.';
END TRY
BEGIN CATCH
    -- Si hay un error, revertimos la transacción
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN @NombreTransaccion;

    PRINT 'Ocurrió un error, se revirtieron los cambios.';
    THROW;
END CATCH;

--7) Backup de LOG
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\Backups\BusRD';
	DECLARE @path NVARCHAR(200) = CONCAT(@SqlBackupPath, '\');
	DECLARE @dbName NVARCHAR(50) = 'BusRD';
	DECLARE @fileExtension NVARCHAR(10) = '.trn';
	DECLARE @fileName NVARCHAR(200) = CONCAT(@dbName, '_Log_1', @fileExtension);
	DECLARE @fullFilePath NVARCHAR(200) = CONCAT(@path, @fileName);
	DECLARE @completedMessage NVARCHAR(200) = CONCAT(
		'Respaldo de logs en el archivo "' 
		,@fileName
		,'" En la ruta "'
		, @fullFilePath,
		'"');
	
	BACKUP LOG @dbName
	TO DISK = @fullFilePath
	WITH INIT,
	NAME = @completedMessage,
	STATS = 10;
END;

--8) Borrar todos los boletos del viaje asignado
PRINT 'Hora exacta antes del DELETE: ' + CONVERT(varchar, SYSDATETIME(), 121);
GO
DELETE FROM dbo.Boletos WHERE ViajeID = 3000;
GO

--9) Backup de LOG de cola
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\Backups\BusRD';
	DECLARE @path NVARCHAR(200) = CONCAT(@SqlBackupPath, '\');
	DECLARE @dbName NVARCHAR(50) = 'BusRD';
	DECLARE @fileExtension NVARCHAR(10) = '.trn';
	DECLARE @fileName NVARCHAR(200) = CONCAT(@dbName, '_TailLog_BorradoBoletos', @fileExtension);
	DECLARE @fullFilePath NVARCHAR(200) = CONCAT(@path, @fileName);
	DECLARE @completedMessage NVARCHAR(200) = CONCAT(
		'Respaldo de tail logs en el archivo "' 
		,@fileName
		,'" En la ruta "'
		, @fullFilePath,
		'"');

	USE master;

	--Forzar cierre de conexiones
	ALTER DATABASE BusRD SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	
	BACKUP LOG @dbName
	TO DISK = @fullFilePath
	WITH
	NORECOVERY,
	FORMAT,
	NAME = @completedMessage,
	STATS = 10;
END;

--10) Restaurar en una base nueva BusRD_Recuperada hasta un momento antes del DELETE 
--(STOPAT). 

--Restauramos al primer backup realizado
BEGIN
	USE master; --Es recomendable cambiar de base de datos a master (u otra) antes de resturar backup de nuestra otra base de datos objetivo
	DECLARE @dbName NVARCHAR(50) = 'BusRD';

	-- Hora exacta del desastre para el STOPAT
	DECLARE @stopAtTime DATETIME2 = '2026-10-25T21:04:59';

	--Resturamos nuestro Full Backup
	RESTORE DATABASE @dbName
		FROM DISK = 'C:\Backups\BusRD\BusRD_Full.bak'
		WITH REPLACE,
		MOVE 'BusRD' TO 'C:\Backups\BusRD\SQLData\BusRD.mdf',
		MOVE 'BusRD_log' TO 'C:\Backups\BusRD\SQLLogs\BusRD_log.ldf',
		NORECOVERY,
		STATS = 10;
	PRINT '1. Backup FULL restaurado (en espera...).';

	--Resturamos nuestros logs diferenciales
	RESTORE DATABASE @dbName
		FROM DISK = 'C:\Backups\BusRD\BusRD_Diff.bak'
		WITH NORECOVERY,
		STATS = 10;
	PRINT '2. Backup DIFERENCIAL restaurado (en espera...).';

	--Restauramos los logs intermedios en orden cronológico.
	RESTORE LOG @dbName
		FROM DISK = 'C:\Backups\BusRD\BusRD_Log_1.trn'
		WITH NORECOVERY,
		STATS = 10;
	PRINT '3. Log intermedio restaurado (en espera...).';

	--Restauraramos el Tail-Log final USANDO STOPAT
	RESTORE LOG @dbName
		FROM DISK = 'C:\Backups\BusRD\BusRD_TailLog_BorradoBoletos.trn'
		WITH STOPAT = @stopAtTime,
		RECOVERY;
	PRINT '4. Tail-Log restaurado con STOPAT. ¡Base de datos recuperada y en línea!';

	--Devolver a multiusuario (sin rollback)
	ALTER DATABASE BusRD SET MULTI_USER;

	USE BusRD;
END;
