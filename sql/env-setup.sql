-- 1.- Creating VW
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE XSMALL_SNOWFLAKE_DBT WITH COMMENT = 'X-Small: max cluster 3'
    WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'ECONOMY';

USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE SMALL_SNOWFLAKE_DBT WITH COMMENT = 'Small: max cluster 3'
    WAREHOUSE_SIZE = 'SMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'ECONOMY';

-- 2.- Creating Databases
USE ROLE SYSADMIN;
CREATE OR REPLACE DATABASE SNOWFLAKE_DBT COMMENT = 'SNOWFLAKE_DBT DEMO'
 DATA_RETENTION_TIME_IN_DAYS = 3
 MAX_DATA_EXTENSION_TIME_IN_DAYS = 3;

-- 3.- Creating schemas
USE DATABASE SNOWFLAKE_DBT;
CREATE OR REPLACE SCHEMA SNOWFLAKE_DBT.RAW WITH MANAGED ACCESS
COMMENT = 'RAW data';

CREATE OR REPLACE SCHEMA SNOWFLAKE_DBT.STG WITH MANAGED ACCESS
COMMENT = 'STG data';

CREATE OR REPLACE SCHEMA SNOWFLAKE_DBT.INTERMEDIATE WITH MANAGED ACCESS
COMMENT = 'INTERMEDIATE data';

CREATE OR REPLACE SCHEMA SNOWFLAKE_DBT.MARTS WITH MANAGED ACCESS
COMMENT = 'MARTS data';

-- 4.- Creating simple Snowpark python Stored Procedure
USE ROLE SYSADMIN;
CREATE OR REPLACE PROCEDURE SNOWFLAKE_DBT.STG.REPLICATE_LIMIT(from_table STRING, to_table STRING, count INT)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'Simple transformation Python Stored Procedure'
AS
$$
def run(session, from_table, to_table, count):
  session.table(from_table).limit(count).write.save_as_table(to_table)
  return "SUCCESS"
$$;

