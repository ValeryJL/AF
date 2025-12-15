# Dashboard: AF Construcciones y Servicios

**ID:** 2  
**Creado:** 2025-08-07 16:53:37 UTC  
**Última actualización:** 2025-11-13 21:40:33 UTC  
**Ancho:** Fixed  
**Auto-aplicar filtros:** Sí

---

## Descripción General

Este es el tablero principal para AF Construcciones y Servicios que proporciona una visión completa del estado de los servicios, inspecciones, partes y parámetros técnicos.

---

## Parámetros del Dashboard

1. **Fecha** (tipo: date/month-year)
   - Slug: `fecha`
   - Sección: date
   - Por defecto: No especificado

2. **Servicio** (tipo: string/=)
   - Slug: `servicio`
   - Sección: string
   - Por defecto: ["Absa 56"]
   - Requerido: Sí
   - Fuente: Card ID 38, campo: nombre

3. **Tipo de Servicio** (tipo: string/=)
   - Slug: `tipo_de_servicio`
   - Sección: string
   - Por defecto: ["Bomba","Caldera","Grupo Electrogeno","Hidrante","Incendio","Otro"]
   - Requerido: Sí
   - Fuente: Card ID 40, campo: tipo

4. **Período a analizar** (tipo: date/range)
   - Slug: `periodo_a_analizar`
   - Sección: date

5. **Campo** (tipo: string/=)
   - Slug: `campo`
   - Sección: string
   - Por defecto: ["tension_l1"]
   - Requerido: Sí
   - Valores estáticos: tension_l1, tension_l2, tension_l3, corriente_l1, corriente_l2, corriente_l3, potencia_total, fp, frecuencia

6. **Aumento** (tipo: number/=)
   - Slug: `aumento`
   - Sección: number
   - Por defecto: ["1"]
   - Requerido: Sí
   - Valores estáticos: 1, 2, 4, 8, 16, 32, 64

7. **Parámetro** (tipo: string/=)
   - Slug: `parametro`
   - Sección: string
   - Por defecto: ["Tensión - Fase 1"]
   - Requerido: Sí
   - Valores estáticos: Horas, Arranques, Energía Activa, Energía Reactiva, Temperatura en reposo, Temperatura durante prueba, Combustible (%), Batería en reposo, Batería durante prueba, Presión de Aceite, Tensión - Fase 1, Tensión - Fase 2, Tensión - Fase 3, Tensión - Línea 1-2, Tensión - Línea 1-3, Tensión - Línea 2-3, Frecuencia, RPM, Potencia - Línea 1, Potencia - Línea 2, Potencia - Línea 3, Factor de Potencia - Línea 1, Factor de Potencia - Línea 2, Factor de Potencia - Línea 3

---

## Pestañas del Dashboard

### 1. Vista General (Tab ID: 4)

**Tarjetas:**

#### 1.1 Cantidad de Inspecciones cargadas (Card ID: 41)
- **Tipo:** Scalar
- **Display:** Valor escalar
- **Query:**
```sql
WITH total_inspecciones AS (
  SELECT COUNT(*) as total
  FROM informes_servicios 
  WHERE tipo ILIKE 'Inspeccion'
),
inspecciones_mes AS (
  SELECT COUNT(*) as mes_actual
  FROM informes_servicios 
  WHERE tipo ILIKE 'Inspeccion'
    AND fecha >= DATE_TRUNC('month', CURRENT_DATE)
)
SELECT 
  CASE 
    WHEN im.mes_actual > 0 THEN 
      CONCAT(ti.total, ' (', im.mes_actual, ' este mes)')
    ELSE 
      ti.total::text
  END as resultado
FROM total_inspecciones ti, inspecciones_mes im;
```

#### 1.2 Cantidad de Services cargados (Card ID: 42)
- **Tipo:** Scalar
- **Display:** Valor escalar
- **Query:**
```sql
WITH total_inspecciones AS (
  SELECT COUNT(*) as total
  FROM informes_servicios 
  WHERE tipo ILIKE 'Service'
),
inspecciones_mes AS (
  SELECT COUNT(*) as mes_actual
  FROM informes_servicios 
  WHERE tipo ILIKE 'Service'
    AND fecha >= DATE_TRUNC('month', CURRENT_DATE)
)
SELECT 
  CASE 
    WHEN im.mes_actual > 0 THEN 
      CONCAT(ti.total, ' (', im.mes_actual, ' este mes)')
    ELSE 
      ti.total::text
  END as resultado
FROM total_inspecciones ti, inspecciones_mes im;
```

