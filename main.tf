variable "aiven_api_token" {}
variable "allowed_ips" {}
variable "project_name" {}
variable "kafka_version" {}
variable "service_cloud" {}
variable "service_cloud_alt" {}
variable "service_cloud_flink" {}
variable "service_name_prefix" {}
variable "service_plan_clickhouse" {}
variable "service_plan_flink" {}
variable "service_plan_kafka" {}
variable "service_plan_kafka_connect" {}
variable "service_plan_grafana" {}
variable "service_plan_m3db" {}
variable "service_plan_opensearch" {}
variable "service_plan_pg" {}

terraform {
  required_providers {
    aiven = {
      source = "aiven/aiven"
      version = "3.6.0"
    }
  }
}

provider "aiven" {
  api_token = var.aiven_api_token
}

###################################################
# Apache Kafka
###################################################

resource "aiven_kafka" "demo-kafka" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_kafka
  service_name            = "${var.service_name_prefix}-kafka"
  default_acl             = false
  termination_protection  = false
  kafka_user_config {
    schema_registry = true
    kafka_rest = true
    kafka_connect = false
    kafka_version = var.kafka_version
    ip_filter = var.allowed_ips
    kafka {
      auto_create_topics_enable = false
    }  
    public_access {
      kafka = false
      kafka_rest = false
      kafka_connect = true
      schema_registry = false
    }
  }
}

resource "aiven_kafka_connect" "demo-kafka-connect" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_kafka_connect
  service_name            = "${var.service_name_prefix}-kafka-connect"
  kafka_connect_user_config {
    ip_filter = var.allowed_ips
    public_access {
      kafka_connect = true
      prometheus = true
    }
  }
}

resource "aiven_service_integration" "demo-kafka-connect-source-integration" {
  project                  = var.project_name
  integration_type         = "kafka_connect"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
}

###################################################
# Apache Flink
###################################################

resource "aiven_flink" "demo-flink" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_flink
  service_name            = "${var.service_name_prefix}-flink"
  termination_protection  = true
  flink_user_config {
    parallelism_default = 3
  }
}

resource "aiven_service_integration" "demo-flink-kafka-integration" {
  project                  = var.project_name
  integration_type         = "flink"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_flink.demo-flink.service_name
}

###################################################
# PostgreSQL
###################################################

resource "aiven_pg" "demo-postgres" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_pg
  service_name            = "${var.service_name_prefix}-postgres"
  pg_user_config {
    pg_version            = "14"
  }
}

resource "aiven_service_integration" "demo-flink-postgres-integration" {
  project                  = var.project_name
  integration_type         = "flink"
  source_service_name      = aiven_pg.demo-postgres.service_name
  destination_service_name = aiven_flink.demo-flink.service_name
}

###################################################
# ClickHouse
###################################################

resource "aiven_clickhouse" "demo-clickhouse" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_clickhouse
  service_name            = "${var.service_name_prefix}-clickhouse"
}

# resource "aiven_service_integration" "demo-clickhouse-kafka-integration" {
#   project                  = var.project_name
#   integration_type         = "clickhouse_kafka"
#   source_service_name      = aiven_kafka.demo-kafka.service_name
#   destination_service_name = aiven_clickhouse.demo-clickhouse.service_name
# }

###################################################
# DigiTransit HFP feeds
###################################################

module "digitransit-hfp-bus-positions" {
  source = "./digitransit-hfp"
  connect_integration = aiven_service_integration.demo-kafka-connect-source-integration
  aiven_project_name = var.project_name
  kafka_connect_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
  kafka_service_name = aiven_kafka.demo-kafka.service_name
  kafka_topic_name = "digitransit-hfp-bus-positions-raw"
  mqtt_topic_name = "/hfp/v2/journey/ongoing/vp/bus/+/+/+/+/+/+/+/+/+/+/+/+"
}

module "digitransit-hfp-train-positions" {
  source = "./digitransit-hfp"
  connect_integration = aiven_service_integration.demo-kafka-connect-source-integration
  aiven_project_name = var.project_name
  kafka_connect_service_name = aiven_kafka_connect.demo-kafka-connect.service_name
  kafka_service_name = aiven_kafka.demo-kafka.service_name
  kafka_topic_name = "digitransit-hfp-train-positions-raw"
  mqtt_topic_name = "/hfp/v2/journey/ongoing/vp/train/+/+/+/+/+/+/+/+/+/+/+/+"
}

resource "aiven_flink_table" "demo-flink-table-digitransit-hfp-bus-positions-raw" {
  project              = var.project_name
  service_name         = aiven_flink.demo-flink.service_name
  integration_id       = aiven_service_integration.demo-flink-kafka-integration.integration_id
  kafka_connector_type = "kafka"
  kafka_topic          = "digitransit-hfp-bus-positions-raw"
  table_name           = "digitransit_hfp_bus_positions_raw"
  kafka_value_format   = "json"
  kafka_startup_mode   = "latest-offset"
  # deleted some useless fields to get this column descriptor below < 256 chars and avoid 500 errors from Flink API
  schema_sql = <<EOF
      `VP` ROW<`desi` STRING,`dir` STRING,`oper` INT,`veh` INT,`tst` STRING,`tsi` INT,`spd` FLOAT,`hdg` INT,`lat` FLOAT,`long` FLOAT,`acc` FLOAT,`dl` INT,`drst` INT,`oday` STRING,`start` STRING,`loc` STRING,`stop` STRING,`route` STRING,`occu` INT>
  EOF
}

