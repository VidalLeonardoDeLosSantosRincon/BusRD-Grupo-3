USE BusRD;
GO

DECLARE @BoletoID INT;

EXEC dbo.sp_VenderBoleto
    @ViajeID = 1,
    @NumeroAsiento = 5,
    @ClienteID = 1,
    @Canal = 'Taquilla',
    @MetodoPago = 'Efectivo',
    @Monto = 500.00,
    @BoletoID = @BoletoID OUTPUT,
    @SimularDemora = 0;

SELECT @BoletoID AS BoletoIDGenerado;
GO