#### 1.3 Cantidad de Eventuales cargados (Card ID: 43)
- **Tipo:** Scalar
- **Display:** Valor escalar
- **Query:**
```sql
WITH total_inspecciones AS (
  SELECT COUNT(*) as total
  FROM informes_servicios 
  WHERE tipo ILIKE 'Eventual'
),
inspecciones_mes AS (
  SELECT COUNT(*) as mes_actual
  FROM informes_servicios 
  WHERE tipo ILIKE 'Eventual'
    AND fecha >= DATE_TRUNC('month', CURRENT_DATE)
)
SELECT 
  CASE 
    WHEN im.mes_actual > 0 THEN 
      CONCAT(ti.total, ' (', im.mes_actual, ' este mes)')
    ELSE 
      ti.total::text
  END as resultado
FROM total_inspecciones ti, inspecciones_mes im;
```

#### 1.4 Servicios realizados vs esperados Semanales (Card ID: 44)
- **Tipo:** Table (Bar Chart)
- **Display:** table
- **Query:**
```sql
WITH servicios_semanales AS (
  SELECT
    s.id AS servicio_id,
    s.nombre AS servicio,
    s.alta,
    DATE_TRUNC('week', s.alta + INTERVAL '2 days')::date AS lunes_inicial
  FROM servicios s
  WHERE s.frecuencia ILIKE 'semanal'
),
semanas_transcurridas AS (
  SELECT
    ss.servicio_id,
    ss.servicio,
    ss.lunes_inicial,
    GREATEST(FLOOR((CURRENT_DATE - ss.lunes_inicial::date) / 7.0) + 1, 0)::int AS semanas_esperadas
  FROM servicios_semanales ss
),
inspecciones_realizadas AS (
  SELECT
    i.servicios_id AS servicio_id,
    COUNT(*) AS inspecciones_realizadas
  FROM informes_servicios i
  WHERE i.tipo ILIKE 'inspeccion'
  GROUP BY i.servicios_id
)
SELECT
  st.servicio,
  COALESCE(ir.inspecciones_realizadas, 0) AS realizados,
  st.semanas_esperadas AS esperados
FROM semanas_transcurridas st
LEFT JOIN inspecciones_realizadas ir ON st.servicio_id = ir.servicio_id
ORDER BY st.servicio;
```
- **Visualización:** Bar chart con dimensiones: servicio, métricas: realizados, esperados

#### 1.5 Servicios realizados vs esperados Quincenales (Card ID: 45)
- **Tipo:** Table (Bar Chart)
- **Display:** table
- **Query:**
```sql
WITH servicios_quincenales AS (
  SELECT
    s.id AS servicio_id,
    s.nombre AS servicio,
    s.alta
  FROM servicios s
  WHERE s.frecuencia ILIKE 'quincenal'
),
quincenas_esperadas AS (
  SELECT
    sq.servicio_id,
    sq.servicio,
    (DATE_PART('year', CURRENT_DATE) - DATE_PART('year', sq.alta)) * 12 +
    (DATE_PART('month', CURRENT_DATE) - DATE_PART('month', sq.alta)) AS meses_diferencia,
    DATE_PART('day', CURRENT_DATE) AS dia_actual
  FROM servicios_quincenales sq
),
calculo_final AS (
  SELECT
    servicio_id,
    servicio,
    (meses_diferencia * 2 + CASE WHEN dia_actual > 15 THEN 1 ELSE 0 END) AS quincenas_esperadas
  FROM quincenas_esperadas
),
inspecciones_realizadas AS (
  SELECT
    i.servicios_id AS servicio_id,
    COUNT(*) AS inspecciones_realizadas
  FROM informes_servicios i
  WHERE i.tipo ILIKE 'inspeccion'
  GROUP BY i.servicios_id
)
SELECT
  cf.servicio,
  COALESCE(ir.inspecciones_realizadas, 0) AS realizados,
  cf.quincenas_esperadas AS esperados
FROM calculo_final cf
LEFT JOIN inspecciones_realizadas ir ON cf.servicio_id = ir.servicio_id
ORDER BY cf.servicio;
```

