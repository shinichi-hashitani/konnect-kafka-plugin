CREATE STREAM source_events (
  day_key VARCHAR KEY,
  id      VARCHAR,
  score   INTEGER,
  ip      VARCHAR,
  name    VARCHAR,
  day     VARCHAR
) WITH (
  KAFKA_TOPIC  = 'source',
  KEY_FORMAT   = 'KAFKA',
  VALUE_FORMAT = 'JSON'
);
