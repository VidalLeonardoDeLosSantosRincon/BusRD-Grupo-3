USE BusRD;
GO

DECLARE @ClienteID INT = 3000;
DECLARE @ViajeID INT;
DECLARE @AutobusID INT;
DECLARE @NumeroAsiento INT;

SELECT @ViajeID = ViajeID 
FROM dbo.Viajes 
WHERE Estado = 'Programado' 
ORDER BY ViajeID ASC;

SELECT TOP 1 @AutobusID = AutobusID 
FROM dbo.Viajes WHERE ViajeID = @ViajeID
ORDER BY AutobusID;

SELECT TOP 1 @NumeroAsiento = a.NumeroAsiento FROM dbo.Asientos a
WHERE 1 = 1
AND a.AutobusID = @AutobusID
AND NOT EXISTS (
		SELECT 1 FROM dbo.Boletos b
		WHERE b.ViajeID = @ViajeID
		AND b.NumeroAsiento = a.NumeroAsiento
);

SET @ViajeID = ISNULL(@ViajeID, 0);
SET @AutobusID = ISNULL(@AutobusID, 0);
SET @NumeroAsiento = ISNULL(@NumeroAsiento, 0);

DECLARE @BoletoID INT;

EXEC dbo.sp_VenderBoleto
    @ViajeID = @ViajeID,
    @NumeroAsiento = @NumeroAsiento,
    @AutobusID = @AutobusID,
    @ClienteID = @ClienteID,
    @Canal = 'Taquilla',
    @MetodoPago = 'Efectivo',
    @Monto = 500.00,
    @BoletoID = @BoletoID OUTPUT,
    @SimularDemora = 1;

SELECT @BoletoID AS BoletoIDGenerado;
GO
