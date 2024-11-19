-- Remove duplicated rows
SELECT DISTINCT * 
INTO deduped_lab_results 
FROM lab_results;

-- Handling Missing Values - Discard instances where age was recorded as 123
SELECT * 
INTO clean_lab_results 
FROM deduped_lab_results 
WHERE age != 123;

-- Filtering Valid Results - Retain only rows where the result is numeric and convert to FLOAT
SELECT *,
       TRY_CAST(result AS FLOAT) AS Result_FLOAT
INTO valid_lab_results_temp
FROM clean_lab_results 
WHERE ISNUMERIC(result) = 1
AND TRY_CAST(result AS FLOAT) IS NOT NULL;

-- Create separate tables for each Service resource
DECLARE @service_resource NVARCHAR(255);
DECLARE service_resource_cursor CURSOR FOR
SELECT DISTINCT [Service resource] FROM valid_lab_results;

OPEN service_resource_cursor;
FETCH NEXT FROM service_resource_cursor INTO @service_resource;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @query NVARCHAR(MAX);
    SET @query = 'SELECT * INTO service_resource_' + REPLACE(@service_resource, ' ', '_') + ' FROM valid_lab_results WHERE [Service resource] = ''' + @service_resource + '''';
    EXEC sp_executesql @query;
    
    FETCH NEXT FROM service_resource_cursor INTO @service_resource;
END

CLOSE service_resource_cursor;
DEALLOCATE service_resource_cursor;

-- Create separate tables for each DTA
DECLARE @dta NVARCHAR(255);
DECLARE dta_cursor CURSOR FOR
SELECT DISTINCT DTA FROM valid_lab_results;

OPEN dta_cursor;
FETCH NEXT FROM dta_cursor INTO @dta;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @query_dta NVARCHAR(MAX);
    SET @query_dta = 'SELECT * INTO DTA_' + REPLACE(@dta, ' ', '_') + ' FROM valid_lab_results WHERE DTA = ''' + @dta + '''';
    EXEC sp_executesql @query_dta;
    
    FETCH NEXT FROM dta_cursor INTO @dta;
END

CLOSE dta_cursor;
DEALLOCATE dta_cursor;

-- Apply Constant Error (CE) selectively to specific periods
SELECT *,
       CASE 
           WHEN Recorded BETWEEN '2023-02-01' AND '2023-02-07' 
           THEN Result_FLOAT + 5 
           ELSE Result_FLOAT 
       END AS Result_CE
INTO biased_lab_results_constant
FROM valid_lab_results;

-- Apply Proportional Error (PE) selectively to specific periods
SELECT *,
       CASE 
           WHEN Recorded BETWEEN '2023-02-01' AND '2023-02-07' 
           THEN Result_FLOAT * 1.02 
           ELSE Result_FLOAT 
       END AS Result_PE
INTO biased_lab_results_proportional
FROM valid_lab_results;


-- Apply Random Error (RE) selectively to specific periods
SELECT *,
       CASE 
           WHEN Recorded BETWEEN '2023-02-01' AND '2023-02-07' 
           THEN Result_FLOAT + (0.1 * Result_FLOAT * RAND())
           ELSE Result_FLOAT 
       END AS Result_RE
INTO biased_lab_results_random
FROM valid_lab_results;

-- Create a view for the preprocessed data

GO

CREATE VIEW preprocessed_lab_results AS
SELECT 
    Facility,
    Ward,
    MRN,
    Age,
    [Service resource],
    Accessin,
    DTA,
    Result_FLOAT AS Result,
    Ord,
    Coll,
    Recorded,
    Verified,
    time_diff,
    time_of_day
FROM valid_lab_results;