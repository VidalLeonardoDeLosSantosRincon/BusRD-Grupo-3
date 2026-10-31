--BACKUPS
USE BusRD;
GO

-- 1) Colocamos la base de datos en Recuperación Completa para poder respaldar 
-- y restaurar nuestros logs
ALTER DATABASE BusRD SET RECOVERY FULL;
GO

-- 2) creamos un procedimiento en la base de datos temporal 
-- para simular nuestro proces de venta de boletos
IF OBJECT_ID('tempdb..#usp_SimulaVentaBoletos') IS NOT NULL
    DROP PROCEDURE #usp_SimulaVentaBoletos;
GO

CREATE PROCEDURE #usp_SimulaVentaBoletos
    @ViajeID INT,
    @ClienteID INT,
    @CantidadBoletos INT = 1
AS
BEGIN
	--Canal: Taquilla, Web
	--Metodo: Efectivo, Tarjeta, Transferencia
	--Estado viaje: Programado, Completado, Cancelado
	DECLARE @NombreTransaccion VARCHAR(50) = CONCAT('Comprar', @CantidadBoletos, 'Boletos');
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	BEGIN TRY
		BEGIN TRAN @NombreTransaccion;

		-- Parámetros comunes para todos los boletos
		DECLARE @Canal VARCHAR(20) = 'Taquilla';
		DECLARE @Metodo VARCHAR(20) = 'Efectivo';

		DECLARE @AutobusID INT;

		-- seleccionamos un autobus de nuestro viaje o buscamos otro que este disponible
		SELECT TOP 1 @AutobusID = AutobusID, @ViajeID = ViajeID 
		FROM dbo.Viajes WHERE (ViajeID = @ViajeID AND Estado = 'Programado') OR Estado = 'Programado';
	
		SET @AutobusID = ISNULL(@AutobusID, 0);
		SET @ViajeID = ISNULL(@ViajeID, 0);

		IF 0 IN (@ViajeID, @AutobusID)
			THROW 50001, 'No Se encontró un autobus o un viaje disponibles.', 1;

		-- 1. Definimos los 5 asientos que queremos vender de forma dinámica
		DECLARE @Asientos TABLE (
			ID INT IDENTITY(1,1),
			NumeroAsiento INT
		);

		-- buscamos los asientos con boletos disponibles
		INSERT INTO @Asientos(NumeroAsiento)
		SELECT TOP (@CantidadBoletos) a.NumeroAsiento FROM dbo.Asientos a
		WHERE a.AutobusID = @AutobusID
		AND NOT EXISTS (
			SELECT 1 FROM dbo.Boletos b
			WHERE b.ViajeID = @ViajeID
			AND b.NumeroAsiento = a.NumeroAsiento
			AND b.Estado = 'Activo'
		);
	
		-- 2. Variables para el bucle y para armar el mensaje dinámico
		DECLARE @CurrentIndex INT = 1;
		DECLARE @TotalAsientos INT = (SELECT COUNT(ID) FROM @Asientos);
		DECLARE @AsientoActual INT;
		DECLARE @MensajeExito VARCHAR(MAX) = CONCAT('Se vendieron ', @TotalAsientos, ' boletos del viaje ', @ViajeID,' para los asientos: ');
		DECLARE @BoletoID INT;
    
		-- 3. Bucle para ejecutar el procedimiento por cada asiento
		WHILE @CurrentIndex <= @TotalAsientos
		BEGIN
			SELECT @AsientoActual = NumeroAsiento 
			FROM @Asientos 
			WHERE ID = @CurrentIndex;

			--Ejecutamos el procedimiento con el asiento actual
	        EXEC dbo.sp_VenderBoleto
	            @ViajeID = @ViajeID,
	            @NumeroAsiento = @AsientoActual,
	            @ClienteID = @ClienteID,
	            @Canal = @Canal,
	            @MetodoPago = @Metodo,
				@AutobusID = @AutobusID,
				@Monto = 500.00,
				@BoletoID = @BoletoID OUTPUT,
				@SimularDemora = 0;

			-- Concatenamos el asiento actual al mensaje final
			SET @MensajeExito = @MensajeExito + CAST(@AsientoActual AS VARCHAR(10));
        
			-- Si no es el último, agregamos una coma y espacio para que se vea ordenado
			IF @CurrentIndex < @TotalAsientos
			BEGIN
				SET @MensajeExito = @MensajeExito + ', ';
			END

			SET @CurrentIndex = @CurrentIndex + 1;
		END

		COMMIT TRAN @NombreTransaccion;
    
		-- Mostramos el mensaje final
		PRINT '¡Transacción completada con éxito!';
		PRINT @MensajeExito;

	END TRY
	BEGIN CATCH
		-- Si hay un error, revertimos la transacción
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN @NombreTransaccion;

		DECLARE @MensajeError VARCHAR(MAX) = ERROR_MESSAGE();
    
		PRINT 'Ocurrió un error, se revirtieron los cambios.';
		PRINT 'Detalle del error: ' + @MensajeError;

		THROW;
	END CATCH;
