CREATE OR REPLACE FUNCTION explain_json(_qry text, _analyze boolean = TRUE)
  RETURNS jsonb
  LANGUAGE plpgsql AS
$$
DECLARE
  _result jsonb;
  _options text;
BEGIN
  IF _analyze THEN
    _options := '(FORMAT JSON, ANALYZE)';
  ELSE
    _options := '(FORMAT JSON)';
  END IF;

  EXECUTE format('EXPLAIN %s %s', _options, _qry)
  INTO _result;
  
  RETURN _result;
END
$$;


CREATE OR REPLACE FUNCTION show_card_est(_qry text)
  RETURNS TABLE(estimate double precision, actual double precision, "q-error" double precision)
  LANGUAGE sql AS
$$
    WITH cte as (
        SELECT (output->0->'Plan'->>'Plan Rows')::double precision estimate, (output->0->'Plan'->>'Actual Rows')::double precision actual 
        FROM explain_json(_qry) as f(output)
    ) 
    SELECT estimate, actual, ROUND(GREATEST(estimate/actual, actual/estimate)::numeric, 2) as "q-error" FROM cte;
$$;

-- WITH cte as (SELECT (output->0->'Plan'->>'Plan Rows')::double precision estimate, (output->0->'Plan'->>'Actual Rows')::double precision actual FROM explain_json('select * from orders where total_amount < 200 and status in (''Cancelled'')') as f(output)) SELECT estimate, actual, ROUND(GREATEST(estimate/actual, actual/estimate)::numeric, 2) as "q-error" FROM cte;