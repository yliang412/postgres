set pg_feedback.enabled = true;
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) SELECT *
FROM title
WHERE 
    -- id: all positive integers (assuming no id <= 0)
    id > 0
    
    -- title: all non-empty strings (NOT NULL constraint ensures this)
    AND title IS NOT NULL
    
    -- imdb_index: all values including NULL
    AND (imdb_index IS NULL OR imdb_index IS NOT NULL)
    
    -- kind_id: all positive integers
    AND kind_id > 0
    
    -- production_year: reasonable movie years (1800-2100)
    AND (production_year IS NULL OR production_year BETWEEN 1800 AND 2100)
    
    -- imdb_id: all values including NULL
    AND (imdb_id IS NULL OR imdb_id >= 0)
    
    -- phonetic_code: all values including NULL
    AND (phonetic_code IS NULL OR LENGTH(phonetic_code) <= 5)
    
    -- episode_of_id: all values including NULL
    AND (episode_of_id IS NULL OR episode_of_id > 0)
    
    -- season_nr: all values including NULL
    AND (season_nr IS NULL OR season_nr >= 0)
    
    -- episode_nr: all values including NULL
    AND (episode_nr IS NULL OR episode_nr >= 0)
    
    -- series_years: all values including NULL
    AND (series_years IS NULL OR LENGTH(series_years) <= 49)
    
    -- md5sum: all values including NULL (valid MD5 is 32 chars)
    AND (md5sum IS NULL OR LENGTH(md5sum) = 32);