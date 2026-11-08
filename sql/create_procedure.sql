-- =============================================
-- 3. Procedimientos almacenados
-- =============================================
USE EmpresaDB;
GO

-- ---------------------------------------------
-- 3.1 Versión original (fila a fila)
-- Recibe UN solo VentaID. Se conserva para comparar con la versión por
-- conjuntos y para registrar una venta manualmente. Ya incluye la
-- actualización de inventario del reto avanzado.
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sp_RegistrarAuditoria
    @VentaID INT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AuditoriaVentas(VentaID, Mensaje)
    VALUES(@VentaID, 'Venta registrada automáticamente');

    UPDATE i
       SET i.Existencia          = i.Existencia - v.Cantidad,
           i.UltimaActualizacion = GETDATE()
      FROM Inventario AS i
      JOIN Ventas     AS v ON v.Producto = i.Producto
     WHERE v.VentaID = @VentaID;
END;
GO

-- ---------------------------------------------
-- 3.2 Versión por conjuntos (set-based)
-- Un tipo de tabla permite pasar TODAS las filas insertadas al
-- procedimiento en una sola llamada (Table-Valued Parameter).
-- ---------------------------------------------
IF TYPE_ID('dbo.TipoVentas') IS NULL
    CREATE TYPE dbo.TipoVentas AS TABLE(
        VentaID  INT PRIMARY KEY,
        Producto VARCHAR(100),
        Cantidad INT
    );
GO

CREATE OR ALTER PROCEDURE sp_RegistrarAuditoriaLote
    @Ventas dbo.TipoVentas READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- Una fila de auditoría por cada venta, en una sola sentencia
    INSERT INTO AuditoriaVentas(VentaID, Mensaje)
    SELECT VentaID, 'Venta registrada automáticamente'
      FROM @Ventas;

    -- Reto avanzado: descontar existencias.
    -- Se agrupa por producto para que, si llegan varias ventas del mismo
    -- producto en el mismo INSERT, se descuente la suma una sola vez.
    UPDATE i
       SET i.Existencia          = i.Existencia - s.Total,
           i.UltimaActualizacion = GETDATE()
      FROM Inventario AS i
      JOIN (SELECT Producto, SUM(Cantidad) AS Total
              FROM @Ventas
             GROUP BY Producto) AS s
        ON s.Producto = i.Producto;
END;
GO

PRINT 'Procedimientos sp_RegistrarAuditoria y sp_RegistrarAuditoriaLote creados.';
GO
