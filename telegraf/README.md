Telegraf configuration

- `telegraf.conf` is mounted into the `telegraf` container at `/etc/telegraf/telegraf.conf`.
- MQTT logs for `iot/+/message` are sent to Loki with `device_id` and `service_id` labels.

Quick checks:

```sh
docker compose restart telegraf
curl -sS -G \
  --data-urlencode 'query={__name="iot_log"}' \
  --data-urlencode "start=$(($(date +%s)-300))000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode 'limit=5' \
  http://localhost:3100/loki/api/v1/query_range
```
