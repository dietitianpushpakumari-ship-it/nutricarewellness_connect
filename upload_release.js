const admin = require("firebase-admin");

// 🔐 Load service account (Ensure this file is in the same directory)
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // 👇 YOUR STORAGE BUCKET
  storageBucket: "nutricarewellness-live.appspot.com",
});

const db = admin.firestore();
const bucket = admin.storage().bucket(); // Initialize Storage

async function addRelease() {
  // 🚀 CATCH ALL 6 ARGUMENTS FROM THE BASH SCRIPT
  const version = process.argv[2];
  const date = process.argv[3];
  const localApkPath = process.argv[4];
  const appName = process.argv[5] || "Nutricare Admin";
  const appType = process.argv[6] || "Administrative"; // 👈 Catches the Tab/Group name
  const description = process.argv[7] || "Official Android release."; // 👈 Catches the Card description

  if (!version || !date || !localApkPath) {
    console.error("❌ Missing arguments. Expected: VERSION DATE FILE_PATH [APP_NAME] [APP_TYPE] [DESCRIPTION]");
    process.exit(1);
  }

  try {
    console.log(`⬆️ Uploading ${appName} APK to Firebase Storage. This may take a minute...`);

    // 1. Upload the file to Firebase Storage
    const destinationPath = `releases/${appName.replace(/\s+/g, '_')}_v${version}.apk`;
    await bucket.upload(localApkPath, {
      destination: destinationPath,
      metadata: { contentType: 'application/vnd.android.package-archive' },
    });

    // 2. Generate a permanent public download link (expires in 2099)
    const [downloadUrl] = await bucket.file(destinationPath).getSignedUrl({
      action: 'read',
      expires: '01-01-2099',
    });

    console.log(`✅ Upload Complete! Permanent Link: ${downloadUrl}`);

    const batch = db.batch();
    const releasesRef = db.collection("releases");

    // 3. Find currently active releases FOR THIS SPECIFIC APP and turn them OFF
    const activeReleases = await releasesRef
      .where("is_active", "==", true)
      .where("app_name", "==", appName)
      .get();

    activeReleases.forEach((doc) => {
      batch.update(doc.ref, { is_active: false });
    });

    // 4. Add the NEW release and turn it ON
    const newReleaseRef = releasesRef.doc(); // Auto-generates an ID
    batch.set(newReleaseRef, {
      version: version,
      release_date: date,
      apk_url: downloadUrl,
      app_name: appName,
      app_type: appType,        // 👈 Saves the Group/Tab name for the UI
      description: description, // 👈 Saves the description for the UI Card
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true,
    });

    // 5. Commit the changes instantly
    await batch.commit();

    console.log(`🎉 Firestore updated. ${appName} v${version} is now LIVE under the '${appType}' tab.`);
    process.exit(0);
  } catch (error) {
    console.error("❌ Error updating Firestore or Storage:", error);
    process.exit(1);
  }
}

addRelease();