#### 1.6 Servicios realizados vs esperados Mensuales (Card ID: 46)
- **Tipo:** Table (Bar Chart)
- **Display:** table
- **Query:**
```sql
WITH servicios_mensuales AS (
  SELECT
    s.id AS servicio_id,
    s.nombre AS servicio,
    s.alta
  FROM servicios s
  WHERE s.frecuencia ILIKE 'mensual'
),
meses_esperados AS (
  SELECT
    sm.servicio_id,
    sm.servicio,
    (DATE_PART('year', CURRENT_DATE) - DATE_PART('year', sm.alta)) * 12 +
    (DATE_PART('month', CURRENT_DATE) - DATE_PART('month', sm.alta)) AS meses_diferencia
  FROM servicios_mensuales sm
),
inspecciones_realizadas AS (
  SELECT
    i.servicios_id AS servicio_id,
    COUNT(*) AS inspecciones_realizadas
  FROM informes_servicios i
  WHERE i.tipo ILIKE 'inspeccion'
  GROUP BY i.servicios_id
)
SELECT
  me.servicio,
  COALESCE(ir.inspecciones_realizadas, 0) AS realizados,
  GREATEST(me.meses_diferencia, 0) AS esperados
FROM meses_esperados me
LEFT JOIN inspecciones_realizadas ir ON me.servicio_id = ir.servicio_id
ORDER BY me.servicio;
```

---

### 2. Mensual (Tab ID: 5)

**Tarjetas:**

#### 2.1 Estado Mensual (Card ID: 47)
- **Tipo:** Table
- **Parámetros:** Mes, Tipo de Servicio
- **Query:**
```sql
WITH parametros AS (
  SELECT
    DATE_TRUNC('month', MAX(fecha))::date AS mes_actual,
    CURRENT_DATE AS hoy
  FROM informes_servicios
  WHERE {{mes}}
),
base_servicios AS (
  SELECT s.id, s.nombre
  FROM servicios s,
       parametros p
  WHERE s.frecuencia = 'Mensual'
    AND (s.alta IS NULL OR s.alta <= p.mes_actual + INTERVAL '1 month - 1 day')
    AND (s.baja IS NULL OR s.baja >= p.mes_actual)
	and s.tipo IN (SELECT tipo FROM servicios WHERE {{tipo}})
),
inspecciones AS (
  SELECT
    iserv.servicios_id AS servicio_id,
    DATE_TRUNC('month', iserv.fecha)::date AS mes_inspeccion
  FROM informes_servicios iserv
  WHERE iserv.tipo = 'Inspeccion'
),
estado_mensual AS (
  SELECT
    bs.nombre AS servicio,
    p.mes_actual AS mes,
    CASE
      WHEN COUNT(i.servicio_id) > 0 THEN 'Realizado'
      WHEN p.mes_actual <= DATE_TRUNC('month', p.hoy) THEN 'Pendiente'
      ELSE 'Espera'
    END AS estado
  FROM base_servicios bs
  CROSS JOIN parametros p
  LEFT JOIN inspecciones i
    ON i.servicio_id = bs.id
    AND i.mes_inspeccion = p.mes_actual
  GROUP BY bs.nombre, p.mes_actual, p.hoy
)

SELECT servicio, estado
FROM estado_mensual
ORDER BY servicio;
```

