-- Sql scripts tools
-- Resolved max crate_id
SELECT MAX(crate_id) FROM dep_version INNER JOIN versions on dep_version.version_from=versions.id
-- Find Current Max resolved Offset
with max_crate as (SELECT MAX(crate_id) 
FROM dep_version INNER JOIN versions on dep_version.version_from=versions.id) 
SELECT COUNT(versions) FROM versions WHERE versions.crate_id<ANY(SELECT max FROM max_crate)

-- Indirect Current resolved Crates_from counts
SELECT COUNT(DISTINCT crate_id) FROM dep_version INNER JOIN versions ON dep_version.version_from=versions.crate_id
-- Indirect Current resolved Version_from counts
SELECT COUNT(DISTINCT version_from) FROM dep_version 
-- Yanked versions that have dependencies
SELECT COUNT(DISTINCT versions.id) FROM dependencies INNER JOIN versions 
ON versions.id = dependencies.version_id WHERE versions.yanked = true
-- Select unresolved version including yanked version)
SELECT COUNT(*) FROM versions WHERE 
id NOT IN (SELECT DISTINCT version_from FROM dep_version) AND
id IN (SELECT DISTINCT version_id FROM dependencies) AND
id NOT IN (SELECT ver FROM dep_errors) ;
-- Find ver with no direct dependency
WITH dep_dis_ver AS
(SELECT DISTINCT version_from FROM dep_version)
SELECT * FROM dep_dis_ver WHERE version_from NOT IN (SELECT DISTINCT version_id FROM dependencies) LIMIT 100;
-- Find crates whose versions are all yanked
SELECT crate_id FROM versions WHERE crate_id NOT IN 
(SELECT DISTINCT crate_id FROM versions WHERE yanked = false);

-- Export DATABASE 
copy dep_version to 'version_dep.csv' WITH CSV DELIMITER ',';


-- Hot Keywords by Crates
SELECT * FROM keywords ORDER BY crates_cnt desc LIMIT 100 
-- Hot Keywords by Downloads
with hot_keywords as 
(SELECT SUM(downloads) as total_downloads, keyword_id FROM crates_keywords INNER JOIN crates ON crate_id=id GROUP BY keyword_id )
SELECT keyword, total_downloads FROM hot_keywords INNER JOIN keywords ON keyword_id=id ORDER BY total_downloads desc LIMIT 100
-- Hot Category by Crates
SELECT * FROM categories ORDER BY crates_cnt desc LIMIT 100 
-- Hot Category by Downloads
with hot_categories  as 
(SELECT SUM(downloads) as total_downloads, category_id FROM crates_categories  INNER JOIN crates ON crate_id=id GROUP BY category_id )
SELECT category, total_downloads FROM hot_categories  INNER JOIN categories ON category_id=id ORDER BY total_downloads desc LIMIT 100

-- Owner: 78924/78935 crates have owner, 
-- -- and each crates may have multiple owners but only one creator.
-- Hot Owner by Crates
SELECT owner_id  ,COUNT(crate_id) as owned_count FROM crate_owners GROUP BY owner_id ORDER BY owned_count desc LIMIT 100
-- Hot Owner by Downloads
with hot_owner  as 
(SELECT SUM(downloads) as total_downloads, owner_id, COUNT(id) as count_crates FROM crate_owners INNER JOIN crates ON crate_id=id GROUP BY owner_id )
SELECT name, total_downloads, count_crates  , gh_login as GithubAccount, gh_avatar as GithubAvatar, gh_id as GithubID FROM hot_owner  INNER JOIN users ON owner_id =id ORDER BY total_downloads desc LIMIT 100
-- Hot Owner by Indir Dependents (Need to build table `dep_crate` first)
WITH hot_owner AS 
(SELECT owner_id, COUNT(DISTINCT crate_from) AS total_dependents FROM crate_owners INNER JOIN dep_crate ON crate_id=crate_to GROUP BY owner_id)
SELECT name, total_dependents, gh_login as GithubAccount, gh_avatar as GithubAvatar, gh_id as GithubID 
FROM hot_owner INNER JOIN users ON owner_id =id ORDER BY total_dependents desc LIMIT 100

-- Accumulative Hot Owner by Indir Dependents of TOP `N=50` (`N`<=50)
-- ATTENTION: It uses table `hot_owner`. 
DROP TABLE IF EXISTS tmp_owner_indir_crate,tmp_hot_owner_id,accumulate_hot_owners,accumulate_hot_owners_10near;
CREATE TEMP TABLE tmp_owner_indir_crate AS
(SELECT DISTINCT owner_id,  crate_from  FROM crate_owners INNER JOIN dep_crate ON crate_id=crate_to);
CREATE TEMP TABLE tmp_hot_owner_id AS
(SELECT owner_id, COUNT(DISTINCT crate_from) AS total_dependents FROM tmp_owner_indir_crate 
GROUP BY owner_id ORDER BY total_dependents desc LIMIT 100);
CREATE TABLE accumulate_hot_owners(
    accumulative_num integer PRIMARY KEY,
    crates_count integer
);
do 
$$
declare
	N integer;
begin
	IF EXISTS (
    SELECT FROM 
        information_schema.tables 
    WHERE
        table_name = 'accumulate_hot_owners'
    )THEN
        for N in 1..100 loop
            INSERT INTO accumulate_hot_owners 
            SELECT N, COUNT(DISTINCT crate_from) AS total_dependents FROM tmp_owner_indir_crate  WHERE owner_id 
            IN (SELECT owner_id FROM tmp_hot_owner_id LIMIT N);
        end loop;
    END IF;
end; 
$$;

CREATE TABLE accumulate_hot_owners_10near(
    near_accumulative_num integer PRIMARY KEY,
    crates_count integer
);
-- 10 Near Accumulative Hot Owner by Indir Dependents of TOP `N=50`
do 
$$
declare
	N integer;
begin
	IF EXISTS (
    SELECT FROM 
        information_schema.tables 
    WHERE
        table_name = 'accumulate_hot_owners_10near'
    )THEN
        for N in 0..50 loop
            INSERT INTO accumulate_hot_owners_10near 
            SELECT N, COUNT(DISTINCT crate_from) AS total_dependents FROM tmp_owner_indir_crate  WHERE owner_id 
            IN (SELECT owner_id FROM tmp_hot_owner_id OFFSET N LIMIT 10);
        end loop;
    END IF;
end; 
$$;

-- How many owners do hot crates have
SELECT name as crate_name, COUNT(owner_id) as owner_count, downloads FROM crates INNER JOIN crate_owners ON id=crate_id GROUP BY id ORDER BY downloads desc LIMIT 100
-- Top 500 (Downloads) owners
SELECT * FROM crate_owners WHERE crate_id IN (SELECT id FROM crates ORDER BY downloads desc LIMIT 500);




