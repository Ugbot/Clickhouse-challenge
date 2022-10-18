-- ref https://aiven.slab.com/posts/click-house-service-integrations-mabby40v#h8pnk-kafka-table
DROP VIEW IF EXISTS `default`.`bus_positions`;
CREATE MATERIALIZED VIEW `default`.`bus_positions` ENGINE = ReplicatedMergeTree
ORDER BY tsi AS SELECT * FROM `service_bigdataldn-demo-kafka`.`digitransit_hfp_bus_positions_flattened`;
