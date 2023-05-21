#!/usr/bin/env python3

import redis
import time
import psutil
import threading
import subprocess
import prometheus_client
from pprint import pprint
from flask import Response, Flask
from prometheus_client import Counter, Gauge
from prometheus_client.core import CollectorRegistry

lip = "10.5.11.4"
clusterName = "业务s_redis非持久化"
ports = ["7000", "7001", "7002", "7003", "7004"]
redisPasswd = "xxxyy"
latency_dict = {
    "{}:{}".format(lip, ports[0]): 0,
    "{}:{}".format(lip, ports[1]): 0,
    "{}:{}".format(lip, ports[2]): 0,
    "{}:{}".format(lip, ports[3]): 0,
    "{}:{}".format(lip, ports[4]): 0
}

app = Flask(__name__)

redis_gauge_list = [
    "used_memory",
    "used_memory_rss_human",
    "used_memory_peak_human",
    "used_memory_lua_human",
    "mem_fragmentation_ratio",
    "blocked_clients",
    "connected_clients",
    "connected_slaves",
    "rdb_last_save_time",
    "instantaneous_ops_per_sec",
    "instantaneous_input_kbps",
    "instantaneous_output_kbps",
    "sync_partial_err",
    "db0"
]

redis_counter_list = [
    "evicted_keys",
    "keyspace_hits",
    "keyspace_misses",
    "rejected_connections",
    "total_connections_received",
    "expired_keys"
]

redis_list = redis_gauge_list + redis_counter_list

redis_cluster_gauge_list = [
    "cluster_state",
    "cluster_slots_assigned",
    "cluster_size",
    "cluster_slots_pfail",
    "cluster_slots_fail",
    "cluster_known_nodes",
    "cluster_stats_messages_pong_sent",
    "cluster_stats_messages_received",
    "cluster_stats_messages_sent",
]

host_gauge_list = [
    "memory_total",
    "memory_used_percent",
    "swap_total",
    "swap_used_percent",
    "cpu_sys_percent",
    "cpu_use_percent",
    "cpu_iowait_percent",
    "cpu_irq_percent",
    "cpu_softirq_percent",
    "cpu_idle_percent",
]

host_counter_list = [
    "io_read_bytes",
    "io_write_bytes",
    "net_send_bytes",
    "net_receive_bytes",
    "net_package_errors",
    "net_package_drops"
]


class CheckRedis:
    def __init__(self, port=6379, password="123456", host="127.0.0.1"):
        self.port = port
        self.password = password
        self.host = host
        self.conn = self._get_conn()

    def _get_conn(self):
        conn = None
        try:
            pool = redis.ConnectionPool(host=self.host, password=self.password, port=self.port, db=0)
            conn = redis.Redis(connection_pool=pool)
        except:
            pass
        return conn

    # 获取redis info
    def get_info(self):
        result = {}
        t = ['used_memory_lua_human', 'used_memory_peak_human', 'used_memory_rss_human']
        for key, value in self.conn.info().items():
            if key in redis_list:
                if key in t:
                    if value.endswith("K"):
                        value = float(value.rstrip("K")) * 1024
                    elif value.endswith("M"):
                        value = float(value.rstrip("M")) * 1024 * 1024
                    elif value.endswith("G"):
                        value = float(value.rstrip("G")) * 1024 * 1024 * 1024
                    else:
                        value = float(value)
                    result[key] = value
                elif key == "db0":
                    result["db0_keys"] = float(value.get("keys"))
                else:
                    result[key] = value

        return result

    def get_all_info(self):
        pprint(self.conn.info())

    def get_all_cluster_info(self):
        pprint(self.conn.cluster("info"))

    def get_slownum(self):
        return len(self.conn.slowlog_get())

    # 获取redis cluster info
    def get_cluster_info(self):
        result = {}
        t = ["cluster_state"]
        for key, value in self.conn.cluster("info").items():
            if key in redis_cluster_gauge_list:
                if key in t:
                    if key == "cluster_state":
                        if value == "ok":
                            result[key] = 1
                        else:
                            result[key] = 0
                    else:
                        result[key] = value
                else:
                    result[key] = value
        return result


