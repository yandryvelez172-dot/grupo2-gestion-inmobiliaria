CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(30) NOT NULL CHECK (rol IN ('PROPIETARIO', 'ADMIN_TEMPORAL', 'ADMIN_SISTEMA')),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE propiedades (
    id_propiedad SERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(120) NOT NULL,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('DEPARTAMENTO', 'CASA', 'LOCAL_COMERCIAL')),
    direccion TEXT NOT NULL,
    estado_actual VARCHAR(30) NOT NULL CHECK (
        estado_actual IN ('LIBRE', 'MANTENIMIENTO', 'RENTA_TRADICIONAL', 'RENTA_TEMPORAL', 'ANTICRESIS')
    ),
    id_propietario INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
    id_administrador_actual INT NULL REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contratos (
    id_contrato SERIAL PRIMARY KEY,
    id_propiedad INT NOT NULL REFERENCES propiedades(id_propiedad) ON DELETE RESTRICT,
    id_administrador INT NULL REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    tipo_contrato VARCHAR(30) NOT NULL CHECK (
        tipo_contrato IN ('RENTA_TRADICIONAL', 'ADMINISTRACION_TEMPORAL', 'ANTICRESIS')
    ),
    fecha_firma DATE NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    canon_mensual NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (canon_mensual >= 0),
    monto_garantia_anticresis NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (monto_garantia_anticresis >= 0),
    porcentaje_comision NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (
        porcentaje_comision IN (0.00, 20.00, 25.00, 30.00)
    ),
    dias_aviso_vencimiento INT NOT NULL DEFAULT 30 CHECK (dias_aviso_vencimiento >= 0),
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('VIGENTE', 'VENCIDO', 'TERMINADO')),
    ruta_archivo_pdf VARCHAR(500) NOT NULL,
    nombre_original_pdf VARCHAR(255) NOT NULL,
    hash_sha256_pdf VARCHAR(64) NOT NULL,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fechas_contrato CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE inventario_items (
    id_item SERIAL PRIMARY KEY,
    id_propiedad INT NOT NULL REFERENCES propiedades(id_propiedad) ON DELETE RESTRICT,
    descripcion VARCHAR(150) NOT NULL,
    categoria VARCHAR(60) NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    estado VARCHAR(20) NOT NULL CHECK (
        estado IN ('NUEVO', 'BUENO', 'REGULAR', 'DANADO', 'DADO_DE_BAJA')
    ),
    fecha_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    observaciones TEXT
);

CREATE TABLE informes_reservas_mensuales (
    id_informe SERIAL PRIMARY KEY,
    id_propiedad INT NOT NULL REFERENCES propiedades(id_propiedad) ON DELETE RESTRICT,
    id_administrador INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
    anio INT NOT NULL CHECK (anio >= 2020),
    mes INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fecha_entrega DATE NOT NULL,
    plataforma_origen VARCHAR(30) NOT NULL CHECK (
        plataforma_origen IN ('AIRBNB', 'BOOKING', 'DIRECTA', 'OTRA')
    ),
    fecha_checkin DATE NOT NULL,
    fecha_checkout DATE NOT NULL,
    monto_reserva NUMERIC(12,2) NOT NULL CHECK (monto_reserva >= 0),
    observaciones TEXT,
    CONSTRAINT chk_fechas_reserva CHECK (fecha_checkout >= fecha_checkin)
);

