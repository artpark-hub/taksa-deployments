-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 2. CUSTOM ENUM TYPES
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'work_center_status') THEN
        CREATE TYPE work_center_status AS ENUM ('active', 'maintenance', 'offline');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'equipment_level') THEN
        CREATE TYPE equipment_level AS ENUM ('Unit', 'Work Station');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'material_type_enum') THEN
        CREATE TYPE material_type_enum AS ENUM ('Raw', 'Consumable', 'Packaging');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'personnel_role') THEN
        CREATE TYPE personnel_role AS ENUM ('operator', 'supervisor', 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
        CREATE TYPE order_status AS ENUM ('planned', 'in_progress', 'completed', 'hold');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit_state') THEN
        CREATE TYPE unit_state AS ENUM ('queued', 'processing', 'scrapped', 'shipped');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_result') THEN
        CREATE TYPE event_result AS ENUM ('pass', 'fail', 'rework');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'defect_severity') THEN
        CREATE TYPE defect_severity AS ENUM ('reworkable', 'scrap');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'state_category') THEN
        CREATE TYPE state_category AS ENUM ('Uptime', 'Planned Downtime', 'Unplanned Downtime');
    END IF;
END$$;

-- 3. INFRASTRUCTURE HIERARCHY
CREATE TABLE IF NOT EXISTS enterprises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    headquarters_location VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    enterprise_id UUID REFERENCES enterprises(id),
    name VARCHAR(255) NOT NULL,
    location_code VARCHAR(50),
    timezone VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID REFERENCES sites(id),
    name VARCHAR(255) NOT NULL,
    area_type VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS work_centers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    area_id UUID REFERENCES areas(id),
    name VARCHAR(255) NOT NULL,
    status work_center_status DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS work_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_center_id UUID REFERENCES work_centers(id),
    name VARCHAR(255) NOT NULL,
    equipment_level equipment_level,
    serial_number VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS control_modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_unit_id UUID REFERENCES work_units(id),
    name VARCHAR(255) NOT NULL,
    data_type VARCHAR(50),
    protocol VARCHAR(50),
    connection_metadata JSONB
);

-- 4. MASTER DATA
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku VARCHAR(255) UNIQUE NOT NULL,
    revision VARCHAR(50),
    description TEXT
);

CREATE TABLE IF NOT EXISTS material_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    material_type material_type_enum,
    default_supplier_id UUID
);

CREATE TABLE IF NOT EXISTS bill_of_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(id),
    material_definition_id UUID REFERENCES material_definitions(id),
    quantity_required DECIMAL NOT NULL,
    unit_of_measure VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS personnel (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    role personnel_role
);

CREATE TABLE IF NOT EXISTS personnel_shifts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    start_time TIME,
    end_time TIME
);

CREATE TABLE IF NOT EXISTS product_recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(id),
    work_unit_id UUID REFERENCES work_units(id),
    version INT,
    ideal_cycle_seconds DECIMAL DEFAULT 60.0,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS recipe_parameters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID REFERENCES product_recipes(id),
    param_name VARCHAR(255) NOT NULL,
    min_value DECIMAL,
    max_value DECIMAL,
    target_value DECIMAL
);

-- 5. TRACEABILITY (EXECUTION)
CREATE TABLE IF NOT EXISTS work_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(255) UNIQUE NOT NULL,
    product_id UUID REFERENCES products(id),
    target_quantity INT,
    start_date TIMESTAMP,
    status order_status
);

CREATE TABLE IF NOT EXISTS traceability_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_order_id UUID REFERENCES work_orders(id),
    parent_unit_id UUID REFERENCES traceability_units(id),
    serial_number VARCHAR(255) UNIQUE,
    current_state unit_state,
    last_work_unit_id UUID REFERENCES work_units(id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS process_events (
    id BIGSERIAL PRIMARY KEY,
    traceability_unit_id UUID REFERENCES traceability_units(id),
    work_unit_id UUID REFERENCES work_units(id),
    operation_name VARCHAR(255),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    result event_result,
    personnel_id UUID REFERENCES personnel(id),
    process_data JSONB
);

CREATE TABLE IF NOT EXISTS material_consumption (
    id BIGSERIAL PRIMARY KEY,
    process_event_id BIGINT REFERENCES process_events(id),
    material_sku VARCHAR(255),
    supplier_lot_number VARCHAR(255),
    quantity_consumed DECIMAL
);

-- 6. MACHINE TELEMETRY (HYPERTABLE)
CREATE TABLE IF NOT EXISTS module_telemetry (
    time TIMESTAMPTZ NOT NULL,
    control_module_id UUID NOT NULL REFERENCES control_modules(id),
    metric_key VARCHAR(255),
    metric_value DOUBLE PRECISION,
    traceability_unit_id UUID
);

SELECT create_hypertable('module_telemetry', 'time', if_not_exists => TRUE);


-- 6b. NATS COLLECTOR EQUIPMENT TELEMETRY (HYPERTABLE)
-- The taksa-nats-data-collector writes decoded NATS/UNS values here.
-- Keep this schema in the TSDB init path so fresh deployments match the collector contract.
CREATE TABLE IF NOT EXISTS equipment_master (
    id VARCHAR(50) PRIMARY KEY,
    operational_status VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS equipment_telemetry (
    id BIGSERIAL,
    equipment_id VARCHAR(50) NOT NULL REFERENCES equipment_master(id) ON DELETE CASCADE,
    parameter_name VARCHAR(100) NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit_of_measure VARCHAR(50),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable($$equipment_telemetry$$, $$recorded_at$$, if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_equipment_telemetry_equipment_time
    ON equipment_telemetry(equipment_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_equipment_telemetry_param_time
    ON equipment_telemetry(equipment_id, parameter_name, recorded_at DESC);

-- 7. QUALITY & DEFECTS
CREATE TABLE IF NOT EXISTS defect_definitions (
    id INT PRIMARY KEY,
    code VARCHAR(50),
    description VARCHAR(255),
    category VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS quality_incidents (
    id BIGSERIAL PRIMARY KEY,
    process_event_id BIGINT REFERENCES process_events(id),
    defect_definition_id INT REFERENCES defect_definitions(id),
    comment TEXT,
    severity defect_severity
);

-- 8. PERFORMANCE ANALYSIS (OEE)
CREATE TABLE IF NOT EXISTS equipment_state_history (
    id BIGSERIAL PRIMARY KEY,
    work_unit_id UUID REFERENCES work_units(id),
    state_code VARCHAR(50),
    category state_category,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    duration_seconds INT,
    reason_comment TEXT
);