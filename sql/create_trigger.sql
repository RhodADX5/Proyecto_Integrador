-- =============================================
-- 4. Trigger
-- =============================================
USE EmpresaDB;
GO

/*
  Versión original (NO soporta inserciones múltiples):

    CREATE TRIGGER trg_AuditarVenta ON Ventas AFTER INSERT AS
    BEGIN
      DECLARE @VentaID INT;
      SELECT @VentaID = VentaID FROM inserted;   -- solo se queda con UNA fila
      EXEC sp_RegistrarAuditoria @VentaID;
    END;

  En SQL Server un trigger se ejecuta UNA vez por sentencia, no por fila.
  Si un INSERT agrega 3 filas, la tabla lógica "inserted" tiene 3 filas, pero
  la variable escalar @VentaID solo guarda una de ellas, así que solo se
  audita una venta y se pierden las otras dos.

  Versión corregida (por conjuntos): copia todas las filas de "inserted" a
  una variable de tipo tabla y las manda juntas al procedimiento.
*/
CREATE OR ALTER TRIGGER trg_AuditarVenta
ON Ventas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Un INSERT que no agregó filas también dispara el trigger
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @Ventas dbo.TipoVentas;

    INSERT INTO @Ventas(VentaID, Producto, Cantidad)
    SELECT VentaID, Producto, Cantidad
      FROM inserted;

    EXEC sp_RegistrarAuditoriaLote @Ventas = @Ventas;
END;
GO

PRINT 'Trigger trg_AuditarVenta (por conjuntos) creado.';
GO