CREATE TABLE movimientos_financieros (
    id_movimiento SERIAL PRIMARY KEY,
    id_propiedad INT NOT NULL REFERENCES propiedades(id_propiedad) ON DELETE RESTRICT,
    anio INT NOT NULL CHECK (anio >= 2020),
    mes INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fecha_movimiento DATE NOT NULL,
    tipo_movimiento VARCHAR(15) NOT NULL CHECK (tipo_movimiento IN ('INGRESO', 'EGRESO')),
    categoria VARCHAR(40) NOT NULL CHECK (
        categoria IN (
            'CANON_RENTA', 'RESERVA_TEMPORAL', 'LUZ', 'AGUA', 'ALICUOTA',
            'INTERNET', 'TELEFONO', 'MANTENIMIENTO', 'REPOSICION_INVENTARIO', 'OTRO'
        )
    ),
    descripcion VARCHAR(255) NOT NULL,
    monto NUMERIC(12,2) NOT NULL CHECK (monto >= 0),
    es_gasto_compartido BOOLEAN NOT NULL DEFAULT FALSE,
    porcentaje_prorrateo NUMERIC(5,2) NOT NULL DEFAULT 100.00 CHECK (
        porcentaje_prorrateo > 0 AND porcentaje_prorrateo <= 100.00
    ),
    ruta_comprobante_pdf VARCHAR(500) NULL,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cierres_mensuales (
    id_cierre SERIAL PRIMARY KEY,
    id_propiedad INT NOT NULL REFERENCES propiedades(id_propiedad) ON DELETE RESTRICT,
    anio INT NOT NULL CHECK (anio >= 2020),
    mes INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    ingresos_brutos NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    egresos_operativos NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    base_comision NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    porcentaje_comision_aplicado NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    monto_comision NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    utilidad_neta NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    estado_cierre VARCHAR(15) NOT NULL DEFAULT 'ABIERTO' CHECK (estado_cierre IN ('ABIERTO', 'CERRADO')),
    fecha_cierre TIMESTAMP NULL,
    cerrado_por INT NULL REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    CONSTRAINT uq_cierre_propiedad_periodo UNIQUE (id_propiedad, anio, mes)
);

CREATE OR REPLACE FUNCTION fn_bloquear_periodo_cerrado()
RETURNS TRIGGER AS $$
DECLARE
    v_propiedad INT;
    v_anio INT;
    v_mes INT;
    v_cerrado BOOLEAN;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_propiedad := OLD.id_propiedad;
        v_anio := OLD.anio;
        v_mes := OLD.mes;
    ELSE
        v_propiedad := NEW.id_propiedad;
        v_anio := NEW.anio;
        v_mes := NEW.mes;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM cierres_mensuales
        WHERE id_propiedad = v_propiedad
          AND anio = v_anio
          AND mes = v_mes
          AND estado_cierre = 'CERRADO'
    ) INTO v_cerrado;

    IF v_cerrado THEN
        RAISE EXCEPTION 'Operacion denegada: El periodo %/% para la propiedad % ya se encuentra CERRADO.', v_mes, v_anio, v_propiedad;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloqueo_movimientos_cerrados
BEFORE INSERT OR UPDATE OR DELETE ON movimientos_financieros
FOR EACH ROW EXECUTE FUNCTION fn_bloquear_periodo_cerrado();

CREATE TRIGGER trg_bloqueo_informes_cerrados
BEFORE INSERT OR UPDATE OR DELETE ON informes_reservas_mensuales
FOR EACH ROW EXECUTE FUNCTION fn_bloquear_periodo_cerrado();

INSERT INTO usuarios (nombre, correo, password_hash, rol) VALUES
('Familia Propietaria', 'propietario@inmobiliaria.local', 'hash_demo_123', 'PROPIETARIO'),
('Carlos Gestor Temporal', 'admin.temporal@inmobiliaria.local', 'hash_demo_456', 'ADMIN_TEMPORAL'),
('Administrador Sistema', 'sysadmin@inmobiliaria.local', 'hash_demo_789', 'ADMIN_SISTEMA');

INSERT INTO propiedades (codigo, nombre, tipo, direccion, estado_actual, id_propietario, id_administrador_actual) VALUES
('PROP-01', 'Departamento Norte 101', 'DEPARTAMENTO', 'Av. Republica y Eloy Alfaro', 'RENTA_TEMPORAL', 1, 2),
('PROP-02', 'Departamento Norte 102', 'DEPARTAMENTO', 'Av. Republica y Eloy Alfaro', 'RENTA_TEMPORAL', 1, 2),
('PROP-03', 'Casa Familiar Cumbaya', 'CASA', 'Sector La Primavera, Cumbaya', 'RENTA_TRADICIONAL', 1, NULL),
('PROP-04', 'Local Comercial Centro 1', 'LOCAL_COMERCIAL', 'Calle Guayaquil y Espejo', 'RENTA_TRADICIONAL', 1, NULL),
('PROP-05', 'Local Comercial Centro 2', 'LOCAL_COMERCIAL', 'Calle Guayaquil y Espejo', 'LIBRE', 1, NULL),
('PROP-06', 'Suite La Carolina', 'DEPARTAMENTO', 'Av. Shyris y Portugal', 'RENTA_TEMPORAL', 1, 2),
('PROP-07', 'Departamento Valle 201', 'DEPARTAMENTO', 'Av. General Ruminahui', 'RENTA_TRADICIONAL', 1, NULL),
('PROP-08', 'Departamento Valle 202', 'DEPARTAMENTO', 'Av. General Ruminahui', 'MANTENIMIENTO', 1, NULL),
('PROP-09', 'Casa Rentera Sur', 'CASA', 'Sector El Recreo', 'RENTA_TRADICIONAL', 1, NULL),
('PROP-10', 'Oficina / Local Carolina', 'LOCAL_COMERCIAL', 'Av. Amazonas y Naciones Unidas', 'ANTICRESIS', 1, NULL);