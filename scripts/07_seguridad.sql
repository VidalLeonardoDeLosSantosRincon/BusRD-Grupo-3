
USE BusRD;
GO

-- CREACIÓN DE VISTAS
CREATE OR ALTER VIEW dbo.vw_AsientosDisponibles
AS
SELECT v.ViajeID, s.NumeroAsiento, s.Ubicacion
FROM dbo.Viajes v
JOIN dbo.Asientos s ON s.AutobusID = v.AutobusID
WHERE v.Estado = 'Programado'
  AND NOT EXISTS (SELECT 1
                  FROM dbo.Boletos b
                  WHERE b.ViajeID = v.ViajeID
                    AND b.NumeroAsiento = s.NumeroAsiento
                    AND b.Estado = 'Activo');
GO

CREATE OR ALTER VIEW dbo.vw_VentasMensuales
AS
SELECT YEAR(b.FechaVenta)  AS Anio,
       MONTH(b.FechaVenta) AS Mes,
       r.Origen,
       r.Destino,
       COUNT(DISTINCT b.BoletoID) AS Boletos,
       SUM(p.Monto)               AS Ingresos
FROM dbo.Boletos b
JOIN dbo.Pagos   p ON p.BoletoID = b.BoletoID
JOIN dbo.Viajes  v ON v.ViajeID  = b.ViajeID
JOIN dbo.Rutas   r ON r.RutaID   = v.RutaID
WHERE b.Estado = 'Activo'
GROUP BY YEAR(b.FechaVenta), MONTH(b.FechaVenta), r.Origen, r.Destino;
GO

-- ROLES Y USUARIOS
IF DATABASE_PRINCIPAL_ID('rol_taquilla') IS NULL CREATE ROLE rol_taquilla;
IF DATABASE_PRINCIPAL_ID('rol_reportes') IS NULL CREATE ROLE rol_reportes;
IF DATABASE_PRINCIPAL_ID('rol_admin')    IS NULL CREATE ROLE rol_admin;
GO

IF DATABASE_PRINCIPAL_ID('usr_taquilla') IS NULL CREATE USER usr_taquilla WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_reportes') IS NULL CREATE USER usr_reportes WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_admin')    IS NULL CREATE USER usr_admin    WITHOUT LOGIN;
GO

ALTER ROLE rol_taquilla ADD MEMBER usr_taquilla;
ALTER ROLE rol_reportes ADD MEMBER usr_reportes;
ALTER ROLE rol_admin    ADD MEMBER usr_admin;
GO

-- PERMISOS
GRANT EXECUTE ON OBJECT::dbo.sp_VenderBoleto         TO rol_taquilla;
GRANT EXECUTE ON OBJECT::dbo.sp_AnularBoleto         TO rol_taquilla;
GRANT SELECT  ON OBJECT::dbo.vw_AsientosDisponibles  TO rol_taquilla;


GRANT SELECT ON OBJECT::dbo.vw_VentasMensuales TO rol_reportes;
DENY  SELECT ON OBJECT::dbo.Clientes (Email, Telefono) TO rol_reportes;

GRANT CONTROL ON DATABASE::BusRD TO rol_admin;
GO

-- MATRIZ DE PERMISOS
SELECT r.name AS Rol, m.name AS Miembro
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'rol[_]%'
ORDER BY r.name;

-- Permisos concedidos y denegados
SELECT pr.name AS Principal,
       pe.state_desc AS Estado,
       pe.permission_name AS Permiso,
       COALESCE(OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id), DB_NAME()) AS Objeto,
       c.name AS Columna
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
LEFT JOIN sys.columns c ON c.object_id = pe.major_id
                       AND c.column_id = pe.minor_id
                       AND pe.minor_id > 0
WHERE pr.name IN ('rol_taquilla', 'rol_reportes', 'rol_admin')
ORDER BY pr.name, Objeto, pe.permission_name;
GO

-- PRUEBAS USUARIO TAQUILLA
DECLARE @ViajeID INT, @AutobusID INT, @Asiento INT, @Monto DECIMAL(10,2), @BoletoID INT;

-- Como dbo: viaje programado, su autobus y el precio de su ruta
SELECT TOP 1 @ViajeID = v.ViajeID, @AutobusID = v.AutobusID, @Monto = r.PrecioBase
FROM dbo.Viajes v JOIN dbo.Rutas r ON r.RutaID = v.RutaID
WHERE v.Estado = 'Programado' ORDER BY v.ViajeID;
SELECT TOP 1 @Asiento = NumeroAsiento
FROM dbo.vw_AsientosDisponibles WHERE ViajeID = @ViajeID ORDER BY NumeroAsiento DESC;

