import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import { signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { auth } from './firebase.js';
import './App.css';

const API = 'https://sevasync-backend-h2gh.onrender.com/api';

const NEED_COLORS = {
  food: '#f59e0b',
  medical: '#ef4444',
  shelter: '#8b5cf6',
  water: '#06b6d4',
  other: '#6b7280'
};

const URGENCY_RANK = { high: 3, medium: 2, low: 1 };

// ── Heatmap ─────────────────────────────────────────────────────────────────
function Heatmap({ requests }) {
  const active = requests.filter(r => r.status !== 'completed');
  return (
    <div className="heatmap-wrap">
      <div className="heatmap-grid">
        {active.map(r => {
          const hash = r.id.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
          const top  = `${(hash % 68) + 8}%`;
          const left = `${((hash * 13) % 75) + 10}%`;
          const radius = Math.min(70, 30 + (r.people_count || 5) * 0.6);
          const color = NEED_COLORS[r.need_type] || '#6b7280';
          return (
            <div
              key={r.id}
              className={`heat-blob urgency-${r.urgency}`}
              style={{ top, left, width: radius, height: radius, background: `radial-gradient(circle, ${color}cc 0%, ${color}00 70%)` }}
              title={`${r.need_type.toUpperCase()} — ${r.location} (${r.urgency})`}
            />
          );
        })}
        {active.length === 0 && <p className="no-data">No active crises on map</p>}
      </div>
      <div className="map-legend">
        {Object.entries(NEED_COLORS).map(([k, c]) => (
          <span key={k} className="legend-item">
            <span style={{ background: c }} className="legend-dot" />{k}
          </span>
        ))}
      </div>
    </div>
  );
}

// ── Analytics Bar ────────────────────────────────────────────────────────────
function Analytics({ requests }) {
  const counts = {};
  requests.forEach(r => { counts[r.need_type] = (counts[r.need_type] || 0) + 1; });
  const total = requests.length || 1;
  return (
    <div className="analytics-panel">
      <h3>Needs Breakdown</h3>
      {Object.entries(NEED_COLORS).map(([type, color]) => (
        <div key={type} className="bar-row">
          <span className="bar-label">{type}</span>
          <div className="bar-track">
            <div className="bar-fill" style={{ width: `${((counts[type] || 0) / total) * 100}%`, background: color }} />
          </div>
          <span className="bar-count">{counts[type] || 0}</span>
        </div>
      ))}
    </div>
  );
}

// ── Volunteer Tracker ────────────────────────────────────────────────────────
function VolunteerTracker({ volunteers, onAdd, onRemove }) {
  const [showAdd, setShowAdd] = useState(false);
  const [newVol, setNewVol] = useState({ name: '', skills: '', location: '' });

  const handleAdd = (e) => {
    e.preventDefault();
    onAdd(newVol);
    setNewVol({ name: '', skills: '', location: '' });
    setShowAdd(false);
  };

  const sorted = [...volunteers].sort((a, b) => b.trust_score - a.trust_score);

  return (
    <div className="volunteer-panel">
      <div className="panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h3>Volunteer Leaderboard</h3>
        <button className="btn-sm" onClick={() => setShowAdd(!showAdd)}>
          {showAdd ? 'Cancel' : '+ Add'}
        </button>
      </div>

      {showAdd && (
        <form className="add-vol-form" onSubmit={handleAdd}>
          <input className="input-sm" placeholder="Name" required value={newVol.name} onChange={e => setNewVol({...newVol, name: e.target.value})} />
          <input className="input-sm" placeholder="Skills (comma separated)" required value={newVol.skills} onChange={e => setNewVol({...newVol, skills: e.target.value})} />
          <input className="input-sm" placeholder="Location" required value={newVol.location} onChange={e => setNewVol({...newVol, location: e.target.value})} />
          <button type="submit" className="btn-sm btn-primary">Save</button>
        </form>
      )}

      <div className="vol-list">
        {sorted.map(v => (
          <div key={v.id} className={`vol-card ${v.available ? 'available' : 'busy'}`}>
            <div className="vol-dot" />
            <div className="vol-info">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="vol-name">{v.name}</span>
                <span className="vol-status">{v.available ? 'Free' : 'On Mission'}</span>
              </div>
              <span className="vol-meta">{v.skills.join(', ')} · 📍 {v.location}</span>
              <div className="vol-perf">
                <div className="perf-bar-wrap">
                  <div className="perf-bar" style={{ width: `${(v.trust_score / 10) * 100}%` }} />
                </div>
                <span className="perf-text">Trust: {v.trust_score.toFixed(1)}/10</span>
                <span className="perf-text">· Missions: <strong style={{color: 'white'}}>{v.tasks_completed || 0}</strong></span>
              </div>
            </div>
            <div className="vol-actions">
              <button className="btn-icon" onClick={() => onRemove(v.id)} title="Remove volunteer">×</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Live Feed ────────────────────────────────────────────────────────────────
function LiveFeed({ requests, onAllocate }) {
  const sorted = [...requests].sort((a, b) => URGENCY_RANK[b.urgency] - URGENCY_RANK[a.urgency]);

  const statusLabel = (r) => {
    if (r.status === 'completed')    return <span className="badge badge-done">✓ Done</span>;
    if (r.status === 'in-progress')  return <span className="badge badge-active">⚡ In Progress</span>;
    if (r.status === 'allocated')    return <span className="badge badge-allocated">👷 {r.assignedVolunteer}</span>;
    if (r.status === 'declined')     return <span className="badge badge-declined">✗ Declined</span>;
    return null;
  };

  return (
    <div className="feed-panel">
      <h3>Global Crisis Feed <span className="count-badge">{requests.filter(r => r.status === 'pending').length} pending</span></h3>
      <div className="feed-scroll">
        {sorted.length === 0 && <p className="empty-state">No requests yet</p>}
        {sorted.map(r => (
          <div key={r.id} className={`feed-card urgency-border-${r.urgency} status-${r.status}`}>
            <div className="feed-top">
              <span className="type-tag" style={{ color: NEED_COLORS[r.need_type] }}>{r.need_type.toUpperCase()}</span>
              <span className={`urg-pill urg-${r.urgency}`}>{r.urgency}</span>
              <span className="src-tag">{r.source}</span>
            </div>
            <div className="feed-loc">📍 {r.location}</div>
            <div className="feed-desc">{r.description}</div>
            <div className="feed-bottom">
              <span className="feed-meta">👥 {r.people_count} people · {new Date(r.createdAt).toLocaleTimeString()}</span>
              {r.status === 'pending' ? (
                <button className="dispatch-btn" onClick={() => onAllocate(r.id)}>
                  ⚡ Dispatch AI
                </button>
              ) : statusLabel(r)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Main App ─────────────────────────────────────────────────────────────────
export default function App() {
  const [userToken, setUserToken]   = useState(() => localStorage.getItem('adminToken') || null);
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPass, setLoginPass]   = useState('');
  const [loginErr, setLoginErr]     = useState('');
  const [requests, setRequests]     = useState([]);
  const [volunteers, setVolunteers] = useState([]);
  const [loading, setLoading]       = useState(true);
  const [alert, setAlert]           = useState(null);

  // Set up axial interceptor for the token
  useEffect(() => {
    const interceptor = axios.interceptors.request.use(config => {
      if (userToken) {
        config.headers.Authorization = `Bearer ${userToken}`;
      }
      return config;
    });
    return () => axios.interceptors.request.eject(interceptor);
  }, [userToken]);

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoginErr('');
    try {
      const fbUser = await signInWithEmailAndPassword(auth, loginEmail, loginPass);
      const token = await fbUser.user.getIdToken();
      setUserToken(token);
      localStorage.setItem('adminToken', token);
    } catch (err) {
      console.error("Firebase Login Error:", err.code, err.message);
      setLoginErr(`Login failed: ${err.message}`);
    }
  };

  const handleLogout = async () => {
    await signOut(auth);
    setUserToken(null);
    localStorage.removeItem('adminToken');
    setRequests([]);
    setVolunteers([]);
  };

  const fetchAll = useCallback(async () => {
    if (!userToken) return;
    try {
      const [rRes, vRes] = await Promise.all([
        axios.get(`${API}/requests`),
        axios.get(`${API}/volunteers`)
      ]);
      setRequests(rRes.data.data);
      setVolunteers(vRes.data.data);
      setLoading(false);
    } catch (err) {
      console.error('Fetch failed:', err.message);
      setLoading(false);
      
      // Force clear state on ANY fetch error to break the loop!
      setUserToken(null);
      localStorage.removeItem('adminToken');
    }
  }, [userToken]);

  useEffect(() => {
    if (!userToken) return;
    fetchAll();
    const t = setInterval(fetchAll, 4000);
    return () => clearInterval(t);
  }, [fetchAll, userToken]);

  const handleAllocate = async (id) => {
    try {
      const res = await axios.post(`${API}/requests/${id}/allocate`);
      setAlert({ type: 'success', msg: `Assigned to ${res.data.volunteer.name}` });
      fetchAll();
    } catch (err) {
      setAlert({ type: 'error', msg: err.response?.data?.error || 'Allocation failed' });
    }
    setTimeout(() => setAlert(null), 3000);
  };

  const addVolunteer = async (vol) => {
    try {
      await axios.post(`${API}/volunteers`, vol);
      setAlert({ type: 'success', msg: `Added ${vol.name}` });
      fetchAll();
    } catch (err) {
      setAlert({ type: 'error', msg: 'Failed to add volunteer' });
    }
    setTimeout(() => setAlert(null), 3000);
  };

  const removeVolunteer = async (id) => {
    try {
      await axios.delete(`${API}/volunteers/${id}`);
      setAlert({ type: 'success', msg: 'Volunteer removed' });
      fetchAll();
    } catch (err) {
      setAlert({ type: 'error', msg: 'Failed to remove volunteer' });
    }
    setTimeout(() => setAlert(null), 3000);
  };

  // Aggregate stats
  const completed  = requests.filter(r => r.status === 'completed');
  const active     = requests.filter(r => ['allocated', 'in-progress'].includes(r.status));
  const rescued    = completed.reduce((s, r) => s + (r.people_count || 0), 0);
  const freeVols   = volunteers.filter(v => v.available).length;

  if (!userToken) {
    return (
      <div className="login-screen">
        <form className="login-box" onSubmit={handleLogin}>
          <div className="login-icon">🛡️</div>
          <h2>SevaSync Admin</h2>
          <p>Login with strict admin credentials to access the command center.</p>
          {loginErr && <div className="toast toast-error" style={{position: 'static', margin: '1rem 0'}}>{loginErr}</div>}
          <input 
            type="email" 
            className="input-sm" 
            placeholder="Admin Email" 
            value={loginEmail} 
            onChange={e => setLoginEmail(e.target.value)} 
            required 
            style={{ width: '100%', marginBottom: '1rem' }}
          />
          <input 
            type="password" 
            className="input-sm" 
            placeholder="Password" 
            value={loginPass} 
            onChange={e => setLoginPass(e.target.value)} 
            required 
            style={{ width: '100%', marginBottom: '1.5rem' }}
          />
          <button type="submit" className="btn-primary login-btn" style={{ width: '100%' }}>
            Secure Login
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="page">
      {/* Alert toast */}
      {alert && <div className={`toast toast-${alert.type}`}>{alert.msg}</div>}

      {/* HEADER */}
      <header className="topbar">
        <div className="topbar-left">
          <div className="live-dot" />
          <div>
            <h1 className="brand">SevaSync</h1>
            <span className="brand-sub">Admin Command Center</span>
          </div>
        </div>
        <div className="topbar-right">
          <button className="btn-logout" onClick={handleLogout}>Logout</button>
        </div>
        <div className="kpi-row">
          <div className="kpi">
            <span className="kpi-v kpi-green">{rescued}</span>
            <span className="kpi-l">Rescued</span>
          </div>
          <div className="kpi">
            <span className="kpi-v kpi-orange">{active.length}</span>
            <span className="kpi-l">Active Ops</span>
          </div>
          <div className="kpi">
            <span className="kpi-v">{completed.length}</span>
            <span className="kpi-l">Completed</span>
          </div>
          <div className="kpi">
            <span className="kpi-v kpi-blue">{freeVols}</span>
            <span className="kpi-l">Free Vols</span>
          </div>
        </div>
      </header>

      {/* BODY */}
      {loading ? (
        <div className="loading-screen"><div className="spinner" /><p>Connecting to SevaSync...</p></div>
      ) : (
        <div className="body-grid">
          {/* Left column */}
          <div className="col-left">
            <section className="panel">
              <h2 className="panel-title">🗺 Geospatial Risk Heatmap</h2>
              <Heatmap requests={requests} />
            </section>
            <section className="panel">
              <Analytics requests={requests} />
            </section>
            <section className="panel">
              <VolunteerTracker volunteers={volunteers} onAdd={addVolunteer} onRemove={removeVolunteer} />
            </section>
          </div>

          {/* Right column */}
          <div className="col-right">
            <section className="panel panel-feed">
              <LiveFeed requests={requests} onAllocate={handleAllocate} />
            </section>
          </div>
        </div>
      )}
    </div>
  );
}
