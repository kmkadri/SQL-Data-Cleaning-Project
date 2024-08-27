-- Create Backup: Before starting the data cleaning it is good practice to create the backup of your data.
CREATE TABLE laptops_backup like laptops;

INSERT INTO laptops 
SELECT * FROM laptops;

/* Check the size of the dataset: 
To check the size of the dataset, calculate the row count of all the entries to know the exact number of rows in the dataset and the result shows 1303 rows and 13 columns.*/

SELECT COUNT(*) FROM laptops;

/*
Drop Non-Important Columns: 
Dropping the columns which are not important, in the following data there was a column which is named “Unamed:0”. 
*/
ALTER TABLE laptops DROP COLUMN `Unnamed: 0`;

/*
Drop Null Values: 
While manually assessing the dataset, I found that the dataset contains a few NULL rows so we need to clean that values. 
After executing the below query we have dropped around 32 rows in the dataset which contains null values.
*/
With index_values AS(SELECT `index`
    FROM laptops 
    WHERE Company IS NULL
      AND TypeName IS NULL
      AND Inches IS NULL
      AND ScreenResolution IS NULL
      AND Cpu IS NULL
      AND Ram IS NULL
      AND Memory IS NULL
      AND GPU IS NULL
      AND OpSys IS NULL
      AND Weight IS NULL
      AND price IS NULL)
      
DELETE laptops 
FROM laptops 
JOIN index_values ONlaptops.`index` = index_values.`index`
WHERE laptops.`index` = index_values.`index`;

/*
Check Duplicate Values: 
It is good to check for duplicate values in the data. 
But in this data, there are no duplicated values.
*/
SELECT Company,TypeName,Inches,ScreenResolution,
        Cpu,Ram,Memory,GPU,OpSys,Weight,price,COUNT(*)
FROM laptops_backup
GROUP BY Company,TypeName,Inches,ScreenResolution,Cpu,Ram,
          Memory,GPU,OpSys,Weight,price
HAVING COUNT(*) > 1;

/*
Let's Check Datatypes of Columns: 
While checking the datatypes of columns in this data, I got to know that the datatypes for some columns are inappropriate like Weight, Price, Ram, etc.
*/
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'laptops';

-- Correcting the Datatype of the column named Inches
ALTER TABLE laptops MODIFY COLUMN Inches DECIMAL(10,1);

-- Before Correcting the datatype of Price columns, Firstly, we need to round the Price Value.
UPDATE laptops
SET Price = ROUND(Price);

ALTER TABLE laptops MODIFY COLUMN Price INTEGER;

/*
Weight column contains measurement values Kg which is inappropriate and unnecessary. 
So, I have decided to remove the Kg keyword and convert it into decimal values.
*/
-- Removing the Kg keyword

UPDATE laptops
set Weight = REPLACE(Weight,'kg','');

-- Changing the datatype

ALTER TABLE laptops MODIFY COLUMN Weight Decimal(10,1);

/*
Ram column contains measurement values that are inappropriate and unnecessary. 
So, I have decided to remove the gb keyword and convert it into decimal values.
*/
-- Removing the GB keyword

UPDATE laptops
set Ram = REPLACE(Weight,'GB','');

-- Changing the datatype

ALTER TABLE laptops MODIFY COLUMN Ram INTEGER;

/*
Cleaning the Remaining Column: 
I decided to clean the remaining columns and format them in a customized way so that they can be used in the data model and analysis.

Creating new columns for Resolution weight and height. 
So Firstly, we need to create columns named Resolution_weight and Resolution_height.
*/
-- Creating the new Columns

ALTER TABLE laptops
ADD COLUMN resolution_width INTEGER AFTER ScreenResolution,
ADD COLUMN resolution_height INTEGER AFTER resolution_width;

-- Extracting the resolution_height
update laptops 
set resolution_height = substring_index(substring_index(ScreenResolution,' ',-1),'x',1);

-- Extracting the resolution_width 
update laptops 
set resolution_width = substring_index(substring_index(ScreenResolution,' ',-1),'x',-1);

