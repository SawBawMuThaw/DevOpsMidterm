# Product API + UI (Express + MongoDB, fallback in-memory)

> Note: This project is provided as a reference foundation for students to complete their midterm presentation in the course 502094 - Software Deployment, Operations And Maintenance (compiled by: MSc. Mai Van Manh). Students are not required to use this exact project — you may choose or build an equivalent project (or more complex), using a different language or framework if desired.

This is a sample project organized following the MVC (Model — View — Controller) pattern built with Node.js + Express, using MongoDB (Mongoose) to store product data. If the server cannot connect to MongoDB during startup (3s timeout), the application will automatically switch to using an in-memory datastore and continue running.

**Main Features**
- Complete REST API for Product management: CRUD (GET/POST/PUT/PATCH/DELETE).
- Server-side rendered UI using `EJS` combined with `Bootstrap` for product management (interface at `/`).
- Each JSON response includes `hostname` and `source` information (indicating whether data is from `mongodb` or `in-memory`).
- Image upload support for products: images are saved to disk in `public/uploads/` and the `imageUrl` field in product stores the relative path (`/uploads/<filename>`).
- When updating or deleting a product, the old image file (located in `/uploads/`) will be deleted from disk.
- On startup, if MongoDB connection is successful and the collection is empty, the application will automatically seed 10 sample Apple products into MongoDB.

**Main Structure**
- `main.js` — entrypoint: connects to MongoDB (3s timeout), falls back to in-memory, starts Express.
- `models/product.js` — Mongoose schema (`name`, `price`, `color`, `description`, `imageUrl`).
- `services/dataSource.js` — abstraction layer between MongoDB and in-memory (seed, CRUD, delete files when needed).
- `controllers/` — controllers handling request/response logic.
- `routes/` — routes for API (`/products`) and UI (`/`).
- `views/` — `EJS` templates for UI.
- `public/` — static files: CSS, JS, `uploads/` (images are stored here).

**Requirements & Configuration**
- Node.js 16+ (or compatible version) and `npm`.
- Environment file `.env` (sample file included in repo):

```text
PORT=3000
MONGO_URI=mongodb://localhost:27017/products_db
```

If you want to connect to MongoDB with username/password, adjust `MONGO_URI` accordingly.

**Installation & Running Locally**
1. Install dependencies:

```bash
cd /Users/mvmanh/Desktop/api
npm install
```

2. Start the server:

```bash
# Run production (node)
npm start

# Or development mode with nodemon
npm run dev
```

3. Open browser to: `http://localhost:3000/` — the UI page will display the product list and provide Add / Edit / Delete operations.

**API (JSON) — Main Endpoints**
- `GET /products` — get product list.
- `GET /products/:id` — get details of 1 product.
- `POST /products` — create new. Supports multipart form-data for image upload (file field: `imageFile`) and text fields: `name`, `price`, `color`, `description`.
- `PUT /products/:id` — replace entire product. Supports file upload via multipart.
- `PATCH /products/:id` — partial update. Supports file upload via multipart.
- `DELETE /products/:id` — delete product and delete corresponding image file if the image is stored in `/uploads/`.

Example creating a product (curl, file upload):

```bash
curl -X POST -F "name=My Device" -F "price=199" -F "color=black" -F "description=Note" -F "imageFile=@/path/to/photo.jpg" http://localhost:3000/products
```

Note: The UI on the homepage uses fetch + FormData to send files, so you don't need to change anything if using the interface.

**Important Behavior**
- On startup, `main.js` attempts to connect to MongoDB with `serverSelectionTimeoutMS: 3000`. If it fails, the application will print a log and use `in-memory` for the entire process lifetime.
- When MongoDB connects successfully and the `products` collection is empty, the repo will seed 10 sample Apple products (with `name`, `price`, `color`, `description`, default empty `imageUrl`).
- Images are saved to disk at `public/uploads/` and served statically by Express; the path stored in DB is relative (`/uploads/<filename>`).
- When updating a product with a new image, the old file if it exists and is located in `/uploads/` will be deleted.

**Limitations & Recommendations**
- Currently the server allows file uploads and saves directly to disk — suitable for demo and dev environments, but not optimal for production (regarding backup, scale, and bandwidth). For production environments, you should use cloud storage (S3/Cloudinary) and only store URLs in DB.
- Add file size limits and MIME type checking if you want more security. I can add `multer` configuration to limit size (e.g., 2MB) and whitelist `image/*`.

**Some Useful Commands**
- Install `nodemon` globally (if desired): `npm i -g nodemon`.
- Check server logs (stdout) to see whether the app is using `mongodb` or `in-memory`.

**I Can Help Further With**
- Adding file size limits and MIME type checking.
- Or migrating image storage to S3/Cloudinary (requires credentials).
- Adding product detail pages or pagination for the list.

