import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';

const router = Router();

// Strict rate limit for auth routes — 10 attempts per 15 minutes
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many login attempts. Try again in 15 minutes.' }
});

router.use(authLimiter);

/**
 * POST /api/auth/admin/login
 * Body: { email, password }
 * Returns: { idToken, email, uid }
 *
 * Uses Firebase Auth REST API (Identity Toolkit) to sign in with email+password.
 * The returned idToken is what the frontend should store and send as Bearer token.
 */
router.post('/admin/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true })
    });

    const data = await response.json();

    if (!response.ok) {
      const msg = data.error?.message || 'Login failed';
      // Normalize Firebase error messages
      if (msg.includes('EMAIL_NOT_FOUND') || msg.includes('INVALID_PASSWORD') || msg.includes('INVALID_LOGIN_CREDENTIALS')) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      return res.status(401).json({ error: msg });
    }

    console.log(`✅ Admin login: ${data.email}`);
    res.json({ success: true, idToken: data.idToken, email: data.email, uid: data.localId });
  } catch (err) {
    console.error('Admin login error:', err.message);
    res.status(500).json({ error: 'Authentication service unavailable' });
  }
});

/**
 * POST /api/auth/refresh
 * Body: { refreshToken }
 * Returns refreshed idToken (for token expiry handling)
 */
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ error: 'refreshToken required' });

  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  const url = `https://securetoken.googleapis.com/v1/token?key=${apiKey}`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ grant_type: 'refresh_token', refresh_token: refreshToken })
    });
    const data = await response.json();
    if (!response.ok) return res.status(401).json({ error: 'Token refresh failed' });

    res.json({ success: true, idToken: data.id_token });
  } catch (err) {
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

export default router;