/*
After creating the resolution columns, I got to know that the resolution column also contains information about the TouchScreen laptops. 
So, I decided to create a column for touchscreen information. 
This column contains two values which are 0 — indicates not a touchscreen laptop and 1- indicates touchscreen laptop.
*/
-- adding a new column

ALTER TABLE laptops
ADD COLUMN is_touchscreen INTEGER AFTER ScreenResolution;

-- Updating the values in new column

UPDATE laptops 
set is_touchscreen = CASE WHEN ScreenResolution LIKE '%touchscreen%' THEN 1 ELSE 0 END

-- Next CPU column contains three pieces of information which are cpu brand, cpu name , cpu speed.
-- Creating the new Columns

ALTER TABLE laptops
ADD COLUMN cpu_brand VARCHAR(255) AFTER cpu,
ADD COLUMN cpu_name VARCHAR(255) AFTER cpu_brand,
ADD COLUMN cpu_speed DECIMAL(10,1) AFTER cpu_name;


-- updating the values in new column
UPDATE laptops 
SET cpu_brand = substring_index(Cpu,' ',1);

update laptops
SET cpu_speed = replace(substring_index(Cpu,' ',-1),'GHz','');

update laptops
SET cpu_name = replace(replace(Cpu,cpu_brand,' ' ),substring_index(Cpu,' ',-1),' ');

/*
Next Memory Column contains information about memory type (eg. SSD, HDD), primary memory, and secondary memory. 
So, I decided to create three new columns and I will extract the values from the Memory column.
*/
-- Creating the new Columns

ALTER TABLE laptops
ADD COLUMN memory_type VARCHAR(255) AFTER memory,
ADD COLUMN primary_storage INT AFTER memory_type,
ADD COLUMN secondary_storage INT AFTER primary_storage;

-- updating the values in new column

UPDATE laptops
SET memory_type = CASE
  WHEN Memory LIKE '%ssd%' AND Memory LIKE '%hdd%' THEN 'Hybrid'
  WHEN Memory LIKE '%flash storage%' AND Memory LIKE '%hdd%' THEN 'Hybrid'
  WHEN Memory LIKE '%ssd%' THEN 'SSD'
  WHEN Memory LIKE '%hdd%' THEN 'HDD'
  WHEN Memory LIKE '%flash storage%' THEN 'Flash Storage'
  ELSE NULL
   END

UPDATE laptops
SET primary_storage = regexp_substr(substring_index(memory,'+',1),'[0-9]+'),
secondary_storage = CASE WHEN memory LIKE '%+%' THEN regexp_substr(substring_index(memory,'+',-1),'[0-9]+') ELSE 0 END;

/*
After creating columns, I got to know that some of the data Memory contains in TB but remaining in MB. 
So, I decided to convert TB values into MB values by multiplying with 1024(1 TB = 1024).
*/
UPDATE laptops
SET primary_storage = CASE WHEN primary_storage <=2 THEN primary_storage*1024 ELSE primary_storage END,
secondary_storage = CASE WHEN secondary_storage <=2 THEN secondary_storage*1024 ELSE secondary_storage END;

-- Next gpu column contains two pieces of information which are gpu brand, and gpu name.
-- Creating the new Columns

ALTER TABLE laptops 
ADD COLUMN gpu_brand VARCHAR(255) AFTER Gpu,
ADD COLUMN gpu_name VARCHAR(255) AFTER gpu_brand;

-- updating the values in new column 

UPDATE laptops 
SET t1.gpu_brand = substring_index(Gpu,' ',1);

UPDATE laptops
SET t1.gpu_name = replace(Gpu,gpu_brand,'');

-- Editing the Operating system column because it contains the values with there version like windows 7,windows10.

-- Editing the OS column

UPDATE laptops
SET t1.OpSys = CASE
               when OpSys like '%mac%' Then 'macos'
               when OpSys like 'windows%' Then 'windows'
               when OpSys like '%linux%' Then 'linux'
               when OpSys like 'No OS' Then 'N/A'
               else 'other'
              END;

-- The final step was taking down some columns which were unncessary and not needed for further analysis.
ALTER TABLE laptops
DROP COLUMN ScreenResolution,Cpu, Gpu, Memory;

