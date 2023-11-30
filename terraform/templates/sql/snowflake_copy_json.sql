copy into ${database}.${schema}.${object_name}
from (
Select         
    METADATA$FILENAME as file_name,
    $1 as json_extract,
    current_timestamp() as loaded_at
from @${database}.${schema}.${object_name}
)