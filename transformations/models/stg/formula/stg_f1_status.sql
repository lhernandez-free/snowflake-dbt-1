with source  as (

    select * from {{ source('formula','status') }}

), 

renamed as (
    select 
        statusid as status_id,
        status 
    from source
)

select * from renamed 