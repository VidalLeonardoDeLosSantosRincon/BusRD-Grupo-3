USE BusRD;
GO

/* E1.1: evidencia previa a cualquier limpieza. */
SELECT 
    ViajeID, 
    NumeroAsiento, 
    COUNT(*) AS ActivosDuplicados
FROM dbo.Boletos
WHERE Estado='Activo'
GROUP BY ViajeID, NumeroAsiento
HAVING COUNT(*)>1
ORDER BY ActivosDuplicados DESC, ViajeID, NumeroAsiento;

SELECT 
    b.BoletoID,
    b.ViajeID,
    b.NumeroAsiento,
    b.ClienteID,
    b.FechaVenta,
    b.Estado
FROM dbo.Boletos b
JOIN (SELECT ViajeID,NumeroAsiento FROM dbo.Boletos
      WHERE Estado='Activo' GROUP BY ViajeID,NumeroAsiento HAVING COUNT(*)>1) d
 ON d.ViajeID = b.ViajeID AND d.NumeroAsiento = b.NumeroAsiento
WHERE b.Estado='Activo'
ORDER BY b.ViajeID,b.NumeroAsiento,b.FechaVenta,b.BoletoID;

SELECT 
    p.PagoID,
    p.BoletoID,
    p.Monto,
    p.Metodo,
    p.FechaPago
FROM dbo.Pagos p LEFT JOIN dbo.Boletos b ON b.BoletoID = p.BoletoID
WHERE b.BoletoID IS NULL ORDER BY p.PagoID;

/* Diagnosticos preventivos de restricciones y relaciones. */
SELECT Cedula,COUNT(*) Repeticiones FROM dbo.Clientes GROUP BY Cedula HAVING COUNT(*)>1;

SELECT Placa,COUNT(*) Repeticiones FROM dbo.Autobuses GROUP BY Placa HAVING COUNT(*)>1;

SELECT 
    b.BoletoID,
    b.ViajeID,
    b.NumeroAsiento
FROM dbo.Boletos b
LEFT JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID
LEFT JOIN dbo.Asientos a ON a.AutobusID=v.AutobusID AND a.NumeroAsiento=b.NumeroAsiento
WHERE v.ViajeID IS NULL OR a.AutobusID IS NULL;

SELECT 'Boletos: estado/canal/precio' AS Problema,COUNT(*) AS Casos
FROM dbo.Boletos WHERE Estado NOT IN ('Activo','Anulado') OR Canal NOT IN ('Taquilla','Web') OR Precio<=0;

SELECT 'Pagos: metodo/monto' AS Problema,COUNT(*) AS Casos
FROM dbo.Pagos WHERE Metodo NOT IN ('Efectivo','Tarjeta','Transferencia') OR Monto<=0;

SELECT 'Autobuses: tipo/capacidad' AS Problema,COUNT(*) AS Casos
FROM dbo.Autobuses WHERE (Tipo='Estandar' AND Capacidad<>44)
 OR (Tipo='Ejecutivo' AND Capacidad<>32) OR Tipo NOT IN ('Estandar','Ejecutivo');
GO

-- LIMPIEZA Y AUDITORIA
USE BusRD;
GO
/* E1.2. Ejecutar UNA VEZ tras 04. Conserva evidencia.
   No hace devoluciones bancarias: los pagos duplicados quedan pendientes. */
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.E1_PagosHuerfanosAudit','U') IS NULL
BEGIN
 CREATE TABLE dbo.E1_PagosHuerfanosAudit(
  PagoID INT NOT NULL PRIMARY KEY, 
  BoletoID INT NOT NULL,
  Monto DECIMAL(10,2) NOT NULL, 
  Metodo VARCHAR(15) NOT NULL,
  FechaPago DATETIME2(0) NOT NULL,
  FechaDeteccion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  Accion VARCHAR(100) NOT NULL DEFAULT 'Separado para revision administrativa'
 );
END;
GO

