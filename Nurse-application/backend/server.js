const path = require('path');
// Load .env from the parent directory (Nurse-application root)
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const express = require('express');
const cors = require('cors');
const geocodeRoutes = require('./routes/geocodeRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors()); // Enable CORS for all origins (Adjust for production security)
app.use(express.json()); // Parse JSON request bodies

// Routes
// Mounts the geocode routes at /api/geocode
app.use('/api', geocodeRoutes);

const directionsRoutes = require('./routes/directionsRoutes');
app.use('/api', directionsRoutes);

// Health Check Endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'Geocoding Service is running',
        timestamp: new Date().toISOString()
    });
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Server running on port ${PORT}`);
    console.log(`📍 Endpoint available at: http://localhost:${PORT}/api/geocode`);
});