END;

--3) Creamos carpetas necesarias para los backups
--Nota: es necesario habilitar las opciones avanzadas y luego habilitar la ejecucion de comandos de consola.
--Importante: Por motivos de seguridad de igual forma estos se deben apagar luego de creadas las carpetas 
--para evitar que se puedan ejecutar algun otro tipo de comandos que puedan comprometer el sistema.
BEGIN
	DECLARE @Result1 INT;
	DECLARE @Result2 INT;
	DECLARE @Result3 INT;

	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD';
	DECLARE @SQLDataPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD\SQLData';
	DECLARE @SQLLogsPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD\SQLLogs';
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
GO

--4) Realizamos un respaldo completo.
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD';
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
GO

--5) Vendemos 5 boletos
EXEC #usp_SimulaVentaBoletos
	@ViajeID = 3000,
	@ClienteID = 3000,
	@CantidadBoletos = 5;
GO

--Consultamos los últimos 5 boletos vendidos para confirmar
SELECT TOP 5 * FROM dbo.Boletos ORDER BY BoletoID DESC;

--6) Realizamos un respaldo diferencial
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD';
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
GO

--7) Vendemos 3 boletos más
EXEC #usp_SimulaVentaBoletos
	@ViajeID = 3000,
	@ClienteID = 3000,
	@CantidadBoletos = 3;
GO

--Consultamos los últimos 8 boletos vendidos para confirmar
SELECT TOP 8 * FROM dbo.Boletos ORDER BY BoletoID DESC;

--8) Realizamos un respaldo de logs
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD';
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
GO

--9) Borramos los últimos 8 boletos agregados y sus pagos

--Creamos la tabla temporal #BorradoAudit para guarda la fecha del borrado
IF OBJECT_ID('tempdb..#BorradoAudit') IS NOT NULL
    DROP TABLE #BorradoAudit;
GO

CREATE TABLE #BorradoAudit (ID INT IDENTITY, Fecha VARCHAR(30));
GO

--Iniciamos el borrado de los boletos
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
	DECLARE @FechaBorrado VARCHAR(30) = CONVERT(varchar, SYSDATETIME(), 121);

	--Guardando registro último borrado
	INSERT INTO #BorradoAudit (Fecha) VALUES (@FechaBorrado);

	--Borrando pago de boletos
	DELETE FROM dbo.Pagos where BoletoID IN (
		SELECT TOP 8 BoletoID FROM dbo.Boletos ORDER BY BoletoID DESC
	);

	--Borrando boletos
	DELETE FROM dbo.Boletos where BoletoID IN (
		SELECT TOP 8 BoletoID FROM dbo.Boletos ORDER BY BoletoID DESC
	);

    COMMIT TRANSACTION;
	PRINT CONCAT('Hora exacta antes del DELETE:', @FechaBorrado);

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Consultamos los últimos 8 boletos agregados
SELECT TOP 8 * FROM dbo.Boletos ORDER BY BoletoID DESC;

