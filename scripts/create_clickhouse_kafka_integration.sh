#/bin/bash

# Find names of Kafka and ClickHouse services in current project
kafka_service=$(avn service list -t kafka --format '{service_name}')
clickhouse_service=$(avn service list -t clickhouse --format '{service_name}')

# Create service integration between Kafka and ClickHouse
avn service integration-create -t clickhouse_kafka -s ${kafka_service} -d ${clickhouse_service}

# Find integration ID
integration_id=$(avn service integration-list $clickhouse_service | fgrep clickhouse_kafka | fgrep true | awk '{print $1}')

avn service integration-update ${integration_id} \
--user-config-json '{
    "tables": [
        {
            "name": "digitransit_hfp_bus_positions_flattened",
            "columns": [
                {"name": "desi", "type": "String"},
                {"name": "dir", "type": "String"},
                {"name": "oper", "type": "Int32"},
                {"name": "oper_name", "type": "String"},
                {"name": "veh", "type": "Int32"},
                {"name": "tst", "type": "String"},
                {"name": "tsi", "type": "Int32"},
                {"name": "spd", "type": "Float32"},
                {"name": "hdg", "type": "Int32"},
                {"name": "lat", "type": "Float32"},
                {"name": "long", "type": "Float32"},
                {"name": "acc", "type": "Float32"},
                {"name": "dl", "type": "Int32"},
                {"name": "drst", "type": "Int32"},
                {"name": "oday", "type": "String"},
                {"name": "start", "type": "String"},
                {"name": "loc", "type": "String"},
                {"name": "stop", "type": "String"},
                {"name": "route", "type": "String"},
                {"name": "occu", "type": "Int32"}
            ],
            "topics": [{"name": "digitransit-hfp-bus-positions-flattened"}],
            "data_format": "JSONEachRow",
            "group_name": "65e9b6ef-978e-4746-8714-dfb2cbef6915"
        },        
        {
            "name": "digitransit_hfp_bus_positions_raw",
            "columns": [
                {"name": "VP", "type": "JSON"}
            ],            
            "topics": [{"name": "digitransit_hfp_bus_positions_raw"}],
            "data_format": "JSONEachRow",
            "group_name": "3e4bf765-3418-42bd-b6f9-0378d677d583"
        }
    ]
}'
