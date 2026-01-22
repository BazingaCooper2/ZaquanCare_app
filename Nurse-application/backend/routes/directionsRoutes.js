const express = require('express');
const router = express.Router();
const directionsController = require('../controllers/directionsController');

router.post('/directions', directionsController.getDirections);

module.exports = router;