IF OBJECT_ID('dbo.E1_BoletosAnuladosAudit','U') IS NULL
BEGIN
 CREATE TABLE dbo.E1_BoletosAnuladosAudit(
  BoletoID INT NOT NULL PRIMARY KEY, 
  ViajeID INT NOT NULL,
  NumeroAsiento INT NOT NULL, 
  FechaVenta DATETIME2(0) NOT NULL,
  BoletoConservadoID INT NOT NULL,
  FechaCorreccion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  Motivo VARCHAR(150) NOT NULL
 );
END;
GO

IF COL_LENGTH('dbo.Pagos','Estado') IS NULL
 ALTER TABLE dbo.Pagos ADD Estado VARCHAR(20) NOT NULL
 CONSTRAINT DF_Pagos_Estado DEFAULT ('Aplicado');
GO

BEGIN TRY
 BEGIN TRAN;

 /* Archivar y retirar los 15 pagos sin boleto para permitir FK. */
 INSERT dbo.E1_PagosHuerfanosAudit(
    PagoID,
    BoletoID,
    Monto,
    Metodo,
    FechaPago
 )
 SELECT 
    p.PagoID,
    p.BoletoID,
    p.Monto,
    p.Metodo,
    p.FechaPago
 FROM dbo.Pagos p 
 LEFT JOIN dbo.Boletos b ON b.BoletoID = p.BoletoID
 WHERE b.BoletoID IS NULL
 AND NOT EXISTS(SELECT 1 FROM dbo.E1_PagosHuerfanosAudit x WHERE x.PagoID = p.PagoID);

 DELETE p FROM dbo.Pagos p
 LEFT JOIN dbo.Boletos b ON b.BoletoID = p.BoletoID
 WHERE b.BoletoID IS NULL;

 /* La venta mas antigua conserva el asiento. BoletoID desempata fechas. */
 ;WITH Orden AS(
  SELECT 
    BoletoID,
    ViajeID,
    NumeroAsiento,
    FechaVenta,
    FIRST_VALUE(BoletoID) OVER(PARTITION BY ViajeID,NumeroAsiento
       ORDER BY FechaVenta,BoletoID) AS BoletoConservadoID,
    ROW_NUMBER() OVER(PARTITION BY ViajeID,NumeroAsiento
       ORDER BY FechaVenta,BoletoID) AS rn
  FROM dbo.Boletos WHERE Estado='Activo'
 )
 INSERT dbo.E1_BoletosAnuladosAudit
 (
    BoletoID,
    ViajeID,
    NumeroAsiento,
    FechaVenta,
    BoletoConservadoID,
    Motivo
 )
 SELECT 
    BoletoID,
    ViajeID,
    NumeroAsiento,
    FechaVenta,
    BoletoConservadoID,
    'Duplicado activo: se conserva la primera venta'
 FROM Orden WHERE rn > 1
 AND NOT EXISTS(
    SELECT 1 FROM dbo.E1_BoletosAnuladosAudit a WHERE a.BoletoID = Orden.BoletoID
 );

 UPDATE b SET Estado='Anulado'
 FROM dbo.Boletos b JOIN dbo.E1_BoletosAnuladosAudit a ON a.BoletoID=b.BoletoID
 WHERE b.Estado='Activo';

 UPDATE p SET Estado = 'ReembolsoPendiente'
 FROM dbo.Pagos p JOIN dbo.E1_BoletosAnuladosAudit a ON a.BoletoID=p.BoletoID
 WHERE p.Estado = 'Aplicado';

 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO

SELECT * FROM dbo.E1_BoletosAnuladosAudit ORDER BY BoletoID;

SELECT * FROM dbo.E1_PagosHuerfanosAudit ORDER BY PagoID;

SELECT p.* FROM dbo.Pagos p WHERE p.Estado = 'ReembolsoPendiente';
GO

-- RESTRICCIONES
USE BusRD;
GO
/* E1.3 y E1.4. Ejecutar DESPUES de limpieza.
   Se usan WITH CHECK para validar datos ya existentes. */