EXECUTE AS USER = 'usr_taquilla';
SELECT USER_NAME() AS UsuarioActual;
BEGIN TRY
    SELECT TOP 10 * FROM dbo.vw_AsientosDisponibles
    WHERE ViajeID = @ViajeID ORDER BY NumeroAsiento;


    EXEC dbo.sp_VenderBoleto @ViajeID = @ViajeID, @NumeroAsiento = @Asiento,
         @AutobusID = @AutobusID, @ClienteID = 1, @Canal = 'Taquilla',
         @MetodoPago = 'Efectivo', @Monto = @Monto,
         @BoletoID = @BoletoID OUTPUT;
    SELECT @BoletoID AS BoletoVendido;

  
    EXEC dbo.sp_AnularBoleto @BoletoID = @BoletoID;
    SELECT 'Boleto anulado' AS Resultado, @BoletoID AS BoletoID;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO


EXECUTE AS USER = 'usr_taquilla';
SELECT USER_NAME() AS UsuarioActual;
BEGIN TRY
    EXEC (N'SELECT TOP 5 * FROM dbo.Clientes');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO


EXECUTE AS USER = 'usr_taquilla';
BEGIN TRY
    EXEC (N'SELECT TOP 5 * FROM dbo.Boletos');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO


EXECUTE AS USER = 'usr_taquilla';
BEGIN TRY
    EXEC (N'DELETE FROM dbo.Boletos WHERE BoletoID = 1');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO

-- PRUEBAS USUARIO REPORTES
EXECUTE AS USER = 'usr_reportes';
SELECT USER_NAME() AS UsuarioActual;

SELECT TOP 10 * FROM dbo.vw_VentasMensuales ORDER BY Anio DESC, Mes DESC, Origen, Destino;

SELECT SUM(Ingresos) AS IngresosTotales, SUM(Boletos) AS BoletosTotales FROM dbo.vw_VentasMensuales;
REVERT;
GO


EXECUTE AS USER = 'usr_reportes';
SELECT USER_NAME() AS UsuarioActual;
BEGIN TRY
    EXEC (N'SELECT TOP 5 Email, Telefono FROM dbo.Clientes');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO


EXECUTE AS USER = 'usr_reportes';
BEGIN TRY
    EXEC (N'SELECT TOP 5 * FROM dbo.Boletos');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO


EXECUTE AS USER = 'usr_reportes';
BEGIN TRY
    DECLARE @id INT;
    EXEC dbo.sp_VenderBoleto @ViajeID = 1, @NumeroAsiento = 1, @AutobusID = 1,
         @ClienteID = 1, @Canal = 'Web', @MetodoPago = 'Tarjeta', @Monto = 500,
         @BoletoID = @id OUTPUT;
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO

-- PRUEBAS USUARIO ADMIN
EXECUTE AS USER = 'usr_admin';
SELECT USER_NAME() AS UsuarioActual;

SELECT COUNT(*) AS TotalBoletos FROM dbo.Boletos;

SELECT TOP 5 ClienteID, Nombre, Apellido, Email, Telefono FROM dbo.Clientes;
REVERT;
GO


EXECUTE AS USER = 'usr_admin';
BEGIN TRY
    EXEC (N'CREATE LOGIN login_de_prueba WITH PASSWORD = ''Prueba#2026Segura''');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO

EXECUTE AS USER = 'usr_admin';
BEGIN TRY
    EXEC (N'CREATE DATABASE BD_Prueba_Admin');
END TRY
BEGIN CATCH
    SELECT 'DENEGADO' AS Resultado, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO

-- CADENA DE PROPIEDAD (OWNERSHIP CHAINING)
SELECT s.name AS Esquema, p.name AS PropietarioDelEsquema
FROM sys.schemas s
JOIN sys.database_principals p ON p.principal_id = s.principal_id
WHERE s.name = 'dbo';

SELECT o.name AS Objeto, o.type_desc AS Tipo,
       SCHEMA_NAME(o.schema_id) AS Esquema,
       ISNULL(USER_NAME(o.principal_id), 'mismo dueño que el esquema') AS Propietario
FROM sys.objects o
WHERE o.name IN ('Boletos', 'Pagos', 'Clientes',
                 'sp_VenderBoleto', 'sp_AnularBoleto',
                 'vw_AsientosDisponibles', 'vw_VentasMensuales')
ORDER BY o.type_desc, o.name;
GO
