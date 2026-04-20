CREATE TABLE weekdays_score_stats AS
SELECT
  day_key,
  MIN(score) AS min_score,
  MAX(score) AS max_score,
  AVG(CAST(score AS DOUBLE)) AS avg_score
FROM weekdays_stream
GROUP BY day_key;
