//Create Snowflake Warehouse
resource "snowflake_warehouse" "warehouse" {
  name              = upper(replace(local.project_name, "-", "_"))
  comment           = "foo"
  warehouse_size    = "x-small"
  max_cluster_count = 1
  scaling_policy    = "ECONOMY"
}


// Create Snowflake Database
resource "snowflake_database" "db" {
  provider = snowflake
  name     = upper(replace(local.project_name, "-", "_"))
  comment  = "Database created for snowflake by terraform."
}

// Create Snowflake Schema
resource "snowflake_schema" "schema" {
  provider = snowflake
  database = snowflake_database.db.name
  name     = upper(var.environment)
  comment  = "Schema for ${upper(var.environment)} schema created by terraform."
}

// Create Snowflake Table
resource "snowflake_table" "json_table" {
  database = snowflake_schema.schema.database
  schema   = snowflake_schema.schema.name
  name     = upper(replace(local.project_name, "-", "_"))
  comment  = "Table where data from ${upper(replace(local.project_name, "-", "_"))} pipe will be loaded."


  column {
    name     = "FILE_NAME"
    type     = "VARCHAR(100)"
    nullable = false
  }

  column {
    name     = "JSON_EXTRACT"
    type     = "VARIANT"
    nullable = false
  }

  column {
    name     = "LOADED_AT"
    type     = "TIMESTAMP_NTZ(9)"
    nullable = false
  }

}

// Create storage integration with S3 
resource "snowflake_storage_integration" "storage_integration" {
  name    = "${local.config.project_name}-integration"
  comment = "A storage integration."
  type    = "EXTERNAL_STAGE"

  enabled = true

  storage_allowed_locations = ["s3://${aws_s3_bucket.bucket.id}"]
  storage_provider     = "S3"
  storage_aws_role_arn = "${local.role_arn}-snowflake-access-role"
}

// Create stage for each loader with configured file format
resource "snowflake_stage" "stage" {

  name                = upper(replace(local.project_name, "-", "_"))
  database            = snowflake_database.db.name
  schema              = snowflake_schema.schema.name
  storage_integration = snowflake_storage_integration.storage_integration.name

  url         = "s3://${aws_s3_bucket.bucket.id}"
  file_format = "TYPE = JSON NULL_IF = []"
}

// Create snowpipe
resource "snowflake_pipe" "pipe" {

  database = snowflake_database.db.name
  schema   = snowflake_schema.schema.name
  name     = upper(replace(local.project_name, "-", "_"))

  comment = "A pipe that moves data from ${upper(replace(local.project_name, "-", "_"))} stage to corresponding table."

  copy_statement = templatefile("templates/sql/snowflake_copy_json.sql",
    {
      database    = snowflake_database.db.name
      schema      = snowflake_schema.schema.name
      object_name = upper(replace(local.project_name, "-", "_"))
    }
  )
  auto_ingest = true
  depends_on = [
    #Pipe requires storage integration before creation
    snowflake_storage_integration.storage_integration,

    # Pipe requires some time while the external_id updates in the snowflake role
    time_sleep.wait_15_seconds,

    #Pipe requires stage before creation
    snowflake_stage.stage
  ]
}