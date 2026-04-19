const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

/**
 * Ambil IP address dari request secara aman.
 * Mendukung proxy (X-Forwarded-For) dan koneksi langsung.
 */
function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) return forwarded.split(',')[0].trim();
  return req.connection?.remoteAddress || req.ip || 'unknown';
}

// ─────────────────────────────────────────────────────────────
// SEC-FIX: Input Validation Helpers
// ─────────────────────────────────────────────────────────────

const VALIDATION = {
  // deviceId: alphanumeric, hyphens, underscores; max 128 chars
  deviceId: /^[a-zA-Z0-9_-]{1,128}$/,
  // platform: only specific values
  platform: /^(android|ios|web|unknown)$/,
  // appVersion: semantic versioning format (e.g., 1.2.3+45)
  appVersion: /^[\w.+-]{1,32}$/,
  // uid: Firebase Auth UID format (alphanumeric, max 128)
  uid: /^[a-zA-Z0-9]{1,128}$/,
  // bengkelId: alphanumeric, hyphens; max 64 chars
  bengkelId: /^[a-zA-Z0-9_-]{1,64}$/,
  // role: only allowed roles
  allowedRoles: ['owner', 'admin', 'mekanik', 'staff'],
};

/**
 * Sanitize string untuk logging - mencegah log injection
 * @param {string} str - string yang akan di-sanitize
 * @param {number} maxLength - panjang maksimum
 * @returns {string} - sanitized string
 */
function sanitizeForLog(str, maxLength = 128) {
  if (typeof str !== 'string') return '[invalid]';
  // Remove control characters dan newlines
  let sanitized = str.replace(/[\x00-\x1F\x7F-\x9F]/g, '');
  // Truncate jika terlalu panjang
  if (sanitized.length > maxLength) {
    sanitized = sanitized.substring(0, maxLength) + '...[truncated]';
  }
  return sanitized;
}

/**
 * Validate and sanitize deviceId
 * @param {string} deviceId
 * @returns {string|null} - sanitized deviceId atau null jika invalid
 */
function validateDeviceId(deviceId) {
  if (typeof deviceId !== 'string') return null;
  if (!VALIDATION.deviceId.test(deviceId)) return null;
  return deviceId;
}

/**
 * Validate platform
 * @param {string} platform
 * @returns {string} - validated platform atau 'unknown'
 */
function validatePlatform(platform) {
  if (typeof platform !== 'string') return 'unknown';
  const lower = platform.toLowerCase();
  return VALIDATION.platform.test(lower) ? lower : 'unknown';
}

/**
 * Validate appVersion
 * @param {string} version
 * @returns {string|null} - validated version atau null jika invalid
 */
function validateAppVersion(version) {
  if (typeof version !== 'string') return null;
  if (!VALIDATION.appVersion.test(version)) return null;
  return version;
}

/**
 * Validate UID
 * @param {string} uid
 * @returns {string|null} - validated uid atau null jika invalid
 */
function validateUid(uid) {
  if (typeof uid !== 'string') return null;
  if (!VALIDATION.uid.test(uid)) return null;
  return uid;
}

/**
 * Validate bengkelId
 * @param {string} bengkelId
 * @returns {string|null} - validated bengkelId atau null jika invalid
 */
function validateBengkelId(bengkelId) {
  if (typeof bengkelId !== 'string') return null;
  if (!VALIDATION.bengkelId.test(bengkelId)) return null;
  return bengkelId;
}

// ─────────────────────────────────────────────────────────────
// PHASE 1.1: verifySession Cloud Function (HTTPS)
// ─────────────────────────────────────────────────────────────
// Dipanggil oleh SessionManager._handshakeOnline() di Flutter.
// Memvalidasi:
//   1. Firebase ID Token (sudah login, tidak expired)
//   2. Status akun user (active/disabled)
//   3. Apakah DeviceId cocok dengan activeDeviceId di Firestore
// Return 200 jika valid, 401 jika tidak.
// ─────────────────────────────────────────────────────────────