resource "aiven_kafka_topic" "demo-kafka-topic-digitransit-hfp-bus-positions-flattened" {
  project                  = var.project_name
  service_name             = aiven_kafka.demo-kafka.service_name
  topic_name               = "digitransit-hfp-bus-positions-flattened"
  partitions               = 3
  replication              = 3
  config {
    retention_ms = 1209600000
  }
}

resource "aiven_flink_table" "demo-flink-table-digitransit-hfp-bus-positions-flattened" {
  project              = var.project_name
  service_name         = aiven_flink.demo-flink.service_name
  integration_id       = aiven_service_integration.demo-flink-kafka-integration.integration_id
  kafka_connector_type = "kafka"
  kafka_topic          = "digitransit-hfp-bus-positions-flattened"
  table_name           = "digitransit_hfp_bus_positions_flattened"
  kafka_value_format   = "json"
  kafka_startup_mode   = "latest-offset"
  schema_sql = <<EOF
    `desi` STRING,
    `dir` STRING,
    `oper` INT,
    `oper_name` STRING,
    `veh` INT,
    `tst` STRING,
    `tsi` INT,
    `spd` FLOAT,
    `hdg` INT,
    `lat` FLOAT,
    `long` FLOAT,
    `acc` FLOAT,
    `dl` INT,
    `drst` INT,
    `oday` STRING,
    `start` STRING,
    `loc` STRING,
    `stop` STRING,
    `route` STRING,
    `occu` INT
  EOF
}

resource "aiven_flink_table" "demo-flink-table-digitransit-operators" {
  project              = var.project_name
  service_name         = aiven_flink.demo-flink.service_name
  integration_id       = aiven_service_integration.demo-flink-postgres-integration.integration_id
  jdbc_table           = "public.digitransit_operators"
  table_name           = "digitransit_operators"
  schema_sql = <<EOF
    `id` INT PRIMARY KEY,
    `name` STRING NOT NULL
  EOF
}

resource "aiven_flink_job" "demo-flink-job-digitransit-hfp-bus-position-flattening" {
  project       = var.project_name
  service_name  = aiven_flink.demo-flink.service_name
  job_name      = "digitransit_hfp_bus_positions_flatten"
  table_ids = [
    aiven_flink_table.demo-flink-table-digitransit-hfp-bus-positions-raw.table_id,
    aiven_flink_table.demo-flink-table-digitransit-hfp-bus-positions-flattened.table_id,
    aiven_flink_table.demo-flink-table-digitransit-operators.table_id
  ]                                                           
  statement = <<EOF
    INSERT INTO ${aiven_flink_table.demo-flink-table-digitransit-hfp-bus-positions-flattened.table_name}
    SELECT
      VP.`desi`,
      VP.`dir`,
      VP.`oper`,
      operators.`name`,
      VP.`veh`,
      VP.`tst`,
      VP.`tsi`,
      VP.`spd`,
      VP.`hdg`,
      VP.`lat`,
      VP.`long`,
      VP.`acc`,
      VP.`dl`,
      VP.`drst`,
      VP.`oday`,
      VP.`start`,
      VP.`loc`,
      VP.`stop`,
      VP.`route`,
      VP.`occu`
    FROM ${aiven_flink_table.demo-flink-table-digitransit-hfp-bus-positions-raw.table_name} positions
    INNER JOIN ${aiven_flink_table.demo-flink-table-digitransit-operators.table_name} operators
    ON positions.VP.`oper` = operators.`id`
  EOF                                                                                             
}

# *********************************
# Monitoring services
# *********************************

resource "aiven_m3db" "demo-metrics" {
  project                 = var.project_name 
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_m3db
  service_name            = "${var.service_name_prefix}-metrics"
  m3db_user_config {
    m3db_version          = "1.5"
    ip_filter             = var.allowed_ips
    namespaces {
      name = "default"
      type = "unaggregated"
      options {
        retention_options {
          blocksize_duration        = "2h"
          retention_period_duration = "8d"
        }
      }
    }
  }
}

resource "aiven_grafana" "demo-metrics-dashboard" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_grafana
  service_name            = "${var.service_name_prefix}-metrics-dashboard"
  grafana_user_config {
    ip_filter = var.allowed_ips
    public_access {
      grafana = true
    }
  }
}

# Metrics integration: Kafka -> M3
resource "aiven_service_integration" "demo-metrics-integration-kafka" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_kafka.demo-kafka.service_name
  destination_service_name = aiven_m3db.demo-metrics.service_name
}

# Metrics integration: Flink -> M3
resource "aiven_service_integration" "demo-metrics-integration-flink" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_flink.demo-flink.service_name
  destination_service_name = aiven_m3db.demo-metrics.service_name
}

# Dashboard integration = M3 -> Grafana
resource "aiven_service_integration" "demo-dashboard-integration" {
  project                  = var.project_name
  integration_type         = "dashboard"
  source_service_name      = aiven_grafana.demo-metrics-dashboard.service_name
  destination_service_name = aiven_m3db.demo-metrics.service_name
}

