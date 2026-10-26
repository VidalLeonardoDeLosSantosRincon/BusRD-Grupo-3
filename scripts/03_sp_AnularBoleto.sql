USE BusRD;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AnularBoleto
    @BoletoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Bloquear y comprobar el boleto.
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Boletos WITH (UPDLOCK, HOLDLOCK)
            WHERE BoletoID = @BoletoID
              AND Estado = 'Activo'
        )
            THROW 50020, 'El boleto no existe o ya fue anulado.', 1;

        -- Registrar el reverso con monto negativo.
        INSERT INTO dbo.Pagos
            (BoletoID, Monto, Metodo,
             Estado, FechaPago)
        SELECT
            BoletoID,
            Monto,
            Metodo,
            'Reversado',
            SYSDATETIME()
        FROM dbo.Pagos
        WHERE BoletoID = @BoletoID
          AND Estado = 'Aprobado';

        IF @@ROWCOUNT = 0
            THROW 50021, 'No existe un pago aprobado para reversar.', 1;

        -- Cambiar el estado del boleto.
        UPDATE dbo.Boletos
        SET Estado = 'Anulado'
        WHERE BoletoID = @BoletoID
          AND Estado = 'Activo';

        COMMIT TRANSACTION;

        SELECT @BoletoID AS BoletoID,
               'Boleto anulado y pago reversado' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