exports.verifySession = functions
  .runWith({
    timeoutSeconds: 15,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    // Hanya izinkan POST
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }

    const clientIp = getClientIp(req);

    // ── PHASE 1.2: Rate Limiting ──────────────────────────────
    // Menggunakan Firestore sebagai counter dengan TTL 1 menit.
    // Batas: 15 request/menit per IP.
    try {
      const rateLimitRef = db.collection('_rate_limits').doc(`session_${clientIp}`);
      const nowMs = Date.now();
      const windowMs = 60 * 1000; // 1 menit
      const maxRequests = 15;

      const result = await db.runTransaction(async (t) => {
        const doc = await t.get(rateLimitRef);
        let count = 1;
        let windowStart = nowMs;

        if (doc.exists) {
          const data = doc.data();
          // Reset window jika sudah lebih dari 1 menit
          if (nowMs - data.windowStart < windowMs) {
            count = data.count + 1;
            windowStart = data.windowStart;
          }
        }

        t.set(rateLimitRef, {
          count,
          windowStart,
          lastRequest: nowMs,
          ip: clientIp,
        });

        return { count, allowed: count <= maxRequests };
      });

      if (!result.allowed) {
        console.warn(`[RATE_LIMIT] IP ${clientIp} exceeded limit (${result.count} req/min)`);
        return res.status(429).json({
          code: 'rate_limit_exceeded',
          error: 'Terlalu banyak permintaan. Coba lagi dalam 1 menit.',
        });
      }
    } catch (rateError) {
      // Jika rate limit check gagal (mis. Firestore error), biarkan request lanjut
      // agar pengguna tidak diblokir secara salah (Safe-Open policy untuk UX)
      console.error('[RATE_LIMIT_ERROR] Rate limit check failed, proceeding:', rateError.message);
    }

    // ── Ambil ID Token dari Authorization header ──────────────
    const authHeader = req.headers['authorization'] || '';
    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        code: 'missing_token',
        error: 'Authorization token tidak ditemukan.',
      });
    }

    const idToken = authHeader.substring(7);

    try {
      // ── 1. Verifikasi Firebase ID Token ──────────────────────
      const decodedToken = await admin.auth().verifyIdToken(idToken, true); // checkRevoked=true
      const uid = decodedToken.uid;

      // ── 2. Cek Status Akun di Firestore ──────────────────────
      const userDocRef = db.collection('users').doc(uid);
      const userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        // SEC-FIX: Generic error untuk client, detail log internally
        console.warn(`[VERIFY_SESSION] User doc not found for uid: ${uid}`);
        return res.status(401).json({ code: 'auth_failed', error: 'Autentikasi gagal.' });
      }

      const userData = userDoc.data();
      const accountStatus = userData.status || 'active';

      if (accountStatus === 'disabled' || accountStatus === 'deleted') {
        // SEC-FIX: Generic error untuk client, detail log internally
        console.warn(`[VERIFY_SESSION] Account ${uid} is ${accountStatus}`);
        return res.status(401).json({
          code: 'auth_failed',
          error: 'Autentikasi gagal.',
        });
      }

      // ── PHASE 1.3: Device Fingerprint Validation ──────────────
      // SEC-FIX: Input validation dan sanitization sebelum processing
      const requestBody = req.body || {};

      // Validate inputs
      const clientDeviceId = validateDeviceId(requestBody.deviceId);
      const clientPlatform = validatePlatform(requestBody.platform);
      const clientAppVersion = validateAppVersion(requestBody.appVersion) || 'unknown';

      // Log sanitized values only
      console.log(`[VERIFY_SESSION] Sanitized: platform=${clientPlatform}, version=${sanitizeForLog(clientAppVersion)}`);

      if (clientDeviceId) {
        const activeDeviceId = userData.activeDeviceId;

        if (activeDeviceId && activeDeviceId !== clientDeviceId) {
          console.warn(
            `[VERIFY_SESSION] Device mismatch for ${sanitizeForLog(uid)}: ` +
            `expected=${sanitizeForLog(activeDeviceId)}, got=${sanitizeForLog(clientDeviceId)}`
          );

          // Log security event ke Firestore
          await db
            .collection('bengkel')
            .doc(userData.bengkelId || 'unknown')
            .collection('security_audit_logs')
            .add({
              type: 'device_mismatch',
              uid,
              expectedDeviceId: activeDeviceId,
              attemptedDeviceId: clientDeviceId,
              platform: clientPlatform,
              clientIp,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              severity: 'high',
            });

          return res.status(401).json({
            code: 'auth_failed',
            error: 'Autentikasi gagal.',
          });
        }
      }

      // ── 3. Update lastSeen & session metadata ─────────────────
      // SEC-FIX: Gunakan sanitized values untuk update
      await userDocRef.update({
        'activeDeviceInfo.lastSeen': admin.firestore.FieldValue.serverTimestamp(),
        lastHandshakeAt: admin.firestore.FieldValue.serverTimestamp(),
        lastHandshakePlatform: clientPlatform,
        lastHandshakeAppVersion: clientAppVersion,
        // SEC-FIX: Log IP yang disanitasi untuk audit
        lastHandshakeIp: sanitizeForLog(clientIp, 45), // IPv6 max length
      });

      // ── 4. Return success ─────────────────────────────────────
      return res.status(200).json({
        code: 'session_valid',
        uid,
        role: decodedToken.role || userData.role || 'staff',
        bengkelId: decodedToken.bengkelId || userData.bengkelId || '',
        serverTime: Date.now(),
      });

    } catch (error) {
      // SEC-FIX: Sanitize error message sebelum logging
      const sanitizedError = sanitizeForLog(error.message || 'Unknown error', 256);

      // SEC-FIX: Generic error messages untuk client
      // Error code tetap spesifik untuk client handling, tapi message generik
      if (error.code === 'auth/id-token-revoked') {
        return res.status(401).json({ code: 'token_revoked', error: 'Sesi tidak valid.' });
      }
      if (error.code === 'auth/id-token-expired') {
        return res.status(401).json({ code: 'token_expired', error: 'Sesi tidak valid.' });
      }
      if (error.code === 'auth/user-disabled') {
        return res.status(401).json({ code: 'auth_failed', error: 'Autentikasi gagal.' });
      }
      console.error('[VERIFY_SESSION] Error:', sanitizedError, error.code);
      return res.status(500).json({ code: 'internal_error', error: 'Terjadi kesalahan server.' });
    }
  });


