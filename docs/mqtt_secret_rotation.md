# MQTT Secret Rotation (Vault AppRole secret_id)

## Goal
- Rotate AppRole `secret_id` every ~6 hours.
- Devices may be offline; when `secret_id` is invalid they should request a new one.
- Only rotate `secret_id` (`role_id` stays static).

## Key Vault Facts (river-iot role)
- `role_id`: static unless explicitly changed (not typically rotated).
- `secret_id`: currently no TTL and unlimited uses unless configured otherwise.
- `token_ttl`/`token_max_ttl` control tokens issued from AppRole, not `secret_id` lifetime.

## Recommended Pattern (Device-Initiated Request/Response)
- Device detects invalid `secret_id` and publishes a request.
- A small responder service listens and replies with fresh `secret_id`.

## Topic Layout (per device)
- `command`: `iot/<device_id>/command` (device subscribes; service publishes)
- `status`: `iot/<device_id>/status` (device publishes JSON; service subscribes)
- `message`: `iot/<device_id>/message` (device publishes text logs; service subscribes)

## Suggested MQTT Flow (using existing topics)
1) Device -> publish to status: `iot/<device_id>/status`
   Payload JSON:
   ```json
   {"nonce":"...","device_id":"...","auth_request":"secret_id","reason":"invalid_secret"}
   ```
2) Service -> publish to command: `iot/<device_id>/command`
   Payload JSON:
   ```json
   {"nonce":"...","role_id":"...","secret_id":"...","ttl_sec":...}
   ```
3) Device -> publish to status: `iot/<device_id>/status`
   Payload JSON:
   ```json
   {"nonce":"...","auth_result":"ok"}
   ```

## Pros
- Works even when devices are offline during scheduled rotation.
- No need to push secrets on a schedule; device pulls when needed.
- Can revoke old `secret_id` after success if desired.

## Cons
- Requires a lightweight always-on responder (MQTT subscriber).

## Alternative Approaches

### A) Scheduled Push + Handshake
- Service rotates `secret_id` every 6 hours.
- Service publishes a ping on `iot/<device_id>/command`; waits for device reply on `iot/<device_id>/status`; then publishes `secret_id`.
- Device publishes success/failure on `iot/<device_id>/status`.

Pros:
- Controlled schedule.

Cons:
- Fails if device is offline during rotation; needs retries and failure logging.

### B) Retained Secret on Topic (Not Preferred)
- Publish new `secret_id` to a retained topic (encrypted).
- Device reads retained message when it reconnects.

Pros:
- No always-on responder required.

Cons:
- Retained secrets increase risk; requires careful encryption and key rotation.

### C) Broker with Webhooks (If switching brokers)
- Some brokers (EMQX/HiveMQ) can call HTTP webhooks on publish.
- Webhook triggers secret issuance and response.

Pros:
- No custom MQTT subscriber if webhook exists.

Cons:
- Requires broker switch or plugin.

## Implementation Notes
- Use per-device topics and ACLs to restrict who can read creds.
- Include nonce in request/response to avoid replay/confusion.
- Consider setting `secret_id_ttl` (e.g., 6-12 hours) and rotating on request.
- Log failures with `device_id`, nonce, timestamp, secret_id accessor.

## Minimal Responder Responsibilities
- Subscribe to `iot/+/status` and watch for `auth_request` messages.
- Validate device identity (ACLs/allowed list).
- Generate new `secret_id` from Vault.
- Publish creds to `iot/<device_id>/command`.
- Optionally revoke old `secret_id` after `auth_result` ack.

## Open Decisions
- Do we want fixed 6-hour rotation, or rotate on demand only?
- Should `secret_id_ttl` be set to limit exposure?
- How to store device allowlist and audit logs?
