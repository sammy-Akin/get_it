const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const fetch = require("node-fetch");

setGlobalOptions({ maxInstances: 10 });

const MAPS_API_KEY = defineSecret("MAPS_API_KEY");

// Autocomplete
exports.placesAutocomplete = onRequest(
  { secrets: [MAPS_API_KEY] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    const input = req.query.input;
    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${input}&key=${MAPS_API_KEY.value()}&components=country:ng&language=en`;
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  }
);

// Place Details
exports.placeDetails = onRequest(
  { secrets: [MAPS_API_KEY] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    const placeId = req.query.place_id;
    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=geometry&key=${MAPS_API_KEY.value()}`;
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  }
);

// Geocode
exports.geocode = onRequest(
  { secrets: [MAPS_API_KEY] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    const address = req.query.address;
    const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${address}&key=${MAPS_API_KEY.value()}`;
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  }
);

// Reverse Geocode
exports.reverseGeocode = onRequest(
  { secrets: [MAPS_API_KEY] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    const latlng = req.query.latlng;
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latlng}&key=${MAPS_API_KEY.value()}`;
    const response = await fetch(url);
    const data = await response.json();
    res.json(data);
  }
);