
# 使用官方 Logstash 镜像作为基础镜像
FROM docker.elastic.co/logstash/logstash:8.7.0


# 安装插件并固定驱动位置
RUN logstash-plugin install logstash-output-jdbc \
    && mkdir -p /usr/share/logstash/vendor/jar/jdbc

copy ./postgres-driver/postgresql-42.7.4.jar /usr/share/logstash/vendor/jar/jdbc

# 暴露端口（如有需要）
EXPOSE 5044