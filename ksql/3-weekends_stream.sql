CREATE STREAM weekends_stream
WITH (
  KAFKA_TOPIC  = 'weekends',
  VALUE_FORMAT = 'JSON'
) AS
SELECT day_key, id, score, name
FROM source_events
WHERE UCASE(day_key) IN ('SATURDAY','SUNDAY')
EMIT CHANGES;