#### 2.2 Estado Quincenal (Card ID: 48)
- **Tipo:** Table
- **Parámetros:** Mes, Tipo de Servicio
- **Query:**
```sql
WITH parametros AS (
  SELECT
    DATE_TRUNC('month', MAX(fecha))::date AS primer_dia_mes,
    (DATE_TRUNC('month', MAX(fecha)) + INTERVAL '1 month - 1 day')::date AS ultimo_dia_mes,
    CURRENT_DATE AS hoy
  FROM informes_servicios
  WHERE {{mes}}
),
quincenas AS (
  SELECT 1 AS quincena,
         p.primer_dia_mes AS inicio,
         (p.primer_dia_mes + INTERVAL '14 days')::date AS fin,
         p.hoy
  FROM parametros p
  UNION ALL
  SELECT 2 AS quincena,
         (p.primer_dia_mes + INTERVAL '15 days')::date AS inicio,
         p.ultimo_dia_mes,
         p.hoy
  FROM parametros p
),
base_servicios AS (
  SELECT s.id, s.nombre
  FROM servicios s
  CROSS JOIN parametros p
  WHERE s.frecuencia = 'Quincenal'
  AND s.alta < p.ultimo_dia_mes
  AND s.baja > p.primer_dia_mes
  and s.tipo IN (SELECT tipo FROM servicios WHERE {{tipo}})
),
inspecciones AS (
  SELECT
    iserv.servicios_id,
    iserv.fecha
  FROM informes_servicios iserv
  WHERE iserv.tipo = 'Inspeccion'
),
estado_quincenal AS (
  SELECT
    bs.nombre AS servicio,
    q.quincena,
    CASE
      WHEN COUNT(i.fecha) > 0 THEN 'Realizado'
      WHEN q.inicio <= q.hoy THEN 'Pendiente'
      ELSE 'Espera'
    END AS estado
  FROM base_servicios bs
  CROSS JOIN quincenas q
  LEFT JOIN inspecciones i
    ON i.servicios_id = bs.id
    AND i.fecha BETWEEN q.inicio AND q.fin
  GROUP BY bs.nombre, q.quincena, q.inicio, q.hoy
),
pivot AS (
  SELECT
    servicio,
    MAX(CASE WHEN quincena = 1 THEN estado END) AS quincena_1,
    MAX(CASE WHEN quincena = 2 THEN estado END) AS quincena_2
  FROM estado_quincenal
  GROUP BY servicio
)

SELECT * FROM pivot
ORDER BY servicio;
```

