CREATE TABLE weekends_score_stats AS
SELECT
  day_key,
  MIN(score) AS min_score,
  MAX(score) AS max_score,
  AVG(CAST(score AS DOUBLE)) AS avg_score
FROM weekends_stream
GROUP BY day_key;
