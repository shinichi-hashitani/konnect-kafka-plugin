CREATE STREAM weekdays_stream
WITH (
  KAFKA_TOPIC  = 'weekdays',
  VALUE_FORMAT = 'JSON'
) AS
SELECT day_key, id, score, name
FROM source_events
WHERE UCASE(day_key) IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY')
EMIT CHANGES;
