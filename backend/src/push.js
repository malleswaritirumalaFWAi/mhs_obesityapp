/**
 * push.js — Firebase Admin SDK helper for sending FCM push notifications.
 *
 * SETUP REQUIRED:
 *   1. Go to Firebase Console → Project Settings → Service Accounts
 *   2. Click "Generate new private key" → download the JSON file
 *   3. Set env var:  FIREBASE_SERVICE_ACCOUNT=<paste the entire JSON as a single line>
 *      OR set:       GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
 *
 * Without this setup, push calls are silently skipped (in-app notifications still work).
 */

import { q } from './db.js';

let adminInstance = null;

async function getAdmin() {
  if (adminInstance) return adminInstance;

  const serviceAccountStr = process.env.FIREBASE_SERVICE_ACCOUNT;
  const hasCredentials = serviceAccountStr || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!hasCredentials) return null; // Push not configured — skip silently

  try {
    const { default: admin } = await import('firebase-admin');
    if (!admin.apps.length) {
      if (serviceAccountStr) {
        const serviceAccount = JSON.parse(serviceAccountStr);
        admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      } else {
        admin.initializeApp({ credential: admin.credential.applicationDefault() });
      }
    }
    adminInstance = admin;
    return admin;
  } catch (e) {
    console.warn('[push] firebase-admin unavailable:', e.message);
    return null;
  }
}

/**
 * Send a push notification to a single user by their DB user ID.
 * Silently skips if the user has no FCM token or Firebase is not configured.
 */
export async function sendPush(userId, title, body) {
  try {
    const row = (await q(`SELECT fcm_token FROM users WHERE id=$1`, [userId])).rows[0];
    if (!row?.fcm_token) return;

    const admin = await getAdmin();
    if (!admin) return;

    await admin.messaging().send({
      token: row.fcm_token,
      notification: { title, body },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (e) {
    console.warn('[push] Failed to send to user', userId, ':', e.message);
  }
}