--10) Realizamos un respaldo de logs de cola
BEGIN
	DECLARE @SqlBackupPath VARCHAR(50) = 'C:\SqlBackups_Grupo3\BusRD';
	DECLARE @path NVARCHAR(200) = CONCAT(@SqlBackupPath, '\');
	DECLARE @dbName NVARCHAR(50) = 'BusRD';
	DECLARE @fileExtension NVARCHAR(10) = '.trn';
	DECLARE @fileName NVARCHAR(200) = CONCAT(@dbName, '_TailLog_BorradoBoletos', @fileExtension);
	DECLARE @fullFilePath NVARCHAR(200) = CONCAT(@path, @fileName);
	DECLARE @completedMessage NVARCHAR(200) = 'Respaldo de tail logs en el archivo';

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
GO

--11) Restauramos la base de datos BusRD hasta un momento antes del DELETE 
--(STOPAT). 

--Restauramos al primer backup realizado
BEGIN
	USE master; --Es recomendable cambiar de base de datos a master (u otra) antes de resturar backup de nuestra otra base de datos objetivo
	DECLARE @dbName NVARCHAR(50) = 'BusRD';

	-- Hora exacta del desastre para el STOPAT 
	--Nota: para este ejemplo solo restauraremos hasta un minuto antes de la ejecución
	-- en un escenario real es importante el saber el punto exacto hasta donde ocurrio el incidente
	--para perder la menor cantidad de transacciones posibles.
	DECLARE @stopAtTime VARCHAR(30);

	--Buscamos la última fecha de borrado.
	SELECT TOP 1 @stopAtTime = Fecha FROM #BorradoAudit ORDER BY ID DESC;

	--Resturamos nuestro Full Backup
	RESTORE DATABASE @dbName
		FROM DISK = 'C:\SqlBackups_Grupo3\BusRD\BusRD_Full.bak'
		WITH REPLACE,
		MOVE 'BusRD' TO 'C:\SqlBackups_Grupo3\BusRD\SQLData\BusRD.mdf',
		MOVE 'BusRD_log' TO 'C:\SqlBackups_Grupo3\BusRD\SQLLogs\BusRD_log.ldf',
		NORECOVERY,
		STATS = 10;
	PRINT '1. Backup FULL restaurado (en espera...).';

	--Resturamos nuestros logs diferenciales
	RESTORE DATABASE @dbName
		FROM DISK = 'C:\SqlBackups_Grupo3\BusRD\BusRD_Diff.bak'
		WITH NORECOVERY,
		STATS = 10;
	PRINT '2. Backup DIFERENCIAL restaurado (en espera...).';

	--Restauramos los logs intermedios en orden cronológico.
	RESTORE LOG @dbName
		FROM DISK = 'C:\SqlBackups_Grupo3\BusRD\BusRD_Log_1.trn'
		WITH NORECOVERY,
		STATS = 10;
	PRINT '3. Log intermedio restaurado (en espera...).';

	--Restauraramos el Tail-Log final USANDO STOPAT
	RESTORE LOG @dbName
		FROM DISK = 'C:\SqlBackups_Grupo3\BusRD\BusRD_TailLog_BorradoBoletos.trn'
		WITH STOPAT = @stopAtTime,
		RECOVERY;
	PRINT CONCAT('4. Tail-Log restaurado con STOPAT (', @stopAtTime,'). ¡Base de datos recuperada y en línea!');

	--Devolver a multiusuario (sin rollback)
	ALTER DATABASE BusRD SET MULTI_USER;

	USE BusRD;
END;
GO

-- Consultamos los últimos 8 boletos agregados
SELECT TOP 8 * FROM dbo.Boletos ORDER BY BoletoID DESC;
