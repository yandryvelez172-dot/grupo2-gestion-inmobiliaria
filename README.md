# Grupo #2 — Sistema Web de Gestión Inmobiliaria

Proyecto semestral de **Modelos de Procesos de Desarrollo de Software** (Ingeniería en Software — 4.º nivel), aplicando los procesos de **ISO/IEC/IEEE 12207:2026** y referencias documentales complementarias (**ISO/IEC/IEEE 29148:2018** e **ISO/IEC/IEEE 15289:2019**).

## Integrantes y Roles
- **Sofi:** Revisión de norma/guía, unificación documental, formato, coherencia y versión final.
- **Vicky:** Stakeholders, reglas de negocio, historias de usuario, RF/RNF, matriz de trazabilidad, glosario y referencias.
- **Mateo:** Cronograma en MS Project, EDT/WBS, seguimiento de hitos e incrementos y control de avance.
- **Roberto:** Configuración de GitHub, arquitectura inicial, modelo conceptual de BD y backend del Incremento 1.
- **Yandry:** Apoyo en GitHub, modelo lógico/físico y PostgreSQL, Docker/entorno local/infraestructura y reportes/exportaciones.

## Entregables de la Actividad N.º 1 (18 de noviembre de 2026)
- docs/Grupo2_Acta_Inicio.pdf — Acta de Inicio y Autorización del Proyecto.
- docs/Grupo2_SRS.pdf — Especificación de Requisitos de Software (versión inicial 1.0 para revisión).
- evidencias/ — Respaldos de elicitación, entrevista al cliente y avance del equipo.

## Alcance y Restricciones Técnicas
- **Módulos (6):** Portafolio y modalidades de renta (tradicional, temporal, anticresis), liquidación de comisiones (20%, 25%, 30%), gestión de contratos notarizados en PDF, inventario valorizado, flujo de caja (ingresos/egresos) y reportes mensuales con utilidad neta y cierre de mes.
- **Base de datos:** PostgreSQL 17 (NUMERIC/DECIMAL para valores monetarios; metadatos/rutas en BD y binarios PDF en almacenamiento persistente externo).
- **Infraestructura:** Contenerización con Docker y Docker Compose para despliegue en VPS DigitalOcean (Ubuntu Server 22.04 x64, 1 vCPU compartida, 1 GB RAM, 25 GB SSD), manteniendo intactos los puertos 80/443 usados por Apache2.
