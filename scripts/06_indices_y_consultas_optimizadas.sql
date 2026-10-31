USE BusRD;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

/* C1 - Pantalla de taquilla: asientos disponibles de un viaje */
DROP INDEX IF EXISTS IX_Viajes_AutobusID ON dbo.Viajes;
GO

DROP INDEX IF EXISTS IX_Asientos_NumeroAsiento ON dbo.Asientos;
GO

DROP INDEX IF EXISTS IX_Boletos_ViajeID_Estado_NumeroAsiento_AutobusID ON dbo.Boletos;
GO

CREATE NONCLUSTERED INDEX IX_Viajes_AutobusID
ON dbo.Viajes (AutobusID);
GO

CREATE NONCLUSTERED INDEX IX_Asientos_NumeroAsiento
ON dbo.Asientos (NumeroAsiento) INCLUDE(Ubicacion);
GO

CREATE NONCLUSTERED INDEX IX_Boletos_ViajeID_Estado_NumeroAsiento_AutobusID
ON dbo.Boletos (ViajeID, Estado, NumeroAsiento, AutobusID);
GO

DECLARE @ViajeID INT = 3000;
SELECT 
	s.NumeroAsiento, 
	s.Ubicacion
FROM dbo.Viajes v
JOIN dbo.Asientos s ON s.AutobusID = v.AutobusID
WHERE v.ViajeID = @ViajeID
  AND NOT EXISTS (SELECT 1
					FROM dbo.Boletos b
					WHERE b.ViajeID = @ViajeID
					AND b.Estado = 'Activo'
					AND b.NumeroAsiento = s.NumeroAsiento
					AND b.AutobusID = s.AutobusID)
ORDER BY s.NumeroAsiento;
GO


/* C2 - Historial de viajes de un cliente por cédula */
DROP INDEX IF EXISTS IX_Clientes_Cedula ON dbo.Clientes;
GO

DROP INDEX IF EXISTS IX_Boleto_ClienteID ON dbo.Boletos;
GO

DROP INDEX IF EXISTS IX_Boleto_ViajeID ON dbo.Boletos;
GO

DROP INDEX IF EXISTS IX_Viajes_RutaID_FechaSalida ON dbo.Viajes;
GO

CREATE NONCLUSTERED INDEX IX_Clientes_Cedula 
ON dbo.Clientes (Cedula) INCLUDE (Apellido, Nombre);
GO

CREATE NONCLUSTERED INDEX IX_Boleto_ClienteID 
ON dbo.Boletos (ClienteID) INCLUDE (ViajeID, NumeroAsiento, Precio, Estado);
GO

CREATE NONCLUSTERED INDEX IX_Boleto_ViajeID 
ON dbo.Boletos (ViajeID) INCLUDE (ClienteID, NumeroAsiento, Precio, Estado);
GO

CREATE NONCLUSTERED INDEX IX_Viajes_RutaID_FechaSalida 
ON dbo.Viajes(RutaID, FechaSalida);
GO

UPDATE dbo.Clientes
SET Cedula = LTRIM(RTRIM(Cedula))
WHERE Cedula LIKE ' %' OR Cedula LIKE '% ';

DECLARE @ClienteID INT = 3000;
DECLARE @Cedula CHAR(11)

SELECT @Cedula = Cedula From dbo.Clientes WHERE ClienteID = @ClienteID;

SELECT 
	c.Nombre, 
	c.Apellido, 
	r.Origen, 
	r.Destino,
    v.FechaSalida, 
	b.NumeroAsiento, 
	b.Precio, 
	b.Estado
FROM dbo.Clientes c
JOIN dbo.Boletos b ON b.ClienteID = c.ClienteID
JOIN dbo.Viajes  v ON v.ViajeID   = b.ViajeID
JOIN dbo.Rutas   r ON r.RutaID    = v.RutaID
WHERE c.Cedula = @Cedula
ORDER BY v.FechaSalida DESC;
GO


/* C3 - Reporte mensual de ingresos por ruta (año 2025) */
DROP INDEX IF EXISTS IX_Boletos_Estado_FechaVenta ON dbo.Boletos;
GO

DROP INDEX IF EXISTS IX_Pagos_BoletoID ON dbo.Pagos;
GO

DROP INDEX IF EXISTS IX_Viajes_RutaID ON dbo.Viajes;
GO

DROP INDEX IF EXISTS IX_Rutas_Origen_Destino ON dbo.Rutas;
GO

CREATE NONCLUSTERED INDEX IX_Boletos_Estado_FechaVenta 
ON dbo.Boletos (Estado, FechaVenta) INCLUDE (ViajeID);
GO

CREATE NONCLUSTERED INDEX IX_Pagos_BoletoID
ON dbo.Pagos (BoletoID) INCLUDE (Monto);
GO

CREATE NONCLUSTERED INDEX IX_Viajes_RutaID
ON dbo.Viajes(RutaID);
GO

CREATE NONCLUSTERED INDEX IX_Rutas_Origen_Destino
ON dbo.Rutas (Origen, Destino);
GO

SELECT 
	  r.Origen, 
	  r.Destino, 
	  MONTH(b.FechaVenta) AS Mes,
      COUNT(b.BoletoID) AS Boletos, 
	  SUM(p.Monto) AS Ingresos
FROM dbo.Boletos b
JOIN dbo.Pagos  p ON p.BoletoID = b.BoletoID
JOIN dbo.Viajes v ON v.ViajeID  = b.ViajeID
JOIN dbo.Rutas  r ON r.RutaID   = v.RutaID
WHERE b.Estado = 'Activo'
	AND (b.FechaVenta >= '2025-01-01' AND b.FechaVenta < '2026-01-01')
GROUP BY r.Origen, r.Destino, MONTH(b.FechaVenta)
ORDER BY r.Origen, r.Destino, Mes;
GO
