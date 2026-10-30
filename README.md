# Taller de base de datos III - Grupo #3

## Proyecto: BusRD

## Integrantes

| Sección | Responsable |  Contenido |
|----------|----------|-----------|
| **1. Introducción** | **Grupo** | Problema y alcance |
| **2. Integridad** | **Norkeli Estrella Cabrera** | Datos sucios encontrados, limpieza y restricciones |
| **3. Concurrencia** | **Darling David Solano Tejeda** | Reproducción, causa, solución y evidencia |
| **4. Optimización** | **Vidal Leonardo de Los Santos Rincón** | Tabla antes/después por consulta y conclusiones |
| **5. Seguridad** | **Cecil Ortiz Charles** | Matriz de roles y permisos, con evidencias |
| **6. Respaldos** | **Vidal Leonardo de Los Santos Rincón** | Secuencia ejecutada, restauración y política propuesta |
| **7. Conclusiones** | **Grupo** | Lecciones aprendidas y riesgos pendientes |
| **8. Anexos** | **Grupo** | Aporte de cada integrante |

---

## Estructura del proyecto

- [BusRD-Grupo-3/](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/tree/main)
  - [README.md](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/README.md) *(integrantes, datos asignados, orden de ejecución)*
  - [scripts/](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/tree/main/scripts)
    - [01_integridad.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/01_integridad.sql) *(Norkeli Estrella Cabrera)*
    - [02_sp_VenderBoleto.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/02_sp_VenderBoleto.sql) *(Darling David Solano Tejeda)*
    - [03_sp_AnularBoleto.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/03_sp_AnularBoleto.sql) *(Darling David Solano Tejeda)*
    - [04_demo_concurrencia_sesionA.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/04_demo_concurrencia_sesionA.sql) *(Darling David Solano Tejeda, Vidal Leonardo de Los Santos Rincón)*
    - [05_demo_concurrencia_sesionB.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/05_demo_concurrencia_sesionB.sql) *(Darling David Solano Tejeda, Vidal Leonardo de Los Santos Rincón)*
    - [06_indices_y_consultas_optimizadas.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/06_indices_y_consultas_optimizadas.sql) *(Vidal Leonardo de Los Santos Rincón)*
    - [07_seguridad.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/07_seguridad.sql) *(Cecil Ortiz Charles)*
    - [08_respaldo_y_restauracion.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/08_respaldo_y_restauracion.sql) *(Vidal Leonardo de Los Santos Rincón)*
  - [01_BusRD_base.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/01_BusRD_base.sql)
  - [02_sp_VenderBoleto_v0.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/02_sp_VenderBoleto_v0.sql) 
  - [03_consultas_lentas.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/03_consultas_lentas.sql)

  - [evidencias/](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/tree/main/evidencias) *(capturas de pantalla numeradas)*

---

## Orden de ejecución

| Orden | Script | Descripción |  
|-------|--------|-------------|
| **1** | [01_BusRD_base.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/01_BusRD_base.sql) | Configuración inicial para toda la base de datos.  |
| **2** | [02_sp_VenderBoleto_v0.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/02_sp_VenderBoleto_v0.sql) | Crear el procedimiento para vender boleto por defecto. |
| **3** | [03_consultas_lentas.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/03_consultas_lentas.sql) | Muestra de consultas que presentan lentitud. |
| **4** | [01_integridad.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/01_integridad.sql) | Agrega configuraciones de integridad **(remueve valores duplicaciones, claves foráneas, verificaciones)**. |
| **5** | [02_sp_VenderBoleto.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/02_sp_VenderBoleto.sql) | Crea nuevo procedimiento para la venta de boletos, en base a los críterios especificados. |
| **6** | [03_sp_AnularBoleto.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/03_sp_AnularBoleto.sql) | Crea nuevo procedimiento para la anulación de boletos, en base a los críterios especificado. |
| **7** | [04_demo_concurrencia_sesionA.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/04_demo_concurrencia_sesionA.sql) | Ejemplo de concurrencia A. |
| **8** | [05_demo_concurrencia_sesionB.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/05_demo_concurrencia_sesionB.sql) | Ejemplo de concurrencia B. |
| **9** | [06_indices_y_consultas_optimizadas.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/06_indices_y_consultas_optimizadas.sql) | Creación de índices y optimización de consultas. |
| **10** | [07_seguridad.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/07_seguridad.sql) | Crear usuarios y define sus roles y permisos en la base de datos. |
| **11** | [08_respaldo_y_restauracion.sql](https://github.com/VidalLeonardoDeLosSantosRincon/BusRD-Grupo-3/blob/main/scripts/08_respaldo_y_restauracion.sql) | Crear resplado completo, diferencial y de log, ejecuta proceso de restauración. |

---