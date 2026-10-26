USE BusRD;
GO

CREATE OR ALTER PROCEDURE dbo.sp_VenderBoleto
    @ViajeID INT,
    @AsientoID INT,
    @ClienteID INT,
    @Canal VARCHAR(20),
    @MetodoPago VARCHAR(20),
    @Monto DECIMAL(10,2),
    @BoletoID INT OUTPUT,
    @SimularDemora BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @BoletoID = NULL;

    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        -- Validar viaje programado.
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Viajes
            WHERE ViajeID = @ViajeID
              AND Estado = 'Programado'
        )
            THROW 50010, 'El viaje no existe o no esta programado.', 1;

        -- Validar asiento del autobus asignado al viaje.
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Viajes V
            INNER JOIN dbo.Asientos A
                ON A.AutobusID = V.AutobusID
            WHERE V.ViajeID = @ViajeID
              AND A.AsientoID = @AsientoID
        )
            THROW 50011, 'El asiento no pertenece al autobus del viaje.', 1;

        -- Validar cliente.
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Clientes
            WHERE ClienteID = @ClienteID
        )
            THROW 50012, 'El cliente no existe.', 1;

        -- Validar canal y metodo de pago.
        IF @Canal IS NULL
           OR @Canal NOT IN ('Taquilla', 'Web', 'App')
            THROW 50013, 'Canal de venta no valido.', 1;

        IF @MetodoPago IS NULL
           OR @MetodoPago NOT IN
              ('Efectivo', 'Tarjeta', 'Transferencia')
            THROW 50014, 'Metodo de pago no valido.', 1;

        IF @Monto IS NULL OR @Monto <= 0
            THROW 50015, 'El monto debe ser mayor que cero.', 1;

        -- Impedir la doble venta del asiento.
        IF EXISTS (
            SELECT 1
            FROM dbo.Boletos WITH (UPDLOCK, HOLDLOCK)
            WHERE ViajeID = @ViajeID
              AND AsientoID = @AsientoID
              AND Estado = 'Vendido'
        )
            THROW 50016, 'El asiento ya esta vendido.', 1;

        -- Demora opcional para probar concurrencia.
        IF @SimularDemora = 1
            WAITFOR DELAY '00:00:10';

        -- Insertar boleto.
        INSERT INTO dbo.Boletos
            (ViajeID, AsientoID, ClienteID, Estado, FechaVenta)
        VALUES
            (@ViajeID, @AsientoID, @ClienteID,
             'Vendido', SYSDATETIME());

        SET @BoletoID = CONVERT(INT, SCOPE_IDENTITY());

        -- Registrar pago en la misma transaccion.
        INSERT INTO dbo.Pagos
            (BoletoID, Monto, Canal, MetodoPago,
             Estado, FechaPago)
        VALUES
            (@BoletoID, @Monto, @Canal, @MetodoPago,
             'Aprobado', SYSDATETIME());

        COMMIT TRANSACTION;

        SELECT @BoletoID AS BoletoID,
               'Venta realizada correctamente' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @BoletoID = NULL;
        THROW;
    END CATCH;
END;
GO
