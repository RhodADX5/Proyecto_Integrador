-- =============================================
-- 6. Validaciones automáticas (las ejecuta el workflow)
-- Si una comprobación falla, THROW detiene sqlcmd (-b) y el job falla.
-- =============================================
USE EmpresaDB;
GO
SET NOCOUNT ON;
GO

-- Prueba 1: cada venta tiene exactamente una fila de auditoría
DECLARE @ventas INT = (SELECT COUNT(*) FROM Ventas);
DECLARE @audit  INT = (SELECT COUNT(*) FROM AuditoriaVentas);
DECLARE @sinAud INT = (SELECT COUNT(*) FROM Ventas v
                        WHERE NOT EXISTS (SELECT 1 FROM AuditoriaVentas a WHERE a.VentaID = v.VentaID));

IF @ventas <> 5 OR @audit <> 5 OR @sinAud <> 0
    THROW 50001, 'FALLO: el trigger no auditó todas las ventas (inserción múltiple).', 1;
PRINT 'OK  Prueba 1: 5 ventas y 5 registros de auditoría (inserción múltiple soportada).';
GO

-- Prueba 2: existencias descontadas correctamente
-- Laptop 50-3-2=45, Monitor 80-5=75, Teclado 100-10=90, Mouse 120-15=105
IF EXISTS (
    SELECT 1
      FROM (VALUES ('Laptop',45),('Monitor',75),('Teclado',90),('Mouse',105)) AS e(Producto, Esperado)
      LEFT JOIN Inventario i ON i.Producto = e.Producto
     WHERE i.Existencia IS NULL OR i.Existencia <> e.Esperado)
    THROW 50002, 'FALLO: las existencias del inventario no coinciden con lo esperado.', 1;
PRINT 'OK  Prueba 2: inventario actualizado (Laptop 45, Monitor 75, Teclado 90, Mouse 105).';
GO

-- Prueba 3: una venta mayor a la existencia se rechaza y se revierte completa
DECLARE @antes INT = (SELECT COUNT(*) FROM Ventas);
BEGIN TRY
    INSERT INTO Ventas(Producto, Cantidad) VALUES('Laptop', 1000);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '    Error esperado capturado: ' + ERROR_MESSAGE();
END CATCH;

IF (SELECT COUNT(*) FROM Ventas) <> @antes
   OR (SELECT Existencia FROM Inventario WHERE Producto = 'Laptop') <> 45
    THROW 50003, 'FALLO: una venta sin existencia suficiente no se revirtió.', 1;
PRINT 'OK  Prueba 3: venta sin existencia suficiente rechazada y revertida.';
GO

PRINT 'Todas las validaciones pasaron.';
GO
