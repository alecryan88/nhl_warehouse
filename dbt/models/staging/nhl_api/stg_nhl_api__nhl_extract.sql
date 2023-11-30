with 

source as (

    select * from {{ source('nhl_api', 'nhl_extract') }}

),

renamed as (

    select
        file_name,
        json_extract,
        loaded_at

    from source

)

select * 
from renamed