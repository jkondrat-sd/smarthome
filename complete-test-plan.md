# PostgreSQL大表查询性能测试方案

## 1. 环境准备

### 1.1 工具安装
- JMeter 5.5+
- Grafana + Prometheus
- InfluxDB

### 1.2 测试数据准备
```sql
-- 导出sensorid
COPY (SELECT sensorid FROM sensor) TO '/path/to/sensorids.csv';

-- 导出datentypid
COPY (SELECT datentypid FROM datentyp) TO '/path/to/datatypeids.csv';
```

## 2. JMeter配置

### 2.1 数据源配置
```xml
<JDBCDataSource>
    <stringProp name="dataSource.poolMax">100</stringProp>
    <stringProp name="dataSource.url">jdbc:postgresql://localhost:5432/your_db</stringProp>
    <stringProp name="dataSource.driver">org.postgresql.Driver</stringProp>
    <stringProp name="dataSource.username">taoting</stringProp>
</JDBCDataSource>

<CSVDataSet>
    <stringProp name="filename">sensorids.csv</stringProp>
    <stringProp name="variableName">sensorid</stringProp>
</CSVDataSet>

<CSVDataSet>
    <stringProp name="filename">datatypeids.csv</stringProp>
    <stringProp name="variableName">datatypeid</stringProp>
</CSVDataSet>


```

### 2.2 线程组配置
```xml
<ThreadGroup>
    <stringProp name="ThreadGroup.num_threads">10</stringProp>
    <stringProp name="ThreadGroup.ramp_time">5</stringProp>
    <stringProp name="ThreadGroup.duration">600</stringProp>
    <boolProp name="ThreadGroup.scheduler">true</boolProp>
    <UserDefinedVariables>
        <stringProp name="limit">${__intSum(${baseLimit},${__threadNum()})}</stringProp>
    </UserDefinedVariables>
</ThreadGroup>
```

## 3. 测试场景

### 3.1 基础查询
```xml
<UserDefinedVariables>
    <stringProp name="baseLimit">1000</stringProp> <!-- 每个线程的基础LIMIT值 -->
</UserDefinedVariables>
<!-- 传感器数据查询 -->
<JDBCSampler>
    <stringProp name="query">
        SELECT * FROM sensormesswert 
        WHERE sensorid = ? 
        AND timestamp BETWEEN ? AND ?
        LIMIT ${limit}
    </stringProp>
    <stringProp name="queryArguments">
        ${sensorid},
        ${__timeShift(yyyy-MM-dd HH:mm:ss,,-P1D)},
        ${__time(yyyy-MM-dd HH:mm:ss)}
    </stringProp>
</JDBCSampler>
```

### 3.2 聚合查询
```xml
<!-- 传感器数据统计 -->
<JDBCSampler>
    <stringProp name="query">
        SELECT s.datentypid, d.datentyp, COUNT(*), AVG(CAST(m.messwert AS FLOAT))
        FROM sensormesswert m
        JOIN sensor s ON m.sensorid = s.sensorid
        JOIN datentyp d ON s.datentypid = d.datentypid
        WHERE s.datentypid = ?
        AND m.timestamp >= ?
        GROUP BY s.datentypid, d.datentyp
    </stringProp>
    <stringProp name="queryArguments">
        ${datatypeid},
        ${__timeShift(yyyy-MM-dd HH:mm:ss,,-P1D)}
    </stringProp>
</JDBCSampler>

<!-- 小时统计 -->
<JDBCSampler>
    <stringProp name="query">
        SELECT s.datentypid, d.datentyp, m.log_created_hour, 
        COUNT(*), AVG(CAST(m.messwert AS FLOAT))
        FROM sensormesswert m
        JOIN sensor s ON m.sensorid = s.sensorid
        JOIN datentyp d ON s.datentypid = d.datentypid
        WHERE s.datentypid = ?
        AND m.timestamp >= ?
        GROUP BY s.datentypid, d.datentyp, m.log_created_hour
    </stringProp>
</JDBCSampler>
```

### 3.3 分区查询
```xml
<!-- 跨分区查询 -->
<JDBCSampler>
    <stringProp name="query">
        SELECT COUNT(*) 
        FROM sensormesswert 
        WHERE timestamp BETWEEN '2023-12-01' AND '2024-02-01'
        AND sensorid = ?
    </stringProp>
    <stringProp name="queryArguments">${sensorid}</stringProp>
</JDBCSampler>
```

## 4. 监控配置

### 4.1 JMeter监听器
```xml
<!-- 结果收集器 -->
<ResultCollector>
    <stringProp name="filename">summary.jtl</stringProp>
</ResultCollector>

<!-- InfluxDB监听器 -->
<BackendListener>
    <stringProp name="influxdbUrl">http://localhost:8086/write?db=jmeter</stringProp>
    <stringProp name="application">db_test</stringProp>
    <stringProp name="measurement">performance</stringProp>
</BackendListener>
```

### 4.2 Grafana面板
- 查询响应时间
- 每秒查询数（QPS）
- 错误率
- 系统资源使用率

## 5. 执行计划

### 5.1 测试步骤
1. 基准测试（10用户）：10分钟
2. 梯度测试：
   - 每次增加10用户
   - 每轮持续10分钟
   - 错误率超过1%时停止

### 5.2 监控指标
- 响应时间（avg, p95, p99）
- QPS
- 错误率
- CPU使用率
- 内存使用
- IO状况
- 数据库连接数

## 6. 测试记录
```sql
CREATE TABLE query_test_log (
    id SERIAL PRIMARY KEY,
    query_type VARCHAR(50),
    concurrent_users INT,
    qps FLOAT,
    avg_response_time FLOAT,
    p95_response_time FLOAT,
    error_rate FLOAT,
    test_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    additional_info JSONB
);
```

## 7. 启动命令
```bash
jmeter -n -t test_plan.jmx \
-JbaseLimit=1000 \
-Jthreads=10 \
-Jrampup=5 \
-Jduration=600 \
-l result.jtl \
-e -o report
```
