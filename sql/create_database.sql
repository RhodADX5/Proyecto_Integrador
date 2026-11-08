-- =============================================
-- 1. Creación de la base de datos
-- =============================================
IF DB_ID('EmpresaDB') IS NULL
BEGIN
    CREATE DATABASE EmpresaDB;
END;
GO

PRINT 'Base de datos EmpresaDB lista.';
GO