SET XACT_ABORT ON;
GO

/* La FK compuesta garantiza que el asiento pertenece al autobus del viaje. */
IF COL_LENGTH('dbo.Boletos','AutobusID') IS NULL
 ALTER TABLE dbo.Boletos ADD AutobusID INT NULL;
GO

UPDATE b SET AutobusID=v.AutobusID
FROM dbo.Boletos b JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID
WHERE b.AutobusID IS NULL;
GO

IF EXISTS(SELECT 1 FROM dbo.Boletos WHERE AutobusID IS NULL)
 THROW 51000,'Hay boletos sin viaje valido; corregir antes de crear FK',1;

IF EXISTS(SELECT 1 FROM dbo.Boletos b LEFT JOIN dbo.Asientos a
 ON a.AutobusID=b.AutobusID AND a.NumeroAsiento=b.NumeroAsiento
 WHERE a.AutobusID IS NULL)
 THROW 51001,'Hay boletos con asiento fuera del autobus; corregir',1;

IF EXISTS(SELECT 1 FROM dbo.Boletos b LEFT JOIN dbo.Clientes c ON c.ClienteID=b.ClienteID
 WHERE c.ClienteID IS NULL)
 THROW 51002,'Hay boletos con cliente inexistente',1;

IF EXISTS(SELECT 1 FROM dbo.Viajes v LEFT JOIN dbo.Rutas r ON r.RutaID=v.RutaID
 WHERE r.RutaID IS NULL)
 THROW 51003,'Hay viajes con ruta inexistente',1;

IF EXISTS(SELECT 1 FROM dbo.Viajes v LEFT JOIN dbo.Autobuses a ON a.AutobusID=v.AutobusID
 WHERE a.AutobusID IS NULL)
 THROW 51004,'Hay viajes con autobus inexistente',1;
GO

ALTER TABLE dbo.Boletos ALTER COLUMN AutobusID INT NOT NULL;
GO

ALTER TABLE dbo.Viajes ADD CONSTRAINT UQ_Viajes_ViajeAutobus UNIQUE(ViajeID,AutobusID);

ALTER TABLE dbo.Viajes WITH CHECK ADD CONSTRAINT FK_Viajes_Rutas
 FOREIGN KEY(RutaID) REFERENCES dbo.Rutas(RutaID);

ALTER TABLE dbo.Viajes WITH CHECK ADD CONSTRAINT FK_Viajes_Autobuses
 FOREIGN KEY(AutobusID) REFERENCES dbo.Autobuses(AutobusID);

ALTER TABLE dbo.Asientos WITH CHECK ADD CONSTRAINT FK_Asientos_Autobuses
 FOREIGN KEY(AutobusID) REFERENCES dbo.Autobuses(AutobusID);

ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT FK_Boletos_Clientes
 FOREIGN KEY(ClienteID) REFERENCES dbo.Clientes(ClienteID);

ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT FK_Boletos_ViajeAutobus
 FOREIGN KEY(ViajeID,AutobusID) REFERENCES dbo.Viajes(ViajeID,AutobusID);

ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT FK_Boletos_AsientoAutobus
 FOREIGN KEY(AutobusID,NumeroAsiento) REFERENCES dbo.Asientos(AutobusID,NumeroAsiento);

ALTER TABLE dbo.Pagos WITH CHECK ADD CONSTRAINT FK_Pagos_Boletos
 FOREIGN KEY(BoletoID) REFERENCES dbo.Boletos(BoletoID);
GO

ALTER TABLE dbo.Autobuses ADD CONSTRAINT CK_Autobuses_TipoCapacidad
 CHECK ((Tipo='Estandar' AND Capacidad=44) OR (Tipo='Ejecutivo' AND Capacidad=32));

ALTER TABLE dbo.Viajes ADD CONSTRAINT CK_Viajes_Estado
 CHECK (Estado IN ('Programado','Completado','Cancelado'));

