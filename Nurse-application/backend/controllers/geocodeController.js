const axios = require('axios');

exports.geocodeAddress = async (req, res) => {
    const { address } = req.body;

    // 1. Validate Input
    if (!address || typeof address !== 'string' || address.trim() === '') {
        return res.status(400).json({ error: 'Address is required' });
    }

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
        console.error('Missing GOOGLE_MAPS_API_KEY in environment variables');
        return res.status(500).json({ error: 'Server configuration error' });
    }

    try {
        // 2. Call Google Maps API
        const response = await axios.get('https://maps.googleapis.com/maps/api/geocode/json', {
            params: {
                address: address,
                key: apiKey,
            },
        });

        const data = response.data;

        // 3. Handle Google API Responses
        if (data.status === 'OK') {
            if (data.results && data.results.length > 0) {
                const location = data.results[0].geometry.location;

                // Log for debugging (remove in production if sensitive)
                console.log(`Geocoded "${address}" to [${location.lat}, ${location.lng}]`);

                return res.json({
                    latitude: location.lat,
                    longitude: location.lng,
                    formatted_address: data.results[0].formatted_address // Optional bonus
                });
            } else {
                return res.status(404).json({ error: 'No results found' });
            }
        } else if (data.status === 'ZERO_RESULTS') {
            return res.status(404).json({ error: 'Address not found' });
        } else if (data.status === 'OVER_QUERY_LIMIT') {
            console.error('Google Maps Quota Exceeded');
            return res.status(429).json({ error: 'Service quota exceeded, please try again later' });
        } else if (data.status === 'REQUEST_DENIED') {
            console.error('Google Maps Request Denied (Check API Key):', data.error_message);
            return res.status(500).json({ error: 'Geocoding service unauthorized' });
        } else {
            console.error('Geocoding Error:', data.status, data.error_message);
            return res.status(400).json({ error: `Geocoding failed: ${data.status}` });
        }

    } catch (error) {
        if (error.response) {
            // The request was made and the server responded with a status code outside 2xx
            console.error('API Response Error:', error.response.status, error.response.data);
        } else if (error.request) {
            // The request was made but no response was received
            console.error('No Response from Google API:', error.message);
        } else {
            console.error('Error setting up request:', error.message);
        }
        return res.status(500).json({ error: 'Network error connecting to geocoding service' });
    }
};