#### 2.3 Estado Semanal (Card ID: 49)
- **Tipo:** Table
- **Parámetros:** Mes, Tipo de Servicio
- **Query:**
```sql
WITH parametros AS (
  SELECT
    DATE_TRUNC('month', MAX(fecha))::date AS primer_dia_mes,
    (DATE_TRUNC('month', MAX(fecha)) + INTERVAL '1 month - 1 day')::date AS ultimo_dia_mes,
    CURRENT_DATE AS hoy
  FROM informes_servicios
  WHERE {{mes}}
),
semanas AS (
  SELECT generate_series(0, 4) AS semana_idx
),
limites_semanales AS (
  SELECT
    s.semana_idx + 1 AS semana,
    CASE 
      WHEN s.semana_idx = 0 THEN
        CASE 
          WHEN EXTRACT(ISODOW FROM p.primer_dia_mes) <= 5 THEN
            p.primer_dia_mes - (EXTRACT(ISODOW FROM p.primer_dia_mes) - 1) * INTERVAL '1 day'
          ELSE
            p.primer_dia_mes + (8 - EXTRACT(ISODOW FROM p.primer_dia_mes)) * INTERVAL '1 day'
        END
      ELSE
        p.primer_dia_mes 
        + (
            CASE 
              WHEN EXTRACT(ISODOW FROM p.primer_dia_mes) <= 5 THEN
                -(EXTRACT(ISODOW FROM p.primer_dia_mes) - 1)
              ELSE
                (8 - EXTRACT(ISODOW FROM p.primer_dia_mes))
            END
          + 7 * s.semana_idx
        ) * INTERVAL '1 day'
    END AS lunes,
    CASE 
      WHEN s.semana_idx = 0 THEN
        CASE 
          WHEN EXTRACT(ISODOW FROM p.primer_dia_mes) <= 5 THEN
            (p.primer_dia_mes - (EXTRACT(ISODOW FROM p.primer_dia_mes) - 1) * INTERVAL '1 day') + INTERVAL '4 days'
          ELSE
            (p.primer_dia_mes + (8 - EXTRACT(ISODOW FROM p.primer_dia_mes)) * INTERVAL '1 day') + INTERVAL '4 days'
        END
      ELSE
        p.primer_dia_mes 
        + (
            CASE 
              WHEN EXTRACT(ISODOW FROM p.primer_dia_mes) <= 5 THEN
                -(EXTRACT(ISODOW FROM p.primer_dia_mes) - 1)
              ELSE
                (8 - EXTRACT(ISODOW FROM p.primer_dia_mes))
            END
          + 7 * s.semana_idx
        ) * INTERVAL '1 day'
        + INTERVAL '4 days'
    END AS viernes,
    p.ultimo_dia_mes,
    p.hoy
  FROM semanas s, parametros p
),
limites_validos AS (
  SELECT *
  FROM limites_semanales
  WHERE EXTRACT(MONTH FROM viernes) = EXTRACT(MONTH FROM ultimo_dia_mes)
),
servicios_semanales AS (
  SELECT id AS servicio_id, nombre AS servicio
  FROM servicios
  WHERE frecuencia ILIKE 'semanal'
  	AND alta < (SELECT ultimo_dia_mes FROM parametros)
	AND baja > (SELECT primer_dia_mes FROM parametros)
	and {{tipo}}
),
inspecciones AS (
  SELECT
    i.servicios_id AS servicio_id,
    i.fecha
  FROM informes_servicios i
  WHERE tipo ILIKE 'inspeccion'
),
estado_semanal AS (
  SELECT
    ss.servicio,
    lv.semana,
    CASE
      WHEN lv.lunes > lv.viernes THEN NULL
      WHEN EXISTS (
        SELECT 1
        FROM inspecciones i
        WHERE i.servicio_id = ss.servicio_id
          AND i.fecha BETWEEN lv.lunes AND lv.viernes
      ) THEN 'Realizado'
      WHEN lv.viernes < lv.hoy THEN 'Pendiente'
      WHEN lv.lunes > lv.hoy THEN 'Espera'
      ELSE 'Pendiente'
    END AS estado
  FROM servicios_semanales ss
  CROSS JOIN limites_validos lv
),
pivot AS (
  SELECT
    servicio,
    semana,
    estado
  FROM estado_semanal
)
SELECT
  servicio,
  MAX(CASE WHEN semana = 1 THEN estado END) AS "Semana 1",
  MAX(CASE WHEN semana = 2 THEN estado END) AS "Semana 2",
  MAX(CASE WHEN semana = 3 THEN estado END) AS "Semana 3",
  MAX(CASE WHEN semana = 4 THEN estado END) AS "Semana 4",
  MAX(CASE WHEN semana = 5 THEN estado END) AS "Semana 5"
FROM pivot
GROUP BY servicio
ORDER BY servicio;
```

#### 2.4 Mes (Card ID: 58)
- **Tipo:** Scalar
- **Parámetros:** Fecha
- **Query:**
```sql
WITH ultima_fecha AS (
  SELECT MAX(fecha) AS f
  FROM informes_servicios
  WHERE
  	{{fecha}}
)
SELECT 
  CASE TO_CHAR(f, 'MM')
    WHEN '01' THEN 'Enero'
    WHEN '02' THEN 'Febrero'
    WHEN '03' THEN 'Marzo'
    WHEN '04' THEN 'Abril'
    WHEN '05' THEN 'Mayo'
    WHEN '06' THEN 'Junio'
    WHEN '07' THEN 'Julio'
    WHEN '08' THEN 'Agosto'
    WHEN '09' THEN 'Septiembre'
    WHEN '10' THEN 'Octubre'
    WHEN '11' THEN 'Noviembre'
    WHEN '12' THEN 'Diciembre'
  END
  || ' de ' || TO_CHAR(f, 'YYYY') AS mes_anio
FROM ultima_fecha;
```

---

### 3. Servicios (Tab ID: 6)

**Tarjetas:**

#### 3.1 Fecha de último Service (Card ID: 50)
- **Tipo:** Scalar
- **Parámetros:** Servicio
- **Query:**
```sql
SELECT
  COALESCE(
    TO_CHAR(
      COALESCE(MAX(iserv.fecha)::date, MIN(s.alta)::date),
      'DD/MM/YYYY'
    ),
    'Agregar alta o service'
  ) AS ultima_fecha_service
FROM servicios s
LEFT JOIN informes_servicios iserv
  ON iserv.servicios_id = s.id
  AND iserv.tipo = 'Service'
WHERE s.id = (SELECT id FROM servicios WHERE {{servicio}});
```

