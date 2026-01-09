 const express = require('express');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const cors = require('cors');
require('dotenv').config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK
// TODO: Download your service account key from Firebase Console -> Project Settings -> Service Accounts
// and save it as 'serviceAccountKey.json' in the 'backend' directory.
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // Production: Use environment variable
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  // Development: Use local file
  serviceAccount = require('../serviceAccountKey.json');
}

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  
  console.log('Firebase Admin Initialized');
} catch (error) {
  console.error('Firebase Admin Initialization Error:', error);
}

// Initialize Firestore Database
const db = getFirestore();

// Middleware to verify Firebase Auth Token from Flutter App
const verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  const idToken = authHeader.split('Bearer ')[1];
  try {
    // Verify the ID token sent from the client
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken; // Attach user info to request
    next();
  } catch (error) {
    console.error('Error verifying token:', error);
    return res.status(403).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Routes
app.get('/', (req, res) => {
  res.send('Health Nexus Backend is running.');
});

// Example Protected Route
app.get('/api/health-data', verifyToken, (req, res) => {
  res.json({ message: `Secure health data for user: ${req.user.uid}` });
});

// POST Endpoint: Save User Profile
app.post('/api/user-profile', verifyToken, async (req, res) => {
  try {
    const userData = req.body;
    // Save data to 'users' collection using the user's UID as the document ID
    await db.collection('users').doc(req.user.uid).set(userData, { merge: true });
    
    res.status(200).json({ message: 'User profile saved successfully' });
  } catch (error) {
    console.error('Error saving user profile:', error);
    res.status(500).json({ error: 'Failed to save user profile' });
  }
});

// GET Endpoint: Fetch User Profile
app.get('/api/user-profile', verifyToken, async (req, res) => {
  try {
    const userDoc = await db.collection('users').doc(req.user.uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User profile not found' });
    }
    res.status(200).json(userDoc.data());
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

// Start Server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});