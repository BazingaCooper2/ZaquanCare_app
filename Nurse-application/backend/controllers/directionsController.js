const axios = require('axios');

exports.getDirections = async (req, res) => {
    try {
        const { origin, destination } = req.body;

        if (!origin || !destination) {
            return res.status(400).json({ error: "Origin and destination required" });
        }

        // Expecting objects { lat: number, lng: number }
        // Construct coordinate strings "lat,lng"
        const originStr = `${origin.lat},${origin.lng}`;
        const destinationStr = `${destination.lat},${destination.lng}`;

        if (!process.env.DIRECTIONS_API_KEY) {
            console.error("DIRECTIONS_API_KEY is missing in environment variables");
            return res.status(500).json({ error: "Server configuration error" });
        }

        console.log(`🗺️  Fetching directions from ${originStr} to ${destinationStr}`);

        const response = await axios.get(
            "https://maps.googleapis.com/maps/api/directions/json",
            {
                params: {
                    origin: originStr,
                    destination: destinationStr,
                    key: process.env.DIRECTIONS_API_KEY,
                },
            }
        );

        if (response.data.status !== "OK") {
            console.error("Google Directions API Error:", response.data);
            return res.status(400).json({
                error: "Directions failed",
                status: response.data.status,
                errorMessage: response.data.error_message
            });
        }

        const route = response.data.routes[0];
        const leg = route.legs[0];

        res.json({
            polyline: route.overview_polyline.points,
            distance: leg.distance.text,
            duration: leg.duration.text,
        });

    } catch (err) {
        console.error("Server Error in getDirections:", err.message);
        res.status(500).json({ error: "Server error" });
    }
};
