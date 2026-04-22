import { Router } from 'express';
import { VOLUNTEERS, saveVolunteers } from '../engine/allocate.js';

const router = Router();

// GET /api/volunteers
router.get('/', (req, res) => {
  const data = VOLUNTEERS.map(v => ({
    id: v.id,
    name: v.name,
    skills: v.skills,
    location: v.location,
    trust_score: v.trust_score,
    available: v.available,
    active_task: v.active_task,
    tasks_completed: v.tasks_completed || 0
  }));
  res.json({ success: true, data });
});

// POST /api/volunteers (Admin)
router.post('/', (req, res) => {
  const { name, skills, location } = req.body;
  if (!name) return res.status(400).json({ error: 'Name is required' });
  
  const newVol = {
    id: 'v' + Date.now(),
    name,
    skills: Array.isArray(skills) ? skills : (skills || '').split(',').map(s => s.trim()),
    location: location || 'Unknown',
    trust_score: 5.0, // Default starting trust score
    available: true,
    active_task: null,
    tasks_completed: 0
  };
  VOLUNTEERS.push(newVol);
  saveVolunteers();
  res.json({ success: true, volunteer: newVol });
});

// DELETE /api/volunteers/:id (Admin)
router.delete('/:id', (req, res) => {
  const idx = VOLUNTEERS.findIndex(v => v.id === req.params.id);
  if (idx !== -1) {
    VOLUNTEERS.splice(idx, 1);
    saveVolunteers();
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Not found' });
  }
});

export default router;
