CREATE TABLE DatenTyp (
    datenTypID VARCHAR(1) PRIMARY KEY,
    datenTyp VARCHAR(255) UNIQUE,
    beschreibung TEXT
);

-- Create Raum Table
CREATE TABLE Raum (
    raumID INT PRIMARY KEY,
    raumName VARCHAR(255)
);

-- Create Bereich Table
CREATE TABLE Bereich (
    bereichID INT PRIMARY KEY,
    bereichName VARCHAR(255)
);

-- Create Koppler Table
CREATE TABLE Koppler (
    kopplerID INT PRIMARY KEY,
    beschreibung VARCHAR(255),
    raumID INT REFERENCES Raum(raumID)
);


CREATE TABLE SensorTyp (
    sensorTypID INT PRIMARY KEY,
    sensorTyp VARCHAR(255) UNIQUE,
);


CREATE TABLE Funktion (
    funktionID INT PRIMARY KEY,
    funktionName VARCHAR(255),
    beschreibung TEXT
);

CREATE TABLE Sensor (
    sensorID INT PRIMARY KEY,
    datenTypID VARCHAR(1) REFERENCES DatenTyp(datenTypID),
    raumID INT REFERENCES Raum(raumID),
    bereichID INT REFERENCES Bereich(bereichID),
    kopplerID INT REFERENCES Koppler(kopplerID),
    sensorTypID INT REFERENCES SensorTyp(sensorTypID),
    funktionID INT REFERENCES Funktion(funktionID)
);


CREATE TABLE Einheit (
    sensorID INT REFERENCES Sensor(sensorID),
    einheitszeichen VARCHAR(255),
    beschreibung VARCHAR(255),
    ergaenzung VARCHAR(255),
    PRIMARY KEY(sensorID)
);



-- Create Sensormesswert table with combined timestamp
CREATE TABLE sensormesswert (
    id SERIAL,
    sensorID INT REFERENCES Sensor(sensorID) ON DELETE SET NULL ON UPDATE CASCADE,
    timestamp TIMESTAMP,
    unix_zeit BIGINT NOT NULL,
    millisekunde INT NOT NULL,
    konsolzeit TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sensortypid  integer default 0,
    PRIMARY KEY (id,timestamp,sensortypid)
) PARTITION BY RANGE (timestamp);

---------------------------------------------------

DO $$
DECLARE
    start_year INT := 2020; -- 分区起始年份
    end_year INT := 2025;   -- 分区结束年份
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    FOR year IN start_year..end_year LOOP
        -- 动态生成分区表名称
        partition_name := 'sensormesswert_' || year;
        -- 动态生成时间范围
        start_date := make_date(year, 1, 1);
        end_date := make_date(year + 1, 1, 1);

        -- 动态创建分区表
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I PARTITION OF sensormesswert FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            start_date || ' 00:00:00',
            end_date || ' 00:00:00'
        );

    END LOOP;
END $$;


-- Create Trigger Function
CREATE OR REPLACE FUNCTION convert_unix_to_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    -- 检查是否需要更新 timestamp
    IF NEW.timestamp IS NULL OR NEW.unix_zeit IS DISTINCT FROM OLD.unix_zeit OR NEW.millisekunde IS DISTINCT FROM OLD.millisekunde THEN
        NEW.timestamp = TO_TIMESTAMP(NEW.unix_zeit) + (NEW.millisekunde || ' milliseconds')::INTERVAL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Trigger
CREATE TRIGGER convert_unix_to_timestamp
BEFORE INSERT OR UPDATE ON Sensormesswert
FOR EACH ROW
EXECUTE FUNCTION convert_unix_to_timestamp();

---------------------------------------------------
CREATE OR REPLACE FUNCTION create_dynamic_partition(
    p_start TIMESTAMP,
    p_end TIMESTAMP,
    p_sensortyp_ids INT[]
)
RETURNS VOID AS
$$
DECLARE
    v_partition_name TEXT;
    v_subpartition_name TEXT;
    v_sensortypid INT;
BEGIN
    -- 根据起始时间构造一级分区名称，例如 "Sensormesswert_2020"
    v_partition_name := format('Sensormesswert_%s', to_char(p_start, 'YYYY'));

    RAISE NOTICE 'Creating main partition: % (FROM % TO %)', v_partition_name, p_start, p_end;

    -- 创建一级分区：注意此处使用 IF NOT EXISTS 避免重复创建
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS %I
       PARTITION OF Sensormesswert
       FOR VALUES FROM (%L) TO (%L)
       PARTITION BY LIST (sensortypid);',
      v_partition_name, p_start, p_end
    );

    -- 循环创建二级分区，每个子分区对应一个 sensortypid 值
    FOREACH v_sensortypid IN ARRAY p_sensortyp_ids
    LOOP
        v_subpartition_name := format('%I_st%s', v_partition_name, v_sensortypid);
        RAISE NOTICE 'Creating sub-partition: % for sensortypid = %', v_subpartition_name, v_sensortypid;

        EXECUTE format(
          'CREATE TABLE IF NOT EXISTS %I
           PARTITION OF %I
           FOR VALUES IN (%s);',
          v_subpartition_name, v_partition_name, v_sensortypid
        );
    END LOOP;

    RAISE NOTICE 'Partition creation completed.';
END;
$$ LANGUAGE plpgsql;