ALTER TABLE dbo.Boletos ADD CONSTRAINT CK_Boletos_Estado
 CHECK (Estado IN ('Activo','Anulado'));

ALTER TABLE dbo.Boletos ADD CONSTRAINT CK_Boletos_Canal
 CHECK (Canal IN ('Taquilla','Web'));

ALTER TABLE dbo.Boletos ADD CONSTRAINT CK_Boletos_Precio CHECK (Precio>0);

ALTER TABLE dbo.Pagos ADD CONSTRAINT CK_Pagos_Metodo
 CHECK (Metodo IN ('Efectivo','Tarjeta','Transferencia'));

ALTER TABLE dbo.Pagos ADD CONSTRAINT CK_Pagos_Monto CHECK (Monto>0);

ALTER TABLE dbo.Pagos ADD CONSTRAINT CK_Pagos_Estado
 CHECK (Estado IN ('Aplicado','ReembolsoPendiente','Reembolsado'));

ALTER TABLE dbo.Rutas ADD CONSTRAINT CK_Rutas_DistanciaPrecio
 CHECK (DistanciaKm>0 AND PrecioBase>0);

ALTER TABLE dbo.Asientos ADD CONSTRAINT CK_Asientos_Numero
 CHECK (NumeroAsiento BETWEEN 1 AND 44);
GO

ALTER TABLE dbo.Clientes ADD CONSTRAINT UQ_Clientes_Cedula UNIQUE(Cedula);

ALTER TABLE dbo.Autobuses ADD CONSTRAINT UQ_Autobuses_Placa UNIQUE(Placa);
GO

/* E1.4: SQL Server solo permite una venta ACTIVA por viaje/asiento. */
CREATE UNIQUE NONCLUSTERED INDEX UX_Boletos_Activo_ViajeAsiento
ON dbo.Boletos(ViajeID,NumeroAsiento)
WHERE Estado='Activo';
GO

/* Comprobacion de confianza de restricciones */
SELECT name,is_disabled,is_not_trusted FROM sys.foreign_keys;
SELECT name,is_disabled,is_not_trusted FROM sys.check_constraints;
GO

-- PRUEBAS E1
USE BusRD;
GO

/* Verificacion final: deben salir cero filas. */
SELECT 
    ViajeID,
    NumeroAsiento,
    COUNT(*) AS Activos
FROM dbo.Boletos 
WHERE Estado = 'Activo'
GROUP BY ViajeID, NumeroAsiento 
HAVING COUNT(*)>1;

SELECT p.* 
FROM dbo.Pagos p 
LEFT JOIN dbo.Boletos b ON b.BoletoID=p.BoletoID
WHERE b.BoletoID IS NULL;

/* Comprobar que un asiento anulado queda disponible */
SELECT 
    TOP(10) b.ViajeID,
    b.NumeroAsiento,
    SUM(CASE WHEN b.Estado='Activo' THEN 1 ELSE 0 END) AS Activos,
    SUM(CASE WHEN b.Estado='Anulado' THEN 1 ELSE 0 END) AS Anulados
FROM dbo.Boletos b 
GROUP BY b.ViajeID, b.NumeroAsiento
HAVING SUM(CASE WHEN b.Estado='Anulado' THEN 1 ELSE 0 END) > 0
ORDER BY b.ViajeID;

/* Pruebas negativas en transaccion reversible (ejecutar por separado).
BEGIN TRY
 BEGIN TRAN;
 INSERT dbo.Boletos(ViajeID,AutobusID,NumeroAsiento,ClienteID,FechaVenta,Canal,Precio,Estado)
 SELECT TOP(1) ViajeID,AutobusID,NumeroAsiento,ClienteID,SYSDATETIME(),Canal,Precio,'Activo'
 FROM dbo.Boletos WHERE Estado='Activo';
 ROLLBACK;
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 SELECT ERROR_NUMBER() AS CodigoError,ERROR_MESSAGE() AS Mensaje;
END CATCH;
*/
GO