// ─────────────────────────────────────────────────────────────
// PHASE 1.1b: setRole Cloud Function (Role Management)
// Dipanggil oleh Owner untuk menetapkan role staf.
// ─────────────────────────────────────────────────────────────

exports.setRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Endpoint requires authentication!');
  }

  if (context.auth.token.role !== 'owner') {
    throw new functions.https.HttpsError('permission-denied', 'Only owners can assign roles.');
  }

  // SEC-FIX: Input validation dengan sanitization
  const rawUid = data.uid;
  const rawRole = data.role;
  const rawBengkelId = data.bengkelId;

  // Validasi required parameters
  if (!rawUid || !rawRole || !rawBengkelId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters.');
  }

  // SEC-FIX: Validate and sanitize inputs
  const uid = validateUid(rawUid);
  const bengkelId = validateBengkelId(rawBengkelId);
  const role = typeof rawRole === 'string' ? rawRole.toLowerCase().trim() : null;

  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid uid format.');
  }
  if (!bengkelId) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid bengkelId format.');
  }

  // Validasi role yang diizinkan
  if (!VALIDATION.allowedRoles.includes(role)) {
    throw new functions.https.HttpsError('invalid-argument', `Role '${sanitizeForLog(rawRole)}' tidak diizinkan.`);
  }

  try {
    await admin.auth().setCustomUserClaims(uid, { role, bengkelId });

    // Log aksi ke Firestore: audit trail
    await db
      .collection('bengkel')
      .doc(bengkelId)
      .collection('security_audit_logs')
      .add({
        type: 'role_assignment',
        targetUid: uid,
        newRole: role,
        assignedByUid: context.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        severity: 'medium',
      });

    return { message: `Success! User ${uid} assigned as ${role} for bengkel ${bengkelId}` };
  } catch (error) {
    // SEC-FIX: Log detail internally, return generic error ke client
    const sanitizedError = sanitizeForLog(error.message || 'Unknown error', 256);
    console.error('[SET_ROLE] Error:', sanitizedError);
    throw new functions.https.HttpsError('internal', 'Gagal mengatur role.');
  }
});


// ─────────────────────────────────────────────────────────────
// CLEANUP: Rate Limit Data (dipanggil otomatis setiap jam)
// Menghapus data rate limiting yang sudah kedaluwarsa (> 5 menit)
// agar Firestore tidak penuh dengan data sementara.
// ─────────────────────────────────────────────────────────────

exports.cleanupRateLimits = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (_context) => {
    const cutoff = Date.now() - 5 * 60 * 1000; // 5 menit lalu
    const snapshot = await db
      .collection('_rate_limits')
      .where('lastRequest', '<', cutoff)
      .get();

    if (snapshot.empty) {
      console.log('[CLEANUP] No stale rate limit docs found.');
      return null;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    console.log(`[CLEANUP] Deleted ${snapshot.docs.length} stale rate limit docs.`);
    return null;
  });
