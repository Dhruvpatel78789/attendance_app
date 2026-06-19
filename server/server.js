const express = require('express');
const cors = require('cors');
const { MongoClient, ObjectId } = require('mongodb');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = process.env.PORT || 5050;
const JWT_SECRET = process.env.JWT_SECRET || 'bloomfield_jwt_secret_key_12345!';

// MongoDB Connection String
const MONGO_URI = process.env.MONGODB_URI || 'mongodb+srv://bloomfieldllp_db_user:zXeEFqe5U8cExf7z@cluster0.gh9jr5i.mongodb.net/attendance_db?retryWrites=true&w=majority&appName=Cluster0';
const DB_NAME = process.env.DB_NAME || 'attendance_db';

let db;

app.use(cors());
app.use(express.json());

// --- VALIDATION HELPER ---
async function validateDocument(collection, id, data, isUpdate = false) {
  let fullData = { ...data };
  if (isUpdate) {
    const existing = await db.collection(collection).findOne({ _id: id });
    if (existing) {
      fullData = { ...existing };
      if (data.$set) {
        fullData = { ...fullData, ...data.$set };
      }
      if (data.$unset) {
        for (const k of Object.keys(data.$unset)) {
          delete fullData[k];
        }
      }
    }
  }

  if (collection === 'users') {
    const usersColl = db.collection('users');
    
    // 1. Email uniqueness
    if (fullData.email) {
      const duplicate = await usersColl.findOne({ email: fullData.email, _id: { $ne: id } });
      if (duplicate) throw new Error('Email already registered');
    }
    
    // 2. Phone uniqueness
    if (fullData.phone) {
      const duplicate = await usersColl.findOne({ phone: fullData.phone, _id: { $ne: id } });
      if (duplicate) throw new Error('Phone number already exists');
    }
    
    // 3. Admin uniqueness per school
    if (fullData.role === 'admin' && fullData.schoolId) {
      const duplicate = await usersColl.findOne({ schoolId: fullData.schoolId, role: 'admin', _id: { $ne: id } });
      if (duplicate) throw new Error('This school already has an Admin');
    }
    
    // 4. Principal uniqueness per school
    if (fullData.role === 'principal' && fullData.schoolId) {
      const duplicate = await usersColl.findOne({ schoolId: fullData.schoolId, role: 'principal', _id: { $ne: id } });
      if (duplicate) throw new Error('This school already has a Principal');
    }
  }

  if (collection === 'classes') {
    const classesColl = db.collection('classes');
    if (fullData.name && fullData.schoolId) {
      const duplicate = await classesColl.findOne({ schoolId: fullData.schoolId, name: fullData.name, _id: { $ne: id } });
      if (duplicate) throw new Error('Class name already exists in this school');
    }
  }

  if (collection === 'students') {
    const studentsColl = db.collection('students');
    if (fullData.grNumber && fullData.schoolId) {
      const duplicate = await studentsColl.findOne({ schoolId: fullData.schoolId, grNumber: fullData.grNumber, _id: { $ne: id } });
      if (duplicate) throw new Error('Student with this GR number already exists in this school');
    }
  }
}

// --- AUTH APIs ---
app.post('/api/auth/register', async (req, res) => {
  const { email, password, customUid, role, schoolId } = req.body;
  try {
    const usersColl = db.collection('users');
    const existing = await usersColl.findOne({ email });
    if (existing) return res.status(400).json({ error: 'Email already registered' });

    const uid = customUid || new ObjectId().toString();
    const existingUid = await usersColl.findOne({ _id: uid });
    if (existingUid) return res.status(400).json({ error: 'User ID already exists' });

    const userRole = role || 'admin';

    // Validate school limits if schoolId is provided at signup
    if (schoolId) {
      if (userRole === 'admin') {
        const existingAdmin = await usersColl.findOne({ schoolId, role: 'admin' });
        if (existingAdmin) return res.status(400).json({ error: 'This school already has an Admin' });
      }
      if (userRole === 'principal') {
        const existingPrincipal = await usersColl.findOne({ schoolId, role: 'principal' });
        if (existingPrincipal) return res.status(400).json({ error: 'This school already has a Principal' });
      }
    }

    await usersColl.insertOne({
      _id: uid,
      email,
      password,
      role: userRole,
      schoolId: schoolId || null,
      createdAt: new Date()
    });

    const token = jwt.sign({ sub: uid, role: userRole }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, uid });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const usersColl = db.collection('users');
    const user = await usersColl.findOne({ email });
    if (!user) return res.status(400).json({ error: 'User not found' });
    if (user.password !== password) return res.status(400).json({ error: 'Wrong password' });

    const token = jwt.sign({ sub: user._id, role: user.role || 'teacher' }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, uid: user._id, user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- GENERIC REST CRUD APIs ---
app.get('/api/documents/:collection', async (req, res) => {
  const { collection } = req.params;
  const filters = req.query.filters ? JSON.parse(req.query.filters) : {};
  const limit = req.query.limit ? parseInt(req.query.limit) : 0;
  const sort = req.query.sort ? JSON.parse(req.query.sort) : null;

  try {
    const coll = db.collection(collection);
    let query = coll.find(filters);
    if (sort) query = query.sort(sort);
    if (limit > 0) query = query.limit(limit);
    const docs = await query.toArray();
    res.json(docs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  try {
    const coll = db.collection(collection);
    const doc = await coll.findOne({ _id: id });
    res.json(doc);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  const data = req.body;
  try {
    await validateDocument(collection, id, data, false);

    const coll = db.collection(collection);

    // Preserve the password field if it already exists and is not provided in this payload
    if (collection === 'users' && !data.password) {
      const existingUser = await coll.findOne({ _id: id });
      if (existingUser && existingUser.password) {
        data.password = existingUser.password;
      }
    }

    data._id = id;
    if (data.createdAt && typeof data.createdAt === 'string') data.createdAt = new Date(data.createdAt);
    if (data.dob && typeof data.dob === 'string') data.dob = new Date(data.dob);
    
    await coll.replaceOne({ _id: id }, data, { upsert: true });
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  const updatePayload = req.body;
  try {
    await validateDocument(collection, id, updatePayload, true);

    const coll = db.collection(collection);
    const finalUpdate = {};
    if (updatePayload.$set) {
      const $set = { ...updatePayload.$set };
      if ($set.createdAt && typeof $set.createdAt === 'string') $set.createdAt = new Date($set.createdAt);
      if ($set.dob && typeof $set.dob === 'string') $set.dob = new Date($set.dob);
      finalUpdate.$set = $set;
    }
    if (updatePayload.$unset) {
      finalUpdate.$unset = updatePayload.$unset;
    }
    await coll.updateOne({ _id: id }, finalUpdate);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  try {
    const coll = db.collection(collection);
    await coll.deleteOne({ _id: id });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start server after connecting to MongoDB
MongoClient.connect(MONGO_URI)
  .then(client => {
    db = client.db(DB_NAME);
    console.log(`Connected to MongoDB database: ${DB_NAME}`);
    app.listen(PORT, () => {
      console.log(`API Server running on port ${PORT}`);
    });
  })
  .catch(err => {
    console.error('Failed to connect to MongoDB Atlas', err);
    process.exit(1);
  });
