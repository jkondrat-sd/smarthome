create table sensormesswert
(
    id                integer   default nextval('sensormesswert_id_seq'::regclass) not null,
    sensorid          integer                                                      not null,
    timestamp         timestamp                                                    not null,
    unix_zeit         bigint                                                       not null,
    millisekunde      integer                                                      not null,
    konsolzeit        timestamp default CURRENT_TIMESTAMP,
    messwert          varchar(255),
    datentypid        varchar(1),
    log_created_year  integer,
    log_created_month integer,
    log_created_day   integer,
    log_created_hour  smallint,
    sensortypid       integer,
    primary key (sensorid, id, timestamp)
)
    partition by RANGE ("timestamp");

alter table sensormesswert
    owner to taoting;

create index idx_sensormesswert_sensorid
    on sensormesswert (sensorid);

create index idx_log_created_year
    on sensormesswert (log_created_year);

create index idx_log_created_month
    on sensormesswert (log_created_month);

create index idx_log_created_day
    on sensormesswert (log_created_day);

create index sensormesswert_timestamp_brin_idx
    on sensormesswert using brin (timestamp);

create index sensormesswert_datentyp_idx
    on sensormesswert (datentypid);

create index sensormesswert_log_created_hour_idx
    on sensormesswert (log_created_hour);

create index sensormesswert_time_sensor_idx
    on sensormesswert (timestamp, sensorid);

create index sensormesswert_time_sensor_datentyp_idx
    on sensormesswert (timestamp, sensorid, datentypid);

create trigger convert_unix_to_timestamp
    before insert or update
    on sensormesswert
    for each row
execute procedure convert_unix_to_timestamp();

create table "Sensormesswert_2020"
    partition of sensormesswert
        FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2021-01-01 00:00:00');

alter table "Sensormesswert_2020"
    owner to taoting;

create trigger convert_unix_to_timestamp
    before insert or update
    on "Sensormesswert_2020"
    for each row
execute procedure convert_unix_to_timestamp();

create table "Sensormesswert_2021"
    partition of sensormesswert
        FOR VALUES FROM ('2021-01-01 00:00:00') TO ('2022-01-01 00:00:00');

alter table "Sensormesswert_2021"
    owner to taoting;

create trigger convert_unix_to_timestamp
    before insert or update
    on "Sensormesswert_2021"
    for each row
execute procedure convert_unix_to_timestamp();

create table "Sensormesswert_2022"
    partition of sensormesswert
        FOR VALUES FROM ('2022-01-01 00:00:00') TO ('2023-01-01 00:00:00');

alter table "Sensormesswert_2022"
    owner to taoting;

create trigger convert_unix_to_timestamp
    before insert or update
    on "Sensormesswert_2022"
    for each row
execute procedure convert_unix_to_timestamp();

create table "Sensormesswert_2023"
    partition of sensormesswert
        FOR VALUES FROM ('2023-01-01 00:00:00') TO ('2024-01-01 00:00:00');

alter table "Sensormesswert_2023"
    owner to taoting;

create trigger convert_unix_to_timestamp
    before insert or update
    on "Sensormesswert_2023"
    for each row
execute procedure convert_unix_to_timestamp();

create table "Sensormesswert_2024"
    partition of sensormesswert
        FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');

alter table "Sensormesswert_2024"
    owner to taoting;

create trigger convert_unix_to_timestamp
    before insert or update
    on "Sensormesswert_2024"
    for each row
execute procedure convert_unix_to_timestamp();

create table "Sensormesswert_2025"
    partition of sensormesswert
        FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');

alter table "Sensormesswert_2025"
    owner to taoting;

create trigger convert_unix_to_timestamp
    before insert or update
    on "Sensormesswert_2025"
    for each row
execute procedure convert_unix_to_timestamp();



DO $$
DECLARE
    start_year INT := 2020;  -- 分区起始年份
    end_year   INT := 2025;  -- 分区结束年份
    partition_name TEXT;
    start_date DATE;
    end_date   DATE;
    sensortypid_val INT;
    -- 生成 1 到 37 的数组
    sensortypid_array INT[] := (SELECT array_agg(x) FROM generate_series(1,37) AS x);
BEGIN
    FOR year IN start_year..end_year LOOP
        -- 构造一级分区表名称，例如 "sensormesswert_2020"
        partition_name := 'sensormesswert_' || year;
        start_date := make_date(year, 1, 1);
        end_date   := make_date(year + 1, 1, 1);

        -- 创建一级分区表，并指定其内部采用 LIST 分区（按 sensortypid）
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I
             PARTITION OF Sensormesswert
             FOR VALUES FROM (%L) TO (%L)
             PARTITION BY LIST (sensortypid);',
            partition_name,
            start_date || ' 00:00:00',
            end_date   || ' 00:00:00'
        );
        RAISE NOTICE 'Created main partition: % (FROM % TO %)', partition_name, start_date || ' 00:00:00', end_date || ' 00:00:00';

        -- 循环为当前年份分区创建二级分区：使用 sensortypid_array 中的每个值
        FOREACH sensortypid_val IN ARRAY sensortypid_array LOOP
            EXECUTE format(
                'CREATE TABLE IF NOT EXISTS %I
                 PARTITION OF %I
                 FOR VALUES IN (%s);',
                partition_name || '_st' || sensortypid_val,
                partition_name,
                sensortypid_val
            );
            RAISE NOTICE '  Created sub-partition: % for sensortypid = %', partition_name || '_st' || sensortypid_val, sensortypid_val;
        END LOOP;
    END LOOP;
END $$;