#### 3.2 Partes Vencidas (Card ID: 51)
- **Tipo:** Scalar
- **Parámetros:** Servicio
- **Query:** (Truncada por longitud - consulta compleja de partes vencidas)

#### 3.3 Días al próximo service (Card ID: 52)
- **Tipo:** Scalar
- **Parámetros:** Servicio
- **Query:** (Truncada por longitud - consulta de cálculo de días restantes)

#### 3.4 Estado de partes (Card ID: 53)
- **Tipo:** Table
- **Parámetros:** Servicio
- **Query:** (Truncada por longitud - consulta de estado de partes por servicio)

#### 3.5 Histórico de Parámetros (Card ID: 54)
- **Tipo:** Table (Line Chart)
- **Parámetros:** Servicio, Campo, Aumento
- **Query:** (Truncada por longitud - consulta de histórico de parámetros con CASE múltiple)
- **Visualización:** Line chart

#### 3.6 Histórico de Visitas (Card ID: 55)
- **Tipo:** Table
- **Parámetros:** Servicio
- **Query:**
```sql
SELECT
  iserv.fecha::date AS fecha,
  iserv.tipo,
  CONCAT(t.nombre, ' ', t.apellido) AS tecnico,
  iserv.observaciones

FROM informes_servicios iserv
JOIN tecnicos t ON t.id = iserv.tecnicos_id
WHERE iserv.servicios_id = (SELECT id FROM servicios WHERE {{servicio}})
ORDER BY iserv.fecha DESC;
```

#### 3.7 Eventualidades sin resolver (Card ID: 59)
- **Tipo:** Table
- **Parámetros:** Servicio
- **Query:**
```sql
SELECT fecha,descripcion FROM eventuales 
WHERE (SELECT id FROM servicios WHERE {{servicio}})=servicios_id 
and informes_servicios_id IS NULL
```

---

### 4. Cámaras Economía (Tab ID: 7)

#### 4.1 Parámetros por trafo (Card ID: 56)
- **Tipo:** Line Chart
- **Parámetros:** Campo, Fecha, Aumento
- **Query:** (Truncada por longitud - consulta compleja de parámetros de cámaras con agregación por intervalo)

---

### 5. Sitios Importantes (Tab ID: 8)

**Secciones con enlaces y textos descriptivos:**

#### 5.1 Base de datos
- Enlace a base de datos NocoDB: https://noco.insanustech.com.ar/dashboard/#/base/2e96629e-ca5c-41e3-84e3-c697b17b7267

#### 5.2 Formularios
- **Formulario Servicios:** https://noco.insanustech.com.ar/dashboard/#/nc/form/5dfd6966-b457-4f1b-98c1-c8fa2814c864
- **Formulario Informes:** https://noco.insanustech.com.ar/dashboard/#/nc/form/239d9398-6841-4b07-9ad9-69d2132ca650
- **Formulario Partes:** https://noco.insanustech.com.ar/dashboard/#/nc/form/85adff3d-e603-4f5b-9187-8d4e47adf85e
- **Formulario Técnicos:** https://noco.insanustech.com.ar/dashboard/#/nc/form/b8a88b99-8f3d-42bb-ac5a-2b9297df3179
- **Formulario Eventualidades:** https://noco.insanustech.com.ar/dashboard/#/nc/form/63afc083-e0d2-4663-a70d-dacadba688b0

#### 5.3 Automatización (N8N)
- Enlace a N8N: https://n8n.insanustech.com.ar/

#### 5.4 Versión editable y de solo lectura
- Dashboard editable (requiere usuario): https://noco.insanustech.com.ar
- Dashboard solo lectura: https://noco.insanustech.com.ar

---

### 6. Importante (Tab ID: 9)

