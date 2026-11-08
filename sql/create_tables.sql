-- =============================================
-- 2. Creación de tablas
-- =============================================
USE EmpresaDB;
GO

-- Tabla de ventas
CREATE TABLE Ventas(
    VentaID  INT IDENTITY(1,1) PRIMARY KEY,
    Producto VARCHAR(100),
    Cantidad INT,
    Fecha    DATETIME DEFAULT GETDATE()
);
GO

-- Tabla de auditoría (la llena el trigger a través del procedimiento)
CREATE TABLE AuditoriaVentas(
    AuditoriaID   INT IDENTITY(1,1) PRIMARY KEY,
    VentaID       INT,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    Mensaje       VARCHAR(255)
);
GO

-- Reto avanzado: tabla de inventario
-- La restricción CHECK impide existencias negativas: si una venta deja el
-- inventario en negativo, falla el UPDATE y se revierte toda la transacción
-- (incluido el INSERT en Ventas que disparó el trigger).
CREATE TABLE Inventario(
    Producto            VARCHAR(100) PRIMARY KEY,
    Existencia          INT NOT NULL,
    UltimaActualizacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT CK_Inventario_Existencia CHECK (Existencia >= 0)
);
GO

PRINT 'Tablas Ventas, AuditoriaVentas e Inventario creadas.';
GO
