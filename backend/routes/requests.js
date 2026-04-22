import { Router } from 'express';
import { DB } from '../db/firebase.js';
import { allocateBestVolunteer, freeVolunteer } from '../engine/allocate.js';

const router = Router();

// GET /api/requests — All requests, newest first
router.get('/', async (req, res) => {
  try {
    const data = await DB.getRequests();
    res.json({ success: true, count: data.length, data });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch requests' });
  }
});

// POST /api/requests/:id/allocate — Admin dispatches AI allocation
router.post('/:id/allocate', async (req, res) => {
  try {
    const request = await DB.getRequest(req.params.id);
    if (!request) return res.status(404).json({ error: 'Request not found' });
    if (request.status !== 'pending') {
      return res.status(400).json({ error: `Request is already ${request.status}` });
    }

    const volunteer = allocateBestVolunteer(request);
    if (!volunteer) {
      return res.status(400).json({ error: 'No available volunteers match this need' });
    }

    await DB.updateRequest(req.params.id, {
      status: 'allocated',
      assignedVolunteerId: volunteer.id,
      assignedVolunteer: volunteer.name,
      allocatedAt: new Date().toISOString()
    });

    res.json({ success: true, volunteer });
  } catch (err) {
    console.error('Allocate error:', err);
    res.status(500).json({ error: 'Allocation failed' });
  }
});

// PUT /api/requests/:id/status — Volunteer updates status from mobile
router.put('/:id/status', async (req, res) => {
  try {
    const { status, notes } = req.body;
    const valid = ['in-progress', 'completed', 'declined'];
    if (!valid.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${valid.join(', ')}` });
    }

    const request = await DB.getRequest(req.params.id);
    if (!request) return res.status(404).json({ error: 'Request not found' });

    const updates = { status, updatedAt: new Date().toISOString() };
    if (notes) updates.completionNotes = notes;
    if (status === 'completed') updates.completedAt = new Date().toISOString();

    await DB.updateRequest(req.params.id, updates);

    // Free up volunteer if task is done or declined (track performance)
    if (status === 'completed') {
      freeVolunteer(req.params.id, true);
    } else if (status === 'declined') {
      freeVolunteer(req.params.id, false);
    }

    res.json({ success: true, status });
  } catch (err) {
    console.error('Status update error:', err);
    res.status(500).json({ error: 'Failed to update status' });
  }
});

export default router;
