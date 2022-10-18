variable "aiven_project_name" {
  type = string
}

variable "kafka_service_name" {
  type = string
}

variable "kafka_connect_service_name" {
  type = string
}

variable "kafka_topic_name" {
  type = string
}

variable "mqtt_topic_name" {
  type = string
}

variable "connect_integration" {
  type    = any
  default = []
}
