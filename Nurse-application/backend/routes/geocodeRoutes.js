const express = require('express');
const router = express.Router();
const geocodeController = require('../controllers/geocodeController');

// Define the route: POST /api/geocode
router.post('/geocode', geocodeController.geocodeAddress);

module.exports = router;
