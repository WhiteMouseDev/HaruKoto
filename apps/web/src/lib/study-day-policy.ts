// Enable together with the API only after compatibility deployment and drain.
// Source-controlled deliberately: no new environment/runtime setting contract.
export const ANSWERED_STUDY_DAY_RECOGNITION_ENABLED = true;

// Local feature policy. Readers and real-activity writers remain compatible
// with explicit credit values even when new delayed-completion separation is OFF.
export const STUDY_DAY_CREDIT_SEPARATION_ENABLED = false;