def getHostGaugeInfo():
    cpu = psutil.cpu_times_percent(interval=1)
    return {
        "memory_total": psutil.virtual_memory().total,
        "memory_used_percent": psutil.virtual_memory().percent,
        "swap_total": psutil.swap_memory().total,
        "swap_used_percent": psutil.swap_memory().percent,
        "cpu_sys_percent": cpu.system,
        "cpu_use_percent": cpu.user,
        "cpu_iowait_percent": cpu.iowait,
        "cpu_irq_percent": cpu.irq,
        "cpu_softirq_percent": cpu.softirq,
        "cpu_idle_percent": cpu.idle
    }


def getHostCounterInfo():
    return {
        "io_read_bytes": psutil.disk_io_counters().read_bytes,
        "io_write_bytes": psutil.disk_io_counters().write_bytes,
        "net_send_bytes": psutil.net_io_counters().bytes_sent,
        "net_receive_bytes": psutil.net_io_counters().bytes_recv,
        "net_package_errors": psutil.net_io_counters().errin + psutil.net_io_counters().errout,
        "net_package_drops": psutil.net_io_counters().dropin + psutil.net_io_counters().dropout
    }


class RedisGaugeInfo():
    def __init__(self, group, ip, info, key, gauge="", instance=""):
        self.gauge = gauge
        self.instance = instance
        self.info = info
        self.key = key
        self.group = group
        self.ip = ip

    def register(self):
        self.gauge.labels(host=self.instance, ip=self.ip, group=self.group).set(self.info.get(self.key))


class RedisCounterInfo():
    def __init__(self, group, ip, info, key, counter="", instance=""):
        self.counter = counter
        self.instance = instance
        self.info = info
        self.key = key
        self.group = group
        self.ip = ip

    def register(self):
        self.counter.labels(host=self.instance, ip=self.ip, group=self.group).inc(self.info.get(self.key))


class RedisClusterGaugeInfo():
    def __init__(self, group, ip, info, key, gauge="", instance=""):
        self.gauge = gauge
        self.instance = instance
        self.info = info
        self.key = key
        self.group = group
        self.ip = ip

    def register(self):
        self.gauge.labels(host=self.instance, ip=self.ip, group=self.group).set(self.info.get(self.key))


class HostGaugeInfo():
    def __init__(self, group, info, key, gauge="", ip=""):
        self.gauge = gauge
        self.ip = ip
        self.info = info
        self.key = key
        self.group = group

    def register(self):
        self.gauge.labels(ip=self.ip, group=self.group).set(self.info.get(self.key))


class HostCounterInfo():
    def __init__(self, group, info, key, counter="", ip=""):
        self.counter = counter
        self.ip = ip
        self.info = info
        self.key = key
        self.group = group

    def register(self):
        self.counter.labels(ip=self.ip, group=self.group).inc(self.info.get(self.key))


class RedisGaugeOther():
    def __init__(self, group, ip, value, gauge="", instance=""):
        self.gauge = gauge
        self.instance = instance
        self.group = group
        self.ip = ip
        self.value = value

    def register(self):
        self.gauge.labels(host=self.instance, ip=self.ip, group=self.group).set(self.value)