#### 6.1 Partes próximas a vencer (Card ID: 60)
- **Tipo:** Table
- **Query:**
```sql
WITH servicio_partes AS (
  SELECT
    s.id AS servicio_id,
    s.nombre AS servicio_nombre,
    p.id AS parte_id,
    p.nombre AS parte_nombre,
    p.descripcion AS parte_descripcion,
    p.duracion_horas,
    p.duracion_dias,
    s.alta::date AS alta
  FROM partes p
  JOIN servicios_partes sp ON sp.partes_id = p.id
  JOIN servicios s ON s.id = sp.servicios_id
),
ultimo_cambio_parte AS (
  SELECT DISTINCT ON (isp.partes_id)
    isp.partes_id,
    iserv.servicios_id,
    iserv.fecha::date AS fecha_cambio,
    iserv.horas_despues AS horas_cambio
  FROM informes_servicios_partes isp
  JOIN informes_servicios iserv ON iserv.id = isp.informes_servicios_id
  ORDER BY isp.partes_id, iserv.fecha DESC
),
ultima_inspeccion AS (
  SELECT
    iserv.servicios_id,
    MAX(iserv.fecha)::date AS fecha_ultima,
    MAX(iserv.horas_despues) AS horas_ultima
  FROM informes_servicios iserv
  GROUP BY iserv.servicios_id
),
primera_inspeccion AS (
  SELECT
    iserv.servicios_id,
    MIN(iserv.horas_antes) AS horas_primera
  FROM informes_servicios iserv
  GROUP BY iserv.servicios_id
),
calculos AS (
  SELECT
    sp.servicio_id,
    sp.servicio_nombre,
    sp.parte_id,
    sp.parte_nombre,
    sp.parte_descripcion,
    COALESCE(ucp.fecha_cambio, sp.alta) AS ultima_fecha,
    CASE 
      WHEN ucp.horas_cambio IS NOT NULL AND ui.horas_ultima IS NOT NULL THEN 
        ui.horas_ultima - ucp.horas_cambio
      WHEN ucp.horas_cambio IS NULL AND ui.horas_ultima IS NOT NULL AND pi.horas_primera IS NOT NULL THEN 
        ui.horas_ultima - pi.horas_primera
      ELSE 0
    END AS horas_transcurridas,
    CURRENT_DATE - COALESCE(ucp.fecha_cambio, sp.alta) AS dias_transcurridos,
    sp.duracion_horas,
    sp.duracion_dias
  FROM servicio_partes sp
  LEFT JOIN ultimo_cambio_parte ucp 
    ON ucp.partes_id = sp.parte_id AND ucp.servicios_id = sp.servicio_id
  LEFT JOIN ultima_inspeccion ui 
    ON ui.servicios_id = sp.servicio_id
  LEFT JOIN primera_inspeccion pi 
    ON pi.servicios_id = sp.servicio_id
),
vencimientos AS (
  SELECT
    servicio_id,
    servicio_nombre,
    parte_id,
    parte_nombre,
    parte_descripcion,
    ultima_fecha,
    (duracion_horas - horas_transcurridas) AS horas_restantes,
    (duracion_dias - dias_transcurridos) AS dias_restantes
  FROM calculos
)

SELECT
  servicio_nombre,
  parte_nombre,
  parte_descripcion,
  ultima_fecha,
  horas_restantes,
  dias_restantes
FROM vencimientos
WHERE horas_restantes < 11 OR dias_restantes < 60
ORDER BY servicio_nombre, parte_nombre;
```

#### 6.2 Eventualidades sin resolver (Card ID: 61)
- **Tipo:** Table
- **Query:**
```sql
SELECT 
  e.fecha,
  s.nombre AS servicio,
  e.descripcion
FROM eventuales e
JOIN servicios s 
  ON s.id = e.servicios_id
WHERE e.informes_servicios_id IS NULL;
```

---

## Estadísticas del Dashboard

- **Total de tarjetas:** 28
- **Total de pestañas:** 6
- **Tarjetas con parámetros:** 14
- **Tarjetas sin parámetros:** 14
- **Tarjetas escalares:** 7
- **Tarjetas de tabla:** 14
- **Tarjetas de gráfico:** 7

---

## Notas Técnicas

- **Base de datos:** PostgreSQL (ID: 2)
- **Query type:** Native SQL
- **Schema:** datos
- **Color de "Espera":** #F9D45C (Amarillo)
- **Color de "Realizado":** #88BF4D (Verde)
- **Color de "Pendiente":** #EF8C8C (Rojo)

---

**Generado:** 6 de diciembre de 2025
