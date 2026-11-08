-- =============================================
-- 5. Datos de prueba
-- =============================================
USE EmpresaDB;
GO
SET NOCOUNT ON;
GO

-- Existencias iniciales (reto avanzado)
INSERT INTO Inventario(Producto, Existencia) VALUES
    ('Laptop',  50),
    ('Monitor', 80),
    ('Teclado', 100),
    ('Mouse',   120);
GO

-- Inserciones individuales (las del enunciado)
INSERT INTO Ventas(Producto, Cantidad)
VALUES('Laptop', 3);

INSERT INTO Ventas(Producto, Cantidad)
VALUES('Monitor', 5);
GO

-- Reto principal: inserción múltiple en una sola sentencia.
-- Con el trigger original solo se auditaría 1 de estas 3 ventas.
INSERT INTO Ventas(Producto, Cantidad) VALUES
    ('Teclado', 10),
    ('Mouse',   15),
    ('Laptop',  2);
GO

PRINT 'Datos de prueba insertados.';
GO

SELECT * FROM Ventas;
SELECT * FROM AuditoriaVentas;
SELECT * FROM Inventario;
GO