def redisRegistryMetrics(registry, group, ip, instance, host, port, password):
    checkredis = CheckRedis(port=port, password=password, host=host)

    info = checkredis.get_info()
    clusterinfo = checkredis.get_cluster_info()
    slownum = checkredis.get_slownum()

    redisgauge1 = Gauge("redis_latency", "get redis latency {}".format(port), ["host", "ip", "group"],
                        registry=registry)
    redisggaugeother1 = RedisGaugeOther(group, ip, latency_dict.get("{}:{}".format(ip, port)), gauge=redisgauge1,
                                        instance=instance)
    redisggaugeother1.register()

    redisgauge2 = Gauge("redis_slow_num", "get redis slow num {}".format(port), ["host", "ip", "group"],
                        registry=registry)
    redisggaugeother2 = RedisGaugeOther(group, ip, slownum, gauge=redisgauge2, instance=instance)
    redisggaugeother2.register()

    for key in redis_gauge_list:
        if key == "db0":
            key = "db0_keys"
        redisginfo = Gauge("redis_{}".format(key), "get {}".format(key), ["host", "ip", "group"], registry=registry)
        redisgaugeinfo = RedisGaugeInfo(group, ip, info, key, gauge=redisginfo, instance=instance)
        redisgaugeinfo.register()

    for key in redis_counter_list:
        rediscinfo = Counter("redis_{}".format(key), "get {}".format(key), ["host", "ip", "group"], registry=registry)
        rediscounterinfo = RedisCounterInfo(group, ip, info, key, counter=rediscinfo, instance=instance)
        rediscounterinfo.register()

    for key in redis_cluster_gauge_list:
        redisclusterinfo = Gauge("redis_{}".format(key), "get {}".format(key), ["host", "ip", "group"],
                                 registry=registry)
        regisclustergaugeinfo = RedisClusterGaugeInfo(group, ip, clusterinfo, key, gauge=redisclusterinfo,
                                                      instance=instance)
        regisclustergaugeinfo.register()


def hostRegistryMetrics(registry, group, ip):
    hginfo = getHostGaugeInfo()
    hcinfo = getHostCounterInfo()
    for key in host_gauge_list:
        hostgauge = Gauge("host_{}".format(key), "get {}".format(key), ["ip", "group"], registry=registry)
        hostgaugeinfo = HostGaugeInfo(group, hginfo, key, gauge=hostgauge, ip=ip)
        hostgaugeinfo.register()

    for key in host_counter_list:
        hostcounter = Counter("host_{}".format(key), "get {}".format(key), ["ip", "group"], registry=registry)
        hostcounterinfo = HostCounterInfo(group, hcinfo, key, counter=hostcounter, ip=ip)
        hostcounterinfo.register()


@app.route("/v0/metrics")
def main1():
    registry = CollectorRegistry(auto_describe=False)
    redisRegistryMetrics(registry, clusterName, lip, "{}:{}".format(lip, ports[0]), "127.0.0.1", ports[0],
                         redisPasswd)
    hostRegistryMetrics(registry, "业务_redis非持久化", lip)
    return Response(prometheus_client.generate_latest(registry), mimetype="text/plain")


@app.route("/v1/metrics")
def main2():
    registry = CollectorRegistry(auto_describe=False)
    redisRegistryMetrics(registry, clusterName, lip, "{}:{}".format(lip, ports[1]), "127.0.0.1", ports[1],
                         redisPasswd)
    return Response(prometheus_client.generate_latest(registry), mimetype="text/plain")


@app.route("/v2/metrics")
def main3():
    registry = CollectorRegistry(auto_describe=False)
    redisRegistryMetrics(registry, clusterName, lip, "{}:{}".format(lip, ports[2]), "127.0.0.1", ports[2],
                         redisPasswd)
    return Response(prometheus_client.generate_latest(registry), mimetype="text/plain")


@app.route("/v3/metrics")
def main4():
    registry = CollectorRegistry(auto_describe=False)
    redisRegistryMetrics(registry, clusterName, lip, "{}:{}".format(lip, ports[3]), "127.0.0.1", ports[3],
                         redisPasswd)
    return Response(prometheus_client.generate_latest(registry), mimetype="text/plain")


@app.route("/v4/metrics")
def main5():
    registry = CollectorRegistry(auto_describe=False)
    redisRegistryMetrics(registry, clusterName, lip, "{}:{}".format(lip, ports[4]), "127.0.0.1", ports[4],
                         redisPasswd)
    return Response(prometheus_client.generate_latest(registry), mimetype="text/plain")


def genLatency():
    while True:
        for key in ports:
            cmd = "/usr/bin/redis-cli -h 127.0.0.1 -p %s --latency |awk  '{print $3}'" % key
            status, result = subprocess.getstatusoutput(cmd)
            latency_dict["{}:{}".format(lip, key)] = float(result)
        time.sleep(30)


if __name__ == "__main__":
    t = threading.Thread(target=genLatency)
    t.start()
    app.run(host="0.0.0.0", port=27000)
