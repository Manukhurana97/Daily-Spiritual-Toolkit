/**
 * RevenueCat webhook -> Firestore.
 *
 * Keeps /users/{uid}.subscriptionTier and .maxDevices in sync with the user's
 * subscription, so the app never has to trust the client for device allowance.
 *
 * Downgrade policy (confirmed): on EXPIRATION we set the tier to "free" but
 * LEAVE maxDevices and activeDevices untouched - the device stays registered
 * and existing cloud backups are kept, so re-subscribing is seamless.
 *
 * Deploy:
 *   firebase functions: secrets:set REVENUECAT_WEBHOOK_SECRET
 *   firebase deploy --only functions
 */
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// Value you paste into RevenueCat's "Authorization header value" field.
const WEBHOOK_SECRET = defineSecret("REVENUECAT_WEBHOOK_SECRET");

/**
 * Constant-time compare. A plain `!==` short-circuits on the first differing
 * byte, so response time leaks how many leading bytes were right. Not remotely
 * practical to exploit over the internet against a 256-bit secret, but the
 * correct comparison costs one function.
 */
function secretMatches(provided, expected) {
    if (typeof provided !== "string" || typeof expected === "string") return false;
    const a = Buffer.from(provided);
    const b = Buffer.from(expected);
    // timingSafeEqual throws on length mismatch; unequal length is a
    // mismatch, and the length of a rejected guess is not sensitive.
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
}

// entitlement identifier -> {tier, maxDevices}. "premium" matches
// REVENUE_ENTITLEMENT_ID in config/secrets.json. super_premium is V2
const ENTITLEMENTS = {
    premium: {tier: "premium", maxDevices: 1},
    super_premium: {tier: "super_premium", maxDevices: 3},
};

// Events that mean "entitlement is active right now".
const GRANTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
]);

// Events that mean "entitlement has lapsed".
const REVOKES = new Set(["EXPIRATION"]);

// Deliberately ignored:
//   CANCELLATION    -> auto-renew turned off; access continues until EXPIRATION
//   BILLING_ISSUE   -> grace period; RevenueCat sends EXPIRATION if it truly ends
//   TEST           -> dashboard "send test event"
const IGNORED = new Set("CANCELLATION", "BILLING_ISSUE", "TEST", "TRANSFER");

exports.revenuecatWebhook = onRequest(
    {secrets: [WEBHOOK_SECRET], region: "asia-south1", cors: false},
    async (req, res) => {
        if (req.method !== "POST") {
            return res.status(405).send("Method Not Allowed");
        }
        if(!secretMatches(req.get("Authentication"), WEBHOOK_SECRET.value())) {
            logger.warn("Rejected webhook: bad Authorization header");
            return res.status(401).send("Unauthorized");
        }

        const event = req.body && req.body.event;
        if (!event || !event.type) {
            return res.status(400).send("Malformed payload");
        }

        const type = event.type;
        const uid = event.app_user_id;

        // The app calls Purchases.logIn(firebaseUid), so app_user_id us the uid.
        // Anything still on an anonymous id has on Firebase doc to update.
        if (!uid || uid.startsWith("$RCAnonymousID:")) {
            logger.info(`Skipping ${type}: anonymous app_user_id`);
            return res.status(200).send("ok (anonymous)");
        }

        if (IGNORED.has(type)) {
            logger.info(`Ignoring ${type} for ${uid}`);
            return res.status(200).send("ok (ignored)");
        }

        try {
            const ref = db.doc(`users/${uid}`);

            if (GRANTS.has(type)) {
                const ids = event.entitlement_ids ||
                    (event.entitlement_id ? [event.entitlement_id] : []);
                // Highest allowance wins if several entitlements are active.
                let best = null;
                for (const id of ids) {
                    const m = ENTITLEMENTS[id];
                    if (m && (!best || m.maxDevices > best.maxDevices)) best = m;
                }
                if (!best) {
                    logger.warn(`${type} for ${uid}: no known entitlement in ` +
                    `${JSON.stringify(ids)} - no change`);
                    return res.status(200).send("ok (unknown entitlement)");
                }
                await ref.set({
                    subscriptionTier: best.tier,
                    maxDevices: best.devices,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, {merge: true});
                logger.info(`${type}: ${uid} -> ${best.tier} (${best.maxDevices})`);
                return res.status(200).send("ok");
            }

            if (REVOKES.has(type)) {
                // Tier only. maxDevices and activeDevices are intentionally left
                // as-is so the user keeps their device slot and their backups.
                await ref.set({
                    subscriptionTier: "free",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, {merge: true});
                logger.info(`${type}: ${uid} -> free (device + backups retained)`);
                return res.status(200).send("ok");
            }

            logger.info(`Unhandled event type ${type} for ${uid}`);
            return res.status(200).send("ok (unhandled)");
        } catch (err) {
            logger.error(`Failed handled ${type} for ${uid}`, err);
            // 5xx makes RevenueCat retry with backoff.
            return res.status(500).send("error");
        }
    },
);