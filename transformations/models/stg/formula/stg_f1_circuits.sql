with source  as (

    SELECT * FROM {{ source('formula','circuits') }}

), 

renamed as (
    SELECT circuitid as circuit_id,
           circuitref as circuit_ref,
           name as circuit_name,
           location,
           country,
           lat as latitude,
           lng as longitude,
           alt as altitude
        -- omit the url
    FROM source
)
SELECT * FROM renamed
