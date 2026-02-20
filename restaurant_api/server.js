const express = require("express");
const cors = require("cors");
const mysql = require("mysql2");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const app = express();
app.use(cors());
app.use(express.json());

// 1. FIX: Ensure uploads directory exists properly
const uploadDir = "./uploads";
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

// 2. Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/");
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  },
});
const upload = multer({ storage: storage });

app.use("/uploads", express.static("uploads"));

const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "restaurant_db",
});

db.connect((err) => {
  if (err) {
    console.error("MySQL Connection Error: " + err.message);
    return;
  }
  console.log("Connected to MySQL Database");
});

// --- FOOD API ---

// GET ALL
app.get("/api/foods", (req, res) => {
  db.query("SELECT * FROM foods", (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(result);
  });
});

// POST (CREATE)
app.post("/api/foods", upload.single("image"), (req, res) => {
  const { name, price, category, description } = req.body;
  const imageUrl = req.file
    ? `http://10.0.2.2:3000/uploads/${req.file.filename}`
    : null;

  const sql =
    "INSERT INTO foods (name, price, category, description, image_url) VALUES (?, ?, ?, ?, ?)";
  db.query(
    sql,
    [name, price, category, description, imageUrl],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Food Added!", id: result.insertId });
    },
  );
});

// PUT (UPDATE)
app.put("/api/foods/:id", upload.single("image"), (req, res) => {
  const { id } = req.params;
  const { name, price, category, description } = req.body;

  let sql =
    "UPDATE foods SET name = ?, price = ?, category = ?, description = ? WHERE id = ?";
  let params = [name, price, category, description, id];

  if (req.file) {
    const imageUrl = `http://10.0.2.2:3000/uploads/${req.file.filename}`;
    sql =
      "UPDATE foods SET name = ?, price = ?, category = ?, description = ?, image_url = ? WHERE id = ?";
    params = [name, price, category, description, imageUrl, id];
  }

  db.query(sql, params, (err, result) => {
    if (err) return res.status(500).json({ error: err.message }); // Send JSON error
    res.json({ message: "Updated!" });
  });
});

// DELETE
app.delete("/api/foods/:id", (req, res) => {
  const { id } = req.params;
  db.query("DELETE FROM foods WHERE id = ?", [id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: "Delete Successful!" });
  });
});

app.post("/api/login", (req, res) => {
  const { username, password } = req.body;

  // ប្រើឈ្មោះតារាង 'users' តាមរូបភាពដែលអ្នកបានផ្ញើមក
  const sql = "SELECT * FROM users WHERE username = ? AND password = ?";

  db.query(sql, [username, password], (err, results) => {
    if (err) {
      return res
        .status(500)
        .json({ success: false, message: "Error ខាង Database" });
    }

    if (results.length > 0) {
      // បើមាន User ក្នុង Database មែន
      res.json({ success: true, message: "Login ជោគជ័យ!" });
    } else {
      // បើអត់មាន ឬវាយខុស
      res
        .status(401)
        .json({ success: false, message: "Username ឬ Password ខុស" });
    }
  });
});

const PORT = 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
