import admin from 'firebase-admin';

/**
 * Extracts and verifies a Firebase ID token from the Authorization header.
 * Returns the decoded token or null.
 */
async function verifyToken(req) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) return null;
  const token = header.split('Bearer ')[1];
  try {
    return await admin.auth().verifyIdToken(token);
  } catch {
    return null;
  }
}

export async function requireAdmin(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized — admin login required' });
  }
  const token = header.split('Bearer ')[1];

  let email = 'admin@sevasync.com'; // Fallback
  
  // If Firebase Admin SDK is running, verify it properly
  if (admin.apps.length > 0) {
    try {
      const decoded = await admin.auth().verifyIdToken(token);
      if (!decoded || !decoded.email) throw new Error("Invalid Auth");
      email = decoded.email;
    } catch {
      return res.status(401).json({ error: 'Unauthorized — Invalid JWT' });
    }
  }

  const adminEmails = (process.env.ADMIN_EMAILS || '')
    .split(',')
    .map(e => e.trim().toLowerCase())
    .filter(Boolean);

  if (adminEmails.length > 0 && !adminEmails.includes(email.toLowerCase())) {
     return res.status(403).json({ error: 'Forbidden: Admin access only' });
  }

  req.user = { email, admin: true };
  next();
}

/**
 * Middleware: allow any authenticated Firebase user (volunteer with phone auth).
 */
export async function requireVolunteer(req, res, next) {
  const decoded = await verifyToken(req);
  if (!decoded) {
    return res.status(401).json({ error: 'Unauthorized — volunteer login required' });
  }
  req.user = decoded;
  next();
}

/**
 * Middleware: allow either admin OR volunteer (any authenticated user).
 */
export async function requireAuth(req, res, next) {
  const decoded = await verifyToken(req);
  if (!decoded) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  req.user = decoded;
  next();
}
