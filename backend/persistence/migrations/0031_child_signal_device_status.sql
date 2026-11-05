-- Device-scoped read access for child signals and acknowledgements.
-- Allows the enrolled child device to query honest delivery and acknowledgement
-- status for signals it raised, without exposing other devices or children.

CREATE POLICY device_signal_read ON ap_m1.child_signals
  FOR SELECT TO ap_m1_api
  USING (ap_m1.owns_active_device(device_id));

CREATE POLICY device_ack_read ON ap_m1.signal_acknowledgements
  FOR SELECT TO ap_m1_api
  USING (EXISTS (
    SELECT 1 FROM ap_m1.child_signals s
    WHERE s.event_id = signal_acknowledgements.event_id
      AND ap_m1.owns_active_device(s.device_id)
  ));

CREATE POLICY device_alert_read ON ap_m1.alert_events
  FOR SELECT TO ap_m1_api
  USING (EXISTS (
    SELECT 1 FROM ap_m1.child_signals s
    WHERE s.event_id = alert_events.signal_event_id
      AND ap_m1.owns_active_device(s.device_id)
  ));

CREATE POLICY device_delivery_read ON ap_m1.notification_deliveries
  FOR SELECT TO ap_m1_api
  USING (EXISTS (
    SELECT 1 FROM ap_m1.alert_events e
    JOIN ap_m1.child_signals s ON s.event_id = e.signal_event_id
    WHERE e.id = notification_deliveries.alert_id
      AND ap_m1.owns_active_device(s.device_id)
  ));
