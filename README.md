# Proyecto Integrador: GitHub Actions + Docker + Microsoft SQL Server

Automatización del despliegue de una base de datos **Microsoft SQL Server 2022** dentro de un contenedor **Docker**, orquestado por **GitHub Actions**. El workflow crea la base `EmpresaDB`, sus tablas, procedimientos almacenados y un trigger de auditoría. Después inserta datos de prueba y valida automáticamente que todo funcione. La contraseña del usuario `sa` nunca aparece en el código: se lee del secret `MSSQL_SA_PASSWORD`.

Referencia: [jesusrevilla/T41A-P16](https://github.com/jesusrevilla/T41A-P16)

## Estructura

```
proyecto-sqlserver-actions
│
├── .github
│   └── workflows
│       ├── deploy.yml          # CI: despliega y valida en cada push
│       └── report.yml          # Programado: genera un CSV y lo publica como Artifact
│
├── sql
│   ├── create_database.sql     # EmpresaDB
│   ├── create_tables.sql       # Ventas, AuditoriaVentas, Inventario
│   ├── create_procedure.sql    # sp_RegistrarAuditoria, TipoVentas, sp_RegistrarAuditoriaLote
│   ├── create_trigger.sql      # trg_AuditarVenta (soporta inserciones múltiples)
│   ├── test_data.sql           # inventario inicial + ventas individuales y múltiples
│   ├── validate.sql            # pruebas automáticas (fallan el job si algo no cuadra)
│   └── report.sql              # consulta del reporte CSV
│
└── README.md
```

`validate.sql` y `report.sql` son adicionales a la estructura mínima: el primero comprueba los resultados y el segundo alimenta el workflow programado.

## Configuración

1. Crea un repositorio en GitHub (por ejemplo `proyecto-sqlserver-actions`) y sube estos archivos a la rama `main`.
2. Ve a **Settings → Secrets and variables → Actions → New repository secret** y crea:
   - Nombre: `MSSQL_SA_PASSWORD`
   - Valor: `Str0ngP@ssword2026!`
3. Ve a la pestaña **Actions**. El workflow **Deploy SQL Server (Docker)** se ejecuta solo con cada push. También puedes lanzarlo con **Run workflow**.
4. Para el reporte, abre **Reporte programado de ventas (CSV)** y pulsa **Run workflow**. Al terminar, el CSV aparece en la sección **Artifacts** de esa ejecución. Además, el workflow corre solo cada lunes a las 08:00 (hora del centro de México).

Variables de entorno usadas por ambos workflows:

```yaml
env:
  ACCEPT_EULA: Y
  MSSQL_PID: Developer
  SA_PASSWORD: ${{ secrets.MSSQL_SA_PASSWORD }}
```

## Qué hace `deploy.yml`

| Paso | Acción |
| --- | --- |
| Verificar secret | Falla con un mensaje claro si `MSSQL_SA_PASSWORD` no existe |
| Iniciar contenedor | `docker run mcr.microsoft.com/mssql/server:2022-latest` con las variables de entorno |
| Esperar a SQL Server | Reintenta `SELECT @@VERSION` hasta 30 veces (cada 5 s) |
| Ejecutar scripts | `create_database` → `create_tables` → `create_procedure` → `create_trigger` → `test_data` con `sqlcmd -b` (se detiene al primer error) |
| Validar | `validate.sql` comprueba auditoría, inventario y el rechazo de ventas sin existencia |
| Limpiar | Elimina el contenedor aunque algo haya fallado |

La contraseña se pasa a `sqlcmd` con la variable `SQLCMDPASSWORD` en lugar de `-P`, para que no aparezca en la lista de procesos. GitHub enmascara el valor del secret en los logs (`***`).

## Reto principal: trigger para inserciones múltiples

### El problema

```sql
DECLARE @VentaID INT;
SELECT @VentaID = VentaID FROM inserted;   -- solo guarda UNA fila
EXEC sp_RegistrarAuditoria @VentaID;
```

En SQL Server un trigger se ejecuta **una vez por sentencia**, no una vez por fila. Este INSERT dispara el trigger una sola vez con 3 filas:

```sql
INSERT INTO Ventas(Producto, Cantidad) VALUES ('Teclado',10), ('Mouse',15), ('Laptop',2);
```

La variable escalar `@VentaID` se queda con un solo valor, así que solo se audita una venta y se pierden las otras dos.

### La solución (por conjuntos)

```sql
CREATE OR ALTER TRIGGER trg_AuditarVenta ON Ventas AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    DECLARE @Ventas dbo.TipoVentas;              -- variable de tipo tabla
    INSERT INTO @Ventas(VentaID, Producto, Cantidad)
    SELECT VentaID, Producto, Cantidad FROM inserted;

    EXEC sp_RegistrarAuditoriaLote @Ventas = @Ventas;   -- todas las filas en una llamada
END;
```

`sp_RegistrarAuditoriaLote` recibe un **parámetro con valores de tabla** (TVP). Inserta toda la auditoría con un solo `INSERT ... SELECT` y descuenta el inventario con un solo `UPDATE ... JOIN`.

### La tabla lógica `inserted`

- Es una tabla virtual de solo lectura que SQL Server crea mientras se ejecuta el trigger.
- Tiene las mismas columnas que la tabla del trigger y contiene **todas** las filas afectadas por la sentencia: 1, 3 o 0.
- En `INSERT` contiene las filas nuevas. En `UPDATE` contiene los valores nuevos, y su pareja `deleted` contiene los anteriores. En `DELETE` solo existe `deleted`.
- Ya trae los valores generados por el motor, como `VentaID` (IDENTITY) y `Fecha` (DEFAULT).
- Solo existe dentro del trigger y se consulta como cualquier tabla (`SELECT`, `JOIN`, `EXISTS`).

### Procesamiento por conjuntos (set-based)

Consiste en decirle al motor **qué** resultado se quiere sobre un conjunto completo de filas, con una sola sentencia (`INSERT ... SELECT`, `UPDATE ... JOIN`, `GROUP BY`). El optimizador decide **cómo** obtenerlo. Lo contrario es recorrer las filas una por una con un cursor o un `WHILE` y ejecutar una sentencia por cada fila.

### Fila a fila vs. por conjuntos

| Aspecto | Fila a fila (cursor, `WHILE`, variable escalar) | Por conjuntos |
| --- | --- | --- |
| Sentencias ejecutadas | Una por fila (N) | Una por operación |
| Inserciones múltiples en trigger | Pierde filas o necesita cursor | Correcto por diseño |
| Rendimiento | Crece linealmente con N; muchas idas al motor, bloqueos y log | El optimizador usa joins y operaciones en bloque |
| Bloqueos y transacción | Más tiempo con bloqueos abiertos | Transacción más corta |
| Código | Más largo; hay que manejar el cursor | Declarativo y corto |
| Cuándo usarlo | Lógica que de verdad depende de la fila anterior, o llamadas externas por fila | Casi siempre en SQL |

En este proyecto, `sp_RegistrarAuditoria` (recibe un `@VentaID`) se conserva como ejemplo fila a fila. El trigger usa `sp_RegistrarAuditoriaLote`, que es por conjuntos.

## Reto avanzado: inventario

- Tabla `Inventario(Producto, Existencia, UltimaActualizacion)` con `CHECK (Existencia >= 0)`.
- El procedimiento descuenta `SUM(Cantidad)` agrupado por producto, así que dos ventas del mismo producto en un INSERT se descuentan bien.
- Si una venta deja la existencia en negativo, el `CHECK` falla y **toda** la transacción se revierte: la venta, la auditoría y el inventario.

Resultado esperado después de `test_data.sql`:

| Producto | Inicial | Vendido | Existencia final |
| --- | --- | --- | --- |
| Laptop | 50 | 3 + 2 | 45 |
| Monitor | 80 | 5 | 75 |
| Teclado | 100 | 10 | 90 |
| Mouse | 120 | 15 | 105 |

## Validaciones automáticas (`validate.sql`)

1. Hay 5 ventas y 5 registros de auditoría, y ninguna venta queda sin auditar.
2. Las existencias coinciden con la tabla anterior.
3. Una venta de 1000 laptops se rechaza y no deja rastro en `Ventas` ni en `Inventario`.

Si alguna falla, `THROW` termina `sqlcmd` con error y el job queda en rojo.

## Workflow programado (`report.yml`)

- Se dispara con `schedule` (cron `0 14 * * 1`) y con `workflow_dispatch`.
- Levanta SQL Server, despliega la base y ejecuta `report.sql` con `sqlcmd -h -1 -W -s ","`.
- Genera `reportes/reporte_ventas_AAAAMMDD.csv`, lo muestra en el resumen de la ejecución y lo publica con `actions/upload-artifact@v4` (se guarda 30 días).

## Ejecutar localmente (opcional)

```bash
docker run -d --name sqlserver -e ACCEPT_EULA=Y -e MSSQL_PID=Developer \
  -e "MSSQL_SA_PASSWORD=Str0ngP@ssword2026!" -p 1433:1433 \
  mcr.microsoft.com/mssql/server:2022-latest

docker cp ./sql sqlserver:/sql
for f in create_database create_tables create_procedure create_trigger test_data validate; do
  docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa \
    -P 'Str0ngP@ssword2026!' -b -f 65001 -i /sql/$f.sql
done
```
