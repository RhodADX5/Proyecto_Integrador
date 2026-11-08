-- =============================================
-- 7. Consulta del reporte CSV (workflow programado)
-- Una fila por venta con su auditoría y la existencia actual del producto.
-- =============================================
-- Se ejecuta con: sqlcmd -d EmpresaDB (sin USE, para que el mensaje
-- "Changed database context" no se cuele en el CSV).
SET NOCOUNT ON;

SELECT v.VentaID,
       v.Producto,
       v.Cantidad,
       CONVERT(VARCHAR(19), v.Fecha, 120)          AS FechaVenta,
       a.AuditoriaID,
       CONVERT(VARCHAR(19), a.FechaRegistro, 120)  AS FechaAuditoria,
       i.Existencia                                AS ExistenciaActual
  FROM Ventas v
  LEFT JOIN AuditoriaVentas a ON a.VentaID  = v.VentaID
  LEFT JOIN Inventario      i ON i.Producto = v.Producto
 ORDER BY v.VentaID;