-- 5.- Creating a bit more complex Snowpark python Stored Procedure
USE ROLE SYSADMIN;
CREATE OR REPLACE PROCEDURE SNOWFLAKE_DBT.STG.TOP_IMDB_SCORE_MOVIES(table_credits STRING, table_titles STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
PACKAGES = ('snowflake-snowpark-python', 'numpy', 'pandas')
HANDLER = 'run'
COMMENT = 'Getting top IMDB_SCORE movies'
AS
$$
def run(session, table_credits, table_titles):
  import pandas as pd
  # Loading tables
  sp_df_credits = session.table(table_credits)
  sp_df_titles = session.table(table_titles)

  # Transforming to pandas dfs
  df_credits = sp_df_credits.to_pandas()
  df_titles = sp_df_titles.to_pandas()

  # Merging the dataframes
  df_merge = pd.merge(df_titles, df_credits, on="ID", how="inner")
  df_merge['AGGREGATOR'] = 1
  df_merge = df_merge.groupby(['TITLE','RELEASE_YEAR','IMDB_SCORE']).agg({'AGGREGATOR': 'sum'}).sort_values(by = ['IMDB_SCORE'], ascending=[False])[1:50]
  df_merge.reset_index(inplace=True)
  df_merge.columns = ['TITLE', 'RELEASE_YEAR', 'IMDB_SCORE', 'NUMBER_OF_ACTORS']

  df_merge['TITLE'] = df_merge['TITLE'].apply(lambda x: x.upper())

  # Converting pandas df into a snowpark dataframe
  df = session.create_dataframe(df_merge)
  df.write.save_as_table(table_name='STG_TOP_IMDB_SCORE_MOVIES',mode="overwrite")

  return "SUCCESS"
$$;

USE ROLE USERADMIN;

CREATE OR REPLACE USER DBTDEMO
 LOGIN_NAME = 'DBTDEMO'
 DISPLAY_NAME = 'DBTDEMO'
 PASSWORD = 'XXX'
 DEFAULT_ROLE = SYSTEMADMIN
 DEFAULT_WAREHOUSE = SMALL_SNOWFLAKE_DBT
 DEFAULT_NAMESPACE = SNOWFLAKE_DBT
 MUST_CHANGE_PASSWORD = FALSE;

USE ROLE SECURITYADMIN;
GRANT ROLE SYSADMIN TO USER DBTDEMO;

/*
This is our setup script to create a new database for SNOWFLAKE_DBT data in Snowflake.
We are copying data from a public s3 bucket into snowflake by defining our csv format and snowflake stage. 
*/
-- create and define our formula1 database

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_DBT;
USE SCHEMA RAW;

-- define our file format for reading in the csvs 
CREATE OR REPLACE FILE FORMAT CSVFORMAT
TYPE = CSV
FIELD_DELIMITER =','
FIELD_OPTIONALLY_ENCLOSED_BY = '"', 
SKIP_HEADER=1; 

-- define our stage that is pointing to S3 bucket
CREATE OR REPLACE STAGE FORMULA1_STAGE
FILE_FORMAT = CSVFORMAT 
URL = 'S3://snowflake-s3-sfc-demo-ep/formula1/';

LS @FORMULA1_STAGE;

-- we are first creating the table then copying our data in from s3
-- think of this as an empty container or shell that we are then filling
CREATE OR REPLACE TABLE CIRCUITS (
	CIRCUITID NUMBER(38,0),
	CIRCUITREF VARCHAR(16777216),
	NAME VARCHAR(16777216),
	LOCATION VARCHAR(16777216),
	COUNTRY VARCHAR(16777216),
	LAT FLOAT,
	LNG FLOAT,
	ALT NUMBER(38,0),
	URL VARCHAR(16777216)
);

-- copy our data from public s3 bucket into our tables 
COPY INTO CIRCUITS 
FROM @FORMULA1_STAGE/circuits.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.CONSTRUCTORS (
	CONSTRUCTORID NUMBER(38,0),
	CONSTRUCTORREF VARCHAR(16777216),
	NAME VARCHAR(16777216),
	NATIONALITY VARCHAR(16777216),
	URL VARCHAR(16777216)
);
COPY INTO CONSTRUCTORS 
FROM @FORMULA1_STAGE/constructors.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.DRIVERS (
	DRIVERID NUMBER(38,0),
	DRIVERREF VARCHAR(16777216),
	NUMBER VARCHAR(16777216),
	CODE VARCHAR(16777216),
	FORENAME VARCHAR(16777216),
	SURNAME VARCHAR(16777216),
	DOB DATE,
	NATIONALITY VARCHAR(16777216),
	URL VARCHAR(16777216)
);
COPY INTO DRIVERS
FROM @FORMULA1_STAGE/drivers.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.LAP_TIMES (
	RACEID NUMBER(38,0),
	DRIVERID NUMBER(38,0),
	LAP NUMBER(38,0),
	POSITION FLOAT,
	TIME VARCHAR(16777216),
	MILLISECONDS NUMBER(38,0)
);
COPY INTO LAP_TIMES 
FROM @FORMULA1_STAGE/lap_times.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.PIT_STOPS (
	RACEID NUMBER(38,0),
	DRIVERID NUMBER(38,0),
	STOP NUMBER(38,0),
	LAP NUMBER(38,0),
	TIME VARCHAR(16777216),
	DURATION VARCHAR(16777216),
	MILLISECONDS NUMBER(38,0)
);
COPY INTO PIT_STOPS 
FROM @FORMULA1_STAGE/pit_stops.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.RACES (
	RACEID NUMBER(38,0),
	YEAR NUMBER(38,0),
	ROUND NUMBER(38,0),
	CIRCUITID NUMBER(38,0),
	NAME VARCHAR(16777216),
	DATE DATE,
	TIME VARCHAR(16777216),
	URL VARCHAR(16777216),
	FP1_DATE VARCHAR(16777216),
	FP1_TIME VARCHAR(16777216),
	FP2_DATE VARCHAR(16777216),
	FP2_TIME VARCHAR(16777216),
	FP3_DATE VARCHAR(16777216),
	FP3_TIME VARCHAR(16777216),
	QUALI_DATE VARCHAR(16777216),
	QUALI_TIME VARCHAR(16777216),
	SPRINT_DATE VARCHAR(16777216),
	SPRINT_TIME VARCHAR(16777216)
);
COPY INTO RACES 
FROM @FORMULA1_STAGE/races.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.RESULTS (
	RESULTID NUMBER(38,0),
	RACEID NUMBER(38,0),
	DRIVERID NUMBER(38,0),
	CONSTRUCTORID NUMBER(38,0),
	NUMBER NUMBER(38,0),
	GRID NUMBER(38,0),
	POSITION FLOAT,
	POSITIONTEXT VARCHAR(16777216),
	POSITIONORDER NUMBER(38,0),
	POINTS NUMBER(38,0),
	LAPS NUMBER(38,0),
	TIME VARCHAR(16777216),
	MILLISECONDS NUMBER(38,0),
	FASTESTLAP NUMBER(38,0),
	RANK NUMBER(38,0),
	FASTESTLAPTIME VARCHAR(16777216),
	FASTESTLAPSPEED FLOAT,
	STATUSID NUMBER(38,0)
);
COPY INTO RESULTS 
FROM @FORMULA1_STAGE/results.csv
ON_ERROR='CONTINUE';

CREATE OR REPLACE TABLE RAW.STATUS (
	STATUSID NUMBER(38,0),
	STATUS VARCHAR(16777216)
);
COPY INTO STATUS 
FROM @FORMULA1_STAGE/status.csv
ON_ERROR='CONTINUE';
